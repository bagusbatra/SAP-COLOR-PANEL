/* ============================================================
 * Color Panel Prototype - Sticker & QR Module
 * ============================================================
 * Generate stiker DCP/MCP dengan 3 kolom tanda tangan:
 *   Buyer | RND | AkzoNobel
 * Stiker ukuran ~10x7 cm (A7-ish landscape).
 *
 * QR code pakai qrcodejs (CDN) — render dulu ke canvas,
 * convert ke dataURL, taruh di PDF.
 * ============================================================ */

const Sticker = {

  /* ------------------------------------------------------------
   * QR generator (pakai qrcodejs library)
   * Return: dataURL PNG dari canvas
   * ------------------------------------------------------------ */
  async generateQrDataUrl(text, size = 200) {
    return new Promise((resolve) => {
      const tmpDiv = document.createElement('div');
      tmpDiv.style.position = 'fixed';
      tmpDiv.style.left = '-9999px';
      document.body.appendChild(tmpDiv);

      // eslint-disable-next-line no-undef
      new QRCode(tmpDiv, {
        text: text,
        width: size,
        height: size,
        correctLevel: QRCode.CorrectLevel.M,
      });

      /* qrcodejs render ke canvas atau img — kita ambil dari img */
      setTimeout(() => {
        const img = tmpDiv.querySelector('img');
        const canvas = tmpDiv.querySelector('canvas');
        let dataUrl = '';
        if (img && img.src) {
          dataUrl = img.src;
        } else if (canvas) {
          dataUrl = canvas.toDataURL('image/png');
        }
        document.body.removeChild(tmpDiv);
        resolve(dataUrl);
      }, 100);
    });
  },

  /* ------------------------------------------------------------
   * Render QR ke DOM (untuk preview inline)
   * ------------------------------------------------------------ */
  renderQrTo(elementId, text, size = 140) {
    const el = document.getElementById(elementId);
    if (!el) return;
    el.innerHTML = '';
    // eslint-disable-next-line no-undef
    new QRCode(el, {
      text: text,
      width: size,
      height: size,
      correctLevel: QRCode.CorrectLevel.M,
    });
  },

  /* ------------------------------------------------------------
   * Generate stiker PDF untuk panel (DCP atau MCP)
   * Ukuran: A6 landscape (148 x 105 mm)
   * ------------------------------------------------------------ */
  async generatePanelSticker(type, refId, panelNumber) {
    /* type = 'DCP' atau 'MCP' */
    let panel, header, color;
    if (type === 'DCP') {
      panel = DB.filter('dcp_items', p => p.dcp_id === refId && p.panel_number === panelNumber)[0];
      header = DB.find('dcp_headers', 'dcp_id', refId);
    } else {
      panel = DB.filter('mcp_items', p => p.mcp_id === refId && p.panel_number === panelNumber)[0];
      header = DB.find('mcp_headers', 'mcp_id', refId);
    }
    if (!panel || !header) {
      Utils.toastError('Data panel tidak lengkap');
      return;
    }
    color = DB.find('color_codes', 'color_code', header.color_code);
    const buyerName = DB.getBuyerName(header.buyer_id);

    /* QR data — pakai qr_token biar unik dan tidak reveal ID langsung */
    const qrText = JSON.stringify({
      type: type,
      panel_id: panel.panel_id,
      token: panel.qr_token,
    });
    const qrDataUrl = await this.generateQrDataUrl(qrText, 200);

    /* jsPDF setup — A6 landscape (148 x 105 mm) */
    // eslint-disable-next-line no-undef
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF({
      orientation: 'landscape',
      unit: 'mm',
      format: 'a6',
    });

    const W = 148, H = 105;
    const margin = 6;

    /* Border */
    doc.setDrawColor(30, 58, 138);
    doc.setLineWidth(0.8);
    doc.rect(margin, margin, W - margin * 2, H - margin * 2);

    /* Header bar (navy) */
    doc.setFillColor(30, 58, 138);
    doc.rect(margin, margin, W - margin * 2, 10, 'F');

    doc.setTextColor(255, 255, 255);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(11);
    doc.text(type === 'DCP'
      ? 'DEVELOPMENT COLOR PANEL (DCP)'
      : 'MASTER COLOR PANEL (MCP)', W / 2, margin + 6.5, { align: 'center' });

    /* Kolom kiri: Info panel */
    let y = margin + 15;
    doc.setTextColor(30, 41, 59);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8);

    const infoRows = [
      ['Panel ID',    panel.panel_id],
      ['Color Code',  header.color_code],
      ['Material',    header.matnr],
      ['Deskripsi',   (header.maktx || '-').substring(0, 30)],
      ['Buyer',       buyerName.substring(0, 30)],
      ['MFG Date',    panel.mfg_date ? Utils.formatDate(panel.mfg_date) : '-'],
      ['Expired',     header.expire_date ? Utils.formatDate(header.expire_date) : '-'],
    ];

    const labelX = margin + 3;
    const valueX = margin + 22;
    for (const [k, v] of infoRows) {
      doc.setFont('helvetica', 'bold');
      doc.text(k, labelX, y);
      doc.setFont('helvetica', 'normal');
      doc.text(':  ' + String(v), valueX, y);
      y += 5;
    }

    /* Color swatch */
    if (color && color.color_hex) {
      const hex = color.color_hex.replace('#', '');
      const r = parseInt(hex.substring(0, 2), 16);
      const g = parseInt(hex.substring(2, 4), 16);
      const b = parseInt(hex.substring(4, 6), 16);
      doc.setFillColor(r, g, b);
      doc.setDrawColor(150, 150, 150);
      doc.rect(labelX, y + 1, 10, 10, 'FD');
      doc.setFont('helvetica', 'bold');
      doc.text('Color:', labelX + 13, y + 5);
      doc.setFont('helvetica', 'normal');
      doc.text(color.color_hex, labelX + 13, y + 9);
    }

    /* Kolom kanan: QR */
    const qrSize = 32;
    const qrX = W - margin - qrSize - 3;
    const qrY = margin + 15;
    if (qrDataUrl) {
      try {
        doc.addImage(qrDataUrl, 'PNG', qrX, qrY, qrSize, qrSize);
      } catch (e) {
        console.error('QR embed failed', e);
      }
    }
    doc.setFontSize(6);
    doc.setTextColor(100, 100, 100);
    doc.text('Scan untuk verifikasi', qrX + qrSize / 2, qrY + qrSize + 3, { align: 'center' });

    /* Kolom tanda tangan (3 kolom) */
    const sigY = H - margin - 22;
    const sigW = (W - margin * 2 - 6) / 3;
    doc.setDrawColor(180, 180, 180);
    doc.setTextColor(30, 41, 59);
    doc.setFontSize(8);
    doc.setFont('helvetica', 'bold');

    for (let i = 0; i < CONFIG.STICKER_SIGNATORIES.length; i++) {
      const x = margin + 3 + i * (sigW + 2);
      /* Kotak ttd */
      doc.rect(x, sigY, sigW, 14);
      doc.setFontSize(6);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(120, 120, 120);
      doc.text('Tanda tangan:', x + 1.5, sigY + 3);

      /* Label bawah */
      doc.setFontSize(8);
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(30, 41, 59);
      doc.text(CONFIG.STICKER_SIGNATORIES[i], x + sigW / 2, sigY + 19, { align: 'center' });
    }

    /* Footer */
    doc.setFontSize(6);
    doc.setTextColor(150, 150, 150);
    doc.setFont('helvetica', 'normal');
    doc.text(`${CONFIG.COMPANY} — ${CONFIG.APP_NAME} v${CONFIG.APP_VERSION}`,
      W / 2, H - margin + 1, { align: 'center' });

    /* Print / download */
    const filename = `sticker_${type}_${panel.panel_id}.pdf`;
    doc.save(filename);

    if (typeof Auth !== 'undefined' && Auth.getSession()) {
      DB.audit(type, refId, 'PRINT_STICKER',
        `Cetak stiker panel ${panel.panel_id}`);
    }
  },

  /* ------------------------------------------------------------
   * Bulk print — cetak semua panel dalam 1 DCP/MCP jadi 1 PDF
   * ------------------------------------------------------------ */
  async generateBulkStickers(type, refId) {
    let items, header;
    if (type === 'DCP') {
      items = DB.filter('dcp_items', p => p.dcp_id === refId)
        .sort((a, b) => a.panel_number - b.panel_number);
      header = DB.find('dcp_headers', 'dcp_id', refId);
    } else {
      items = DB.filter('mcp_items', p => p.mcp_id === refId)
        .sort((a, b) => a.panel_number - b.panel_number);
      header = DB.find('mcp_headers', 'mcp_id', refId);
    }
    if (!items || items.length === 0) {
      Utils.toastError('Tidak ada panel');
      return;
    }
    const color = DB.find('color_codes', 'color_code', header.color_code);
    const buyerName = DB.getBuyerName(header.buyer_id);

    // eslint-disable-next-line no-undef
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a6' });

    for (let i = 0; i < items.length; i++) {
      if (i > 0) doc.addPage('a6', 'landscape');
      await this._drawSticker(doc, type, header, items[i], color, buyerName);
    }

    const filename = `stickers_bulk_${type}_${refId}.pdf`;
    doc.save(filename);
    DB.audit(type, refId, 'PRINT_BULK_STICKER',
      `Cetak bulk stiker ${items.length} panel dari ${refId}`);
  },

  /* Internal: draw sticker ke page existing */
  async _drawSticker(doc, type, header, panel, color, buyerName) {
    const W = 148, H = 105, margin = 6;

    doc.setDrawColor(30, 58, 138);
    doc.setLineWidth(0.8);
    doc.rect(margin, margin, W - margin * 2, H - margin * 2);

    doc.setFillColor(30, 58, 138);
    doc.rect(margin, margin, W - margin * 2, 10, 'F');
    doc.setTextColor(255, 255, 255);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(11);
    doc.text(type === 'DCP'
      ? 'DEVELOPMENT COLOR PANEL (DCP)'
      : 'MASTER COLOR PANEL (MCP)', W / 2, margin + 6.5, { align: 'center' });

    let y = margin + 15;
    doc.setTextColor(30, 41, 59);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8);

    const infoRows = [
      ['Panel ID',    panel.panel_id],
      ['Color Code',  header.color_code],
      ['Material',    header.matnr],
      ['Deskripsi',   (header.maktx || '-').substring(0, 30)],
      ['Buyer',       buyerName.substring(0, 30)],
      ['MFG Date',    panel.mfg_date ? Utils.formatDate(panel.mfg_date) : '-'],
      ['Expired',     header.expire_date ? Utils.formatDate(header.expire_date) : '-'],
    ];
    const labelX = margin + 3, valueX = margin + 22;
    for (const [k, v] of infoRows) {
      doc.setFont('helvetica', 'bold');
      doc.text(k, labelX, y);
      doc.setFont('helvetica', 'normal');
      doc.text(':  ' + String(v), valueX, y);
      y += 5;
    }

    if (color && color.color_hex) {
      const hex = color.color_hex.replace('#', '');
      const r = parseInt(hex.substring(0, 2), 16);
      const g = parseInt(hex.substring(2, 4), 16);
      const b = parseInt(hex.substring(4, 6), 16);
      doc.setFillColor(r, g, b);
      doc.setDrawColor(150, 150, 150);
      doc.rect(labelX, y + 1, 10, 10, 'FD');
      doc.setFont('helvetica', 'bold');
      doc.text('Color:', labelX + 13, y + 5);
      doc.setFont('helvetica', 'normal');
      doc.text(color.color_hex, labelX + 13, y + 9);
    }

    const qrText = JSON.stringify({
      type: type, panel_id: panel.panel_id, token: panel.qr_token,
    });
    const qrDataUrl = await this.generateQrDataUrl(qrText, 200);
    const qrSize = 32;
    const qrX = W - margin - qrSize - 3;
    const qrY = margin + 15;
    if (qrDataUrl) {
      try { doc.addImage(qrDataUrl, 'PNG', qrX, qrY, qrSize, qrSize); }
      catch (e) { console.error('QR embed failed', e); }
    }
    doc.setFontSize(6);
    doc.setTextColor(100, 100, 100);
    doc.text('Scan untuk verifikasi', qrX + qrSize / 2, qrY + qrSize + 3, { align: 'center' });

    const sigY = H - margin - 22;
    const sigW = (W - margin * 2 - 6) / 3;
    doc.setDrawColor(180, 180, 180);
    doc.setTextColor(30, 41, 59);

    for (let i = 0; i < CONFIG.STICKER_SIGNATORIES.length; i++) {
      const x = margin + 3 + i * (sigW + 2);
      doc.rect(x, sigY, sigW, 14);
      doc.setFontSize(6);
      doc.setFont('helvetica', 'normal');
      doc.setTextColor(120, 120, 120);
      doc.text('Tanda tangan:', x + 1.5, sigY + 3);
      doc.setFontSize(8);
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(30, 41, 59);
      doc.text(CONFIG.STICKER_SIGNATORIES[i], x + sigW / 2, sigY + 19, { align: 'center' });
    }

    doc.setFontSize(6);
    doc.setTextColor(150, 150, 150);
    doc.setFont('helvetica', 'normal');
    doc.text(`${CONFIG.COMPANY} — ${CONFIG.APP_NAME} v${CONFIG.APP_VERSION}`,
      W / 2, H - margin + 1, { align: 'center' });
  },
};
