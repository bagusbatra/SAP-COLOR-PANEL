*&---------------------------------------------------------------------*
*& Report ZCP_FIX_USER
*&---------------------------------------------------------------------*
*& Pemulihan darurat untuk ZCP_USER.
*&
*& Dipakai saat seseorang menonaktifkan akunnya sendiri lewat
*& admin_user.htm dan akibatnya terkunci di luar aplikasi. Halaman
*& admin_user.htm tidak bisa dipakai memperbaikinya karena untuk
*& membukanya pun sudah butuh akses.
*&
*& Report ini SENGAJA tidak dibuat cantik dan tidak dipanggil dari
*& mana pun. Ia alat pemadam kebakaran: dibuat sekali, dipakai saat
*& perlu, dan boleh dihapus kalau dirasa mengganggu.
*&
*& Cara pakai: SE38 -> ZCP_FIX_USER -> Execute.
*&---------------------------------------------------------------------*
REPORT zcp_fix_user.

TABLES zcp_user.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-t01.
PARAMETERS: p_user TYPE zcp_user-user_id OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE text-t02.
PARAMETERS: p_akt RADIOBUTTON GROUP g1 DEFAULT 'X',
            p_hps RADIOBUTTON GROUP g1,
            p_lst RADIOBUTTON GROUP g1.
SELECTION-SCREEN END OF BLOCK b2.

DATA: gs_row TYPE zcp_user,
      gt_row TYPE STANDARD TABLE OF zcp_user,
      gv_ts  TYPE timestamp,
      gv_usr TYPE zcp_user-user_id.

START-OF-SELECTION.

  gv_usr = p_user.
  TRANSLATE gv_usr TO UPPER CASE.

*&--- Pilihan 3: tampilkan isi tabel, tidak mengubah apa pun ----------
  IF p_lst = 'X'.
    SELECT * INTO TABLE gt_row FROM zcp_user ORDER BY user_id.
    IF gt_row IS INITIAL.
      WRITE: / 'ZCP_USER kosong. Tidak ada baris yang memblokir siapa pun.'.
      RETURN.
    ENDIF.
    WRITE: / 'USER_ID', 25 'AKTIF', 33 'BUYER_ID', 46 'NAMA'.
    ULINE.
    LOOP AT gt_row INTO gs_row.
      WRITE: / gs_row-user_id, 25 gs_row-is_active,
               33 gs_row-buyer_id, 46 gs_row-full_name.
    ENDLOOP.
    RETURN.
  ENDIF.

*&--- Baris yang hendak diperbaiki harus ada --------------------------
  CLEAR gs_row.
  SELECT SINGLE * INTO gs_row FROM zcp_user WHERE user_id = gv_usr.

  IF sy-subrc <> 0.
    WRITE: / 'Tidak ada baris ZCP_USER untuk user', gv_usr.
    WRITE: / 'Berarti user ini TIDAK diblokir oleh ZCP_USER.'.
    WRITE: / 'Kalau tetap tidak bisa masuk, sebabnya ada di PFCG:'.
    WRITE: / 'role ZCP_ belum ditugaskan, atau User Comparison'.
    WRITE: / 'belum dijalankan sehingga AGR_USERS masih kosong.'.
    RETURN.
  ENDIF.

  GET TIME STAMP FIELD gv_ts.

*&--- Pilihan 1: aktifkan kembali -------------------------------------
  IF p_akt = 'X'.
    gs_row-is_active  = 'X'.
    gs_row-changed_by = sy-uname.
    gs_row-changed_at = gv_ts.
    UPDATE zcp_user FROM gs_row.
    IF sy-subrc = 0.
      COMMIT WORK.
      WRITE: / 'User', gv_usr, 'diaktifkan kembali. Silakan buka'.
      WRITE: / 'main.htm lagi -- tidak perlu logout dari SAP.'.
    ELSE.
      ROLLBACK WORK.
      WRITE: / 'Gagal memperbarui baris. Periksa lock di SM12.'.
    ENDIF.
    RETURN.
  ENDIF.

*&--- Pilihan 2: hapus barisnya ---------------------------------------
* Menghapus baris juga memulihkan akses. role_detect memperlakukan
* "tidak punya baris di ZCP_USER" sebagai keadaan yang sah -- yang
* hilang hanya BUYER_ID, dan role selain SALES memang tidak perlu.
  IF p_hps = 'X'.
    DELETE FROM zcp_user WHERE user_id = gv_usr.
    IF sy-subrc = 0.
      COMMIT WORK.
      WRITE: / 'Baris ZCP_USER untuk', gv_usr, 'dihapus.'.
      WRITE: / 'Akses pulih selama role ZCP_ di PFCG masih ada.'.
      WRITE: / 'Catatan: BUYER_ID user ini ikut hilang. Kalau dia'.
      WRITE: / 'ber-role SALES, petakan ulang lewat admin_user.htm.'.
    ELSE.
      ROLLBACK WORK.
      WRITE: / 'Gagal menghapus baris. Periksa lock di SM12.'.
    ENDIF.
  ENDIF.


*&---------------------------------------------------------------------*
*& Text elements yang harus diisi lewat menu Goto -> Text Elements
*&---------------------------------------------------------------------*
*  T01   User yang hendak diperbaiki
*  T02   Tindakan
*
*  Text untuk parameter (tab Selection Texts):
*    P_USER   User ID
*    P_AKT    Aktifkan kembali (IS_ACTIVE = X)
*    P_HPS    Hapus barisnya dari ZCP_USER
*    P_LST    Hanya tampilkan isi ZCP_USER
*
*  Kalau text element belum diisi, report tetap jalan -- judul blok
*  saja yang tampil kosong. Tidak perlu diisi kalau sedang buru-buru.
*&---------------------------------------------------------------------*
