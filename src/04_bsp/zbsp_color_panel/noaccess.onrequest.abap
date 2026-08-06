*&---------------------------------------------------------------------*
*& noaccess.htm - OnRequest
*&---------------------------------------------------------------------*
*& Menentukan SEBAB penolakan, bukan sekadar menyatakan ditolak. Tiga
*& sebab yang mungkin, masing-masing dengan tindak lanjut berbeda:
*&
*&   1. Tidak punya role ZCP_ apa pun        -> minta Basis assign role
*&   2. Baris ZCP_USER dengan IS_ACTIVE <> X -> minta IT aktifkan
*&   3. Role SALES tanpa BUYER_ID            -> minta IT isi buyer
*&
*& Tanpa membedakan ketiganya, user dan IT akan menebak-nebak, dan
*& tebakan pertama hampir selalu "coba login ulang" yang tidak
*& menyelesaikan apa pun.
*&
*& PENTING: blok penentuan role di bawah harus IDENTIK dengan yang ada
*& di _shared/role_detect.abap. Kalau kedua halaman memakai algoritma
*& berbeda, akan ada user yang dilempar bolak-balik antara main.htm dan
*& noaccess.htm tanpa henti karena keduanya tidak sepakat soal role-nya.
*&---------------------------------------------------------------------*

DATA: lt_agr      TYPE STANDARD TABLE OF agr_name,
      lv_agr      TYPE agr_name,
      lv_has_adm  TYPE c LENGTH 1,
      lv_has_it   TYPE c LENGTH 1,
      lv_has_qc   TYPE c LENGTH 1,
      lv_has_sls  TYPE c LENGTH 1,
      lv_role     TYPE string,
      ls_cpuser   TYPE zcp_user,
      lv_name     TYPE ad_namtext.

CLEAR: gv_user_id, gv_user_name, gv_reason, lv_role,
       lv_has_adm, lv_has_it, lv_has_qc, lv_has_sls.

gv_user_id = sy-uname.

* --- Nama tampilan dari master alamat SAP ----------------------------
CLEAR lv_name.
SELECT SINGLE b~name_text INTO lv_name
  FROM usr21 AS a
  INNER JOIN adrp AS b ON b~persnumber = a~persnumber
  WHERE a~bname = sy-uname.
IF sy-subrc = 0.
  gv_user_name = lv_name.
ELSE.
  gv_user_name = sy-uname.
ENDIF.

* --- Baca role PFCG, algoritma sama persis dengan role_detect --------
SELECT agr_name INTO TABLE lt_agr
  FROM agr_users
  WHERE uname     = sy-uname
    AND agr_name  LIKE 'ZCP_%'
    AND from_dat <= sy-datum
    AND to_dat   >= sy-datum.

LOOP AT lt_agr INTO lv_agr.
  CASE lv_agr.
    WHEN 'ZCP_ADMIN'.
      lv_has_adm = 'X'.
    WHEN 'ZCP_IT'.
      lv_has_it = 'X'.
    WHEN 'ZCP_QC'.
      lv_has_qc = 'X'.
    WHEN 'ZCP_SALES'.
      lv_has_sls = 'X'.
  ENDCASE.
ENDLOOP.

IF lv_has_adm = 'X'.
  lv_role = 'ADMIN'.
ELSEIF lv_has_it = 'X'.
  lv_role = 'IT'.
ELSEIF lv_has_qc = 'X'.
  lv_role = 'QC'.
ELSEIF lv_has_sls = 'X'.
  lv_role = 'SALES'.
ENDIF.

* --- Sebab 1: tidak punya role ZCP_ sama sekali ----------------------
IF lv_role IS INITIAL.
  CONCATENATE 'SAP user Anda belum ditugaskan ke role Color Panel'
              'mana pun. Hubungi Basis untuk meminta penugasan role'
              'ZCP_SALES, ZCP_ADMIN, ZCP_QC, atau ZCP_IT sesuai'
              'pekerjaan Anda.'
         INTO gv_reason SEPARATED BY space.
  RETURN.
ENDIF.

* --- Sebab 2: baris ZCP_USER ada tapi dinonaktifkan ------------------
CLEAR ls_cpuser.
SELECT SINGLE * INTO ls_cpuser
  FROM zcp_user
  WHERE user_id = sy-uname.

IF sy-subrc = 0 AND ls_cpuser-is_active <> 'X'.
  CONCATENATE 'Akses Color Panel Anda sedang dinonaktifkan.'
              'Hubungi IT untuk mengaktifkan kembali.'
         INTO gv_reason SEPARATED BY space.
  RETURN.
ENDIF.

* --- Sebab 3: Sales tanpa buyer --------------------------------------
IF lv_role = 'SALES' AND ls_cpuser-buyer_id IS INITIAL.
  CONCATENATE 'Anda terdaftar sebagai Sales tapi belum dipetakan ke'
              'buyer mana pun. Hubungi IT untuk mengisi Buyer pada'
              'halaman Master User.'
         INTO gv_reason SEPARATED BY space.
  RETURN.
ENDIF.

* --- Sampai di sini berarti sebenarnya berhak ------------------------
* Terjadi bila user membuka noaccess.htm langsung lewat URL padahal
* aksesnya baik-baik saja. Lempar balik ke dashboard daripada
* menampilkan halaman penolakan yang membingungkan.
navigation->goto_page( 'main.htm' ).
