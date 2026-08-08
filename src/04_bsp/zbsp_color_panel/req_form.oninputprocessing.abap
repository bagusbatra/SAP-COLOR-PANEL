*&---------------------------------------------------------------------*
*& req_form.htm - OnInputProcessing
*&---------------------------------------------------------------------*
*& Dua kejadian:
*&   'lookup'  baca SO dari VBAK/VBAP, tandai kelayakan tiap material
*&   'submit'  buat ZCP_REQUEST + ZCP_REQUEST_ITM
*&
*& Handler ini berjalan LEBIH DULU daripada OnInitialization, jadi
*& gv_as_* belum terisi. Kapabilitas dihitung ulang di sini. Terlihat
*& mubazir, tapi tanpa itu siapa pun yang tahu nama field form bisa
*& mengirim submit langsung dan datanya tersimpan sebelum sempat
*& ditolak OnInitialization.
*&
*& Pembacaan VBAK/VBAP nanti pindah ke ZCL_CP_SO_READER (Task 11 di
*& plan). Untuk sekarang inline, supaya alurnya bisa diuji tanpa
*& menunggu seluruh lapisan class selesai.
*&---------------------------------------------------------------------*

DATA: lv_event    TYPE string,
      lv_raw      TYPE string,
      lv_vbeln    TYPE vbak-vbeln,
      lv_kunnr    TYPE vbak-kunnr,
      lv_vbtyp    TYPE vbak-vbtyp,
      lv_bname    TYPE kna1-name1,
      lv_loevm    TYPE kna1-loevm,
      lv_aufsd    TYPE kna1-aufsd,
      lv_dup      TYPE zcp_de_request_id,
      lv_ts       TYPE timestamp,
      lv_year     TYPE n LENGTH 4,
      lv_nrlevel  TYPE c LENGTH 20,
      lv_seq      TYPE n LENGTH 4,
      lv_reqid    TYPE zcp_de_request_id,
      lv_cnt      TYPE i,
      lv_cnt_txt  TYPE c LENGTH 10.

DATA: lt_agr      TYPE STANDARD TABLE OF agr_name,
      lv_agr      TYPE agr_name,
      lv_has_adm  TYPE c LENGTH 1,
      lv_has_it   TYPE c LENGTH 1,
      lv_has_sls  TYPE c LENGTH 1,
      lv_ok_sales TYPE c LENGTH 1,
      lv_ok_admin TYPE c LENGTH 1,
      ls_cpuser   TYPE zcp_user.

DATA: lt_vbap     TYPE tt_soitem,
      ls_vbap     TYPE ty_soitem,
      lt_matkey   TYPE tt_matkey,
      ls_matkey   TYPE ty_matkey,
      lt_makt     TYPE tt_makt,
      ls_makt     TYPE ty_makt,
      lt_ccode    TYPE tt_ccode,
      ls_ccode    TYPE ty_ccode,
      lt_imported TYPE tt_matkey,
      lv_idx      TYPE sy-tabix.

DATA: ls_hdr      TYPE zcp_request,
      ls_itm      TYPE zcp_request_itm.

CLEAR: gv_error, gv_info.

lv_event = request->get_form_field( 'onInputProcessing' ).

IF lv_event <> 'lookup' AND lv_event <> 'submit'.
  RETURN.
ENDIF.

*&--- Kapabilitas, dihitung ulang di sini ------------------------------

CLEAR: lv_has_adm, lv_has_it, lv_has_sls, lv_ok_sales, lv_ok_admin.

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
    WHEN 'ZCP_SALES'.
      lv_has_sls = 'X'.
  ENDCASE.
ENDLOOP.

IF lv_has_sls = 'X'.
  lv_ok_sales = 'X'.
ENDIF.
IF lv_has_adm = 'X'.
  lv_ok_admin = 'X'.
ENDIF.

* SEMENTARA: IT memegang akses penuh. Lihat role-capability-map bagian 8.
IF lv_has_it = 'X'.
  lv_ok_sales = 'X'.
  lv_ok_admin = 'X'.
ENDIF.

IF lv_ok_sales <> 'X' AND lv_ok_admin <> 'X'.
  gv_error = 'Anda tidak berhak membuat request'.
  RETURN.
ENDIF.

*&--- Normalkan nomor SO -----------------------------------------------
* User mengetik 12345, VBAK menyimpan 0000012345. Tanpa konversi ini,
* pencarian selalu gagal dan pesannya berbunyi "SO tidak ditemukan"
* padahal SO-nya ada.

lv_raw = request->get_form_field( 'so_number' ).
CONDENSE lv_raw NO-GAPS.

IF lv_raw IS INITIAL.
  gv_error = 'Nomor SO wajib diisi'.
  CLEAR: gv_found, gt_items, gv_cnt_ok.
  RETURN.
ENDIF.

CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
  EXPORTING
    input  = lv_raw
  IMPORTING
    output = lv_vbeln.

gv_so_number = lv_vbeln.
gv_remarks   = request->get_form_field( 'remarks' ).

*&--- Baca header SO ----------------------------------------------------

CLEAR: gv_found, gv_so_kunnr, gv_so_name, gt_items, gv_cnt_ok.

SELECT SINGLE kunnr vbtyp INTO (lv_kunnr, lv_vbtyp)
  FROM vbak
  WHERE vbeln = lv_vbeln.

IF sy-subrc <> 0.
  CONCATENATE 'SO' lv_vbeln 'tidak ditemukan di VBAK.'
         INTO gv_error SEPARATED BY space.
  RETURN.
ENDIF.

* vbtyp 'C' = sales order. Nomor delivery atau invoice juga ada di
* VBAK/VBAK-sejenis, dan membacanya akan menghasilkan daftar material
* yang terlihat masuk akal tapi salah konteks.
IF lv_vbtyp <> 'C'.
  CONCATENATE 'Dokumen' lv_vbeln 'bukan Sales Order (VBTYP ='
              lv_vbtyp 'ke). Masukkan nomor SO.'
         INTO gv_error SEPARATED BY space.
  RETURN.
ENDIF.

gv_so_kunnr = lv_kunnr.

*&--- Buyer dibaca langsung dari KNA1 ----------------------------------
* Keputusan 8 Agustus 2026: ZCP_BUYER dipensiunkan. Tidak ada lagi
* daftar buyer yang harus dirawat terpisah -- nama diambil dari master
* pelanggan SAP setiap kali dibutuhkan, jadi selalu terkini.
*
* Penyaringan pelanggan bermasalah memakai penanda SAP sendiri:
*   LOEVM  ditandai untuk dihapus
*   AUFSD  diblokir untuk order (blok pusat, bukan per area penjualan)
* Keduanya ada di KNA1, jadi tidak perlu membaca KNVV dan tidak perlu
* tahu sales area. Memakai penanda SAP berarti sekali diblokir di
* master pelanggan, seluruh sistem ikut menolak -- tidak ada daftar
* tandingan yang bisa ketinggalan.

CLEAR: lv_bname, lv_loevm, lv_aufsd.
SELECT SINGLE name1 loevm aufsd INTO (lv_bname, lv_loevm, lv_aufsd)
  FROM kna1
  WHERE kunnr = lv_kunnr.

IF sy-subrc <> 0.
  CONCATENATE 'Pelanggan' lv_kunnr 'pada SO ini tidak ada di master'
              'pelanggan KNA1. Periksa datanya lewat XD03.'
         INTO gv_error SEPARATED BY space.
  RETURN.
ENDIF.

IF lv_loevm = 'X'.
  CONCATENATE 'Pelanggan' lv_kunnr lv_bname 'ditandai untuk dihapus'
              'di master pelanggan.'
         INTO gv_error SEPARATED BY space.
  RETURN.
ENDIF.

IF lv_aufsd <> space.
  CONCATENATE 'Pelanggan' lv_kunnr lv_bname 'sedang diblokir untuk'
              'order di master pelanggan (KNA1-AUFSD).'
         INTO gv_error SEPARATED BY space.
  RETURN.
ENDIF.

gv_so_name = lv_bname.

*&--- Sales murni hanya boleh SO milik buyer-nya ------------------------
* Pemegang kapabilitas Admin dilewatkan: dia memang boleh lintas buyer.

IF lv_ok_admin <> 'X'.
  CLEAR ls_cpuser.
  SELECT SINGLE * INTO ls_cpuser
    FROM zcp_user
    WHERE user_id = sy-uname.

  IF ls_cpuser-buyer_id <> lv_kunnr.
    CONCATENATE 'SO ini milik buyer' lv_kunnr
                'sedangkan Anda dipetakan ke buyer' ls_cpuser-buyer_id
           INTO gv_error SEPARATED BY space.
    RETURN.
  ENDIF.
ENDIF.

*&--- Baca item SO ------------------------------------------------------
* ABGRU terisi berarti item ditolak di SD. Item seperti itu tidak akan
* dikirim, jadi tidak ada gunanya dibuatkan panel.

SELECT posnr matnr kwmeng vrkme INTO CORRESPONDING FIELDS OF TABLE lt_vbap
  FROM vbap
  WHERE vbeln =  lv_vbeln
    AND abgru =  space
    AND matnr <> space.

IF lt_vbap IS INITIAL.
  CONCATENATE 'SO' lv_vbeln 'tidak punya item yang aktif.'
         INTO gv_error SEPARATED BY space.
  RETURN.
ENDIF.

SORT lt_vbap BY posnr.

*&--- Kumpulkan material untuk pembacaan massal -------------------------

CLEAR lt_matkey.
LOOP AT lt_vbap INTO ls_vbap.
  CLEAR ls_matkey.
  ls_matkey-matnr = ls_vbap-matnr.
  APPEND ls_matkey TO lt_matkey.
ENDLOOP.
SORT lt_matkey BY matnr.
DELETE ADJACENT DUPLICATES FROM lt_matkey COMPARING matnr.

SELECT matnr maktx INTO TABLE lt_makt
  FROM makt
  FOR ALL ENTRIES IN lt_matkey
  WHERE matnr = lt_matkey-matnr
    AND spras = sy-langu.
SORT lt_makt BY matnr.

SELECT matnr color_code INTO TABLE lt_ccode
  FROM zcp_color_code
  FOR ALL ENTRIES IN lt_matkey
  WHERE matnr = lt_matkey-matnr.
SORT lt_ccode BY matnr.

SELECT matnr INTO TABLE lt_imported
  FROM zcp_so_import
  FOR ALL ENTRIES IN lt_matkey
  WHERE so_number = lv_vbeln
    AND matnr     = lt_matkey-matnr.
SORT lt_imported BY matnr.

*&--- Tentukan kelayakan tiap item --------------------------------------

CLEAR gv_cnt_ok.

LOOP AT lt_vbap INTO ls_vbap.
  lv_idx = sy-tabix.

  CLEAR ls_makt.
  READ TABLE lt_makt INTO ls_makt
       WITH KEY matnr = ls_vbap-matnr BINARY SEARCH.
  IF sy-subrc = 0.
    ls_vbap-maktx = ls_makt-maktx.
  ENDIF.

  CLEAR: ls_vbap-eligible, ls_vbap-reason.

  CLEAR ls_ccode.
  READ TABLE lt_ccode INTO ls_ccode
       WITH KEY matnr = ls_vbap-matnr BINARY SEARCH.

  IF sy-subrc = 0.
    CONCATENATE 'Sudah punya Color Code' ls_ccode-color_code
           INTO ls_vbap-reason SEPARATED BY space.
  ELSE.
    CLEAR ls_matkey.
    READ TABLE lt_imported INTO ls_matkey
         WITH KEY matnr = ls_vbap-matnr BINARY SEARCH.
    IF sy-subrc = 0.
      ls_vbap-reason = 'Sudah pernah di-import dari SO ini'.
    ELSE.
      ls_vbap-eligible = 'X'.
      gv_cnt_ok = gv_cnt_ok + 1.
    ENDIF.
  ENDIF.

  MODIFY lt_vbap FROM ls_vbap INDEX lv_idx.
ENDLOOP.

gt_items = lt_vbap.
gv_found = 'X'.

IF lv_event = 'lookup'.
  IF gv_cnt_ok = 0.
    gv_error = 'Tidak ada material yang layak di SO ini. Yang sudah punya Color Code ditangani lewat halaman Renewal.'.
  ENDIF.
  RETURN.
ENDIF.

*&======================================================================
*& Mulai dari sini: lv_event = 'submit'
*&======================================================================

IF gv_cnt_ok = 0.
  gv_error = 'Tidak ada material yang layak untuk di-request'.
  RETURN.
ENDIF.

*&--- Jangan buat request kedua untuk SO yang masih pending -------------

CLEAR lv_dup.
SELECT SINGLE request_id INTO lv_dup
  FROM zcp_request
  WHERE so_number = lv_vbeln
    AND status    = 'P'.

IF sy-subrc = 0.
  CONCATENATE 'SO ini sudah punya request' lv_dup
              'yang masih Pending. Selesaikan dulu request tersebut.'
         INTO gv_error SEPARATED BY space.
  RETURN.
ENDIF.

*&--- Ambil nomor request dari SNRO -------------------------------------
* lv_year dan lv_nrlevel sengaja TIDAK diikat ke komponen struktur INRI.
* Nama komponen di struktur bawaan SAP berbeda antar rilis, dan kalau
* meleset aktivasinya gagal dengan pesan "No component exists with the
* name ..." yang tidak menunjuk ke mana-mana. Tipe dasar dengan panjang
* yang cukup diterima NUMBER_GET_NEXT lewat konversi parameter.

lv_year = sy-datum(4).

CALL FUNCTION 'NUMBER_GET_NEXT'
  EXPORTING
    nr_range_nr             = '01'
    object                  = 'ZCP_REQ'
    toyear                  = lv_year
  IMPORTING
    number                  = lv_nrlevel
  EXCEPTIONS
    interval_not_found      = 1
    number_range_not_intern = 2
    object_not_found        = 3
    quantity_is_0           = 4
    quantity_is_not_1       = 5
    interval_overflow       = 6
    buffer_overflow         = 7
    OTHERS                  = 8.

IF sy-subrc <> 0.
  CONCATENATE 'Gagal mengambil nomor request dari SNRO (sy-subrc ='
              'lihat SNRO objek ZCP_REQ). Interval 01 untuk tahun'
              lv_year 'kemungkinan belum dibuat.'
         INTO gv_error SEPARATED BY space.
  RETURN.
ENDIF.

lv_seq = lv_nrlevel.
CONCATENATE 'REQ-' lv_year '-' lv_seq INTO lv_reqid.

*&--- Simpan header ------------------------------------------------------

GET TIME STAMP FIELD lv_ts.

CLEAR ls_hdr.
ls_hdr-request_id   = lv_reqid.
ls_hdr-so_number    = lv_vbeln.
ls_hdr-sales_user   = sy-uname.
ls_hdr-buyer_id     = lv_kunnr.
ls_hdr-request_date = sy-datum.
ls_hdr-status       = 'P'.
ls_hdr-remarks      = gv_remarks.
ls_hdr-created_by   = sy-uname.
ls_hdr-created_at   = lv_ts.
ls_hdr-changed_by   = sy-uname.
ls_hdr-changed_at   = lv_ts.

INSERT zcp_request FROM ls_hdr.

IF sy-subrc <> 0.
  ROLLBACK WORK.
  CONCATENATE 'Gagal menyimpan header request' lv_reqid
         INTO gv_error SEPARATED BY space.
  RETURN.
ENDIF.

*&--- Simpan item yang layak saja ----------------------------------------
* Material yang tidak layak sengaja TIDAK disimpan sebagai item ber-status
* R. Item berstatus R lahir dari keputusan Admin, bukan dari penyaringan
* mesin. Mencampurnya membuat laporan "berapa yang ditolak Admin" jadi
* berbohong.

CLEAR lv_cnt.

LOOP AT gt_items INTO ls_vbap WHERE eligible = 'X'.

  CLEAR ls_itm.
  ls_itm-request_id = lv_reqid.
  ls_itm-so_item    = ls_vbap-posnr.
  ls_itm-matnr      = ls_vbap-matnr.
  ls_itm-maktx      = ls_vbap-maktx.
  ls_itm-menge      = ls_vbap-kwmeng.
  ls_itm-meins      = ls_vbap-vrkme.
  ls_itm-status     = 'P'.
  ls_itm-created_at = lv_ts.

  INSERT zcp_request_itm FROM ls_itm.

  IF sy-subrc <> 0.
    ROLLBACK WORK.
    CONCATENATE 'Gagal menyimpan item' ls_vbap-posnr 'request dibatalkan.'
           INTO gv_error SEPARATED BY space.
    RETURN.
  ENDIF.

  lv_cnt = lv_cnt + 1.

ENDLOOP.

COMMIT WORK.

CLEAR: gv_found, gt_items, gv_cnt_ok, gv_so_number, gv_remarks,
       gv_so_kunnr, gv_so_name.

* CONCATENATE hanya menerima operand bertipe karakter (C, N, D, T,
* STRING). lv_cnt bertipe I, jadi harus disalin dulu ke field karakter
* -- kalau langsung dipakai, aktivasi gagal dengan pesan "must be a
* character-like data object".
lv_cnt_txt = lv_cnt.
CONDENSE lv_cnt_txt.

CONCATENATE 'Request' lv_reqid 'dibuat dengan' lv_cnt_txt
            'material. Menunggu keputusan Admin.'
       INTO gv_info SEPARATED BY space.
