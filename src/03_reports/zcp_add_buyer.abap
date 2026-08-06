*&---------------------------------------------------------------------*
*& Report ZCP_ADD_BUYER
*&---------------------------------------------------------------------*
*& Mendaftarkan satu pelanggan SAP sebagai buyer Color Panel.
*&
*& Dibuat karena Table Maintenance Generator untuk ZCP_BUYER belum ada,
*& sehingga SM30 belum bisa dipakai. Setelah TMG dibuat, report ini
*& boleh dihapus -- SM30 lebih nyaman untuk pemakaian sehari-hari.
*&
*& Nama buyer diambil otomatis dari KNA1, jadi tidak ada yang perlu
*& diketik ulang dan tidak ada salah ketik.
*&
*& Cara pakai: SE38 -> ZCP_ADD_BUYER -> Execute.
*&---------------------------------------------------------------------*
REPORT zcp_add_buyer.

TABLES zcp_buyer.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-t01.
PARAMETERS: p_kunnr TYPE kna1-kunnr.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE text-t02.
PARAMETERS: p_add RADIOBUTTON GROUP g1 DEFAULT 'X',
            p_off RADIOBUTTON GROUP g1,
            p_lst RADIOBUTTON GROUP g1.
SELECTION-SCREEN END OF BLOCK b2.

DATA: gs_kna1  TYPE kna1,
      gs_buyer TYPE zcp_buyer,
      gt_buyer TYPE STANDARD TABLE OF zcp_buyer,
      gv_ts    TYPE timestamp,
      gv_kunnr TYPE kna1-kunnr.

START-OF-SELECTION.

*&--- Pilihan 3: tampilkan isi ZCP_BUYER, tidak mengubah apa pun -------
  IF p_lst = 'X'.
    SELECT * INTO TABLE gt_buyer FROM zcp_buyer ORDER BY buyer_id.
    IF gt_buyer IS INITIAL.
      WRITE: / 'ZCP_BUYER masih kosong.'.
      WRITE: / 'Selama kosong, tidak ada SO yang bisa di-request.'.
      RETURN.
    ENDIF.
    WRITE: / 'BUYER_ID', 15 'AKTIF', 23 'NAMA'.
    ULINE.
    LOOP AT gt_buyer INTO gs_buyer.
      WRITE: / gs_buyer-buyer_id, 15 gs_buyer-is_active,
               23 gs_buyer-buyer_name.
    ENDLOOP.
    RETURN.
  ENDIF.

*&--- Dua pilihan lain butuh nomor pelanggan ---------------------------
  IF p_kunnr IS INITIAL.
    WRITE: / 'Isi dulu Nomor Pelanggan (KUNNR).'.
    RETURN.
  ENDIF.

* Ubah 12345 menjadi 0000012345 supaya cocok dengan isi KNA1
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = p_kunnr
    IMPORTING
      output = gv_kunnr.

  GET TIME STAMP FIELD gv_ts.

*&--- Pilihan 2: nonaktifkan buyer -------------------------------------
  IF p_off = 'X'.
    CLEAR gs_buyer.
    SELECT SINGLE * INTO gs_buyer FROM zcp_buyer
      WHERE buyer_id = gv_kunnr.
    IF sy-subrc <> 0.
      WRITE: / 'Buyer', gv_kunnr, 'tidak ada di ZCP_BUYER.'.
      RETURN.
    ENDIF.
    CLEAR gs_buyer-is_active.
    gs_buyer-changed_by = sy-uname.
    gs_buyer-changed_at = gv_ts.
    UPDATE zcp_buyer FROM gs_buyer.
    IF sy-subrc = 0.
      COMMIT WORK.
      WRITE: / 'Buyer', gv_kunnr, 'dinonaktifkan.'.
    ELSE.
      ROLLBACK WORK.
      WRITE: / 'Gagal memperbarui. Periksa lock di SM12.'.
    ENDIF.
    RETURN.
  ENDIF.

*&--- Pilihan 1: daftarkan atau aktifkan kembali -----------------------

* Pelanggan harus benar-benar ada di master pelanggan SAP
  CLEAR gs_kna1.
  SELECT SINGLE * INTO gs_kna1 FROM kna1 WHERE kunnr = gv_kunnr.

  IF sy-subrc <> 0.
    WRITE: / 'Pelanggan', gv_kunnr, 'tidak ada di KNA1.'.
    WRITE: / 'Periksa nomornya lewat XD03 atau SE16N tabel KNA1.'.
    RETURN.
  ENDIF.

  CLEAR gs_buyer.
  SELECT SINGLE * INTO gs_buyer FROM zcp_buyer
    WHERE buyer_id = gv_kunnr.

  IF sy-subrc = 0.
*   Sudah ada barisnya: cukup hidupkan dan segarkan namanya
    gs_buyer-buyer_name = gs_kna1-name1.
    gs_buyer-country    = gs_kna1-land1.
    gs_buyer-is_active  = 'X'.
    gs_buyer-changed_by = sy-uname.
    gs_buyer-changed_at = gv_ts.
    UPDATE zcp_buyer FROM gs_buyer.
    IF sy-subrc = 0.
      COMMIT WORK.
      WRITE: / 'Buyer', gv_kunnr, 'sudah ada, kini diaktifkan.'.
      WRITE: / 'Nama:', gs_buyer-buyer_name.
    ELSE.
      ROLLBACK WORK.
      WRITE: / 'Gagal memperbarui. Periksa lock di SM12.'.
    ENDIF.
    RETURN.
  ENDIF.

  CLEAR gs_buyer.
  gs_buyer-buyer_id   = gv_kunnr.
  gs_buyer-buyer_name = gs_kna1-name1.
  gs_buyer-company    = gs_kna1-name1.
  gs_buyer-country    = gs_kna1-land1.
  gs_buyer-is_active  = 'X'.
  gs_buyer-created_by = sy-uname.
  gs_buyer-created_at = gv_ts.
  gs_buyer-changed_by = sy-uname.
  gs_buyer-changed_at = gv_ts.

  INSERT zcp_buyer FROM gs_buyer.

  IF sy-subrc = 0.
    COMMIT WORK.
    WRITE: / 'Buyer', gv_kunnr, 'berhasil didaftarkan.'.
    WRITE: / 'Nama  :', gs_buyer-buyer_name.
    WRITE: / 'Negara:', gs_buyer-country.
    WRITE: /.
    WRITE: / 'Sekarang SO milik pelanggan ini sudah bisa di-request'.
    WRITE: / 'lewat halaman req_form.htm.'.
  ELSE.
    ROLLBACK WORK.
    WRITE: / 'Gagal menyisipkan baris ZCP_BUYER.'.
  ENDIF.


*&---------------------------------------------------------------------*
*& Text elements -- Goto -> Text Elements. Boleh dilewati kalau buru-buru;
*& tanpa diisi, judul blok tampil kosong tapi report tetap jalan.
*&---------------------------------------------------------------------*
*  T01   Nomor Pelanggan
*  T02   Tindakan
*
*  Selection Texts:
*    P_KUNNR  Nomor Pelanggan (KUNNR)
*    P_ADD    Daftarkan / aktifkan sebagai buyer
*    P_OFF    Nonaktifkan buyer
*    P_LST    Hanya tampilkan isi ZCP_BUYER
*&---------------------------------------------------------------------*
