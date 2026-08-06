/* ============================================================
 * Color Panel Prototype - Sidebar Renderer
 * ============================================================
 * Render sidebar menu berdasarkan role user.
 * Menu yang tidak sesuai role -> hidden total (bukan disabled).
 * ============================================================ */

const Sidebar = {

  render(containerId = 'sidebar') {
    const session = Auth.getSession();
    if (!session) return;

    const container = Utils.el(containerId);
    if (!container) return;

    /* Determine current page path (untuk highlight active) */
    const currentPath = window.location.pathname.split('/').pop();

    let html = `
      <div class="sidebar-header">
        <div class="sidebar-brand">
          <div class="sidebar-brand-icon">
            <i class="fa-solid fa-palette"></i>
          </div>
          <div class="sidebar-brand-text">
            <div class="sidebar-brand-title">${CONFIG.APP_NAME}</div>
            <div class="sidebar-brand-sub">${CONFIG.COMPANY}</div>
          </div>
        </div>
      </div>

      <nav class="sidebar-nav">
    `;

    /* Loop through menu items */
    for (const item of NAV_MENU) {
      /* Check role visibility */
      if (!Utils.hasAnyRole(session.role, item.roles)) continue;

      /* Divider */
      if (item.label.startsWith('__DIVIDER_')) {
        html += `<div class="sidebar-divider">${item.label_text}</div>`;
        continue;
      }

      /* Menu item */
      const targetFile = item.href.split('/').pop();
      const matches = item.match || [targetFile];
      const isActive = matches.includes(currentPath);
      const activeClass = isActive ? 'active' : '';
      const href = Utils.path(item.href);

      html += `
        <a href="${href}" class="sidebar-link ${activeClass}">
          <i class="fa-solid ${item.icon}"></i>
          <span>${item.label}</span>
        </a>
      `;
    }

    /* Alat bantu uji coba — dev-only, tidak ikut ke BSP.
       Hanya ADMIN & IT; SALES dan QC tidak melihatnya sama sekali. */
    const canFormat = Utils.hasAnyRole(session.role, [ROLES.ADMIN, ROLES.IT]);

    html += `
      </nav>

      <div class="sidebar-footer">
        ${canFormat ? `
          <button class="sidebar-format" onclick="Sidebar.formatData()"
                  title="Hapus semua data transaksi uji coba (master data tetap)">
            <i class="fa-solid fa-eraser"></i>
            <span>Format Data</span>
          </button>
        ` : ''}
        <div class="sidebar-user">
          <div class="sidebar-user-avatar">
            ${session.full_name.charAt(0).toUpperCase()}
          </div>
          <div class="sidebar-user-info">
            <div class="sidebar-user-name">${Utils.escapeHtml(session.full_name)}</div>
            <div class="sidebar-user-role">${Utils.escapeHtml(session.role)}</div>
          </div>
        </div>
        <button class="sidebar-logout" onclick="Sidebar.logout()">
          <i class="fa-solid fa-right-from-bracket"></i>
          <span>Logout</span>
        </button>
      </div>
    `;

    container.innerHTML = html;
  },

  logout() {
    Utils.confirm('Logout?', 'Anda akan keluar dari sistem.', 'Ya, logout')
      .then(res => {
        if (res.isConfirmed) {
          Auth.logout();
          window.location.href = Utils.path('login.html');
        }
      });
  },

  /* ------------------------------------------------------------
   * FORMAT DATA — hapus seluruh data transaksi uji coba
   * ------------------------------------------------------------
   * Alat bantu pengembangan, sejajar dengan tombol "Kosongkan log"
   * di halaman Audit Log. Tidak ikut di-port ke BSP.
   * ------------------------------------------------------------ */

  formatData() {
    /* Penjaga kedua: tombolnya memang disembunyikan untuk SALES/QC,
       tapi handler-nya jangan menganggap itu satu-satunya penghalang. */
    if (!Auth.hasAnyRole([ROLES.ADMIN, ROLES.IT])) {
      return Utils.toastError('Hanya ADMIN dan IT yang boleh memformat data');
    }

    const n = DB.countTransactional();

    if (n.total === 0) {
      return Utils.alertSuccess('Sudah Bersih',
        'Tidak ada data transaksi yang perlu dihapus. Master data tetap utuh.');
    }

    const baris = [
      ['Request', n.requests],
      ['Color Code', n.color_codes],
      ['DCP header', n.dcp_headers],
      ['Panel DCP', n.dcp_items],
      ['MCP header', n.mcp_headers],
      ['Slot MCP', n.mcp_items],
      ['Foto', n.photos],
      ['Audit log', n.audit_logs],
    ].filter(([, v]) => v > 0)
     .map(([label, v]) => `<li>${label}: <strong>${v}</strong></li>`)
     .join('');

    Utils.confirmHtml(
      'Format Data Uji Coba?',
      `<div style="text-align:left;font-size:13px;">
         <p style="margin:0 0 8px;">Yang akan dihapus:</p>
         <ul style="margin:0 0 12px;padding-left:20px;">${baris}</ul>
         <p style="margin:0;">Master data (user, buyer, material, SO) <strong>tidak</strong> terpengaruh.
         Penomoran Color Code dan DCP kembali mulai dari awal.</p>
         <p style="margin:8px 0 0;color:#B91C1C;">Tindakan ini tidak bisa dibatalkan.</p>
       </div>`,
      'Ya, format data'
    ).then(res => {
      if (!res.isConfirmed) return;

      const session = Auth.getSession();
      DB.resetTransactional();

      /* Audit ditulis SESUDAH pembersihan — kalau sebelum, barisnya
         ikut terhapus oleh aksinya sendiri. */
      DB.audit('USER', session.user_id, 'FORMAT_DATA',
        `Format data uji coba oleh ${session.full_name}: ` +
        `${n.requests} request, ${n.dcp_headers} DCP, ${n.mcp_headers} MCP, ${n.photos} foto dihapus`);

      Utils.toastSuccess('Data transaksi dihapus');

      /* Redirect, bukan reload: halaman detail yang sedang terbuka
         record-nya sudah tidak ada lagi. */
      setTimeout(() => {
        window.location.href = Utils.path(Auth.getLandingPage());
      }, 800);
    });
  },

  /* Render page header (topbar dengan title + breadcrumb) */
  renderHeader(title, subtitle = '', containerId = 'page-header') {
    const container = Utils.el(containerId);
    if (!container) return;

    container.innerHTML = `
      <div class="page-header-inner">
        <div>
          <h1 class="page-title">${Utils.escapeHtml(title)}</h1>
          ${subtitle ? `<p class="page-subtitle">${Utils.escapeHtml(subtitle)}</p>` : ''}
        </div>
        <div class="page-header-actions" id="page-header-actions"></div>
      </div>
    `;
  },
};
