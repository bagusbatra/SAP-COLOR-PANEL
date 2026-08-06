/* ============================================================
 * Color Panel Prototype - Business Logic
 * ============================================================
 * Centralized business logic yang cross-entity.
 * File ini akan diporting ke Function Modules di ZFGP_COLOR_PANEL.
 * ============================================================ */

const Biz = {

  /* ============================================================
   * APPROVE REQUEST-DCP
   * Ini adalah operasi paling kompleks di sistem:
   *   1. Validasi: material di SO belum punya Color Code
   *   2. Untuk setiap material di SO:
   *      a. Buat entry ZCP_SO_IMPORT (tracking anti duplikat)
   *      b. Auto-generate Color Code baru (KW00001, dst)
   *      c. Buat DCP Header (DCP-YYYY-NNNN)
   *      d. Generate 15 panel DCP status NON-AKTIF
   *   3. Update status Request → APPROVED
   *   4. Audit log
   * ============================================================ */

  approveRequest(requestId) {
    const req = DB.find('requests', 'request_id', requestId);
    if (!req) return { ok: false, msg: 'Request tidak ditemukan' };
    if (req.status !== REQ_STATUS.PENDING) {
      return { ok: false, msg: 'Request sudah diproses sebelumnya' };
    }

    const so = DB.getSalesOrder(req.so_number);
    if (!so) return { ok: false, msg: `SO ${req.so_number} tidak ditemukan` };
    if (!so.items || so.items.length === 0) {
      return { ok: false, msg: 'SO tidak memiliki item material' };
    }

    /* Pre-validation: pastikan semua material di SO belum punya Color Code */
    const conflicts = [];
    for (const item of so.items) {
      if (DB.materialHasColorCode(item.matnr)) {
        conflicts.push(`${item.matnr} (${DB.getMaterialName(item.matnr)})`);
      }
      if (DB.soAlreadyImported(req.so_number, item.matnr)) {
        conflicts.push(`${item.matnr} sudah pernah di-import dari SO ini`);
      }
    }
    if (conflicts.length > 0) {
      return {
        ok: false,
        msg: 'Material sudah punya Color Code atau sudah pernah di-import:\n\n- ' + conflicts.join('\n- ') +
             '\n\nGunakan halaman Renewal untuk material yang sudah ada Color Code-nya.'
      };
    }

    const session = Auth.getSession();
    const now = Utils.now();
    const today = Utils.today();
    const createdDcps = [];

    /* Loop tiap material di SO — 1 material = 1 DCP */
    for (const item of so.items) {
      /* 1. Auto-generate Color Code */
      const colorSeq = DB.nextColorCodeSeq();
      const colorCode = Utils.generateColorCode(colorSeq);
      const material = DB.getMaterial(item.matnr) || {};

      DB.insert('color_codes', {
        color_code: colorCode,
        matnr: item.matnr,
        maktx: material.maktx || item.matnr,
        buyer_id: req.buyer_id,
        color_name: material.maktx || item.matnr, // default = material name, admin bisa rename
        color_hex: '#E2E8F0', // default, admin bisa ubah nanti
        component: '',
        status: COLOR_CODE_STATUS.ACTIVE,
        remarks: `Auto-created dari Request ${req.request_id}`,
        created_by: session.user_id,
        created_at: now,
      });

      /* 2. Buat DCP Header */
      const dcpSeq = DB.nextSeq(ID_PREFIX.DCP);
      const dcpId = Utils.generateId(ID_PREFIX.DCP, dcpSeq);
      const expiryDate = Utils.addDays(today, CONFIG.DCP_EXPIRY_DAYS);
      const reminderDate = Utils.addDays(today, CONFIG.DCP_REMINDER_DAYS);

      DB.insert('dcp_headers', {
        dcp_id: dcpId,
        request_id: req.request_id,
        so_number: req.so_number,
        so_item: item.so_item,
        matnr: item.matnr,
        maktx: material.maktx || item.matnr,
        color_code: colorCode,
        buyer_id: req.buyer_id,
        sales_user: req.sales_user,
        qty_total: item.menge,
        qty_active: 0,
        qty_approved: 0,
        qty_rejected: 0,
        mfg_date: '',
        expire_date: expiryDate,
        reminder_date: reminderDate,
        status: DCP_HDR_STATUS.OPEN,
        remarks: '',
        created_by: session.user_id,
        created_at: now,
      });

      /* 3. Insert entry ZCP_SO_IMPORT (anti duplikat) */
      DB.insert('so_imports', {
        so_number: req.so_number,
        so_item: item.so_item,
        matnr: item.matnr,
        menge: item.menge,
        meins: item.meins,
        request_id: req.request_id,
        dcp_id: dcpId,
        imported_by: session.user_id,
        imported_at: now,
        remarks: '',
        created_by: session.user_id,
        created_at: now,
      });

      /* 4. Generate panel DCP status NON-AKTIF sebanyak qty */
      for (let n = 1; n <= item.menge; n++) {
        const panelId = Utils.generatePanelId(dcpId, n);
        DB.insert('dcp_items', {
          dcp_id: dcpId,
          panel_number: n,
          panel_id: panelId,
          qr_token: Utils.generateToken(),
          status: DCP_PANEL_STATUS.NON_ACTIVE,
          mfg_date: '',
          photo_count: 0,
          undo_flag: '',
          created_by: session.user_id,
          created_at: now,
        });
      }

      DB.audit('DCP', dcpId, 'CREATE',
        `Auto-create DCP ${dcpId} dari SO ${req.so_number}, material ${item.matnr}, qty ${item.menge}, Color Code ${colorCode}`);

      createdDcps.push({
        dcp_id: dcpId,
        color_code: colorCode,
        matnr: item.matnr,
        qty: item.menge,
      });
    }

    /* Update request status */
    DB.update('requests', 'request_id', requestId, {
      status: REQ_STATUS.APPROVED,
      approved_by: session.user_id,
      approved_at: now,
      changed_by: session.user_id,
      changed_at: now,
    });

    DB.audit('REQUEST', requestId, 'APPROVE',
      `Approve Request ${requestId}. ${createdDcps.length} DCP dibuat: ${createdDcps.map(d => d.dcp_id).join(', ')}`);

    return { ok: true, dcps: createdDcps };
  },

  /* ============================================================
   * REJECT REQUEST-DCP
   * ============================================================ */

  rejectRequest(requestId, reason) {
    const req = DB.find('requests', 'request_id', requestId);
    if (!req) return { ok: false, msg: 'Request tidak ditemukan' };
    if (req.status !== REQ_STATUS.PENDING) {
      return { ok: false, msg: 'Request sudah diproses sebelumnya' };
    }
    if (!reason || !reason.trim()) {
      return { ok: false, msg: 'Alasan reject wajib diisi' };
    }

    const session = Auth.getSession();
    const now = Utils.now();

    DB.update('requests', 'request_id', requestId, {
      status: REQ_STATUS.REJECTED,
      reject_reason: reason.trim(),
      approved_by: session.user_id,
      approved_at: now,
      changed_by: session.user_id,
      changed_at: now,
    });

    DB.audit('REQUEST', requestId, 'REJECT',
      `Reject Request ${requestId}. Alasan: ${reason.trim()}`);

    return { ok: true };
  },

  /* ============================================================
   * DCP PANEL OPERATIONS
   * ============================================================ */

  /* Aktivasi panel: NA -> AK. Admin bebas isi mfg_date. */
  activateDcpPanel(dcpId, panelNumber, mfgDate) {
    const panel = DB.filter('dcp_items', p =>
      p.dcp_id === dcpId && p.panel_number === panelNumber)[0];
    if (!panel) return { ok: false, msg: 'Panel tidak ditemukan' };
    if (panel.status !== DCP_PANEL_STATUS.NON_ACTIVE) {
      return { ok: false, msg: 'Panel bukan status NON-AKTIF' };
    }
    if (!mfgDate) return { ok: false, msg: 'Tanggal dibuat wajib diisi' };

    const session = Auth.getSession();
    const now = Utils.now();

    DB.updateWhere('dcp_items',
      p => p.dcp_id === dcpId && p.panel_number === panelNumber,
      {
        status: DCP_PANEL_STATUS.ACTIVE,
        mfg_date: mfgDate,
        activated_at: now,
        activated_by: session.user_id,
        changed_at: now,
        changed_by: session.user_id,
      }
    );

    /* Update counter di header */
    this._recalcDcpHeaderCounters(dcpId);

    /* Update mfg_date di header kalau ini panel pertama yang aktif */
    const hdr = DB.find('dcp_headers', 'dcp_id', dcpId);
    if (hdr && !hdr.mfg_date) {
      DB.update('dcp_headers', 'dcp_id', dcpId, {
        mfg_date: mfgDate,
        expire_date: Utils.addDays(mfgDate, CONFIG.DCP_EXPIRY_DAYS),
        reminder_date: Utils.addDays(mfgDate, CONFIG.DCP_REMINDER_DAYS),
      });
    }

    DB.audit('DCP', dcpId, 'ACTIVATE',
      `Aktivasi panel ${panel.panel_id}, mfg_date=${mfgDate}`);

    return { ok: true };
  },

  /* Submit panel: AK -> SB, dengan min 2 foto */
  submitDcpPanel(dcpId, panelNumber, photos) {
    const panel = DB.filter('dcp_items', p =>
      p.dcp_id === dcpId && p.panel_number === panelNumber)[0];
    if (!panel) return { ok: false, msg: 'Panel tidak ditemukan' };
    if (panel.status !== DCP_PANEL_STATUS.ACTIVE) {
      return { ok: false, msg: 'Panel harus dalam status AKTIF untuk di-submit' };
    }
    if (!photos || photos.length < CONFIG.MIN_PHOTO_PER_PANEL) {
      return {
        ok: false,
        msg: `Minimal ${CONFIG.MIN_PHOTO_PER_PANEL} foto (saat ini: ${photos ? photos.length : 0})`
      };
    }

    const session = Auth.getSession();
    const now = Utils.now();

    /* Simpan foto (simulasi DMS ZDCP) */
    for (let i = 0; i < photos.length; i++) {
      const p = photos[i];
      const photoSeq = DB.nextSeq(ID_PREFIX.PHOTO);
      const photoId = Utils.generateId(ID_PREFIX.PHOTO, photoSeq);

      DB.insert('photos', {
        photo_id: photoId,
        ref_type: 'DCP',
        ref_id: dcpId,
        panel_number: panelNumber,
        panel_id: panel.panel_id,
        photo_seq: i + 1,
        dms_doc_type: CONFIG.DMS_TYPE_DCP,
        dms_docnum: `SIM-${photoId}`, // simulated DMS
        dms_docpart: '000',
        dms_docvers: '00',
        file_name: p.name,
        base64: p.base64, // simpan base64 buat preview (di BSP nanti pakai DMS)
        uploaded_by: session.user_id,
        uploaded_at: now,
        created_by: session.user_id,
        created_at: now,
      });
    }

    DB.updateWhere('dcp_items',
      p => p.dcp_id === dcpId && p.panel_number === panelNumber,
      {
        status: DCP_PANEL_STATUS.SUBMITTED,
        submitted_at: now,
        submitted_by: session.user_id,
        photo_count: photos.length,
        changed_at: now,
        changed_by: session.user_id,
      }
    );

    DB.audit('DCP', dcpId, 'SUBMIT_PANEL',
      `Submit panel ${panel.panel_id} dengan ${photos.length} foto`);

    return { ok: true };
  },

  /* Approve panel: SB -> AP -> langsung jadi MCP item (stiker ditimpa) */
  approveDcpPanel(dcpId, panelNumber) {
    const panel = DB.filter('dcp_items', p =>
      p.dcp_id === dcpId && p.panel_number === panelNumber)[0];
    if (!panel) return { ok: false, msg: 'Panel tidak ditemukan' };
    if (panel.status !== DCP_PANEL_STATUS.SUBMITTED) {
      return { ok: false, msg: 'Panel harus dalam status SUBMITTED untuk di-approve' };
    }

    const session = Auth.getSession();
    const now = Utils.now();
    const hdr = DB.find('dcp_headers', 'dcp_id', dcpId);
    if (!hdr) return { ok: false, msg: 'DCP Header tidak ditemukan' };

    /* 1. Cari atau buat MCP Header
     *    Menurut keputusan: MCP header dibuat saat panel DCP PERTAMA di-approve
     */
    let mcpHdr = DB.filter('mcp_headers', m => m.dcp_id === dcpId && m.status !== MCP_HDR_STATUS.REJECTED)[0];

    if (!mcpHdr) {
      const mcpSeq = DB.nextSeq(ID_PREFIX.MCP);
      const mcpId = Utils.generateId(ID_PREFIX.MCP, mcpSeq);

      mcpHdr = {
        mcp_id: mcpId,
        dcp_id: dcpId,
        so_number: hdr.so_number,
        matnr: hdr.matnr,
        maktx: hdr.maktx,
        color_code: hdr.color_code,
        buyer_id: hdr.buyer_id,
        qty_total: hdr.qty_total,
        qty_approved: 0,
        qty_obsolete: 0,
        mfg_date: hdr.mfg_date,
        expire_date: hdr.expire_date,
        renewal_date: '',
        status: MCP_HDR_STATUS.OPEN,
        is_renewed: '',
        parent_mcp_id: '',
        remarks: '',
        created_by: session.user_id,
        created_at: now,
      };
      DB.insert('mcp_headers', mcpHdr);

      /* Bangkitkan 15 slot MCP dengan status BLANK (polos), kecuali slot ini yg jadi DCP-APPROVED */
      for (let n = 1; n <= hdr.qty_total; n++) {
        const dcpPanel = DB.filter('dcp_items', p =>
          p.dcp_id === dcpId && p.panel_number === n)[0];
        const mcpPanelId = Utils.generatePanelId(mcpId, n);

        DB.insert('mcp_items', {
          mcp_id: mcpId,
          panel_number: n,
          panel_id: mcpPanelId,
          dcp_panel_id: dcpPanel ? dcpPanel.panel_id : '',
          qr_token: Utils.generateToken(),
          status: (n === panelNumber) ? MCP_PANEL_STATUS.DCP_APPROVED : MCP_PANEL_STATUS.BLANK,
          mfg_date: (n === panelNumber) ? panel.mfg_date : '',
          expire_date: hdr.expire_date,
          created_by: session.user_id,
          created_at: now,
        });
      }

      DB.audit('MCP', mcpId, 'CREATE',
        `Auto-create MCP ${mcpId} dari DCP ${dcpId} (panel #${panelNumber} approved pertama)`);
    } else {
      /* MCP header sudah ada — update slot yang sesuai */
      DB.updateWhere('mcp_items',
        p => p.mcp_id === mcpHdr.mcp_id && p.panel_number === panelNumber,
        {
          status: MCP_PANEL_STATUS.DCP_APPROVED,
          dcp_panel_id: panel.panel_id,
          mfg_date: panel.mfg_date,
          changed_at: now,
          changed_by: session.user_id,
        }
      );
    }

    /* 2. Update DCP panel: APPROVED + link ke MCP */
    DB.updateWhere('dcp_items',
      p => p.dcp_id === dcpId && p.panel_number === panelNumber,
      {
        status: DCP_PANEL_STATUS.APPROVED,
        approved_at: now,
        approved_by: session.user_id,
        mcp_id: mcpHdr.mcp_id,
        changed_at: now,
        changed_by: session.user_id,
      }
    );

    this._recalcDcpHeaderCounters(dcpId);

    DB.audit('DCP', dcpId, 'APPROVE_PANEL',
      `Approve panel ${panel.panel_id} — naik ke MCP ${mcpHdr.mcp_id} (stiker ditimpa)`);

    return { ok: true, mcp_id: mcpHdr.mcp_id };
  },

  /* Reject panel: SB -> RJ */
  rejectDcpPanel(dcpId, panelNumber, reason) {
    const panel = DB.filter('dcp_items', p =>
      p.dcp_id === dcpId && p.panel_number === panelNumber)[0];
    if (!panel) return { ok: false, msg: 'Panel tidak ditemukan' };
    if (panel.status !== DCP_PANEL_STATUS.SUBMITTED) {
      return { ok: false, msg: 'Panel harus dalam status SUBMITTED untuk di-reject' };
    }
    if (!reason || !reason.trim()) return { ok: false, msg: 'Alasan wajib diisi' };

    const session = Auth.getSession();
    const now = Utils.now();

    DB.updateWhere('dcp_items',
      p => p.dcp_id === dcpId && p.panel_number === panelNumber,
      {
        status: DCP_PANEL_STATUS.REJECTED,
        rejected_at: now,
        rejected_by: session.user_id,
        reject_reason: reason.trim(),
        changed_at: now,
        changed_by: session.user_id,
      }
    );

    this._recalcDcpHeaderCounters(dcpId);

    DB.audit('DCP', dcpId, 'REJECT_PANEL',
      `Reject panel ${panel.panel_id}. Alasan: ${reason.trim()}`);

    return { ok: true };
  },

  /* Undo: kembalikan panel dari RJ ke SB (fitur "salah pencet") */
  undoDcpPanel(dcpId, panelNumber) {
    const panel = DB.filter('dcp_items', p =>
      p.dcp_id === dcpId && p.panel_number === panelNumber)[0];
    if (!panel) return { ok: false, msg: 'Panel tidak ditemukan' };
    if (panel.status !== DCP_PANEL_STATUS.REJECTED) {
      return { ok: false, msg: 'Undo hanya berlaku untuk panel status REJECTED' };
    }

    const session = Auth.getSession();
    const now = Utils.now();

    DB.updateWhere('dcp_items',
      p => p.dcp_id === dcpId && p.panel_number === panelNumber,
      {
        status: DCP_PANEL_STATUS.SUBMITTED,
        rejected_at: '',
        rejected_by: '',
        reject_reason: '',
        undo_flag: 'X',
        changed_at: now,
        changed_by: session.user_id,
      }
    );

    this._recalcDcpHeaderCounters(dcpId);
    DB.audit('DCP', dcpId, 'UNDO_PANEL', `Undo reject panel ${panel.panel_id}`);
    return { ok: true };
  },

  /* Close DCP header: min 1 panel approved */
  closeDcpHeader(dcpId) {
    const hdr = DB.find('dcp_headers', 'dcp_id', dcpId);
    if (!hdr) return { ok: false, msg: 'DCP tidak ditemukan' };
    if (hdr.status !== DCP_HDR_STATUS.OPEN) {
      return { ok: false, msg: 'DCP sudah closed/rejected' };
    }

    const items = DB.filter('dcp_items', p => p.dcp_id === dcpId);
    const approvedCount = items.filter(p => p.status === DCP_PANEL_STATUS.APPROVED).length;
    if (approvedCount < CONFIG.MIN_APPROVE_DCP_CLOSE) {
      return {
        ok: false,
        msg: `Minimal ${CONFIG.MIN_APPROVE_DCP_CLOSE} panel harus di-approve dulu (saat ini: ${approvedCount})`
      };
    }

    const session = Auth.getSession();
    const now = Utils.now();

    /* Sisa panel yang belum approved (NA/AK/SB) -> tetap seperti apa adanya (bisa lanjut nanti),
     * tapi header sudah CLOSED. Sesuai konsep: panel yg approved lanjut ke MCP,
     * yg reject tetap reject, yg NA/AK/SB tidak bisa maju lagi setelah header closed. */
    DB.update('dcp_headers', 'dcp_id', dcpId, {
      status: DCP_HDR_STATUS.CLOSED,
      closed_at: now,
      closed_by: session.user_id,
      changed_at: now,
      changed_by: session.user_id,
    });

    DB.audit('DCP', dcpId, 'CLOSE',
      `Close DCP ${dcpId}. ${approvedCount} panel approved (naik ke MCP), sisanya tetap.`);

    return { ok: true, approved: approvedCount };
  },

  /* Reject seluruh DCP header (buyer tidak jadi beli) */
  rejectDcpHeader(dcpId, reason) {
    const hdr = DB.find('dcp_headers', 'dcp_id', dcpId);
    if (!hdr) return { ok: false, msg: 'DCP tidak ditemukan' };
    if (hdr.status !== DCP_HDR_STATUS.OPEN) {
      return { ok: false, msg: 'DCP sudah closed/rejected' };
    }
    if (!reason || !reason.trim()) return { ok: false, msg: 'Alasan wajib diisi' };

    const session = Auth.getSession();
    const now = Utils.now();

    DB.update('dcp_headers', 'dcp_id', dcpId, {
      status: DCP_HDR_STATUS.REJECTED,
      close_reason: reason.trim(),
      closed_at: now,
      closed_by: session.user_id,
      changed_at: now,
      changed_by: session.user_id,
    });

    /* Semua panel yg belum approved -> OBSOLETE */
    DB.updateWhere('dcp_items',
      p => p.dcp_id === dcpId && p.status !== DCP_PANEL_STATUS.APPROVED,
      { status: DCP_PANEL_STATUS.OBSOLETE, changed_at: now, changed_by: session.user_id }
    );

    DB.audit('DCP', dcpId, 'REJECT_HDR', `Reject DCP ${dcpId}. Alasan: ${reason.trim()}`);
    return { ok: true };
  },

  /* Recalc counters di DCP header */
  _recalcDcpHeaderCounters(dcpId) {
    const items = DB.filter('dcp_items', p => p.dcp_id === dcpId);
    const active = items.filter(p =>
      p.status === DCP_PANEL_STATUS.ACTIVE ||
      p.status === DCP_PANEL_STATUS.SUBMITTED ||
      p.status === DCP_PANEL_STATUS.APPROVED).length;
    const approved = items.filter(p => p.status === DCP_PANEL_STATUS.APPROVED).length;
    const rejected = items.filter(p => p.status === DCP_PANEL_STATUS.REJECTED).length;
    DB.update('dcp_headers', 'dcp_id', dcpId, {
      qty_active: active,
      qty_approved: approved,
      qty_rejected: rejected,
    });
  },

  /* ============================================================
   * MCP PANEL OPERATIONS
   * ============================================================
   *
   * Panel MCP bisa datang dari 2 sumber:
   * (a) DCP-APPROVED — panel dari DCP yang di-approve (stiker DCP ditimpa MCP)
   *     Status setelah masuk MCP: DCP_APPROVED (DA)
   *     Perlu di-submit + approve lagi di MCP untuk jadi MCP-APPROVED (AP)
   * (b) BLANK (BL) — slot polos yang belum pernah lewat DCP
   *     Admin bisa "start" slot polos ini dan langsung submit foto
   *
   * Approve MCP butuh min 3 panel untuk close.
   */

  /* Start blank slot: BL -> DA (siap disubmit) */
  startBlankMcpSlot(mcpId, panelNumber, mfgDate) {
    const panel = DB.filter('mcp_items', p =>
      p.mcp_id === mcpId && p.panel_number === panelNumber)[0];
    if (!panel) return { ok: false, msg: 'Slot tidak ditemukan' };
    if (panel.status !== MCP_PANEL_STATUS.BLANK) {
      return { ok: false, msg: 'Slot bukan status BLANK' };
    }
    if (!mfgDate) return { ok: false, msg: 'Tanggal wajib diisi' };

    const session = Auth.getSession();
    const now = Utils.now();

    DB.updateWhere('mcp_items',
      p => p.mcp_id === mcpId && p.panel_number === panelNumber,
      {
        status: MCP_PANEL_STATUS.DCP_APPROVED,
        mfg_date: mfgDate,
        changed_at: now,
        changed_by: session.user_id,
      }
    );

    DB.audit('MCP', mcpId, 'START_BLANK',
      `Start slot polos MCP ${panel.panel_id}, mfg_date=${mfgDate}`);
    return { ok: true };
  },

  /* Submit MCP panel: DA -> SB */
  submitMcpPanel(mcpId, panelNumber, photos) {
    const panel = DB.filter('mcp_items', p =>
      p.mcp_id === mcpId && p.panel_number === panelNumber)[0];
    if (!panel) return { ok: false, msg: 'Panel tidak ditemukan' };
    if (panel.status !== MCP_PANEL_STATUS.DCP_APPROVED) {
      return { ok: false, msg: 'Panel harus status DCP-APPROVED untuk di-submit' };
    }
    if (!photos || photos.length < CONFIG.MIN_PHOTO_PER_PANEL) {
      return {
        ok: false,
        msg: `Minimal ${CONFIG.MIN_PHOTO_PER_PANEL} foto (saat ini: ${photos ? photos.length : 0})`
      };
    }

    const session = Auth.getSession();
    const now = Utils.now();

    for (let i = 0; i < photos.length; i++) {
      const p = photos[i];
      const photoSeq = DB.nextSeq(ID_PREFIX.PHOTO);
      const photoId = Utils.generateId(ID_PREFIX.PHOTO, photoSeq);
      DB.insert('photos', {
        photo_id: photoId,
        ref_type: 'MCP',
        ref_id: mcpId,
        panel_number: panelNumber,
        panel_id: panel.panel_id,
        photo_seq: i + 1,
        dms_doc_type: CONFIG.DMS_TYPE_MCP,
        dms_docnum: `SIM-${photoId}`,
        dms_docpart: '000',
        dms_docvers: '00',
        file_name: p.name,
        base64: p.base64,
        uploaded_by: session.user_id,
        uploaded_at: now,
        created_by: session.user_id,
        created_at: now,
      });
    }

    DB.updateWhere('mcp_items',
      p => p.mcp_id === mcpId && p.panel_number === panelNumber,
      {
        status: MCP_PANEL_STATUS.SUBMITTED,
        submitted_at: now,
        submitted_by: session.user_id,
        photo_count: photos.length,
        changed_at: now,
        changed_by: session.user_id,
      }
    );

    DB.audit('MCP', mcpId, 'SUBMIT_PANEL',
      `Submit panel MCP ${panel.panel_id} dengan ${photos.length} foto`);
    return { ok: true };
  },

  /* Approve MCP panel: SB -> AP (MCP-APPROVED, panel master hidup) */
  approveMcpPanel(mcpId, panelNumber) {
    const panel = DB.filter('mcp_items', p =>
      p.mcp_id === mcpId && p.panel_number === panelNumber)[0];
    if (!panel) return { ok: false, msg: 'Panel tidak ditemukan' };
    if (panel.status !== MCP_PANEL_STATUS.SUBMITTED) {
      return { ok: false, msg: 'Panel harus status SUBMITTED untuk di-approve' };
    }

    const session = Auth.getSession();
    const now = Utils.now();

    DB.updateWhere('mcp_items',
      p => p.mcp_id === mcpId && p.panel_number === panelNumber,
      {
        status: MCP_PANEL_STATUS.APPROVED,
        approved_at: now,
        approved_by: session.user_id,
        changed_at: now,
        changed_by: session.user_id,
      }
    );

    this._recalcMcpHeaderCounters(mcpId);
    DB.audit('MCP', mcpId, 'APPROVE_PANEL',
      `Approve MCP panel ${panel.panel_id} — master color panel hidup`);
    return { ok: true };
  },

  /* Reject MCP panel: SB -> revert ke DA (bisa di-submit ulang dengan foto baru) */
  rejectMcpPanel(mcpId, panelNumber, reason) {
    const panel = DB.filter('mcp_items', p =>
      p.mcp_id === mcpId && p.panel_number === panelNumber)[0];
    if (!panel) return { ok: false, msg: 'Panel tidak ditemukan' };
    if (panel.status !== MCP_PANEL_STATUS.SUBMITTED) {
      return { ok: false, msg: 'Panel harus status SUBMITTED untuk di-reject' };
    }
    if (!reason || !reason.trim()) return { ok: false, msg: 'Alasan wajib diisi' };

    const session = Auth.getSession();
    const now = Utils.now();

    /* Revert ke DA supaya bisa submit ulang dengan foto lain */
    DB.updateWhere('mcp_items',
      p => p.mcp_id === mcpId && p.panel_number === panelNumber,
      {
        status: MCP_PANEL_STATUS.DCP_APPROVED,
        photo_count: 0,
        submitted_at: '',
        submitted_by: '',
        remarks: reason.trim(),
        changed_at: now,
        changed_by: session.user_id,
      }
    );

    /* Hapus foto yang sudah di-upload */
    const photos = DB.filter('photos', p =>
      p.ref_type === 'MCP' && p.ref_id === mcpId && p.panel_number === panelNumber);
    for (const ph of photos) {
      DB.delete('photos', 'photo_id', ph.photo_id);
    }

    DB.audit('MCP', mcpId, 'REJECT_PANEL',
      `Reject submit panel ${panel.panel_id}. Alasan: ${reason.trim()}. Foto dihapus, siap submit ulang.`);
    return { ok: true };
  },

  /* Close MCP header: min 3 panel approved */
  closeMcpHeader(mcpId) {
    const hdr = DB.find('mcp_headers', 'mcp_id', mcpId);
    if (!hdr) return { ok: false, msg: 'MCP tidak ditemukan' };
    if (hdr.status !== MCP_HDR_STATUS.OPEN) {
      return { ok: false, msg: 'MCP sudah closed/rejected' };
    }

    const items = DB.filter('mcp_items', p => p.mcp_id === mcpId);
    const approvedCount = items.filter(p => p.status === MCP_PANEL_STATUS.APPROVED).length;
    if (approvedCount < CONFIG.MIN_APPROVE_MCP_CLOSE) {
      return {
        ok: false,
        msg: `Minimal ${CONFIG.MIN_APPROVE_MCP_CLOSE} panel harus di-approve dulu (saat ini: ${approvedCount})`
      };
    }

    const session = Auth.getSession();
    const now = Utils.now();

    /* Sisa panel yang bukan APPROVED -> OBSOLETE */
    DB.updateWhere('mcp_items',
      p => p.mcp_id === mcpId && p.status !== MCP_PANEL_STATUS.APPROVED,
      {
        status: MCP_PANEL_STATUS.OBSOLETE,
        obsolete_at: now,
        obsolete_by: session.user_id,
        obsolete_reason: 'MCP closed — bukan approved',
        changed_at: now,
        changed_by: session.user_id,
      }
    );

    DB.update('mcp_headers', 'mcp_id', mcpId, {
      status: MCP_HDR_STATUS.CLOSED,
      closed_at: now,
      closed_by: session.user_id,
      changed_at: now,
      changed_by: session.user_id,
    });

    this._recalcMcpHeaderCounters(mcpId);

    DB.audit('MCP', mcpId, 'CLOSE',
      `Close MCP ${mcpId}. ${approvedCount} panel hidup sebagai master, sisa OBSOLETE.`);
    return { ok: true, approved: approvedCount };
  },

  /* Recalc counters MCP header */
  _recalcMcpHeaderCounters(mcpId) {
    const items = DB.filter('mcp_items', p => p.mcp_id === mcpId);
    const approved = items.filter(p => p.status === MCP_PANEL_STATUS.APPROVED).length;
    const obsolete = items.filter(p => p.status === MCP_PANEL_STATUS.OBSOLETE).length;
    DB.update('mcp_headers', 'mcp_id', mcpId, {
      qty_approved: approved,
      qty_obsolete: obsolete,
    });
  },

  /* ============================================================
   * RENEWAL MCP
   * ============================================================
   *
   * Alur:
   * 1. Sales siapkan SO baru dengan material color yang SAMA (sudah ada Color Code)
   * 2. Admin input SO number di halaman renewal
   * 3. Sistem detect MCP lama berdasarkan material di SO
   * 4. MCP lama -> OBSOLETE, panel-nya juga OBSOLETE
   * 5. Buat MCP baru dengan expire refreshed, parent_mcp_id = MCP lama
   * 6. 15 slot BLANK di MCP baru — admin/color room isi ulang
   */

  findRenewalCandidate(soNumber) {
    const so = DB.getSalesOrder(soNumber);
    if (!so) return { ok: false, msg: `SO ${soNumber} tidak ditemukan` };

    const results = [];
    for (const item of so.items) {
      if (!DB.materialHasColorCode(item.matnr)) {
        results.push({
          matnr: item.matnr,
          maktx: DB.getMaterialName(item.matnr),
          menge: item.menge,
          status: 'no_color_code',
          note: 'Material belum punya Color Code — tidak bisa renewal (harus lewat Request DCP baru)',
        });
        continue;
      }

      /* Cari MCP paling terbaru (yang belum obsolete) untuk material ini */
      const mcps = DB.filter('mcp_headers', m =>
        m.matnr === item.matnr &&
        (m.status === MCP_HDR_STATUS.CLOSED || m.status === MCP_HDR_STATUS.OPEN) &&
        m.is_renewed !== 'X'
      ).sort((a, b) => (b.created_at || '').localeCompare(a.created_at || ''));

      if (mcps.length === 0) {
        results.push({
          matnr: item.matnr,
          maktx: DB.getMaterialName(item.matnr),
          menge: item.menge,
          status: 'no_mcp',
          note: 'Ada Color Code tapi belum ada MCP aktif',
        });
        continue;
      }

      const oldMcp = mcps[0];
      results.push({
        matnr: item.matnr,
        maktx: DB.getMaterialName(item.matnr),
        menge: item.menge,
        status: 'renewable',
        old_mcp: oldMcp,
        color_code: oldMcp.color_code,
        so_item: item.so_item,
        meins: item.meins,
      });
    }
    return { ok: true, so: so, results: results };
  },

  executeRenewal(soNumber, selectedMaterials) {
    const check = this.findRenewalCandidate(soNumber);
    if (!check.ok) return check;

    /* Cek anti-duplikat SO import */
    const conflicts = [];
    for (const m of selectedMaterials) {
      if (DB.soAlreadyImported(soNumber, m.matnr)) {
        conflicts.push(m.matnr);
      }
    }
    if (conflicts.length > 0) {
      return { ok: false, msg: `Material sudah pernah di-import dari SO ini: ${conflicts.join(', ')}` };
    }

    const session = Auth.getSession();
    const now = Utils.now();
    const today = Utils.today();
    const created = [];

    for (const m of selectedMaterials) {
      const oldMcp = m.old_mcp;

      /* 1. Set MCP lama & panelnya jadi OBSOLETE */
      DB.update('mcp_headers', 'mcp_id', oldMcp.mcp_id, {
        status: MCP_HDR_STATUS.CLOSED,
        is_renewed: 'X',
        renewal_date: today,
        changed_at: now,
        changed_by: session.user_id,
      });
      DB.updateWhere('mcp_items',
        p => p.mcp_id === oldMcp.mcp_id && p.status !== MCP_PANEL_STATUS.OBSOLETE,
        {
          status: MCP_PANEL_STATUS.OBSOLETE,
          obsolete_at: now,
          obsolete_by: session.user_id,
          obsolete_reason: `Renewal — digantikan MCP baru dari SO ${soNumber}`,
          changed_at: now,
          changed_by: session.user_id,
        }
      );

      /* 2. Buat MCP baru */
      const mcpSeq = DB.nextSeq(ID_PREFIX.MCP);
      const newMcpId = Utils.generateId(ID_PREFIX.MCP, mcpSeq);
      const expiryDate = Utils.addDays(today, CONFIG.MCP_EXPIRY_DAYS);

      DB.insert('mcp_headers', {
        mcp_id: newMcpId,
        dcp_id: '', // renewal tidak lewat DCP
        so_number: soNumber,
        matnr: m.matnr,
        maktx: m.maktx,
        color_code: m.color_code,
        buyer_id: check.so.buyer_id,
        qty_total: m.menge,
        qty_approved: 0,
        qty_obsolete: 0,
        mfg_date: today,
        expire_date: expiryDate,
        renewal_date: today,
        status: MCP_HDR_STATUS.OPEN,
        is_renewed: '',
        parent_mcp_id: oldMcp.mcp_id,
        remarks: `Renewal dari MCP ${oldMcp.mcp_id}`,
        created_by: session.user_id,
        created_at: now,
      });

      /* 3. Buat 15 slot BLANK (menunggu admin isi) */
      for (let n = 1; n <= m.menge; n++) {
        const panelId = Utils.generatePanelId(newMcpId, n);
        DB.insert('mcp_items', {
          mcp_id: newMcpId,
          panel_number: n,
          panel_id: panelId,
          dcp_panel_id: '',
          qr_token: Utils.generateToken(),
          status: MCP_PANEL_STATUS.BLANK,
          mfg_date: '',
          expire_date: expiryDate,
          created_by: session.user_id,
          created_at: now,
        });
      }

      /* 4. Insert SO import tracking */
      DB.insert('so_imports', {
        so_number: soNumber,
        so_item: m.so_item,
        matnr: m.matnr,
        menge: m.menge,
        meins: m.meins,
        request_id: '', // renewal tidak lewat request
        dcp_id: '',
        imported_by: session.user_id,
        imported_at: now,
        remarks: `Renewal — parent MCP ${oldMcp.mcp_id}`,
        created_by: session.user_id,
        created_at: now,
      });

      DB.audit('MCP', newMcpId, 'RENEWAL',
        `Renewal MCP ${newMcpId} dari MCP ${oldMcp.mcp_id} (SO ${soNumber}, material ${m.matnr})`);
      DB.audit('MCP', oldMcp.mcp_id, 'OBSOLETE',
        `MCP ${oldMcp.mcp_id} obsolete karena renewal → ${newMcpId}`);

      created.push({ new_mcp_id: newMcpId, old_mcp_id: oldMcp.mcp_id, matnr: m.matnr });
    }

    return { ok: true, created: created };
  },

  /* ============================================================
   * CREATE REQUEST-DCP (dari Sales)
   * ============================================================ */

  createRequest(soNumber, remarks) {
    const so = DB.getSalesOrder(soNumber);
    if (!so) return { ok: false, msg: `SO ${soNumber} tidak ditemukan di sistem` };

    const session = Auth.getSession();

    /* Validasi role SALES: buyer di SO harus match dengan buyer user */
    if (Auth.hasRole(ROLES.SALES) && !Auth.hasRole(ROLES.ADMIN) && !Auth.hasRole(ROLES.IT)) {
      if (session.buyer_id && so.buyer_id !== session.buyer_id) {
        return { ok: false, msg: 'SO ini bukan milik buyer Anda' };
      }
    }

    /* Cek: apakah ada request PENDING/APPROVED untuk SO ini? */
    const existing = DB.filter('requests', r =>
      r.so_number === soNumber &&
      (r.status === REQ_STATUS.PENDING || r.status === REQ_STATUS.APPROVED)
    );
    if (existing.length > 0) {
      return {
        ok: false,
        msg: `SO ${soNumber} sudah pernah di-request (Request ID: ${existing[0].request_id}, status: ${REQ_STATUS_LABEL[existing[0].status]})`
      };
    }

    /* Cek material di SO: min 1 material harus belum punya Color Code */
    const newMaterials = so.items.filter(item => !DB.materialHasColorCode(item.matnr));
    if (newMaterials.length === 0) {
      return {
        ok: false,
        msg: 'Semua material di SO ini sudah punya Color Code. Gunakan halaman Renewal MCP.'
      };
    }

    const seq = DB.nextSeq(ID_PREFIX.REQUEST);
    const requestId = Utils.generateId(ID_PREFIX.REQUEST, seq);
    const now = Utils.now();

    DB.insert('requests', {
      request_id: requestId,
      so_number: soNumber,
      sales_user: session.user_id,
      buyer_id: so.buyer_id,
      request_date: Utils.today(),
      status: REQ_STATUS.PENDING,
      reject_reason: '',
      remarks: remarks || '',
      created_by: session.user_id,
      created_at: now,
    });

    DB.audit('REQUEST', requestId, 'CREATE',
      `Buat Request DCP untuk SO ${soNumber} (${so.items.length} material)`);

    return { ok: true, request_id: requestId };
  },
};
