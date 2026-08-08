*&---------------------------------------------------------------------*
*& admin_user.htm - OnInputProcessing
*&---------------------------------------------------------------------*
*& Menyimpan pemetaan satu SAP user ke buyer, plus penanda aktif.
*&
*& Yang TIDAK dikerjakan halaman ini:
*&   - membuat SAP user          -> SU01
*&   - mengubah password         -> SU01, aplikasi tidak tahu password
*&   - memberi/mencabut role     -> PFCG
*&
*& Halaman ini hanya mengisi apa yang tidak bisa dibawa role PFCG,
*& yaitu BUYER_ID, dan menyediakan rem cepat lewat IS_ACTIVE.
*&
*& Penjagaan role ada di OnInitialization. Handler ini tetap memeriksa
*& ulang karena OnInputProcessing berjalan LEBIH DULU daripada
*& OnInitialization -- tanpa pemeriksaan di sini, user non-IT yang
*& mengirim form lewat URL akan tersimpan datanya sebelum sempat
*& dilempar keluar.
*&---------------------------------------------------------------------*

DATA: lv_event   TYPE string,
      lv_user    TYPE zcp_de_user_id,
      lv_buyer   TYPE zcp_de_buyer_id,
      lv_active  TYPE c LENGTH 1,
      lv_bname   TYPE usr21-bname,
      lv_chk     TYPE usr21-bname,
      lv_name    TYPE ad_namtext,
      lv_bkunnr  TYPE kna1-kunnr,
      lv_bname   TYPE kna1-name1,
      lv_loevm   TYPE kna1-loevm,
      lv_ts      TYPE timestamp,
      ls_row     TYPE zcp_user,
      lt_agr     TYPE STANDARD TABLE OF agr_name,
      lv_role    TYPE string,
      lv_agr     TYPE agr_name,
      lv_adm     TYPE c LENGTH 1,
      lv_it      TYPE c LENGTH 1.

CLEAR: gv_error, gv_info.

lv_event = request->get_form_field( 'onInputProcessing' ).

IF lv_event <> 'save'.
  RETURN.
ENDIF.

*&--- Penjagaan role, diulang di sini dengan sengaja -------------------

CLEAR: lv_adm, lv_it.

SELECT agr_name INTO TABLE lt_agr
  FROM agr_users
  WHERE uname     = sy-uname
    AND agr_name  LIKE 'ZCP_%'
    AND from_dat <= sy-datum
    AND to_dat   >= sy-datum.

LOOP AT lt_agr INTO lv_agr.
  CASE lv_agr.
    WHEN 'ZCP_ADMIN'.
      lv_adm = 'X'.
    WHEN 'ZCP_IT'.
      lv_it = 'X'.
  ENDCASE.
ENDLOOP.

* Syaratnya memegang ZCP_IT, titik. Sengaja TIDAK memakai gv_role
* hasil prioritas: user ber-ZCP_ADMIN sekaligus ZCP_IT tetap berhak,
* padahal gv_role-nya akan berbunyi ADMIN.
IF lv_it <> 'X'.
  gv_error = 'Hanya pemegang role ZCP_IT yang boleh mengubah pemetaan user'.
  RETURN.
ENDIF.

*&--- Baca isian form -------------------------------------------------

lv_user  = request->get_form_field( 'sel_user' ).
lv_buyer = request->get_form_field( 'sel_buyer' ).
lv_active = request->get_form_field( 'sel_active' ).

TRANSLATE lv_user  TO UPPER CASE.
TRANSLATE lv_buyer TO UPPER CASE.

IF lv_user IS INITIAL.
  gv_error = 'Pilih SAP user yang hendak dipetakan'.
  RETURN.
ENDIF.

*&--- Validasi: user harus SAP user yang benar-benar ada ---------------
* lv_user bertipe ZCP_DE_USER_ID (CHAR20), sedangkan USR21-BNAME dan
* AGR_USERS-UNAME bertipe XUBNAME (CHAR12). Disalin sekali ke lv_bname
* supaya seluruh perbandingan ke tabel SAP memakai panjang yang sama.

lv_bname = lv_user.

*&--- Penjagaan: jangan biarkan orang mengunci dirinya sendiri ---------
* Menonaktifkan akun sendiri langsung menutup pintu masuk ke halaman
* ini juga, sehingga tidak ada cara memperbaikinya dari dalam aplikasi.
* Pemulihannya butuh report ZCP_FIX_USER lewat SE38 -- pengalaman yang
* tidak boleh dialami siapa pun hanya karena salah pencet.
*
* Yang dijaga hanya penonaktifan diri sendiri. Menonaktifkan orang lain
* tetap boleh, dan mengubah buyer diri sendiri juga boleh.

IF lv_bname = sy-uname AND lv_active <> 'X'.
  gv_error = 'Anda tidak bisa menonaktifkan akun Anda sendiri. Minta pengguna IT lain yang melakukannya.'.
  RETURN.
ENDIF.

CLEAR lv_chk.
SELECT SINGLE bname INTO lv_chk
  FROM usr21
  WHERE bname = lv_bname.

IF sy-subrc <> 0.
  CONCATENATE 'SAP user' lv_user 'tidak ditemukan. Buat dulu lewat SU01.'
         INTO gv_error SEPARATED BY space.
  RETURN.
ENDIF.

*&--- Validasi: user harus punya role ZCP_ -----------------------------
* Memetakan buyer untuk user tanpa role Color Panel tidak memberi akses
* apa pun. Barisnya hanya akan mengendap dan membingungkan orang
* berikutnya yang membaca tabel ini.

CLEAR lt_agr.
SELECT agr_name INTO TABLE lt_agr
  FROM agr_users
  WHERE uname     = lv_bname
    AND agr_name  LIKE 'ZCP_%'
    AND from_dat <= sy-datum
    AND to_dat   >= sy-datum.

IF lt_agr IS INITIAL.
  CONCATENATE 'User' lv_user 'belum punya role ZCP_ apa pun.'
              'Minta Basis menugaskan role lebih dulu lewat PFCG,'
              'lalu jalankan User Comparison.'
         INTO gv_error SEPARATED BY space.
  RETURN.
ENDIF.

*&--- Validasi: buyer harus ada dan aktif ------------------------------

* Divalidasi ke master pelanggan SAP, bukan ke daftar buatan sendiri.
* ZCP_BUYER dipensiunkan 8 Agustus 2026.
IF lv_buyer IS NOT INITIAL.

* Terima ketikan tanpa nol di depan: 12345 sama dengan 0000012345
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = lv_buyer
    IMPORTING
      output = lv_bkunnr.

  lv_buyer = lv_bkunnr.

  CLEAR: lv_bname, lv_loevm.
  SELECT SINGLE name1 loevm INTO (lv_bname, lv_loevm)
    FROM kna1
    WHERE kunnr = lv_bkunnr.

  IF sy-subrc <> 0.
    CONCATENATE 'Pelanggan' lv_bkunnr 'tidak ada di master pelanggan'
                'KNA1. Periksa nomornya lewat XD03.'
           INTO gv_error SEPARATED BY space.
    RETURN.
  ENDIF.

  IF lv_loevm = 'X'.
    CONCATENATE 'Pelanggan' lv_bkunnr lv_bname 'ditandai untuk dihapus'
                'di master pelanggan.'
           INTO gv_error SEPARATED BY space.
    RETURN.
  ENDIF.

ENDIF.

*&--- Validasi: Sales wajib punya buyer --------------------------------

CLEAR lv_role.
LOOP AT lt_agr INTO lv_agr.
  IF lv_agr = 'ZCP_SALES'.
    lv_role = 'SALES'.
  ENDIF.
  IF lv_agr = 'ZCP_ADMIN' OR lv_agr = 'ZCP_IT' OR lv_agr = 'ZCP_QC'.
    CLEAR lv_role.
    EXIT.
  ENDIF.
ENDLOOP.

IF lv_role = 'SALES' AND lv_buyer IS INITIAL.
  CONCATENATE 'User' lv_user 'ber-role SALES, jadi Buyer wajib diisi.'
              'Sales tanpa buyer akan melihat request milik semua buyer.'
         INTO gv_error SEPARATED BY space.
  RETURN.
ENDIF.

*&--- Simpan -----------------------------------------------------------

GET TIME STAMP FIELD lv_ts.

CLEAR ls_row.
SELECT SINGLE * INTO ls_row
  FROM zcp_user
  WHERE user_id = lv_user.

IF sy-subrc = 0.

  ls_row-buyer_id   = lv_buyer.
  ls_row-is_active  = lv_active.
  ls_row-changed_by = sy-uname.
  ls_row-changed_at = lv_ts.

  UPDATE zcp_user FROM ls_row.

  IF sy-subrc = 0.
    CONCATENATE 'Pemetaan user' lv_user 'diperbarui.'
           INTO gv_info SEPARATED BY space.
  ELSE.
    gv_error = 'Gagal memperbarui baris ZCP_USER'.
  ENDIF.

ELSE.

  CLEAR lv_name.
  SELECT SINGLE b~name_text INTO lv_name
    FROM usr21 AS a
    INNER JOIN adrp AS b ON b~persnumber = a~persnumber
    WHERE a~bname = lv_bname.

  CLEAR ls_row.
  ls_row-user_id    = lv_user.
  ls_row-full_name  = lv_name.
  ls_row-buyer_id   = lv_buyer.
  ls_row-is_active  = lv_active.
  ls_row-created_by = sy-uname.
  ls_row-created_at = lv_ts.
  ls_row-changed_by = sy-uname.
  ls_row-changed_at = lv_ts.

  INSERT zcp_user FROM ls_row.

  IF sy-subrc = 0.
    CONCATENATE 'User' lv_user 'dipetakan.'
           INTO gv_info SEPARATED BY space.
  ELSE.
    gv_error = 'Gagal menyisipkan baris ZCP_USER'.
  ENDIF.

ENDIF.
