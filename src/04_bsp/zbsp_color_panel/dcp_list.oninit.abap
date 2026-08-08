*&---------------------------------------------------------------------*
*& dcp_list.htm - OnInitialization
*&---------------------------------------------------------------------*
*& DIPASTE ke tab Event Handler -> OnInitialization. Tab OnRequest
*& dibiarkan kosong.
*&
*& Isi:
*&   1. Deteksi role + kapabilitas (salinan _shared/role_detect.abap)
*&   2. Penjagaan: butuh kapabilitas Admin atau QC
*&   3. Baca header DCP, hitung panel per status, tandai masa berlaku
*&---------------------------------------------------------------------*

DATA: lt_agr      TYPE STANDARD TABLE OF agr_name,
      lv_agr      TYPE agr_name,
      lv_has_adm  TYPE c LENGTH 1,
      lv_has_it   TYPE c LENGTH 1,
      lv_has_qc   TYPE c LENGTH 1,
      lv_has_sls  TYPE c LENGTH 1,
      ls_cpuser   TYPE zcp_user,
      lv_name     TYPE ad_namtext.

DATA: lt_hdr      TYPE STANDARD TABLE OF zcp_dcp_hdr,
      ls_hdr      TYPE zcp_dcp_hdr,
      lt_pan      TYPE tt_panstat,
      ls_pan      TYPE ty_panstat,
      lt_kunnr    TYPE tt_kunnr,
      ls_kunnr    TYPE ty_kunnr,
      lt_buyer    TYPE tt_buyer,
      ls_buyer    TYPE ty_buyer,
      ls_row      TYPE ty_dcprow,
      lv_fstat    TYPE zcp_de_dcp_st.

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
* DCP adalah wilayah Admin dan QC. Sales tidak melihat halaman ini --
* alur Sales berhenti setelah request dibuat.

IF gv_as_admin <> 'X' AND gv_as_qc <> 'X'.
  navigation->goto_page( 'main.htm' ).
  RETURN.
ENDIF.

*&--- 3. Baca header DCP -----------------------------------------------

CLEAR: gt_dcp, gv_cnt_all.

SELECT * INTO TABLE lt_hdr
  FROM zcp_dcp_hdr
  ORDER BY dcp_id DESCENDING.

DESCRIBE TABLE lt_hdr LINES gv_cnt_all.

IF lt_hdr IS INITIAL.
  RETURN.
ENDIF.

* Saringan status. gv_filter bertipe STRING karena datang dari parameter
* URL; status bertipe CHAR1. Disalin dulu supaya perbandingannya setipe.
IF gv_filter IS NOT INITIAL.
  lv_fstat = gv_filter.
  DELETE lt_hdr WHERE status <> lv_fstat.
ENDIF.

IF lt_hdr IS INITIAL.
  RETURN.
ENDIF.

*&--- Status seluruh panel dibaca sekali, bukan per DCP di dalam loop --

SELECT dcp_id status INTO TABLE lt_pan
  FROM zcp_dcp_item
  FOR ALL ENTRIES IN lt_hdr
  WHERE dcp_id = lt_hdr-dcp_id.

*&--- Nama buyer dari master pelanggan SAP -----------------------------

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

*&--- Susun baris tampilan ----------------------------------------------

LOOP AT lt_hdr INTO ls_hdr.

  CLEAR ls_row.
  ls_row-dcp_id      = ls_hdr-dcp_id.
  ls_row-so_number   = ls_hdr-so_number.
  ls_row-so_item     = ls_hdr-so_item.
  ls_row-matnr       = ls_hdr-matnr.
  ls_row-maktx       = ls_hdr-maktx.
  ls_row-color_code  = ls_hdr-color_code.
  ls_row-buyer_id    = ls_hdr-buyer_id.
  ls_row-qty_total   = ls_hdr-qty_total.
  ls_row-mfg_date    = ls_hdr-mfg_date.
  ls_row-expire_date = ls_hdr-expire_date.
  ls_row-status      = ls_hdr-status.

  CLEAR ls_kunnr.
  ls_kunnr-kunnr = ls_hdr-buyer_id.
  CLEAR ls_buyer.
  READ TABLE lt_buyer INTO ls_buyer
       WITH KEY kunnr = ls_kunnr-kunnr BINARY SEARCH.
  IF sy-subrc = 0.
    ls_row-buyer_name = ls_buyer-name1.
  ENDIF.

  LOOP AT lt_pan INTO ls_pan WHERE dcp_id = ls_hdr-dcp_id.
    CASE ls_pan-status.
      WHEN 'NA'.
        ls_row-cnt_na = ls_row-cnt_na + 1.
      WHEN 'AK'.
        ls_row-cnt_ak = ls_row-cnt_ak + 1.
      WHEN 'SB'.
        ls_row-cnt_sb = ls_row-cnt_sb + 1.
      WHEN 'AP'.
        ls_row-cnt_ap = ls_row-cnt_ap + 1.
      WHEN 'RJ'.
        ls_row-cnt_rj = ls_row-cnt_rj + 1.
      WHEN 'OB'.
        ls_row-cnt_ob = ls_row-cnt_ob + 1.
    ENDCASE.
  ENDLOOP.

* Masa berlaku hanya bermakna untuk DCP yang masih Open. Yang sudah
* Closed atau Rejected tidak perlu diingatkan, dan menandainya merah
* hanya membuat daftar terlihat lebih genting dari kenyataan.
  IF ls_hdr-status = 'O'.
    IF ls_hdr-expire_date IS NOT INITIAL AND ls_hdr-expire_date < sy-datum.
      ls_row-flag_exp = 'X'.
    ELSEIF ls_hdr-reminder_date IS NOT INITIAL
       AND ls_hdr-reminder_date <= sy-datum.
      ls_row-flag_rem = 'X'.
    ENDIF.
  ENDIF.

  APPEND ls_row TO gt_dcp.

ENDLOOP.

*&--- Saringan masa berlaku, diterapkan setelah flag dihitung -----------

IF gv_expiry = 'EXP'.
  DELETE gt_dcp WHERE flag_exp <> 'X'.
ELSEIF gv_expiry = 'REM'.
  DELETE gt_dcp WHERE flag_rem <> 'X'.
ENDIF.
