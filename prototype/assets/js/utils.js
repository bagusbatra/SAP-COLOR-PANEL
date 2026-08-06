/* ============================================================
 * Color Panel Prototype - Utility Functions
 * ============================================================ */

const Utils = {

  /* ------------------------------------------------------------
   * DATE & TIME
   * ------------------------------------------------------------ */

  today() {
    return new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  },

  now() {
    return new Date().toISOString(); // ISO timestamp
  },

  formatDate(iso) {
    if (!iso) return '-';
    const d = new Date(iso);
    if (isNaN(d)) return iso;
    return d.toLocaleDateString('id-ID', {
      day: '2-digit', month: 'short', year: 'numeric'
    });
  },

  formatDateTime(iso) {
    if (!iso) return '-';
    const d = new Date(iso);
    if (isNaN(d)) return iso;
    return d.toLocaleString('id-ID', {
      day: '2-digit', month: 'short', year: 'numeric',
      hour: '2-digit', minute: '2-digit'
    });
  },

  addDays(iso, days) {
    const d = new Date(iso);
    d.setDate(d.getDate() + days);
    return d.toISOString().slice(0, 10);
  },

  daysBetween(iso1, iso2) {
    const d1 = new Date(iso1);
    const d2 = new Date(iso2);
    return Math.floor((d2 - d1) / (1000 * 60 * 60 * 24));
  },

  isExpired(iso) {
    if (!iso) return false;
    return new Date(iso) < new Date();
  },

  /* ------------------------------------------------------------
   * ID GENERATOR (mirror SNRO di SAP)
   * Format: PREFIX-YYYY-NNNN (misal DCP-2026-0001)
   * Color code: KW + 5 digit (misal KW00001)
   * ------------------------------------------------------------ */

  generateId(prefix, sequence) {
    const year = new Date().getFullYear();
    const seq = String(sequence).padStart(4, '0');
    return `${prefix}-${year}-${seq}`;
  },

  generateColorCode(sequence) {
    const seq = String(sequence).padStart(5, '0');
    return `${ID_PREFIX.COLOR}${seq}`;
  },

  generatePanelId(dcpOrMcpId, panelNumber) {
    const num = String(panelNumber).padStart(2, '0');
    return `${dcpOrMcpId}-${num}`;
  },

  /* Random hex token (mirror QR token 128-bit di SAP) */
  generateToken() {
    let token = '';
    for (let i = 0; i < 32; i++) {
      token += Math.floor(Math.random() * 16).toString(16);
    }
    return token;
  },

  /* ------------------------------------------------------------
   * FORMAT HELPERS
   * ------------------------------------------------------------ */

  badge(status, labelMap, badgeMap) {
    const label = labelMap[status] || status;
    const cls = badgeMap[status] || 'badge-neutral';
    return `<span class="badge ${cls}">${label}</span>`;
  },

  reqBadge(s)  { return this.badge(s, REQ_STATUS_LABEL, REQ_STATUS_BADGE); },
  dcpHdrBadge(s) { return this.badge(s, DCP_HDR_STATUS_LABEL, DCP_HDR_STATUS_BADGE); },
  dcpPanelBadge(s) { return this.badge(s, DCP_PANEL_STATUS_LABEL, DCP_PANEL_STATUS_BADGE); },
  mcpHdrBadge(s) { return this.badge(s, MCP_HDR_STATUS_LABEL, MCP_HDR_STATUS_BADGE); },
  mcpPanelBadge(s) { return this.badge(s, MCP_PANEL_STATUS_LABEL, MCP_PANEL_STATUS_BADGE); },

  /* ------------------------------------------------------------
   * ALERTS (SweetAlert2 wrapper)
   * ------------------------------------------------------------ */

  toast(icon, title) {
    return Swal.fire({
      toast: true,
      position: 'top-end',
      icon: icon,
      title: title,
      showConfirmButton: false,
      timer: 2500,
      timerProgressBar: true,
    });
  },

  toastSuccess(msg) { return this.toast('success', msg); },
  toastError(msg)   { return this.toast('error', msg); },
  toastWarning(msg) { return this.toast('warning', msg); },
  toastInfo(msg)    { return this.toast('info', msg); },

  confirm(title, text, confirmText = 'Ya, lanjutkan') {
    return Swal.fire({
      title: title,
      text: text,
      icon: 'question',
      showCancelButton: true,
      confirmButtonText: confirmText,
      cancelButtonText: 'Batal',
      confirmButtonColor: '#1E3A8A',
      cancelButtonColor: '#64748B',
    });
  },

  /* Sama seperti confirm(), tapi isinya dirender sebagai HTML.
     Dipisah karena `text:` di SweetAlert meng-escape markup — kalau
     confirm() diubah jadi `html:`, semua pemanggil lama ikut berubah
     perilakunya. Pakai ini hanya untuk teks yang kita susun sendiri,
     jangan untuk input user. */
  confirmHtml(title, html, confirmText = 'Ya, lanjutkan') {
    return Swal.fire({
      title: title,
      html: html,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: confirmText,
      cancelButtonText: 'Batal',
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#64748B',
    });
  },

  prompt(title, inputPlaceholder, inputLabel = '') {
    return Swal.fire({
      title: title,
      input: 'textarea',
      inputLabel: inputLabel,
      inputPlaceholder: inputPlaceholder,
      showCancelButton: true,
      confirmButtonText: 'Simpan',
      cancelButtonText: 'Batal',
      confirmButtonColor: '#1E3A8A',
      inputValidator: (v) => !v && 'Wajib diisi',
    });
  },

  alertSuccess(title, text) {
    return Swal.fire({
      icon: 'success', title: title, text: text,
      confirmButtonColor: '#1E3A8A',
    });
  },

  alertError(title, text) {
    return Swal.fire({
      icon: 'error', title: title, text: text,
      confirmButtonColor: '#1E3A8A',
    });
  },

  /* ------------------------------------------------------------
   * DOM helpers
   * ------------------------------------------------------------ */

  el(id) { return document.getElementById(id); },

  qs(sel, parent = document) { return parent.querySelector(sel); },
  qsa(sel, parent = document) { return Array.from(parent.querySelectorAll(sel)); },

  setText(id, text) {
    const e = this.el(id);
    if (e) e.textContent = text;
  },

  setHtml(id, html) {
    const e = this.el(id);
    if (e) e.innerHTML = html;
  },

  show(id) { const e = this.el(id); if (e) e.classList.remove('hidden'); },
  hide(id) { const e = this.el(id); if (e) e.classList.add('hidden'); },

  /* ------------------------------------------------------------
   * URL helpers
   * ------------------------------------------------------------ */

  getParam(name) {
    return new URLSearchParams(window.location.search).get(name);
  },

  /* Relative path helper — biar link antar page konsisten.
   * Target selalu ditulis relatif dari root (mis. 'dashboard.html',
   * 'pages/dcp_list.html'), helper ini yang menyesuaikan prefix.
   *
   * dari root   -> 'pages/xxx.html'      tetap 'pages/xxx.html'
   * dari /pages -> 'pages/xxx.html'      jadi  'xxx.html'      (sesama folder)
   * dari /pages -> 'dashboard.html'      jadi  '../dashboard.html'
   */
  path(target) {
    const isInPages = window.location.pathname.includes('/pages/');
    if (!isInPages) return target;

    /* Sudah di dalam /pages/ — target sesama folder cukup nama filenya */
    if (target.startsWith('pages/')) return target.substring(6);

    /* Target ada di root — naik satu level */
    return '../' + target;
  },

  redirect(target) {
    window.location.href = this.path(target);
  },

  /* ------------------------------------------------------------
   * FILE helpers (untuk upload foto)
   * ------------------------------------------------------------ */

  fileToBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  },

  validateImageFile(file) {
    const validTypes = ['image/jpeg', 'image/jpg', 'image/png'];
    if (!validTypes.includes(file.type)) {
      return { valid: false, msg: 'Format harus JPG atau PNG' };
    }
    const sizeMB = file.size / (1024 * 1024);
    if (sizeMB > CONFIG.MAX_PHOTO_SIZE_MB) {
      return { valid: false, msg: `Ukuran maksimal ${CONFIG.MAX_PHOTO_SIZE_MB} MB` };
    }
    return { valid: true };
  },

  /* ------------------------------------------------------------
   * ROLE helpers
   * ------------------------------------------------------------ */

  hasRole(userRoles, requiredRole) {
    if (!userRoles) return false;
    const arr = Array.isArray(userRoles)
      ? userRoles
      : String(userRoles).split(',').map(r => r.trim());
    return arr.includes(requiredRole);
  },

  hasAnyRole(userRoles, requiredRoles) {
    return requiredRoles.some(r => this.hasRole(userRoles, r));
  },

  getPrimaryRole(userRoles) {
    const arr = Array.isArray(userRoles)
      ? userRoles
      : String(userRoles).split(',').map(r => r.trim());
    for (const priority of ROLE_PRIORITY) {
      if (arr.includes(priority)) return priority;
    }
    return arr[0] || null;
  },

  /* ------------------------------------------------------------
   * MISC
   * ------------------------------------------------------------ */

  escapeHtml(str) {
    if (str == null) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  },

  debounce(fn, ms = 300) {
    let t;
    return function (...args) {
      clearTimeout(t);
      t = setTimeout(() => fn.apply(this, args), ms);
    };
  },
};
