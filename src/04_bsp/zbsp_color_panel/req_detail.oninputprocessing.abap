*&---------------------------------------------------------------------*
*& req_detail.htm - OnInputProcessing
*&---------------------------------------------------------------------*
*& Approve atau reject material yang dicentang, SATU PER SATU.
*&
*& Inilah yang membedakan sistem ini dari prototype. Prototype
*& membatalkan seluruh approve begitu satu material bentrok; di sini
*& tiap material adalah satuan kerja tersendiri dengan COMMIT-nya
*& masing-masing. Material yang gagal tidak menjatuhkan yang sah.
*&
*& Konsekuensi teknisnya: COMMIT WORK dipanggil di dalam loop. Itu
*& biasanya pertanda buruk, tapi di sini justru syaratnya -- tanpa
*& commit per item, kegagalan pada item terakhir akan menghapus
*& keberhasilan item-item sebelumnya.
*&
*& Yang dibuat saat satu material di-approve:
*&   1. Color Code  KW#####            ZCP_COLOR_CODE
*&   2. DCP header  DCP-YYYY-NNNN      ZCP_DCP_HDR
*&   3. Panel       sebanyak qty, NA   ZCP_DCP_ITEM
*&   4. Penjaga anti-duplikat          ZCP_SO_IMPORT
*&   5. Item request jadi status A     ZCP_REQUEST_ITM
*&
*& Nanti pindah ke ZCL_CP_REQUEST (Task 11 di plan 28 Juli). Untuk
*& sekarang inline supaya alurnya bisa diuji tanpa menunggu class.
*&---------------------------------------------------------------------*

DATA: lv_event    TYPE string,
      lv_field    TYPE string,
      lv_sel      TYPE string,
      lv_reason   TYPE string,
      lv_ts       TYPE timestamp,
      lv_year     TYPE n LENGTH 4,
      lv_nrlevel  TYPE c LENGTH 20,
      lv_seq5     TYPE n LENGTH 5,
      lv_seq4     TYPE n LENGTH 4,
      lv_ccode    TYPE zcp_de_color_code,
      lv_dcpid    TYPE zcp_de_dcp_id,
      lv_panelid  TYPE zcp_de_panel_id,
      lv_pnum     TYPE n LENGTH 3,
      lv_qty      TYPE i,
      lv_n        TYPE i,
      lv_guid     TYPE c LENGTH 32,
      lv_chk      TYPE zcp_de_color_code,
      lv_chkso    TYPE vbeln,
      lv_remain   TYPE i,
      lv_ok       TYPE i,
      lv_fail     TYPE i,
      lv_ok_txt   TYPE c LENGTH 10,
      lv_fail_txt TYPE c LENGTH 10,
      lv_qty_txt  TYPE c LENGTH 10,
      lv_nsel     TYPE i,
      lv_panelerr TYPE c LENGTH 1.

DATA: lt_agr      TYPE STANDARD TABLE OF agr_name,
      lv_agr      TYPE agr_name,
      lv_has_adm  TYPE c LENGTH 1,
      lv_has_it   TYPE c LENGTH 1,
      lv_ok_admin TYPE c LENGTH 1.

DATA: ls_hdr      TYPE zcp_request,
      lt_itm      TYPE STANDARD TABLE OF zcp_request_itm,
      ls_itm      TYPE zcp_request_itm,
      ls_cc       TYPE zcp_color_code,
      ls_dh       TYPE zcp_dcp_hdr,
      ls_di       TYPE zcp_dcp_item,
      ls_si       TYPE zcp_so_import,
      ls_res      TYPE ty_result.

CLEAR: gv_error, gv_info, gt_result.

lv_event = request->get_form_field( 'onInputProcessing' ).

IF lv_event <> 'approve' AND lv_event <> 'reject'.
  RETURN.
ENDIF.

*&--- Kapabilitas, dihitung ulang di sini -------------------------------
* Handler ini berjalan LEBIH DULU daripada OnInitialization, jadi
* gv_as_* belum terisi. Tanpa pemeriksaan di sini, siapa pun yang tahu
* nama field form bisa mengirim approve langsung dan DCP terbentuk
* sebelum pelakunya sempat ditolak.

CLEAR: lv_has_adm, lv_has_it, lv_ok_admin.

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
  ENDCASE.
ENDLOOP.

IF lv_has_adm = 'X'.
  lv_ok_admin = 'X'.
ENDIF.

* SEMENTARA: IT memegang akses penuh. Lihat role-capability-map bagian 8.
IF lv_has_it = 'X'.
  lv_ok_admin = 'X'.
ENDIF.

IF lv_ok_admin <> 'X'.
  gv_error = 'Hanya Admin yang boleh memutuskan request'.
  RETURN.
ENDIF.

*&--- Request ID -------------------------------------------------------
* Diambil dari hidden field, bukan mengandalkan atribut stateful.
* Kalau sesinya kedaluwarsa dan halaman dimuat ulang, atribut bisa
* kosong sementara form-nya tetap terkirim lengkap.

lv_field = request->get_form_field( 'request_id' ).
IF lv_field IS NOT INITIAL.
  gv_request_id = lv_field.
ENDIF.

IF gv_request_id IS INITIAL.
  gv_error = 'Request ID tidak diketahui'.
  RETURN.
ENDIF.

CLEAR ls_hdr.
SELECT SINGLE * INTO ls_hdr
  FROM zcp_request
  WHERE request_id = gv_request_id.

IF sy-subrc <> 0.
  CONCATENATE 'Request' gv_request_id 'tidak ditemukan.'
         INTO gv_error SEPARATED BY space.
  RETURN.
ENDIF.

IF ls_hdr-status <> 'P'.
  gv_error = 'Request ini sudah ditutup, tidak ada lagi yang bisa diputuskan.'.
  RETURN.
ENDIF.

*&--- Item yang masih menunggu keputusan --------------------------------

SELECT * INTO TABLE lt_itm
  FROM zcp_request_itm
  WHERE request_id = gv_request_id
    AND status     = 'P'
  ORDER BY so_item.

IF lt_itm IS INITIAL.
  gv_error = 'Tidak ada item yang masih menunggu keputusan.'.
  RETURN.
ENDIF.

* Hitung dulu berapa yang dicentang, supaya bisa menolak lebih awal
CLEAR lv_nsel.
LOOP AT lt_itm INTO ls_itm.
  CONCATENATE 'sel_' ls_itm-so_item INTO lv_field.
  lv_sel = request->get_form_field( lv_field ).
  IF lv_sel = 'X'.
    lv_nsel = lv_nsel + 1.
  ENDIF.
ENDLOOP.

IF lv_nsel = 0.
  gv_error = 'Centang dulu material yang hendak diputuskan.'.
  RETURN.
ENDIF.

lv_year = sy-datum(4).
CLEAR: lv_ok, lv_fail.

*&======================================================================
*& Loop utama: satu material, satu satuan kerja
*&======================================================================

LOOP AT lt_itm INTO ls_itm.

  CONCATENATE 'sel_' ls_itm-so_item INTO lv_field.
  lv_sel = request->get_form_field( lv_field ).

  IF lv_sel <> 'X'.
    CONTINUE.
  ENDIF.

  CLEAR ls_res.
  ls_res-so_item = ls_itm-so_item.
  ls_res-matnr   = ls_itm-matnr.

  GET TIME STAMP FIELD lv_ts.

*&--------------------------------------------------------------------
*& REJECT
*&--------------------------------------------------------------------
  IF lv_event = 'reject'.

    CONCATENATE 'reason_' ls_itm-so_item INTO lv_field.
    lv_reason = request->get_form_field( lv_field ).
    CONDENSE lv_reason.

    IF lv_reason IS INITIAL.
      ls_res-success = ' '.
      ls_res-message = 'Alasan penolakan wajib diisi'.
      APPEND ls_res TO gt_result.
      lv_fail = lv_fail + 1.
      CONTINUE.
    ENDIF.

    UPDATE zcp_request_itm
       SET status        = 'R'
           reject_reason = lv_reason
           decided_by    = sy-uname
           decided_at    = lv_ts
     WHERE request_id = gv_request_id
       AND so_item    = ls_itm-so_item.

    IF sy-subrc = 0.
      COMMIT WORK.
      ls_res-success = 'X'.
      ls_res-message = 'Ditolak'.
      lv_ok = lv_ok + 1.
    ELSE.
      ROLLBACK WORK.
      ls_res-success = ' '.
      ls_res-message = 'Gagal menyimpan penolakan'.
      lv_fail = lv_fail + 1.
    ENDIF.

    APPEND ls_res TO gt_result.
    CONTINUE.

  ENDIF.

*&--------------------------------------------------------------------
*& APPROVE
*&--------------------------------------------------------------------

* Kelayakan diperiksa ulang di sini, bukan mengandalkan penandaan di
* layar. Antara halaman dimuat dan tombol ditekan bisa berlalu berjam-
* jam, dan dalam jeda itu Admin lain bisa sudah meng-approve material
* yang sama lewat request berbeda.

  CLEAR lv_chk.
  SELECT SINGLE color_code INTO lv_chk
    FROM zcp_color_code
    WHERE matnr = ls_itm-matnr.

  IF sy-subrc = 0.
    ls_res-success = ' '.
    CONCATENATE 'Material sudah punya Color Code' lv_chk
           INTO ls_res-message SEPARATED BY space.
    APPEND ls_res TO gt_result.
    lv_fail = lv_fail + 1.
    CONTINUE.
  ENDIF.

  CLEAR lv_chkso.
  SELECT SINGLE so_number INTO lv_chkso
    FROM zcp_so_import
    WHERE so_number = ls_hdr-so_number
      AND so_item   = ls_itm-so_item.

  IF sy-subrc = 0.
    ls_res-success = ' '.
    ls_res-message = 'SO dan item ini sudah pernah di-import'.
    APPEND ls_res TO gt_result.
    lv_fail = lv_fail + 1.
    CONTINUE.
  ENDIF.

* Jumlah panel mengikuti qty item SO. PANEL_NUMBER bertipe NUMC3,
* jadi lebih dari 999 panel tidak bisa dinomori.
  lv_qty = ls_itm-menge.

  IF lv_qty < 1.
    ls_res-success = ' '.
    ls_res-message = 'Qty item SO nol, tidak ada panel yang bisa dibuat'.
    APPEND ls_res TO gt_result.
    lv_fail = lv_fail + 1.
    CONTINUE.
  ENDIF.

  IF lv_qty > 999.
    lv_qty_txt = lv_qty.
    CONDENSE lv_qty_txt.
    ls_res-success = ' '.
    CONCATENATE 'Qty' lv_qty_txt 'melebihi batas 999 panel per DCP'
           INTO ls_res-message SEPARATED BY space.
    APPEND ls_res TO gt_result.
    lv_fail = lv_fail + 1.
    CONTINUE.
  ENDIF.

*&--- 1. Color Code ----------------------------------------------------

  CLEAR lv_nrlevel.
  CALL FUNCTION 'NUMBER_GET_NEXT'
    EXPORTING
      nr_range_nr             = '01'
      object                  = 'ZCP_COLOR'
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
    ls_res-success = ' '.
    ls_res-message = 'Gagal mengambil nomor Color Code. Periksa interval 01 objek ZCP_COLOR di SNRO.'.
    APPEND ls_res TO gt_result.
    lv_fail = lv_fail + 1.
    CONTINUE.
  ENDIF.

  lv_seq5 = lv_nrlevel.
  CONCATENATE 'KW' lv_seq5 INTO lv_ccode.

  CLEAR ls_cc.
  ls_cc-color_code = lv_ccode.
  ls_cc-matnr      = ls_itm-matnr.
  ls_cc-maktx      = ls_itm-maktx.
  ls_cc-buyer_id   = ls_hdr-buyer_id.
  ls_cc-color_name = ls_itm-maktx.
  ls_cc-status     = 'A'.
  ls_cc-created_by = sy-uname.
  ls_cc-created_at = lv_ts.
  ls_cc-changed_by = sy-uname.
  ls_cc-changed_at = lv_ts.

  INSERT zcp_color_code FROM ls_cc.

  IF sy-subrc <> 0.
    ROLLBACK WORK.
    ls_res-success = ' '.
    CONCATENATE 'Gagal menyimpan Color Code' lv_ccode
           INTO ls_res-message SEPARATED BY space.
    APPEND ls_res TO gt_result.
    lv_fail = lv_fail + 1.
    CONTINUE.
  ENDIF.

*&--- 2. DCP header ----------------------------------------------------

  CLEAR lv_nrlevel.
  CALL FUNCTION 'NUMBER_GET_NEXT'
    EXPORTING
      nr_range_nr             = '01'
      object                  = 'ZCP_DCP'
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
    ROLLBACK WORK.
    ls_res-success = ' '.
    ls_res-message = 'Gagal mengambil nomor DCP. Periksa interval 01 objek ZCP_DCP di SNRO.'.
    APPEND ls_res TO gt_result.
    lv_fail = lv_fail + 1.
    CONTINUE.
  ENDIF.

  lv_seq4 = lv_nrlevel.
  CONCATENATE 'DCP-' lv_year '-' lv_seq4 INTO lv_dcpid.

  CLEAR ls_dh.
  ls_dh-dcp_id     = lv_dcpid.
  ls_dh-request_id = gv_request_id.
  ls_dh-so_number  = ls_hdr-so_number.
  ls_dh-so_item    = ls_itm-so_item.
  ls_dh-matnr      = ls_itm-matnr.
  ls_dh-maktx      = ls_itm-maktx.
  ls_dh-color_code = lv_ccode.
  ls_dh-buyer_id   = ls_hdr-buyer_id.
  ls_dh-sales_user = ls_hdr-sales_user.
  ls_dh-qty_total  = lv_qty.
  ls_dh-status     = 'O'.
* MFG_DATE dan EXPIRE_DATE sengaja dibiarkan kosong. Keduanya baru
* terisi saat panel PERTAMA diaktivasi -- masa berlaku DCP dihitung
* dari tanggal panel dibuat, bukan tanggal request disetujui.
  ls_dh-reminder_date = sy-datum + 60.
  ls_dh-created_by    = sy-uname.
  ls_dh-created_at    = lv_ts.
  ls_dh-changed_by    = sy-uname.
  ls_dh-changed_at    = lv_ts.

  INSERT zcp_dcp_hdr FROM ls_dh.

  IF sy-subrc <> 0.
    ROLLBACK WORK.
    ls_res-success = ' '.
    CONCATENATE 'Gagal menyimpan DCP header' lv_dcpid
           INTO ls_res-message SEPARATED BY space.
    APPEND ls_res TO gt_result.
    lv_fail = lv_fail + 1.
    CONTINUE.
  ENDIF.

*&--- 3. Panel sebanyak qty, semuanya NA -------------------------------

  CLEAR: lv_n, lv_panelerr.
  DO lv_qty TIMES.

    lv_n    = sy-index.
    lv_pnum = lv_n.
    CONCATENATE lv_dcpid '-' lv_pnum INTO lv_panelid.

    CLEAR lv_guid.
    CALL FUNCTION 'GUID_CREATE'
      IMPORTING
        ev_guid_32 = lv_guid.

    CLEAR ls_di.
    ls_di-dcp_id       = lv_dcpid.
    ls_di-panel_number = lv_pnum.
    ls_di-panel_id     = lv_panelid.
    ls_di-qr_token     = lv_guid.
    ls_di-status       = 'NA'.
    ls_di-undo_count   = 0.
    ls_di-created_at   = lv_ts.
    ls_di-changed_by   = sy-uname.
    ls_di-changed_at   = lv_ts.

    INSERT zcp_dcp_item FROM ls_di.

    IF sy-subrc <> 0.
      ROLLBACK WORK.
      ls_res-success = ' '.
      CONCATENATE 'Gagal menyimpan panel' lv_pnum 'pada' lv_dcpid
             INTO ls_res-message SEPARATED BY space.
      APPEND ls_res TO gt_result.
      lv_fail = lv_fail + 1.
      lv_panelerr = 'X'.
      EXIT.
    ENDIF.

  ENDDO.

* Dipakai flag, bukan sy-subrc. Antara INSERT yang gagal dan pemeriksaan
* ini ada ROLLBACK, CONCATENATE, dan APPEND -- ketiganya bisa menimpa
* sy-subrc, sehingga kegagalan panel bisa lolos tanpa jejak.
  IF lv_panelerr = 'X'.
    CONTINUE.
  ENDIF.

*&--- 4. Penjaga anti-duplikat ------------------------------------------

  CLEAR ls_si.
  ls_si-so_number   = ls_hdr-so_number.
  ls_si-so_item     = ls_itm-so_item.
  ls_si-matnr       = ls_itm-matnr.
  ls_si-menge       = ls_itm-menge.
  ls_si-meins       = ls_itm-meins.
  ls_si-request_id  = gv_request_id.
  ls_si-dcp_id      = lv_dcpid.
  ls_si-color_code  = lv_ccode.
  ls_si-imported_by = sy-uname.
  ls_si-imported_at = lv_ts.

  INSERT zcp_so_import FROM ls_si.

  IF sy-subrc <> 0.
    ROLLBACK WORK.
    ls_res-success = ' '.
    ls_res-message = 'Gagal menyimpan penjaga anti-duplikat ZCP_SO_IMPORT'.
    APPEND ls_res TO gt_result.
    lv_fail = lv_fail + 1.
    CONTINUE.
  ENDIF.

*&--- 5. Item request jadi Approved -------------------------------------

  UPDATE zcp_request_itm
     SET status     = 'A'
         dcp_id     = lv_dcpid
         color_code = lv_ccode
         decided_by = sy-uname
         decided_at = lv_ts
   WHERE request_id = gv_request_id
     AND so_item    = ls_itm-so_item.

  IF sy-subrc <> 0.
    ROLLBACK WORK.
    ls_res-success = ' '.
    ls_res-message = 'Gagal memperbarui status item request'.
    APPEND ls_res TO gt_result.
    lv_fail = lv_fail + 1.
    CONTINUE.
  ENDIF.

  COMMIT WORK.

  lv_qty_txt = lv_qty.
  CONDENSE lv_qty_txt.

  ls_res-success = 'X'.
* Pesan sengaja polos tanpa entity HTML: isinya juga dipakai di luar
* layout kelak (audit log, pesan SE91), dan di sana &middot; hanya
* akan tampil sebagai teks mentah.
  CONCATENATE lv_ccode '-' lv_dcpid 'dengan' lv_qty_txt 'panel'
         INTO ls_res-message SEPARATED BY space.
  APPEND ls_res TO gt_result.
  lv_ok = lv_ok + 1.

ENDLOOP.

*&======================================================================
*& Tutup header bila tidak ada lagi item yang menunggu
*&======================================================================

CLEAR lv_remain.
SELECT COUNT(*) INTO lv_remain
  FROM zcp_request_itm
  WHERE request_id = gv_request_id
    AND status     = 'P'.

IF lv_remain = 0.
  GET TIME STAMP FIELD lv_ts.
  UPDATE zcp_request
     SET status     = 'C'
         changed_by = sy-uname
         changed_at = lv_ts
   WHERE request_id = gv_request_id.
  COMMIT WORK.
ENDIF.

*&--- Ringkasan --------------------------------------------------------

lv_ok_txt   = lv_ok.
lv_fail_txt = lv_fail.
CONDENSE lv_ok_txt.
CONDENSE lv_fail_txt.

IF lv_fail = 0.
  CONCATENATE lv_ok_txt 'material berhasil diproses.'
         INTO gv_info SEPARATED BY space.
ELSEIF lv_ok = 0.
  CONCATENATE lv_fail_txt 'material gagal diproses. Rincian di bawah.'
         INTO gv_error SEPARATED BY space.
ELSE.
* Kasus inilah alasan hasil ditampilkan per item. Pesan tunggal
* "berhasil" atau "gagal" akan berbohong di sini.
  CONCATENATE lv_ok_txt 'material berhasil,' lv_fail_txt
              'gagal. Rincian di bawah.'
         INTO gv_info SEPARATED BY space.
ENDIF.
