/* ============================================================
 * Color Panel Prototype - Database Layer (LocalStorage)
 * ============================================================
 * Mensimulasikan Z-table di SAP.
 * Setiap "table" adalah key di LocalStorage dengan prefix cp_db_
 *
 * Tables:
 *   - users           (ZCP_USER)
 *   - buyers          (ZCP_BUYER)
 *   - color_codes     (ZCP_COLOR_CODE)
 *   - requests        (ZCP_REQUEST)
 *   - so_imports      (ZCP_SO_IMPORT)
 *   - dcp_headers     (ZCP_DCP_HDR)
 *   - dcp_items       (ZCP_DCP_ITEM)
 *   - mcp_headers     (ZCP_MCP_HDR)
 *   - mcp_items       (ZCP_MCP_ITEM)
 *   - photos          (ZCP_PHOTO)
 *   - audit_logs      (ZCP_AUDIT_LOG)
 *   - sequences       (untuk auto-increment ID per prefix per tahun)
 * ============================================================ */

const DB = {

  /* ------------------------------------------------------------
   * LOW-LEVEL storage
   * ------------------------------------------------------------ */

  _key(table) {
    return CONFIG.DB_KEY_PREFIX + table;
  },

  read(table) {
    const raw = localStorage.getItem(this._key(table));
    return raw ? JSON.parse(raw) : [];
  },

  write(table, data) {
    localStorage.setItem(this._key(table), JSON.stringify(data));
  },

  clear() {
    const keys = Object.keys(localStorage).filter(k => k.startsWith(CONFIG.DB_KEY_PREFIX));
    keys.forEach(k => localStorage.removeItem(k));
  },

  /* ------------------------------------------------------------
   * RESET DATA TRANSAKSI (alat bantu uji coba, dev-only)
   * ------------------------------------------------------------
   * Beda dengan clear() yang menghapus SEMUA termasuk master:
   * di sini master data (users, buyers, materials, sales_orders)
   * sengaja dipertahankan, termasuk baris yang ditambahkan Admin
   * lewat halaman Master Data.
   *
   * `color_codes` dan `so_imports` ikut dihapus karena keduanya
   * adalah penjaga anti-duplikat di Biz.approveRequest(). Kalau
   * ditinggal, SO yang sudah pernah diproses tidak akan pernah
   * bisa diuji ulang.
   *
   * Mengembalikan jumlah baris per tabel SEBELUM dihapus, supaya
   * pemanggilnya bisa menyebut angka nyata di dialog konfirmasi.
   * ------------------------------------------------------------ */

  TRANSACTIONAL_TABLES: [
    'requests', 'color_codes', 'so_imports',
    'dcp_headers', 'dcp_items', 'mcp_headers', 'mcp_items',
    'photos', 'audit_logs',
  ],

  /* Hitung isi tabel transaksi tanpa menghapus apa pun */
  countTransactional() {
    const out = { total: 0 };
    this.TRANSACTIONAL_TABLES.forEach(t => {
      const n = this.read(t).length;
      out[t] = n;
      out.total += n;
    });
    return out;
  },

  resetTransactional() {
    const before = this.countTransactional();
    this.TRANSACTIONAL_TABLES.forEach(t => this.write(t, []));
    /* Sequences dikosongkan supaya penomoran kembali dari 00001 */
    this.write('sequences', []);
    return before;
  },

  /* ------------------------------------------------------------
   * SEQUENCE generator (mirror SNRO)
   * ------------------------------------------------------------ */

  nextSeq(prefix) {
    const year = new Date().getFullYear();
    const seqKey = `${prefix}_${year}`;
    const seqs = this.read('sequences');
    let rec = seqs.find(s => s.key === seqKey);
    if (!rec) {
      rec = { key: seqKey, value: 0 };
      seqs.push(rec);
    }
    rec.value += 1;
    this.write('sequences', seqs);
    return rec.value;
  },

  nextColorCodeSeq() {
    /* Color code TIDAK reset per tahun (sesuai legacy Laravel) */
    const seqs = this.read('sequences');
    let rec = seqs.find(s => s.key === 'COLOR_GLOBAL');
    if (!rec) {
      rec = { key: 'COLOR_GLOBAL', value: 0 };
      seqs.push(rec);
    }
    rec.value += 1;
    this.write('sequences', seqs);
    return rec.value;
  },

  /* ------------------------------------------------------------
   * GENERIC CRUD
   * ------------------------------------------------------------ */

  all(table) { return this.read(table); },

  find(table, key, value) {
    return this.read(table).find(r => r[key] === value);
  },

  filter(table, predicate) {
    return this.read(table).filter(predicate);
  },

  insert(table, row) {
    const data = this.read(table);
    data.push(row);
    this.write(table, data);
    return row;
  },

  update(table, key, value, patch) {
    const data = this.read(table);
    const idx = data.findIndex(r => r[key] === value);
    if (idx === -1) return null;
    data[idx] = { ...data[idx], ...patch };
    this.write(table, data);
    return data[idx];
  },

  updateWhere(table, predicate, patch) {
    const data = this.read(table);
    let count = 0;
    for (let i = 0; i < data.length; i++) {
      if (predicate(data[i])) {
        data[i] = { ...data[i], ...patch };
        count++;
      }
    }
    this.write(table, data);
    return count;
  },

  delete(table, key, value) {
    const data = this.read(table).filter(r => r[key] !== value);
    this.write(table, data);
  },

  /* ------------------------------------------------------------
   * AUDIT LOG helper
   * ------------------------------------------------------------ */

  audit(refType, refId, action, description, oldValue = '', newValue = '') {
    const session = Auth.getSession();
    const seq = this.nextSeq(ID_PREFIX.AUDIT);
    const row = {
      log_id: Utils.generateId(ID_PREFIX.AUDIT, seq),
      ref_type: refType,
      ref_id: refId,
      action: action,
      description: description,
      old_value: String(oldValue || ''),
      new_value: String(newValue || ''),
      action_by: session ? session.user_id : 'SYSTEM',
      action_by_name: session ? session.full_name : 'System',
      action_at: Utils.now(),
      ip_address: '127.0.0.1', // dummy
    };
    this.insert('audit_logs', row);
    return row;
  },

  /* ------------------------------------------------------------
   * SEED DATA
   * Dipanggil sekali saat first-load atau saat user klik "Reset"
   * ------------------------------------------------------------ */

  seed(force = false) {
    /* Kalau sudah ada data & tidak force, skip */
    if (!force && this.read('users').length > 0) return false;

    this.clear();

    /* --------- USERS --------- */
    const users = [
      {
        user_id: 'sales01',
        password: 'sales01', // plain untuk prototype (nanti SHA256 di BSP)
        full_name: 'Andi Wijaya',
        role: ROLES.SALES,
        buyer_id: 'BYR-2026-0001',
        email: 'andi.sales@kmi.co.id',
        nik: 'KMI-S-001',
        is_active: 'X',
        created_at: Utils.now(),
      },
      {
        user_id: 'sales02',
        password: 'sales02',
        full_name: 'Bella Kartika',
        role: ROLES.SALES,
        buyer_id: 'BYR-2026-0002',
        email: 'bella.sales@kmi.co.id',
        nik: 'KMI-S-002',
        is_active: 'X',
        created_at: Utils.now(),
      },
      {
        user_id: 'admin01',
        password: 'admin01',
        full_name: 'Yogi Pratama',
        role: ROLES.ADMIN,
        buyer_id: '',
        email: 'yogi.admin@kmi.co.id',
        nik: 'KMI-A-001',
        is_active: 'X',
        created_at: Utils.now(),
      },
      {
        user_id: 'qc01',
        password: 'qc01',
        full_name: 'Citra Handayani',
        role: ROLES.QC,
        buyer_id: '',
        email: 'citra.qc@kmi.co.id',
        nik: 'KMI-Q-001',
        is_active: 'X',
        created_at: Utils.now(),
      },
      {
        user_id: 'it01',
        password: 'it01',
        full_name: 'Arya Nugraha',
        role: ROLES.IT,
        buyer_id: '',
        email: 'arya.it@kmi.co.id',
        nik: 'KMI-I-001',
        is_active: 'X',
        created_at: Utils.now(),
      },
    ];
    this.write('users', users);

    /* --------- BUYERS --------- */
    const buyers = [
      {
        buyer_id: 'BYR-2026-0001',
        buyer_name: 'Ashley Furniture Ltd.',
        company: 'Ashley Furniture Ltd.',
        country: 'US',
        contact: 'John Smith',
        email: 'contact@ashley.com',
        phone: '+1-555-1000',
        is_active: 'X',
        remarks: 'Buyer utama untuk lini walnut',
        created_at: Utils.now(),
      },
      {
        buyer_id: 'BYR-2026-0002',
        buyer_name: 'IKEA Trading',
        company: 'IKEA Trading Southeast Asia',
        country: 'SG',
        contact: 'Anna Lindberg',
        email: 'anna@ikea.sg',
        phone: '+65-6100-2000',
        is_active: 'X',
        remarks: '',
        created_at: Utils.now(),
      },
      {
        buyer_id: 'BYR-2026-0003',
        buyer_name: 'Crate & Barrel',
        company: 'Crate and Barrel Holdings',
        country: 'US',
        contact: 'Michael Brown',
        email: 'michael@crateandbarrel.com',
        phone: '+1-555-3000',
        is_active: 'X',
        remarks: '',
        created_at: Utils.now(),
      },
    ];
    this.write('buyers', buyers);

    /* --------- MATERIAL DUMMY (untuk simulasi SO lookup) --------- */
    /* Ini bukan tabel formal, cuma helper untuk simulasi SO */
    const materials = [
      { matnr: 'MAT-C-00001', maktx: 'Panel Color Walnut Dark',   buyer_id: 'BYR-2026-0001', has_color: false },
      { matnr: 'MAT-C-00002', maktx: 'Panel Color Oak Natural',   buyer_id: 'BYR-2026-0001', has_color: false },
      { matnr: 'MAT-C-00003', maktx: 'Panel Color Teak Brown',    buyer_id: 'BYR-2026-0002', has_color: false },
      { matnr: 'MAT-C-00004', maktx: 'Panel Color Mahogany Red',  buyer_id: 'BYR-2026-0002', has_color: false },
      { matnr: 'MAT-C-00005', maktx: 'Panel Color Beech Cream',   buyer_id: 'BYR-2026-0003', has_color: false },
      { matnr: 'MAT-C-00006', maktx: 'Panel Color Cherry Blossom', buyer_id: 'BYR-2026-0003', has_color: false },
      { matnr: 'MAT-C-00007', maktx: 'Panel Color Ebony Black',   buyer_id: 'BYR-2026-0001', has_color: false },
      { matnr: 'MAT-C-00008', maktx: 'Panel Color Ash Grey',      buyer_id: 'BYR-2026-0002', has_color: false },
      /* Material untuk SO-2026-1006 s/d 1010. Sengaja material baru,
         bukan memakai ulang MAT-C-00001..8 — sekali material dipakai
         dan requestnya di-approve, Color Code-nya terbentuk dan SO
         lain yang memakai material sama tidak bisa di-approve lagi. */
      { matnr: 'MAT-C-00009', maktx: 'Panel Color Maple Blonde',  buyer_id: 'BYR-2026-0001', has_color: false },
      { matnr: 'MAT-C-00010', maktx: 'Panel Color Rosewood Deep', buyer_id: 'BYR-2026-0001', has_color: false },
      { matnr: 'MAT-C-00011', maktx: 'Panel Color Pine Light',    buyer_id: 'BYR-2026-0002', has_color: false },
      { matnr: 'MAT-C-00012', maktx: 'Panel Color Birch Ivory',   buyer_id: 'BYR-2026-0002', has_color: false },
      { matnr: 'MAT-C-00013', maktx: 'Panel Color Sapele Amber',  buyer_id: 'BYR-2026-0003', has_color: false },
      { matnr: 'MAT-C-00014', maktx: 'Panel Color Zebrano Stripe', buyer_id: 'BYR-2026-0003', has_color: false },
    ];
    this.write('materials', materials);

    /* --------- SO DUMMY (untuk simulasi SO lookup di form Request) --------- */
    const sales_orders = [
      {
        so_number: 'SO-2026-1001',
        buyer_id: 'BYR-2026-0001',
        so_date: '2026-07-01',
        items: [
          { so_item: '000010', matnr: 'MAT-C-00001', menge: 15, meins: 'PC' },
          { so_item: '000020', matnr: 'MAT-C-00002', menge: 15, meins: 'PC' },
        ],
      },
      {
        so_number: 'SO-2026-1002',
        buyer_id: 'BYR-2026-0002',
        so_date: '2026-07-05',
        items: [
          { so_item: '000010', matnr: 'MAT-C-00003', menge: 15, meins: 'PC' },
        ],
      },
      {
        so_number: 'SO-2026-1003',
        buyer_id: 'BYR-2026-0002',
        so_date: '2026-07-10',
        items: [
          { so_item: '000010', matnr: 'MAT-C-00004', menge: 15, meins: 'PC' },
          { so_item: '000020', matnr: 'MAT-C-00008', menge: 15, meins: 'PC' },
        ],
      },
      {
        so_number: 'SO-2026-1004',
        buyer_id: 'BYR-2026-0003',
        so_date: '2026-07-15',
        items: [
          { so_item: '000010', matnr: 'MAT-C-00005', menge: 15, meins: 'PC' },
          { so_item: '000020', matnr: 'MAT-C-00006', menge: 15, meins: 'PC' },
        ],
      },
      {
        so_number: 'SO-2026-1005',
        buyer_id: 'BYR-2026-0001',
        so_date: '2026-07-20',
        items: [
          { so_item: '000010', matnr: 'MAT-C-00007', menge: 15, meins: 'PC' },
        ],
      },

      /* SO-2026-1006 s/d 1010 — batch tambahan untuk uji coba.
         Qty sengaja dibuat bermacam-macam, bukan 15 semua: jumlah panel
         per DCP mengikuti qty item SO (biz.js: `for n = 1; n <= item.menge`),
         dan dengan qty seragam 15 perilaku itu tidak pernah kelihatan. */
      {
        so_number: 'SO-2026-1006',
        buyer_id: 'BYR-2026-0001',
        so_date: '2026-07-24',
        items: [
          { so_item: '000010', matnr: 'MAT-C-00009', menge: 5, meins: 'PC' },
        ],
      },
      {
        so_number: 'SO-2026-1007',
        buyer_id: 'BYR-2026-0001',
        so_date: '2026-07-28',
        items: [
          { so_item: '000010', matnr: 'MAT-C-00010', menge: 8, meins: 'PC' },
        ],
      },
      {
        so_number: 'SO-2026-1008',
        buyer_id: 'BYR-2026-0002',
        so_date: '2026-08-01',
        items: [
          { so_item: '000010', matnr: 'MAT-C-00011', menge: 10, meins: 'PC' },
          { so_item: '000020', matnr: 'MAT-C-00012', menge: 20, meins: 'PC' },
        ],
      },
      {
        so_number: 'SO-2026-1009',
        buyer_id: 'BYR-2026-0003',
        so_date: '2026-08-03',
        items: [
          { so_item: '000010', matnr: 'MAT-C-00013', menge: 12, meins: 'PC' },
        ],
      },
      {
        so_number: 'SO-2026-1010',
        buyer_id: 'BYR-2026-0003',
        so_date: '2026-08-05',
        items: [
          { so_item: '000010', matnr: 'MAT-C-00014', menge: 25, meins: 'PC' },
        ],
      },
    ];
    this.write('sales_orders', sales_orders);

    /* --------- Empty transactional tables --------- */
    this.write('color_codes', []);
    this.write('requests', []);
    this.write('so_imports', []);
    this.write('dcp_headers', []);
    this.write('dcp_items', []);
    this.write('mcp_headers', []);
    this.write('mcp_items', []);
    this.write('photos', []);
    this.write('audit_logs', []);
    this.write('sequences', []);

    return true;
  },

  /* ------------------------------------------------------------
   * HELPER lookups
   * ------------------------------------------------------------ */

  getUser(userId) {
    return this.find('users', 'user_id', userId);
  },

  getBuyer(buyerId) {
    return this.find('buyers', 'buyer_id', buyerId);
  },

  getBuyerName(buyerId) {
    const b = this.getBuyer(buyerId);
    return b ? b.buyer_name : '-';
  },

  getMaterial(matnr) {
    return this.find('materials', 'matnr', matnr);
  },

  getMaterialName(matnr) {
    const m = this.getMaterial(matnr);
    return m ? m.maktx : matnr;
  },

  getSalesOrder(so) {
    return this.find('sales_orders', 'so_number', so);
  },

  /* Cek apakah material sudah punya Color Code (untuk validasi request DCP) */
  materialHasColorCode(matnr) {
    return this.filter('color_codes', c => c.matnr === matnr && c.status === COLOR_CODE_STATUS.ACTIVE).length > 0;
  },

  /* Cek apakah SO+material sudah pernah di-import (anti duplikat) */
  soAlreadyImported(soNumber, matnr) {
    return this.filter('so_imports', s => s.so_number === soNumber && s.matnr === matnr).length > 0;
  },

  /* ------------------------------------------------------------
   * DEBUG
   * ------------------------------------------------------------ */

  dump() {
    const tables = ['users', 'buyers', 'materials', 'sales_orders',
      'color_codes', 'requests', 'so_imports',
      'dcp_headers', 'dcp_items', 'mcp_headers', 'mcp_items',
      'photos', 'audit_logs', 'sequences'];
    const out = {};
    tables.forEach(t => out[t] = this.read(t));
    return out;
  },
};

/* Auto-seed saat script pertama kali load */
(function autoSeed() {
  if (typeof window !== 'undefined') {
    DB.seed(false);
  }
})();
