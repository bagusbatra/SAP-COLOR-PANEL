*&---------------------------------------------------------------------*
*& main.htm - OnRequest
*&---------------------------------------------------------------------*
*& REVISI 6 Agustus 2026. Isi lama (dua baris pengisi bertanda TAHAP 1)
*& sudah tidak berlaku: dengan autentikasi SAP standar, identitas dan
*& role sudah bisa dibaca sungguhan sejak sekarang tanpa satu class pun.
*&
*& Blok di bawah adalah salinan persis _shared/role_detect.abap.txt.
*& Kalau file itu berubah, perubahannya harus disebar ke sini dan ke
*& OnRequest setiap halaman lain -- konsekuensi dari memilih menyalin
*& potongan alih-alih meng-include-nya.
*&
*& Task 15 memindahkan blok ini ke ZCL_CP_AUTH=>resolve_user( ) supaya
*& tidak lagi tersalin di delapan tempat. Perilakunya tidak berubah,
*& jadi pemindahan itu murni perapian, bukan perbaikan.
*&
*& Empat SELECT COUNT untuk kartu statistik juga ditambahkan di Task 15.
*&---------------------------------------------------------------------*

DATA: lt_agr      TYPE STANDARD TABLE OF agr_name,
      lv_agr      TYPE agr_name,
      lv_has_adm  TYPE c LENGTH 1,
      lv_has_it   TYPE c LENGTH 1,
      lv_has_qc   TYPE c LENGTH 1,
      lv_has_sls  TYPE c LENGTH 1,
      ls_cpuser   TYPE zcp_user,
      lv_name     TYPE ad_namtext.

CLEAR: gv_user_id, gv_user_name, gv_role, gv_buyer_id,
       gv_as_sales, gv_as_admin, gv_as_qc, gv_as_it,
       lv_has_adm, lv_has_it, lv_has_qc, lv_has_sls.

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

IF gv_role = 'SALES' AND gv_buyer_id IS INITIAL.
  navigation->goto_page( 'noaccess.htm' ).
  RETURN.
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
