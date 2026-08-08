*&---------------------------------------------------------------------*
*& req_detail.htm - OnInitialization
*&---------------------------------------------------------------------*
*& DIPASTE ke tab Event Handler -> OnInitialization. Tab OnRequest
*& dibiarkan kosong.
*&
*& Handler ini berjalan SETELAH OnInputProcessing, jadi daftar item yang
*& dibaca di sini sudah mencerminkan keputusan yang barusan disimpan.
*& Itu disengaja: kalau pembacaan ditaruh di OnRequest, tabel yang
*& tampil masih memuat status lama dan Admin akan mengira klik-nya
*& tidak berpengaruh.
*&
*& gt_result TIDAK disentuh di sini -- isinya berasal dari
*& OnInputProcessing dan harus bertahan sampai dirender.
*&---------------------------------------------------------------------*

DATA: lt_agr      TYPE STANDARD TABLE OF agr_name,
      lv_agr      TYPE agr_name,
      lv_has_adm  TYPE c LENGTH 1,
      lv_has_it   TYPE c LENGTH 1,
      lv_has_qc   TYPE c LENGTH 1,
      lv_has_sls  TYPE c LENGTH 1,
      ls_cpuser   TYPE zcp_user,
      lv_name     TYPE ad_namtext.

DATA: ls_hdr      TYPE zcp_request,
      lt_itm      TYPE STANDARD TABLE OF zcp_request_itm,
      ls_itm      TYPE zcp_request_itm,
      ls_row      TYPE ty_itmrow,
      lv_ccode    TYPE zcp_de_color_code,
      lv_dummy    TYPE vbeln.

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
* apa". Halaman memeriksa flag, BUKAN gv_role.

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
* Keputusan 6 Agustus 2026. Harus DICABUT sebelum go-live. Hapus blok
* IF di bawah ini saja. Lihat role-capability-map bagian 8.

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
* Sales boleh MELIHAT request miliknya, tapi hanya Admin yang boleh
* memutuskan. Pemisahan itu ditegakkan di layout dan di
* OnInputProcessing, bukan di sini.

IF gv_as_sales <> 'X' AND gv_as_admin <> 'X'.
  navigation->goto_page( 'main.htm' ).
  RETURN.
ENDIF.

IF gv_request_id IS INITIAL.
  gv_error = 'Request ID tidak diberikan. Buka halaman ini dari daftar Request.'.
  RETURN.
ENDIF.

*&--- 3. Baca header request -------------------------------------------

CLEAR: gv_so_number, gv_req_buyer, gv_buyer_name, gv_req_date,
       gv_req_status, gv_sales_user, gv_req_remarks,
       gt_items, gv_cnt_pending.

CLEAR ls_hdr.
SELECT SINGLE * INTO ls_hdr
  FROM zcp_request
  WHERE request_id = gv_request_id.

IF sy-subrc <> 0.
  CONCATENATE 'Request' gv_request_id 'tidak ditemukan.'
         INTO gv_error SEPARATED BY space.
  RETURN.
ENDIF.

gv_so_number   = ls_hdr-so_number.
gv_req_buyer   = ls_hdr-buyer_id.
gv_req_date    = ls_hdr-request_date.
gv_req_status  = ls_hdr-status.
gv_sales_user  = ls_hdr-sales_user.
gv_req_remarks = ls_hdr-remarks.

* Sales murni hanya boleh melihat request buyer-nya sendiri. Tanpa
* penjagaan ini, menebak nomor request cukup untuk melihat data buyer
* lain -- dan tebakannya mudah karena nomornya berurutan.
IF gv_as_admin <> 'X' AND ls_hdr-buyer_id <> gv_buyer_id.
  navigation->goto_page( 'req_list.htm' ).
  RETURN.
ENDIF.

SELECT SINGLE name1 INTO gv_buyer_name
  FROM kna1
  WHERE kunnr = ls_hdr-buyer_id.

*&--- 4. Baca item beserta penanda kelayakannya ------------------------

SELECT * INTO TABLE lt_itm
  FROM zcp_request_itm
  WHERE request_id = gv_request_id
  ORDER BY so_item.

LOOP AT lt_itm INTO ls_itm.

  CLEAR ls_row.
  ls_row-so_item       = ls_itm-so_item.
  ls_row-matnr         = ls_itm-matnr.
  ls_row-maktx         = ls_itm-maktx.
  ls_row-menge         = ls_itm-menge.
  ls_row-meins         = ls_itm-meins.
  ls_row-status        = ls_itm-status.
  ls_row-reject_reason = ls_itm-reject_reason.
  ls_row-dcp_id        = ls_itm-dcp_id.
  ls_row-color_code    = ls_itm-color_code.
  ls_row-decided_by    = ls_itm-decided_by.

  IF ls_itm-status = 'P'.

    gv_cnt_pending = gv_cnt_pending + 1.

*   Kelayakan diperiksa ulang setiap kali halaman dibuka, bukan
*   mengandalkan pemeriksaan saat request dibuat. Request bisa dibuat
*   pagi dan diproses sore, dan di antaranya material yang sama bisa
*   sudah di-approve lewat request lain.
    CLEAR lv_ccode.
    SELECT SINGLE color_code INTO lv_ccode
      FROM zcp_color_code
      WHERE matnr = ls_itm-matnr.

    IF sy-subrc = 0.
      ls_row-blocked = 'X'.
      CONCATENATE 'Material sudah punya Color Code' lv_ccode
             INTO ls_row-block_reason SEPARATED BY space.
    ELSE.
      CLEAR lv_dummy.
      SELECT SINGLE so_number INTO lv_dummy
        FROM zcp_so_import
        WHERE so_number = ls_hdr-so_number
          AND so_item   = ls_itm-so_item.

      IF sy-subrc = 0.
        ls_row-blocked = 'X'.
        ls_row-block_reason = 'SO dan item ini sudah pernah di-import'.
      ENDIF.
    ENDIF.

  ENDIF.

  APPEND ls_row TO gt_items.

ENDLOOP.
