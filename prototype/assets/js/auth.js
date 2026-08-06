/* ============================================================
 * Color Panel Prototype - Authentication
 * ============================================================
 * Session disimpan di sessionStorage (bukan localStorage) supaya
 * hilang saat browser tutup — sesuai keputusan Pak Yogi.
 * ============================================================ */

const Auth = {

  /* ------------------------------------------------------------
   * LOGIN
   * ------------------------------------------------------------ */

  login(userId, password) {
    const user = DB.getUser(userId);

    if (!user) {
      return { ok: false, msg: 'User ID tidak ditemukan' };
    }
    if (user.is_active !== 'X') {
      return { ok: false, msg: 'User tidak aktif' };
    }
    if (user.password !== password) {
      return { ok: false, msg: 'Password salah' };
    }

    const session = {
      user_id: user.user_id,
      full_name: user.full_name,
      role: user.role, // comma-separated, e.g. "ADMIN,IT"
      buyer_id: user.buyer_id || '',
      login_at: Utils.now(),
    };

    sessionStorage.setItem(CONFIG.SESSION_KEY, JSON.stringify(session));

    /* Update last_login di "table" users */
    DB.update('users', 'user_id', user.user_id, { last_login: Utils.now() });

    /* Audit */
    DB.audit('USER', user.user_id, 'LOGIN', `Login berhasil oleh ${user.full_name}`);

    return { ok: true, session: session };
  },

  logout() {
    const session = this.getSession();
    if (session) {
      DB.audit('USER', session.user_id, 'LOGOUT', `Logout oleh ${session.full_name}`);
    }
    sessionStorage.removeItem(CONFIG.SESSION_KEY);
  },

  /* ------------------------------------------------------------
   * SESSION
   * ------------------------------------------------------------ */

  getSession() {
    const raw = sessionStorage.getItem(CONFIG.SESSION_KEY);
    return raw ? JSON.parse(raw) : null;
  },

  isLoggedIn() {
    return this.getSession() !== null;
  },

  /* ------------------------------------------------------------
   * ROLE CHECK
   * ------------------------------------------------------------ */

  hasRole(role) {
    const s = this.getSession();
    return s ? Utils.hasRole(s.role, role) : false;
  },

  hasAnyRole(roles) {
    const s = this.getSession();
    return s ? Utils.hasAnyRole(s.role, roles) : false;
  },

  getPrimaryRole() {
    const s = this.getSession();
    return s ? Utils.getPrimaryRole(s.role) : null;
  },

  /* ------------------------------------------------------------
   * GUARD — dipanggil di setiap page
   * requiredRoles: array of roles, atau [] untuk hanya cek login
   * ------------------------------------------------------------ */

  guard(requiredRoles = []) {
    if (!this.isLoggedIn()) {
      window.location.href = Utils.path('login.html');
      return false;
    }
    if (requiredRoles.length > 0 && !this.hasAnyRole(requiredRoles)) {
      /* Balikkan ke landing page role-nya sendiri, BUKAN dashboard.
         SALES tidak punya akses dashboard — kalau dipaksa ke sana
         guard dashboard menolak lagi dan user terjebak bolak-balik. */
      const landing = this.getLandingPage();
      Utils.alertError('Akses Ditolak', 'Anda tidak punya izin untuk mengakses halaman ini.')
        .then(() => window.location.href = Utils.path(landing));
      return false;
    }
    return true;
  },

  /* ------------------------------------------------------------
   * LANDING PAGE per role (setelah login)
   * ------------------------------------------------------------ */

  getLandingPage() {
    const primary = this.getPrimaryRole();
    return ROLE_LANDING[primary] || 'dashboard.html';
  },
};
