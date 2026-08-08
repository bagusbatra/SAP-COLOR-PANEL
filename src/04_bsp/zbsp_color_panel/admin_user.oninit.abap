*&---------------------------------------------------------------------*
*& admin_user.htm - OnInitialization
*&---------------------------------------------------------------------*
*& DIPASTE ke tab Event Handler -> OnInitialization, BUKAN OnRequest.
*& Tab OnRequest halaman ini dibiarkan kosong. Alasannya ada di
*& admin_user.attributes.txt bagian bawah: halaman ini punya form, dan
*& OnRequest berjalan sebelum OnInputProcessing menyimpan perubahan.
*&
*& Isi:
*&   1. Deteksi role pemakai halaman (salinan _shared/role_detect.abap)
*&   2. Penjagaan: hanya IT
*&   3. Susun daftar SAP user yang punya role ZCP_
*&   4. Susun isi dropdown buyer
*&
*& Catatan: tidak ada satu pun SELECT di dalam LOOP. Seluruh data
*& dibaca sekali di depan lalu dicocokkan dengan READ TABLE.
*&---------------------------------------------------------------------*

DATA: lt_agr      TYPE STANDARD TABLE OF agr_name,
      lv_agr      TYPE agr_name,
      lv_has_adm  TYPE c LENGTH 1,
      lv_has_it   TYPE c LENGTH 1,
      lv_has_qc   TYPE c LENGTH 1,
      lv_has_sls  TYPE c LENGTH 1,
      ls_cpuser   TYPE zcp_user,
      lv_name     TYPE ad_namtext.

DATA: lt_assign   TYPE tt_assign,
      ls_assign   TYPE ty_assign,
      lt_cpuser   TYPE STANDARD TABLE OF zcp_user,
      lt_uname    TYPE tt_uname,
      ls_uname    TYPE ty_uname,
      lt_name     TYPE tt_name,
      ls_name     TYPE ty_name,
      ls_map      TYPE ty_usermap,
      ls_buyer    TYPE ty_buyer,
      lt_kunnr    TYPE tt_kunnr,
      ls_kunnr    TYPE ty_kunnr,
      lv_idx      TYPE sy-tabix.

CLEAR: gv_user_id, gv_user_name, gv_role, gv_buyer_id,
       gv_as_sales, gv_as_admin, gv_as_qc, gv_as_it,
       lv_has_adm, lv_has_it, lv_has_qc, lv_has_sls.

*&--- 1. Deteksi role pemakai halaman ---------------------------------

gv_user_id = sy-uname.

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
  gv_role = 'ADMIN'.
ELSEIF lv_has_it = 'X'.
  gv_role = 'IT'.
ELSEIF lv_has_qc = 'X'.
  gv_role = 'QC'.
ELSEIF lv_has_sls = 'X'.
  gv_role = 'SALES'.
ENDIF.

* --- Kapabilitas: apa yang boleh dikerjakan --------------------------
* Dipisahkan dari gv_role dengan sengaja. gv_role menjawab "dia siapa"
* untuk keperluan tampilan; keempat flag di bawah menjawab "dia boleh
* apa". Halaman memeriksa flag, BUKAN gv_role, sehingga pemetaan
* kewenangan bisa diubah di satu tempat saja.
*
* Flag diturunkan dari role PFCG yang BENAR-BENAR dipegang, bukan dari
* gv_role hasil prioritas. Kalau memakai gv_role, user ber-ZCP_ADMIN
* dan ZCP_IT sekaligus akan kehilangan kewenangan IT karena prioritas
* menjadikannya ADMIN.

CLEAR: gv_as_sales, gv_as_admin, gv_as_qc, gv_as_it.

IF lv_has_sls = 'X'.
  gv_as_sales = 'X'.
ENDIF.
IF lv_has_adm = 'X'.
  gv_as_admin = 'X'.
ENDIF.
IF lv_has_qc = 'X'.
  gv_as_qc = 'X'.
ENDIF.
IF lv_has_it = 'X'.
  gv_as_it = 'X'.
ENDIF.

* --- SEMENTARA: IT memegang akses penuh ------------------------------
* Keputusan 6 Agustus 2026. Selama pembangunan, role IT boleh
* menjalankan seluruh alur bisnis dari awal sampai akhir, supaya
* pengujian tidak tersendat menunggu akun role lain tersedia.
*
* INI HARUS DICABUT sebelum go-live. Cara mencabutnya: hapus blok
* IF di bawah ini saja -- tidak ada tempat lain yang perlu disentuh.
* Rinciannya di docs/superpowers/specs/2026-08-06-role-capability-map.md
* bagian 8.

IF lv_has_it = 'X'.
  gv_as_sales = 'X'.
  gv_as_admin = 'X'.
  gv_as_qc    = 'X'.
ENDIF.

IF gv_role IS INITIAL.
  navigation->goto_page( 'noaccess.htm' ).
  RETURN.
ENDIF.

CLEAR ls_cpuser.
SELECT SINGLE * INTO ls_cpuser
  FROM zcp_user
  WHERE user_id = sy-uname.

IF sy-subrc = 0.
  IF ls_cpuser-is_active <> 'X'.
    navigation->goto_page( 'noaccess.htm' ).
    RETURN.
  ENDIF.
  gv_buyer_id  = ls_cpuser-buyer_id.
  gv_user_name = ls_cpuser-full_name.
ENDIF.

IF gv_user_name IS INITIAL.
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
ENDIF.

*&--- 2. Penjagaan: halaman ini hanya untuk IT ------------------------
* Menyembunyikan menu di sidebar saja tidak cukup. Tanpa penjagaan di
* sini, siapa pun yang tahu nama halamannya bisa membukanya lewat URL.

IF gv_as_it <> 'X'.
  navigation->goto_page( 'main.htm' ).
  RETURN.
ENDIF.

*&--- 3. Daftar SAP user yang punya role ZCP_ -------------------------

CLEAR gt_users.

SELECT uname agr_name INTO TABLE lt_assign
  FROM agr_users
  WHERE agr_name  LIKE 'ZCP_%'
    AND from_dat <= sy-datum
    AND to_dat   >= sy-datum.

IF lt_assign IS INITIAL.
  RETURN.
ENDIF.

* AT END OF menuntut tabel terurut menurut field yang dipakai, dan
* field itu harus berada di awal struktur. ty_assign memenuhi keduanya.
SORT lt_assign BY uname agr_name.

CLEAR: lv_has_adm, lv_has_it, lv_has_qc, lv_has_sls.

LOOP AT lt_assign INTO ls_assign.

  CASE ls_assign-agr_name.
    WHEN 'ZCP_ADMIN'.
      lv_has_adm = 'X'.
    WHEN 'ZCP_IT'.
      lv_has_it = 'X'.
    WHEN 'ZCP_QC'.
      lv_has_qc = 'X'.
    WHEN 'ZCP_SALES'.
      lv_has_sls = 'X'.
  ENDCASE.

  AT END OF uname.

    CLEAR ls_map.
    ls_map-user_id = ls_assign-uname.

    IF lv_has_adm = 'X'.
      ls_map-role = 'ADMIN'.
    ELSEIF lv_has_it = 'X'.
      ls_map-role = 'IT'.
    ELSEIF lv_has_qc = 'X'.
      ls_map-role = 'QC'.
    ELSEIF lv_has_sls = 'X'.
      ls_map-role = 'SALES'.
    ENDIF.

    APPEND ls_map TO gt_users.
    CLEAR: lv_has_adm, lv_has_it, lv_has_qc, lv_has_sls.

  ENDAT.

ENDLOOP.

*&--- 4. Lengkapi dengan pemetaan buyer dan nama ----------------------

SELECT * INTO TABLE lt_cpuser
  FROM zcp_user.
SORT lt_cpuser BY user_id.

* gt_users-user_id bertipe ZCP_DE_USER_ID (CHAR20), sedangkan
* USR21-BNAME adalah XUBNAME (CHAR12). FOR ALL ENTRIES menuntut tipe
* dan panjang persis sama, jadi gt_users tidak bisa jadi pendorong.
* lt_uname adalah jembatannya: isi sama, tipe mengikuti kolom tujuan.
CLEAR lt_uname.
LOOP AT gt_users INTO ls_map.
  CLEAR ls_uname.
  ls_uname-bname = ls_map-user_id.
  APPEND ls_uname TO lt_uname.
ENDLOOP.

SORT lt_uname BY bname.
DELETE ADJACENT DUPLICATES FROM lt_uname COMPARING bname.

CLEAR lt_name.
IF lt_uname IS NOT INITIAL.
  SELECT a~bname b~name_text INTO TABLE lt_name
    FROM usr21 AS a
    INNER JOIN adrp AS b ON b~persnumber = a~persnumber
    FOR ALL ENTRIES IN lt_uname
    WHERE a~bname = lt_uname-bname.
  SORT lt_name BY bname.
ENDIF.

* gt_buyers tidak lagi berisi daftar buyer terdaftar -- tabel ZCP_BUYER
* sudah dipensiunkan 8 Agustus 2026. Isinya sekarang hanya nama
* pelanggan untuk KUNNR yang SUDAH dipetakan ke user, semata untuk
* ditampilkan di kolom Buyer pada tabel di bawah.
*
* Pemilihan buyer di form memakai input KUNNR bebas dengan validasi
* ke KNA1, bukan dropdown: master pelanggan SAP bisa berisi ribuan
* baris, dan memuat semuanya ke dropdown akan membuat halaman berat
* tanpa membuat pemilihan jadi lebih mudah.
CLEAR lt_kunnr.
LOOP AT lt_cpuser INTO ls_cpuser WHERE buyer_id IS NOT INITIAL.
  CLEAR ls_kunnr.
  ls_kunnr-kunnr = ls_cpuser-buyer_id.
  APPEND ls_kunnr TO lt_kunnr.
ENDLOOP.
SORT lt_kunnr BY kunnr.
DELETE ADJACENT DUPLICATES FROM lt_kunnr COMPARING kunnr.

CLEAR gt_buyers.
IF lt_kunnr IS NOT INITIAL.
  SELECT kunnr name1 INTO TABLE gt_buyers
    FROM kna1
    FOR ALL ENTRIES IN lt_kunnr
    WHERE kunnr = lt_kunnr-kunnr.
  SORT gt_buyers BY kunnr.
ENDIF.

LOOP AT gt_users INTO ls_map.
  lv_idx = sy-tabix.

  CLEAR ls_cpuser.
  READ TABLE lt_cpuser INTO ls_cpuser
       WITH KEY user_id = ls_map-user_id BINARY SEARCH.
  IF sy-subrc = 0.
    ls_map-has_row   = 'X'.
    ls_map-is_active = ls_cpuser-is_active.
    ls_map-buyer_id  = ls_cpuser-buyer_id.
    ls_map-full_name = ls_cpuser-full_name.

    IF ls_map-buyer_id IS NOT INITIAL.
      CLEAR ls_kunnr.
      ls_kunnr-kunnr = ls_map-buyer_id.
      CLEAR ls_buyer.
      READ TABLE gt_buyers INTO ls_buyer
           WITH KEY kunnr = ls_kunnr-kunnr BINARY SEARCH.
      IF sy-subrc = 0.
        ls_map-buyer_name = ls_buyer-name1.
      ENDIF.
    ENDIF.
  ENDIF.

  IF ls_map-full_name IS INITIAL.
*   Kunci pencarian disalin dulu ke field bertipe sama dengan lt_name,
*   supaya BINARY SEARCH membandingkan CHAR12 lawan CHAR12. Tanpa itu
*   perbandingannya lintas panjang dan urutan hasil SORT tidak lagi
*   menjamin pencarian binernya benar.
    CLEAR ls_uname.
    ls_uname-bname = ls_map-user_id.

    CLEAR ls_name.
    READ TABLE lt_name INTO ls_name
         WITH KEY bname = ls_uname-bname BINARY SEARCH.
    IF sy-subrc = 0.
      ls_map-full_name = ls_name-name_text.
    ELSE.
      ls_map-full_name = ls_map-user_id.
    ENDIF.
  ENDIF.

  MODIFY gt_users FROM ls_map INDEX lv_idx.
ENDLOOP.

SORT gt_users BY role user_id.
