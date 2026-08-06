/* ============================================================
 * Color Panel Prototype - Configuration & Constants
 * ============================================================
 * Berisi semua constant, enum, dan konfigurasi global.
 * Jangan hardcode nilai di file lain — semua di sini.
 * ============================================================ */

const CONFIG = {
  APP_NAME: 'Color Panel',
  APP_VERSION: '0.1.0 (Prototype)',
  COMPANY: 'PT. Kayu Mebel Indonesia',

  /* Panel quantity per SO (locked business rule) */
  PANEL_PER_SO: 15,

  /* Approval thresholds */
  MIN_APPROVE_DCP_CLOSE: 1,   // min panel approved untuk close DCP
  MIN_APPROVE_MCP_CLOSE: 3,   // min panel approved untuk close MCP

  /* Expiry & reminder (in days) */
  DCP_EXPIRY_DAYS: 365,        // DCP max 1 tahun
  DCP_REMINDER_DAYS: 60,       // reminder jika 2 bulan belum ditentukan
  MCP_EXPIRY_DAYS: 365,        // MCP diperbarui setiap tahun

  /* Photo upload */
  MIN_PHOTO_PER_PANEL: 2,      // minimal 2 foto per submit
  MAX_PHOTO_SIZE_MB: 5,

  /* DMS document types */
  DMS_TYPE_DCP: 'ZDCP',
  DMS_TYPE_MCP: 'ZMCP',

  /* Sticker signatories (3 kolom ttd) */
  STICKER_SIGNATORIES: ['Buyer', 'RND', 'AkzoNobel'],

  /* Session storage key */
  SESSION_KEY: 'cp_session',
  DB_KEY_PREFIX: 'cp_db_',
};

/* ------------------------------------------------------------
 * ROLES
 * ------------------------------------------------------------ */
const ROLES = {
  SALES: 'SALES',
  ADMIN: 'ADMIN',
  QC: 'QC',
  IT: 'IT',
};

/* Prioritas redirect kalau user multi-role */
const ROLE_PRIORITY = [ROLES.ADMIN, ROLES.IT, ROLES.QC, ROLES.SALES];

/* Landing page per role */
const ROLE_LANDING = {
  SALES: 'pages/request_list.html',
  ADMIN: 'dashboard.html',
  IT: 'dashboard.html',
  QC: 'pages/mcp_list.html',
};

/* ------------------------------------------------------------
 * STATUS ENUMS
 * ------------------------------------------------------------ */

/* Request-DCP status */
const REQ_STATUS = {
  PENDING: 'P',
  APPROVED: 'A',
  REJECTED: 'R',
};
const REQ_STATUS_LABEL = {
  P: 'Pending',
  A: 'Approved',
  R: 'Rejected',
};
const REQ_STATUS_BADGE = {
  P: 'badge-warning',
  A: 'badge-success',
  R: 'badge-danger',
};

/* DCP Header status */
const DCP_HDR_STATUS = {
  OPEN: 'O',
  APPROVED: 'A',
  REJECTED: 'R',
  CLOSED: 'C',
};
const DCP_HDR_STATUS_LABEL = {
  O: 'Open',
  A: 'Approved',
  R: 'Rejected',
  C: 'Closed',
};
const DCP_HDR_STATUS_BADGE = {
  O: 'badge-info',
  A: 'badge-success',
  R: 'badge-danger',
  C: 'badge-neutral',
};

/* DCP Panel status */
const DCP_PANEL_STATUS = {
  NON_ACTIVE: 'NA',
  ACTIVE: 'AK',
  SUBMITTED: 'SB',
  APPROVED: 'AP',
  REJECTED: 'RJ',
  OBSOLETE: 'OB',
};
const DCP_PANEL_STATUS_LABEL = {
  NA: 'Non-Aktif',
  AK: 'Aktif',
  SB: 'Submitted',
  AP: 'Approved',
  RJ: 'Rejected',
  OB: 'Obsolete',
};
const DCP_PANEL_STATUS_BADGE = {
  NA: 'badge-neutral',
  AK: 'badge-info',
  SB: 'badge-warning',
  AP: 'badge-success',
  RJ: 'badge-danger',
  OB: 'badge-neutral',
};

/* MCP Header status */
const MCP_HDR_STATUS = {
  OPEN: 'O',
  CLOSED: 'A',   // Approved/Closed
  REJECTED: 'R',
};
const MCP_HDR_STATUS_LABEL = {
  O: 'Open',
  A: 'Closed (Released)',
  R: 'Rejected',
};
const MCP_HDR_STATUS_BADGE = {
  O: 'badge-info',
  A: 'badge-success',
  R: 'badge-danger',
};

/* MCP Panel status */
const MCP_PANEL_STATUS = {
  DCP_APPROVED: 'DA',   // lanjutan dari DCP approved
  BLANK: 'BL',           // panel polos, belum di-submit
  SUBMITTED: 'SB',
  APPROVED: 'AP',
  OBSOLETE: 'OB',
};
const MCP_PANEL_STATUS_LABEL = {
  DA: 'DCP-Approved',
  BL: 'Blank (Polos)',
  SB: 'Submitted',
  AP: 'MCP-Approved',
  OB: 'Obsolete',
};
const MCP_PANEL_STATUS_BADGE = {
  DA: 'badge-info',
  BL: 'badge-neutral',
  SB: 'badge-warning',
  AP: 'badge-success',
  OB: 'badge-neutral',
};

/* Color Code status */
const COLOR_CODE_STATUS = {
  ACTIVE: 'A',
  INACTIVE: 'I',
  OBSOLETE: 'O',
};

/* ------------------------------------------------------------
 * ID PREFIXES (mirror SNRO di SAP nanti)
 * ------------------------------------------------------------ */
const ID_PREFIX = {
  REQUEST: 'REQ',
  DCP: 'DCP',
  MCP: 'MCP',
  COLOR: 'KW',
  PHOTO: 'PHT',
  AUDIT: 'LOG',
  USER: 'USR',
  BUYER: 'BYR',
};

/* ------------------------------------------------------------
 * NAVIGATION MENU per role
 * ------------------------------------------------------------ */
/* `match` = daftar file yang ikut menyalakan highlight menu ini
   (halaman detail/form tidak punya entri menu sendiri). */
const NAV_MENU = [
  {
    /* Halaman referensi — satu-satunya yang dibuka untuk semua role */
    label: 'Alur Sistem',
    icon: 'fa-diagram-project',
    href: 'pages/flowchart.html',
    roles: [ROLES.SALES, ROLES.ADMIN, ROLES.QC, ROLES.IT],
  },
  {
    label: 'Dashboard',
    icon: 'fa-gauge',
    href: 'dashboard.html',
    roles: [ROLES.ADMIN, ROLES.IT, ROLES.QC],
  },
  {
    label: 'Request DCP',
    icon: 'fa-envelope-open-text',
    href: 'pages/request_list.html',
    match: ['request_list.html', 'request_form.html', 'request_detail.html'],
    roles: [ROLES.SALES, ROLES.ADMIN, ROLES.IT],
  },
  {
    label: 'DCP',
    icon: 'fa-flask',
    href: 'pages/dcp_list.html',
    match: ['dcp_list.html', 'dcp_detail.html'],
    roles: [ROLES.ADMIN, ROLES.QC, ROLES.IT],
  },
  {
    label: 'MCP',
    icon: 'fa-box-archive',
    href: 'pages/mcp_list.html',
    match: ['mcp_list.html', 'mcp_detail.html'],
    roles: [ROLES.ADMIN, ROLES.QC, ROLES.IT],
  },
  {
    label: 'Renewal MCP',
    icon: 'fa-arrows-rotate',
    href: 'pages/mcp_renewal.html',
    roles: [ROLES.ADMIN, ROLES.IT],
  },
  {
    label: '__DIVIDER_MASTER__',
    label_text: 'Master Data',
    roles: [ROLES.ADMIN, ROLES.IT],
  },
  {
    label: 'User',
    icon: 'fa-users',
    href: 'pages/master_user.html',
    roles: [ROLES.ADMIN, ROLES.IT],
  },
  {
    label: 'Buyer',
    icon: 'fa-building',
    href: 'pages/master_buyer.html',
    roles: [ROLES.ADMIN, ROLES.IT],
  },
  {
    label: 'Color Code',
    icon: 'fa-palette',
    href: 'pages/master_color.html',
    roles: [ROLES.ADMIN, ROLES.IT, ROLES.QC],
  },
  {
    label: '__DIVIDER_UTIL__',
    label_text: 'Utility',
    roles: [ROLES.IT],
  },
  {
    label: 'Audit Log',
    icon: 'fa-clipboard-list',
    href: 'pages/audit_log.html',
    roles: [ROLES.IT],
  },
];
