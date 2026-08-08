*&---------------------------------------------------------------------*
*& req_list.htm - OnInitialization
*&---------------------------------------------------------------------*
*& DIPASTE ke tab Event Handler -> OnInitialization. Tab OnRequest
*& dibiarkan kosong.
*&
*& Isi:
*&   1. Deteksi role + kapabilitas (salinan _shared/role_detect.abap)
*&   2. Penjagaan: butuh kapabilitas Sales atau Admin
*&   3. Tentukan cakupan data: seluruh buyer, atau buyer milik Sales
*&   4. Baca request + hitung status itemnya
*&---------------------------------------------------------------------*

DATA: lt_agr      TYPE STANDARD TABLE OF agr_name,
      lv_agr      TYPE agr_name,
      lv_has_adm  TYPE c LENGTH 1,
      lv_has_it   TYPE c LENGTH 1,
      lv_has_qc   TYPE c LENGTH 1,
      lv_has_sls  TYPE c LENGTH 1,
      ls_cpuser   TYPE zcp_user,
      lv_name     TYPE ad_namtext.

DATA: lt_hdr      TYPE STANDARD TABLE OF zcp_request,
      ls_hdr      TYPE zcp_request,
      lt_itm      TYPE tt_itmstat,
      ls_itm      TYPE ty_itmstat,
      lt_buyer    TYPE tt_buyer,
      ls_buyer    TYPE ty_buyer,
      lt_kunnr    TYPE tt_kunnr,
      ls_kunnr    TYPE ty_kunnr,
      ls_row      TYPE ty_reqrow,
      lv_fstat    TYPE zcp_de_req_st.

CLEAR: gv_user_id, gv_user_name, gv_role, gv_buyer_id,
       gv_as_sales, gv_as_admin, gv_as_qc, gv_as_it,
       lv_has_adm, lv_has_it, lv_has_qc, lv_has_sls.

*&--- 1. Deteksi role dan kapabilitas ---------------------------------

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

*&--- 2. Penjagaan ----------------------------------------------------

IF gv_as_sales <> 'X' AND gv_as_admin <> 'X'.
  navigation->goto_page( 'main.htm' ).
  RETURN.
ENDIF.

*&--- 3. Cakupan data --------------------------------------------------
* Sales murni hanya melihat request buyer-nya sendiri. Siapa pun yang
* punya kapabilitas Admin melihat semuanya.
*
* Perhatikan urutan pemeriksaan: kapabilitas Admin diperiksa LEBIH DULU.
* Kalau dibalik, pemegang IT -- yang selama masa pembangunan memegang
* kapabilitas Sales juga -- akan tersaring ke buyer-nya sendiri dan
* mengira datanya hilang.

CLEAR: gt_req, gv_scope.

IF gv_as_admin = 'X'.

  gv_scope = 'Seluruh buyer'.

  SELECT * INTO TABLE lt_hdr
    FROM zcp_request
    ORDER BY request_id DESCENDING.

ELSE.

  IF gv_buyer_id IS INITIAL.
*   Tidak seharusnya terjadi -- role_detect sudah menolak Sales tanpa
*   buyer. Dijaga di sini juga supaya tidak ada jalur yang berujung
*   menampilkan seluruh buyer karena satu penjagaan terlewat.
    navigation->goto_page( 'noaccess.htm' ).
    RETURN.
  ENDIF.

  CONCATENATE 'Hanya buyer' gv_buyer_id INTO gv_scope SEPARATED BY space.

  SELECT * INTO TABLE lt_hdr
    FROM zcp_request
    WHERE buyer_id = gv_buyer_id
    ORDER BY request_id DESCENDING.

ENDIF.

* gv_filter bertipe STRING karena datang dari parameter URL; status
* bertipe CHAR1. Disalin dulu supaya perbandingannya setipe.
IF gv_filter IS NOT INITIAL.
  lv_fstat = gv_filter.
  DELETE lt_hdr WHERE status <> lv_fstat.
ENDIF.

IF lt_hdr IS INITIAL.
  RETURN.
ENDIF.

*&--- 4. Susun baris tampilan ------------------------------------------

* Status seluruh item dibaca sekali, bukan per request di dalam loop.
SELECT request_id status INTO TABLE lt_itm
  FROM zcp_request_itm
  FOR ALL ENTRIES IN lt_hdr
  WHERE request_id = lt_hdr-request_id.

* Nama buyer dibaca langsung dari master pelanggan SAP. Sejak
* 8 Agustus 2026 tidak ada tabel ZCP_BUYER -- nama yang tampil selalu
* yang berlaku sekarang, bukan salinan yang dibuat saat request dibuat.
CLEAR lt_kunnr.
LOOP AT lt_hdr INTO ls_hdr.
  CLEAR ls_kunnr.
  ls_kunnr-kunnr = ls_hdr-buyer_id.
  APPEND ls_kunnr TO lt_kunnr.
ENDLOOP.
SORT lt_kunnr BY kunnr.
DELETE ADJACENT DUPLICATES FROM lt_kunnr COMPARING kunnr.

CLEAR lt_buyer.
IF lt_kunnr IS NOT INITIAL.
  SELECT kunnr name1 INTO TABLE lt_buyer
    FROM kna1
    FOR ALL ENTRIES IN lt_kunnr
    WHERE kunnr = lt_kunnr-kunnr.
  SORT lt_buyer BY kunnr.
ENDIF.

LOOP AT lt_hdr INTO ls_hdr.

  CLEAR ls_row.
  ls_row-request_id   = ls_hdr-request_id.
  ls_row-so_number    = ls_hdr-so_number.
  ls_row-buyer_id     = ls_hdr-buyer_id.
  ls_row-request_date = ls_hdr-request_date.
  ls_row-status       = ls_hdr-status.
  ls_row-sales_user   = ls_hdr-sales_user.
  ls_row-remarks      = ls_hdr-remarks.

  CLEAR ls_kunnr.
  ls_kunnr-kunnr = ls_hdr-buyer_id.

  CLEAR ls_buyer.
  READ TABLE lt_buyer INTO ls_buyer
       WITH KEY kunnr = ls_kunnr-kunnr BINARY SEARCH.
  IF sy-subrc = 0.
    ls_row-buyer_name = ls_buyer-name1.
  ENDIF.

  LOOP AT lt_itm INTO ls_itm WHERE request_id = ls_hdr-request_id.
    ls_row-cnt_total = ls_row-cnt_total + 1.
    CASE ls_itm-status.
      WHEN 'P'.
        ls_row-cnt_pending = ls_row-cnt_pending + 1.
      WHEN 'A'.
        ls_row-cnt_appr = ls_row-cnt_appr + 1.
      WHEN 'R'.
        ls_row-cnt_rej = ls_row-cnt_rej + 1.
    ENDCASE.
  ENDLOOP.

  APPEND ls_row TO gt_req.

ENDLOOP.
