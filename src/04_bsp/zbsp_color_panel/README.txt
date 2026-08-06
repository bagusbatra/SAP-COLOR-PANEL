CARA MEMBACA FOLDER INI
=======================

Struktur folder ini DATAR, tanpa sub-folder per halaman. Itu disengaja:
SE80 juga datar. Di SAP tidak ada folder di dalam aplikasi BSP -- yang
ada hanya daftar halaman, dan tiap halaman adalah SATU objek dengan
beberapa TAB.


Satu halaman BSP = satu objek, bukan folder
-------------------------------------------

Di SE80, di bawah aplikasi ZBSP_COLOR_PANEL ada node "Pages". Isinya:

    ZBSP_COLOR_PANEL
      |
      +-- Pages
            |
            +-- main.htm          <- satu objek
            +-- noaccess.htm      <- satu objek

Klik dua kali main.htm, dan yang terbuka di kanan adalah satu editor
dengan deretan tab:

    [ Properties ] [ Layout ] [ Page Attributes ] [ Type Definitions ]
    [ Event Handler ]

Tidak ada file terpisah di dalamnya. Semua isi halaman tinggal di
satu objek, terbagi ke tab-tab itu.


Pemetaan file di sini ke tab di SE80
------------------------------------

  File di repo                  Dibawa ke mana di SE80
  --------------------------------------------------------------------
  main.htm                      tab Layout
  main.attributes.txt           tab Page Attributes (DIKETIK, bukan paste)
  main.onrequest.abap           tab Event Handler -> OnRequest

  noaccess.htm                  tab Layout
  noaccess.attributes.txt       tab Page Attributes (DIKETIK)
  noaccess.onrequest.abap       tab Event Handler -> OnRequest

Perhatikan file .attributes.txt tetap berakhiran .txt. Isinya bukan
kode yang di-paste, melainkan tabel yang Anda ketik baris demi baris
ke dalam grid di tab Page Attributes. Format .txt supaya jelas bahwa
file itu bahan bacaan, bukan bahan salin.


DAFTAR ATRIBUT TIAP HALAMAN BERBEDA -- JANGAN DISAMAKAN
-------------------------------------------------------

Ini kesalahan yang paling mudah terjadi. Halaman-halamannya mirip,
jadi godaan menyalin daftar atribut dari halaman sebelumnya besar.

  main.htm      gv_user_id, gv_user_name, gv_role, gv_buyer_id
  noaccess.htm  gv_user_id, gv_user_name, gv_reason

noaccess.htm TIDAK punya gv_role -- dia memakai lv_role lokal, karena
role di halaman itu hanya dipakai untuk menentukan kalimat penolakan,
tidak untuk menyaring menu.

Gejala bila salah: aktivasi gagal dengan "Field GV_xxx is unknown",
dan jumlah error sama dengan berapa kali atribut itu dipakai di
Layout ditambah di Event Handler. Misalnya gv_reason yang belum
dibuat menghasilkan tepat 5 error -- 4 di .onrequest.abap dan 1 di
.htm.

Kalau melihat error semacam itu, jangan cari kesalahan di kode.
Cocokkan dulu tab Page Attributes dengan file .attributes.txt milik
halaman ITU, bukan halaman sebelah.


Folder _shared
--------------

Berisi potongan yang muncul di banyak halaman. Tidak ada padanannya di
SE80 -- isinya disalin ke dalam halaman, bukan dijadikan objek sendiri.
BSP di 1809 tidak punya mekanisme partial yang nyaman untuk konten
bercampur ABAP, jadi menyalin adalah pilihan sadar.

  head.htm          potongan <head>, sudah tertanam di tiap file .htm
  nav.htm           potongan sidebar, sudah tertanam di tiap file .htm
  role_detect.abap  potongan deteksi role, sudah tertanam di tiap
                    file .onrequest.abap

Kata "sudah tertanam" itu penting: Anda TIDAK perlu menyalin isi
_shared secara terpisah. Ketiga file .htm dan .onrequest.abap di folder
ini sudah lengkap dan berdiri sendiri. Folder _shared ada supaya kalau
suatu saat potongannya berubah, jelas dari mana asalnya dan ke mana
saja harus disebarkan.


Urutan membuat satu halaman di SE80
-----------------------------------

  1. SE80 -> BSP Application -> ZBSP_COLOR_PANEL
  2. Klik kanan node "Pages" -> Create -> Page
  3. Isi Page Name (mis. main.htm), Description,
     dan Page Type = "Page with Flow Logic"
  4. Tab Properties  -> centang Stateful -> Save
  5. Tab Page Attributes -> ketik baris-baris dari file .attributes.txt
  6. Tab Layout      -> hapus isi bawaan, paste seluruh isi file .htm
  7. Tab Event Handler -> pilih OnRequest dari dropdown,
     paste seluruh isi file .onrequest.abap
  8. Ctrl+F3 untuk aktivasi


Aturan yang tidak boleh dilanggar
---------------------------------

Nol karakter non-ASCII di seluruh file .htm dan .abap di sini. BSP
merusak semua karakter di atas U+007F, dan gejalanya menyesatkan --
halaman rusak di tempat yang tidak berhubungan dengan perubahan
terakhir. Pakai HTML entity: &mdash; &middot; &#8226; &#10003;

Salin langsung dari file, jangan lewat Word, chat, atau editor yang
mengubah tanda kutip lurus menjadi melengkung.
