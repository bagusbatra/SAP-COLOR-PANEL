# Color Panel Sub-Proyek 1 (Foundation + Request/DCP) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun fondasi sistem Color Panel di SAP S/4HANA 1809 — DDIC, autentikasi, dan siklus penuh Request Sales sampai panel DCP di-approve dan header di-close.

**Architecture:** Halaman BSP tipis yang hanya merender HTML dan memanggil ABAP Class; seluruh aturan bisnis tinggal di kelas `ZCL_CP_*`. Sumber ditulis sebagai file lokal di repo ini, lalu di-paste ke SE11/SE24/SE80. Logic murni (transisi status, format ID, perhitungan tanggal) diuji dengan ABAP Unit; sisanya diuji lewat report SE38 dan pengujian manual.

**Tech Stack:** ABAP 7.52 (S/4HANA 1809, BASIS 753), BSP (SE80), ABAP Unit, SNRO, `cl_bsp_server_side_cookie`, `cl_abap_message_digest`, Tailwind CSS CDN + SweetAlert2 di sisi klien.

**Spec:** `docs/superpowers/specs/2026-07-28-color-panel-foundation-dcp-design.md`

## Checkpoint Terakhir &mdash; 29 Juli 2026

| Task | Status |
|---|---|
| Task 1 &mdash; Inisialisasi repo | Selesai |
| Task 2 &mdash; Domain dan data element | Selesai, 6 domain + 18 data element Active di SE11 |
| Task 3 &mdash; Tabel dkk | **Sebagian** &mdash; 10 tabel + 6 index + lock object `EZCP_SO` Active; 5 objek SNRO dibuat tapi intervalnya belum; SE91 dan TMG belum |
| Task 4 dan seterusnya | Belum mulai |

**Titik lanjut berikutnya:** mengisi interval `01` untuk kelima objek number range di SNRO, lalu message class `ZCP` di SE91 dan Table Maintenance Generator untuk `ZCP_BUYER`.

Catatan dari pengerjaan Task 3 yang tidak ada di langkah asli:

1. **Enhancement Category wajib diisi manual** tiap tabel lewat `Extras -> Enhancement Category`, kalau tidak muncul warning tiap aktivasi. Pilih `Can Be Enhanced (Character-Type or Numeric)` untuk sembilan tabel; `ZCP_PHOTO` harus `Can Be Enhanced (Deep)` karena punya field `RAWSTRING`, dan salah pilih di situ membuat aktivasi gagal, bukan sekadar warning.
2. **`PHOTO_DATA` tidak boleh dicentang Initial Values.** Field `RAWSTRING` menolak flag `NOT NULL` dengan error `Too long for activation of 'not null' flag (>255)`. Semua field lain di semua tabel tetap dicentang.
3. **Field `MENGE` (`MENGE_D`) wajib punya reference field** di tab `Currency/Quantity Fields`, menunjuk ke `MEINS` di tabel yang sama. Berlaku di `ZCP_REQUEST_ITM` dan `ZCP_SO_IMPORT`. Tanpa itu aktivasi gagal.
4. **Index dibuat terpisah setelah tabel Active**, dan `MANDT` harus diketik manual sebagai field pertama &mdash; SE11 tidak menambahkannya otomatis seperti pada primary key.

## Global Constraints

Berlaku untuk **setiap** task. Tidak diulang di tiap langkah.

1. **Nol karakter non-ASCII di seluruh sumber BSP.** Semua karakter di atas U+007F harus ditulis sebagai HTML entity (`&mdash;`, `&#8226;`, `&#10003;`). Berlaku juga untuk komentar dan teks Indonesia — tulis "Tanggal" bukan kata bertanda diakritik.
2. **OpenSQL gaya lama, tanpa `@`.** `SELECT f1 f2 INTO TABLE lt_data FROM ztab WHERE f = lv_var.` Dilarang: inline `DATA(...)`, `VALUE #( )`, `CORRESPONDING #( )`, string template `|...|`, `REDUCE`, `FOR`.
3. **Semua variabel dideklarasikan eksplisit** di blok `DATA:` pada awal method.
4. **Semua halaman BSP stateful.**
5. **`SY-UNAME` tidak pernah dipakai sebagai identitas pelaku.** Selalu `USER_ID` dari session, karena SICF memakai shared user `auto_email`.
6. **Atribut `class` di dalam string JavaScript harus satu baris**, tidak boleh dipecah antar baris.
7. **Package:** `$TMP` selama pengembangan, dipindah ke `ZCOLOR` sebelum transport.
8. **Message class:** `ZCP`. Tidak ada teks error sebagai literal di halaman BSP.
9. **Penamaan:** tabel/DDIC `ZCP_*`, kelas `ZCL_CP_*`, exception `ZCX_CP_*`, report `ZCP_*`, BSP `ZBSP_COLOR_PANEL`.
10. **Setiap task diakhiri commit git** di repo lokal `D:\DEV\SAP COLOR PANEL`.

## Struktur File

```
src/
  01_ddic/
    domains.txt                  Definisi 6 domain fixed-value
    data_elements.txt            Definisi data element ZCP_*
    lock_objects.txt             EZCP_SO
    snro.txt                     5 objek number range
    messages_zcp.txt             Message class ZCP
    tables/
      zcp_user.txt               10 file, satu per tabel
      zcp_buyer.txt
      zcp_color_code.txt
      zcp_request.txt
      zcp_request_itm.txt
      zcp_so_import.txt
      zcp_dcp_hdr.txt
      zcp_dcp_item.txt
      zcp_photo.txt
      zcp_audit_log.txt
  02_classes/
    zcx_cp_error.abap            Exception, satu-satunya jalur error
    zcl_cp_number.abap           SNRO + format ID (pure + DB)
    zcl_cp_audit.abap            Tulis audit log
    zcl_cp_auth.abap             Hash, login, session, guard role
    zcl_cp_so_reader.abap        Baca VBAK/VBAP + saring kelayakan
    zcl_cp_dcp.abap              Seluruh aturan siklus DCP
    zcl_cp_request.abap          Request create + approve/reject per item
    zcl_cp_photo.abap            Upload dan validasi foto
  03_reports/
    zcp_test_so_reader.abap      Harness SE38 untuk SO reader
  04_bsp/zbsp_color_panel/
    <page>/attributes.txt        Page attributes per halaman
    <page>/oninputprocessing.abap.txt
    <page>/layout.htm.txt
docs/superpowers/specs/          Spec (sudah ada)
docs/superpowers/plans/          Plan ini
```

Pembagiannya per tanggung jawab, bukan per layer: satu kelas memegang satu aturan bisnis utuh, dan satu halaman memegang satu layar.

---

### Task 1: Inisialisasi Repo dan Struktur Folder

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: struktur folder `src/01_ddic/tables`, `src/02_classes`, `src/03_reports`, `src/04_bsp/zbsp_color_panel`

**Interfaces:**
- Consumes: tidak ada
- Produces: repo git aktif dan struktur folder yang dipakai semua task berikutnya

- [x] **Step 1: Inisialisasi git dan buat struktur folder**

```bash
cd "D:/DEV/SAP COLOR PANEL"
git init
mkdir -p src/01_ddic/tables src/02_classes src/03_reports src/04_bsp/zbsp_color_panel
```

- [x] **Step 2: Buat `.gitignore`**

```
*.tmp
*.bak
~$*
Thumbs.db
desktop.ini
```

- [x] **Step 3: Buat `README.md`**

```markdown
# Color Panel Management System &mdash; SAP S/4HANA 1809

Sumber ABAP dan BSP untuk aplikasi `ZBSP_COLOR_PANEL` di PT. Kayu Mebel Indonesia.

## Cara pakai repo ini

Repo ini adalah sumber kebenaran. SE80 tidak punya versioning yang layak,
jadi setiap perubahan ditulis di sini lebih dulu, baru di-paste ke SAP.

- `src/01_ddic/` &mdash; definisi domain, data element, tabel, number range, lock object
- `src/02_classes/` &mdash; ABAP Class, dibuat lewat SE24
- `src/03_reports/` &mdash; report uji, dibuat lewat SE38
- `src/04_bsp/` &mdash; halaman BSP, dibuat lewat SE80

## Dokumen

- Spec: `docs/superpowers/specs/2026-07-28-color-panel-foundation-dcp-design.md`
- Plan: `docs/superpowers/plans/2026-07-28-color-panel-foundation-dcp.md`

## Aturan teknis yang tidak boleh dilanggar

1. Nol karakter non-ASCII di sumber BSP &mdash; pakai HTML entity
2. OpenSQL gaya lama tanpa `@`, tanpa inline declaration
3. Semua halaman BSP stateful
4. Identitas pelaku selalu USER_ID dari session, tidak pernah SY-UNAME
```

- [x] **Step 4: Verifikasi struktur terbentuk**

Run: `git status --short && ls src`
Expected: `.gitignore` dan `README.md` muncul sebagai untracked; folder `01_ddic 02_classes 03_reports 04_bsp` terdaftar.

- [x] **Step 5: Commit**

```bash
git add .gitignore README.md docs
git commit -m "chore: inisialisasi repo color panel dengan spec dan plan"
```

---

### Task 2: Domain dan Data Element

**Files:**
- Create: `src/01_ddic/domains.txt`
- Create: `src/01_ddic/data_elements.txt`

**Interfaces:**
- Consumes: tidak ada
- Produces: domain `ZCP_DOM_ROLE`, `ZCP_DOM_REQ_ST`, `ZCP_DOM_ITM_ST`, `ZCP_DOM_DCP_ST`, `ZCP_DOM_PANEL_ST`, `ZCP_DOM_CC_ST` dan data element `ZCP_DE_*` yang dipakai seluruh tabel di Task 3

Status memakai domain berdaftar nilai tetap supaya SM30 menampilkan teks dan nilai salah tertangkap saat aktivasi tabel, bukan saat produksi.

- [x] **Step 1: Tulis `src/01_ddic/domains.txt`**

```
DOMAIN ZCP_DOM_ROLE
  Data Type CHAR  Length 10
  Value Range (Fixed Values):
    SALES   Sales Representative
    ADMIN   Admin Color
    IT      IT Support

DOMAIN ZCP_DOM_REQ_ST
  Data Type CHAR  Length 1
  Value Range (Fixed Values):
    P   Pending
    C   Closed

DOMAIN ZCP_DOM_ITM_ST
  Data Type CHAR  Length 1
  Value Range (Fixed Values):
    P   Pending
    A   Approved
    R   Rejected

DOMAIN ZCP_DOM_DCP_ST
  Data Type CHAR  Length 1
  Value Range (Fixed Values):
    O   Open
    C   Closed
    R   Rejected

DOMAIN ZCP_DOM_PANEL_ST
  Data Type CHAR  Length 2
  Value Range (Fixed Values):
    NA  Non-Aktif
    AK  Aktif
    SB  Submitted
    AP  Approved
    RJ  Rejected
    OB  Obsolete

DOMAIN ZCP_DOM_CC_ST
  Data Type CHAR  Length 1
  Value Range (Fixed Values):
    A   Aktif
    I   Non-Aktif
    O   Obsolete
```

- [x] **Step 2: Tulis `src/01_ddic/data_elements.txt`**

```
Data Element          Domain / Type      Field Label (Medium)
--------------------------------------------------------------------
ZCP_DE_USER_ID        CHAR20             User ID
ZCP_DE_ROLE           ZCP_DOM_ROLE       Role
ZCP_DE_BUYER_ID       CHAR10             Buyer ID
ZCP_DE_COLOR_CODE     CHAR20             Color Code
ZCP_DE_REQUEST_ID     CHAR20             Request ID
ZCP_DE_DCP_ID         CHAR20             DCP ID
ZCP_DE_PANEL_ID       CHAR30             Panel ID
ZCP_DE_PANEL_NUMBER   NUMC3              Nomor Panel
ZCP_DE_PHOTO_ID       CHAR20             Photo ID
ZCP_DE_LOG_ID         CHAR20             Log ID
ZCP_DE_REQ_ST         ZCP_DOM_REQ_ST     Status Request
ZCP_DE_ITM_ST         ZCP_DOM_ITM_ST     Status Item
ZCP_DE_DCP_ST         ZCP_DOM_DCP_ST     Status DCP
ZCP_DE_PANEL_ST       ZCP_DOM_PANEL_ST   Status Panel
ZCP_DE_CC_ST          ZCP_DOM_CC_ST      Status Color Code
ZCP_DE_REASON         CHAR200            Alasan
ZCP_DE_REMARKS        CHAR200            Catatan
ZCP_DE_HASH           CHAR64             Password Hash

Catatan: field yang sudah punya data element standar SAP memakai yang standar,
tidak dibuatkan ZCP_DE_ sendiri:
  MATNR, MAKTX, VBELN, POSNR, MENGE_D, MEINS, LAND1, DATUM, TIMESTAMP
```

- [x] **Step 3: Buat domain di SE11**

Jalankan SE11 untuk tiap domain di `domains.txt`: pilih Domain, isi nama, isi Data Type dan Length di tab Definition, isi Fixed Values di tab Value Range, lalu aktifkan.
Expected: keenam domain berstatus Active. Cek dengan SE11 &rarr; Domain &rarr; Display: kolom Fixed Values terisi lengkap.

- [x] **Step 4: Buat data element di SE11**

Jalankan SE11 untuk tiap baris di `data_elements.txt`: pilih Data Type &rarr; Data Element, isi Domain (atau predefined type untuk CHAR20/CHAR10/NUMC3), isi Field Label pada tab Field Label, lalu aktifkan.
Expected: seluruh data element `ZCP_DE_*` berstatus Active.

- [x] **Step 5: Commit**

```bash
git add src/01_ddic/domains.txt src/01_ddic/data_elements.txt
git commit -m "feat(ddic): domain fixed-value dan data element ZCP"
```

---

### Task 3: Tabel, Lock Object, Number Range, dan Message Class

**Files:**
- Create: `src/01_ddic/tables/zcp_user.txt`, `zcp_buyer.txt`, `zcp_color_code.txt`, `zcp_request.txt`, `zcp_request_itm.txt`, `zcp_so_import.txt`, `zcp_dcp_hdr.txt`, `zcp_dcp_item.txt`, `zcp_photo.txt`, `zcp_audit_log.txt`
- Create: `src/01_ddic/lock_objects.txt`
- Create: `src/01_ddic/snro.txt`
- Create: `src/01_ddic/messages_zcp.txt`

**Interfaces:**
- Consumes: domain dan data element dari Task 2
- Produces: sepuluh tabel transparan, lock object `EZCP_SO` (FM `ENQUEUE_EZCP_SO` / `DEQUEUE_EZCP_SO`), lima objek number range, message class `ZCP` &mdash; semuanya dipakai kelas di Task 4 dan seterusnya

Semua tabel: Delivery Class `A`, Data Browser/Table View Maintenance `Display/Maintenance Allowed`, Technical Settings Data Class `APPL1` (master) atau `APPL0` (transaksi), Size Category `1` kecuali `ZCP_PHOTO` dan `ZCP_AUDIT_LOG` yang memakai `3`.

- [x] **Step 1: Tulis file definisi sepuluh tabel**

Isi tiap file mengikuti bagian 3 spec. Format tiap file:

```
TABLE ZCP_COLOR_CODE
Short Description: Color Panel - Master Color Code
Delivery Class: A
Data Class: APPL1   Size Category: 1

Field           Key  Data Element / Type   Keterangan
--------------------------------------------------------------------
MANDT           X    MANDT                 Client
COLOR_CODE      X    ZCP_DE_COLOR_CODE     KW + 5 digit
MATNR                MATNR                 FERT Material Number
MAKTX                MAKTX                 Snapshot deskripsi material
BUYER_ID             ZCP_DE_BUYER_ID       Buyer
COLOR_NAME           CHAR60                Nama warna
COLOR_HEX            CHAR7                 #RRGGBB, opsional
COMPONENT            CHAR40                Solid / veneer
STATUS               ZCP_DE_CC_ST          A / I / O
SOURCE_DCP_ID        ZCP_DE_DCP_ID         DCP yang melahirkan Color Code
REMARKS              ZCP_DE_REMARKS        Catatan
CREATED_BY           ZCP_DE_USER_ID        USER_ID, bukan SY-UNAME
CREATED_AT           TIMESTAMP             Waktu dibuat
CHANGED_BY           ZCP_DE_USER_ID        USER_ID
CHANGED_AT           TIMESTAMP             Waktu ubah

INDEX MAT (UNIQUE)
  MANDT, MATNR
  Alasan: memaksa aturan 1:1 FERT di level database. Tanpa index ini,
  dua proses paralel bisa membuat dua Color Code untuk satu material.
```

Tabel lain mengikuti pola yang sama. Index yang wajib dibuat:

```
ZCP_COLOR_CODE  INDEX MAT (UNIQUE)      MANDT, MATNR
ZCP_REQUEST     INDEX SO  (non-unique)  MANDT, SO_NUMBER
ZCP_DCP_ITEM    INDEX PID (UNIQUE)      MANDT, PANEL_ID
ZCP_DCP_HDR     INDEX REQ (non-unique)  MANDT, REQUEST_ID
ZCP_PHOTO       INDEX REF (non-unique)  MANDT, REF_TYPE, REF_ID, PANEL_NUMBER
ZCP_AUDIT_LOG   INDEX REF (non-unique)  MANDT, REF_TYPE, REF_ID
```

`ZCP_REQUEST` sengaja non-unique pada `SO_NUMBER`: material yang ditolak harus bisa diajukan ulang dalam request baru dengan nomor SO yang sama.

- [x] **Step 2: Tulis `src/01_ddic/lock_objects.txt`**

```
LOCK OBJECT EZCP_SO
  Primary Table: ZCP_SO_IMPORT
  Lock Mode: E (exclusive, cumulative)
  Lock Parameter: SO_NUMBER
  (SO_ITEM tidak dijadikan parameter &mdash; kunci diambil di level nomor SO
   supaya approve beberapa item dalam satu SO berjalan sebagai satu unit)

  Function Modules yang ter-generate:
    ENQUEUE_EZCP_SO
    DEQUEUE_EZCP_SO
```

- [x] **Step 3: Tulis `src/01_ddic/snro.txt`**

```
SNRO OBJECT ZCP_COLOR       Number Length 5    To-Year Flag: NO
  Interval 01: 00001 - 99999
  Dipakai: ZCL_CP_NUMBER=>next_color_code, hasil "KW00001"

SNRO OBJECT ZCP_REQ         Number Length 4    To-Year Flag: YES
  Interval 01: 0001 - 9999   (per tahun)
  Dipakai: ZCL_CP_NUMBER=>next_request_id, hasil "REQ-2026-0001"

SNRO OBJECT ZCP_DCP         Number Length 4    To-Year Flag: YES
  Interval 01: 0001 - 9999   (per tahun)
  Dipakai: ZCL_CP_NUMBER=>next_dcp_id, hasil "DCP-2026-0001"

SNRO OBJECT ZCP_PHOTO       Number Length 9    To-Year Flag: NO
  Interval 01: 000000001 - 999999999
  Dipakai: ZCL_CP_NUMBER=>next_photo_id, hasil "PH000000001"

SNRO OBJECT ZCP_AUDIT       Number Length 12   To-Year Flag: NO
  Interval 01: 000000000001 - 999999999999
  Dipakai: ZCL_CP_NUMBER=>next_log_id, hasil "LOG000000000001"

Catatan: To-Year Flag YES berarti pemanggilan NUMBER_GET_NEXT wajib mengisi
parameter TOYEAR, dan penomoran mulai dari 0001 lagi tiap tahun.
```

- [x] **Step 4: Tulis `src/01_ddic/messages_zcp.txt`**

```
MESSAGE CLASS ZCP - Color Panel

No   Text
-----------------------------------------------------------------------
001  SO &1 tidak ditemukan
002  SO &1 tidak memiliki material yang layak dijadikan DCP
003  Material &1 sudah memiliki Color Code &2
004  SO item &1 sudah diproses menjadi DCP &2
005  SO item &1 sudah diproses oleh &2 pada &3
006  User atau password salah
007  Session sudah berakhir, silakan login ulang
008  Anda tidak memiliki akses ke halaman ini
009  Panel &1 tidak dapat diubah dari status &2 ke status &3
010  Panel &1 membutuhkan minimal 2 foto sebelum submit
011  DCP &1 tidak dapat di-close, belum ada panel yang approved
012  Undo tidak diizinkan, DCP &1 sudah di-close
013  Tanggal pembuatan tidak boleh di masa depan
014  Ukuran file &1 melebihi batas 2 MB
015  Tipe file &1 tidak diizinkan, hanya JPEG dan PNG
016  Alasan wajib diisi
017  Request &1 tidak ditemukan
018  DCP &1 tidak ditemukan
019  Terjadi kesalahan saat menyimpan, perubahan dibatalkan
020  User &1 sudah terdaftar
```

- [~] **Step 5: Buat semua objek di sistem SAP** &mdash; SEBAGIAN, per 29 Juli 2026

  - [x] Sepuluh tabel dibuat dan Active di SE11, terverifikasi lewat SE16N
  - [x] Enam secondary index dibuat dan aktif: `ZCP_COLOR_CODE~MAT` (unique), `ZCP_REQUEST~SO`, `ZCP_DCP_HDR~REQ`, `ZCP_DCP_ITEM~PID` (unique), `ZCP_PHOTO~REF`, `ZCP_AUDIT_LOG~REF`
  - [x] Lock object `EZCP_SO` &mdash; primary table `ZCP_SO_IMPORT`, mode `E`, parameter `SO_NUMBER` saja setelah `SO_ITEM` dihapus dari daftar bawaan
  - [~] Lima objek number range di SNRO &mdash; objek dibuat dengan domain `NUM5`/`NUM4`/`NUM4`/`NUM9`/`NUM12`, buffering mati; **interval 01 belum dibuat**
  - [ ] Message class `ZCP` dengan 20 pesan di SE91
  - [ ] Table Maintenance Generator untuk `ZCP_BUYER`

Urutan: SE11 buat sepuluh tabel dan aktifkan &rarr; SE11 buat lock object `EZCP_SO` dan aktifkan &rarr; SNRO buat lima objek beserta interval 01 &rarr; SE91 buat message class `ZCP` dan seluruh nomor pesan &rarr; SE11 generate Table Maintenance untuk `ZCP_BUYER` saja (Function Group `ZFGP_COLOR_PANEL`, auth group `&NC&`, one-step).
Expected: sepuluh tabel Active dan bisa dibuka di SE16N; `ENQUEUE_EZCP_SO` muncul di SE37; `SNRO &rarr; ZCP_COLOR &rarr; Number Ranges` menampilkan interval 01; SM30 `ZCP_BUYER` bisa dibuka dan menyimpan satu baris uji.

- [ ] **Step 6: Commit**

```bash
git add src/01_ddic
git commit -m "feat(ddic): 10 tabel, lock object EZCP_SO, 5 number range, message class ZCP"
```

---

### Task 4: ZCX_CP_ERROR dan ZCL_CP_NUMBER

**Files:**
- Create: `src/02_classes/zcx_cp_error.abap`
- Create: `src/02_classes/zcl_cp_number.abap`

**Interfaces:**
- Consumes: message class `ZCP` dan objek SNRO dari Task 3
- Produces:
  - `ZCX_CP_ERROR` &mdash; `raise( iv_msgno TYPE symsgno, iv_v1..iv_v4 TYPE string OPTIONAL )` (static, selalu melempar)
  - `ZCL_CP_NUMBER=>format_color_code( iv_number TYPE i ) RETURNING VALUE(rv_code) TYPE char20`
  - `ZCL_CP_NUMBER=>format_request_id( iv_year TYPE numc4 iv_number TYPE i ) RETURNING VALUE(rv_id) TYPE char20`
  - `ZCL_CP_NUMBER=>format_dcp_id( iv_year TYPE numc4 iv_number TYPE i ) RETURNING VALUE(rv_id) TYPE char20`
  - `ZCL_CP_NUMBER=>build_panel_id( iv_dcp_id TYPE char20 iv_panel_number TYPE numc3 ) RETURNING VALUE(rv_panel_id) TYPE char30`
  - `ZCL_CP_NUMBER=>next_color_code( ) RETURNING VALUE(rv_code) TYPE char20`
  - `ZCL_CP_NUMBER=>next_request_id( ) RETURNING VALUE(rv_id) TYPE char20`
  - `ZCL_CP_NUMBER=>next_dcp_id( ) RETURNING VALUE(rv_id) TYPE char20`
  - `ZCL_CP_NUMBER=>next_photo_id( ) RETURNING VALUE(rv_id) TYPE char20`
  - `ZCL_CP_NUMBER=>next_log_id( ) RETURNING VALUE(rv_id) TYPE char20`

Method `format_*` dan `build_panel_id` sengaja dipisah dari `next_*`: yang pertama murni tanpa akses database sehingga bisa diuji ABAP Unit, yang kedua hanya membungkus `NUMBER_GET_NEXT` lalu memanggil `format_*`.

- [ ] **Step 1: Tulis `src/02_classes/zcx_cp_error.abap`**

```abap
CLASS zcx_cp_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_message.

    DATA: mv_msgno TYPE symsgno,
          mv_v1    TYPE string,
          mv_v2    TYPE string,
          mv_v3    TYPE string,
          mv_v4    TYPE string.

    METHODS constructor
      IMPORTING iv_msgno TYPE symsgno
                iv_v1    TYPE string OPTIONAL
                iv_v2    TYPE string OPTIONAL
                iv_v3    TYPE string OPTIONAL
                iv_v4    TYPE string OPTIONAL.

    CLASS-METHODS raise
      IMPORTING iv_msgno TYPE symsgno
                iv_v1    TYPE string OPTIONAL
                iv_v2    TYPE string OPTIONAL
                iv_v3    TYPE string OPTIONAL
                iv_v4    TYPE string OPTIONAL
      RAISING   zcx_cp_error.

    METHODS get_text_message
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.

CLASS zcx_cp_error IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_msgno = iv_msgno.
    mv_v1    = iv_v1.
    mv_v2    = iv_v2.
    mv_v3    = iv_v3.
    mv_v4    = iv_v4.

    if_t100_message~t100key-msgid = 'ZCP'.
    if_t100_message~t100key-msgno = iv_msgno.
    if_t100_message~t100key-attr1 = 'MV_V1'.
    if_t100_message~t100key-attr2 = 'MV_V2'.
    if_t100_message~t100key-attr3 = 'MV_V3'.
    if_t100_message~t100key-attr4 = 'MV_V4'.
  ENDMETHOD.

  METHOD raise.
    RAISE EXCEPTION TYPE zcx_cp_error
      EXPORTING iv_msgno = iv_msgno
                iv_v1    = iv_v1
                iv_v2    = iv_v2
                iv_v3    = iv_v3
                iv_v4    = iv_v4.
  ENDMETHOD.

  METHOD get_text_message.
    DATA: lv_text TYPE string,
          lv_v1   TYPE symsgv,
          lv_v2   TYPE symsgv,
          lv_v3   TYPE symsgv,
          lv_v4   TYPE symsgv.

    lv_v1 = mv_v1.
    lv_v2 = mv_v2.
    lv_v3 = mv_v3.
    lv_v4 = mv_v4.

    MESSAGE ID 'ZCP' TYPE 'E' NUMBER mv_msgno
      WITH lv_v1 lv_v2 lv_v3 lv_v4
      INTO lv_text.

    rv_text = lv_text.
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 2: Tulis test class untuk ZCL_CP_NUMBER lebih dulu**

Ini isi Local Types (tab "Local Definitions/Implementations" &rarr; "Local Test Classes") pada kelas `ZCL_CP_NUMBER`. Simpan di `src/02_classes/zcl_cp_number.abap` di bagian bawah file, diberi penanda komentar.

```abap
*"* LOCAL TEST CLASSES - paste ke tab "Local Test Classes" di SE24

CLASS ltc_number DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS color_code_pads_to_five FOR TESTING.
    METHODS color_code_keeps_five_digits FOR TESTING.
    METHODS request_id_has_year FOR TESTING.
    METHODS dcp_id_has_year FOR TESTING.
    METHODS panel_id_appends_number FOR TESTING.

ENDCLASS.

CLASS ltc_number IMPLEMENTATION.

  METHOD color_code_pads_to_five.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_number=>format_color_code( 1 )
      exp = 'KW00001'
      msg = 'Angka 1 harus jadi KW00001' ).
  ENDMETHOD.

  METHOD color_code_keeps_five_digits.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_number=>format_color_code( 99999 )
      exp = 'KW99999'
      msg = 'Angka 99999 harus jadi KW99999' ).
  ENDMETHOD.

  METHOD request_id_has_year.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_number=>format_request_id( iv_year = '2026' iv_number = 7 )
      exp = 'REQ-2026-0007'
      msg = 'Format request harus REQ-YYYY-NNNN' ).
  ENDMETHOD.

  METHOD dcp_id_has_year.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_number=>format_dcp_id( iv_year = '2026' iv_number = 123 )
      exp = 'DCP-2026-0123'
      msg = 'Format DCP harus DCP-YYYY-NNNN' ).
  ENDMETHOD.

  METHOD panel_id_appends_number.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_number=>build_panel_id(
              iv_dcp_id       = 'DCP-2026-0123'
              iv_panel_number = '007' )
      exp = 'DCP-2026-0123-007'
      msg = 'Panel ID harus DCP ID + dash + nomor panel 3 digit' ).
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 3: Buat kelas ZCL_CP_NUMBER dengan method kosong, lalu jalankan test**

Buat di SE24 kelas `ZCL_CP_NUMBER`, semua method static public dengan body kosong (hanya `ENDMETHOD.`), paste test class di atas ke Local Test Classes, aktifkan.
Run: SE24 &rarr; `ZCL_CP_NUMBER` &rarr; menu Test &rarr; Unit Test (atau `Ctrl+Shift+F10`).
Expected: FAIL. Kelima test gagal dengan pesan seperti `Angka 1 harus jadi KW00001` dan nilai aktual kosong.

- [ ] **Step 4: Tulis implementasi ZCL_CP_NUMBER**

```abap
CLASS zcl_cp_number DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS format_color_code
      IMPORTING iv_number      TYPE i
      RETURNING VALUE(rv_code) TYPE char20.

    CLASS-METHODS format_request_id
      IMPORTING iv_year      TYPE numc4
                iv_number    TYPE i
      RETURNING VALUE(rv_id) TYPE char20.

    CLASS-METHODS format_dcp_id
      IMPORTING iv_year      TYPE numc4
                iv_number    TYPE i
      RETURNING VALUE(rv_id) TYPE char20.

    CLASS-METHODS build_panel_id
      IMPORTING iv_dcp_id            TYPE char20
                iv_panel_number      TYPE numc3
      RETURNING VALUE(rv_panel_id)   TYPE char30.

    CLASS-METHODS next_color_code
      RETURNING VALUE(rv_code) TYPE char20
      RAISING   zcx_cp_error.

    CLASS-METHODS next_request_id
      RETURNING VALUE(rv_id) TYPE char20
      RAISING   zcx_cp_error.

    CLASS-METHODS next_dcp_id
      RETURNING VALUE(rv_id) TYPE char20
      RAISING   zcx_cp_error.

    CLASS-METHODS next_photo_id
      RETURNING VALUE(rv_id) TYPE char20
      RAISING   zcx_cp_error.

    CLASS-METHODS next_log_id
      RETURNING VALUE(rv_id) TYPE char20
      RAISING   zcx_cp_error.

  PRIVATE SECTION.

    CLASS-METHODS get_next
      IMPORTING iv_object      TYPE nrobj
                iv_year        TYPE numc4 OPTIONAL
      RETURNING VALUE(rv_number) TYPE i
      RAISING   zcx_cp_error.

ENDCLASS.


CLASS zcl_cp_number IMPLEMENTATION.

  METHOD format_color_code.
    DATA: lv_num5 TYPE numc5.

    lv_num5 = iv_number.
    CONCATENATE 'KW' lv_num5 INTO rv_code.
  ENDMETHOD.

  METHOD format_request_id.
    DATA: lv_num4 TYPE numc4.

    lv_num4 = iv_number.
    CONCATENATE 'REQ-' iv_year '-' lv_num4 INTO rv_id.
  ENDMETHOD.

  METHOD format_dcp_id.
    DATA: lv_num4 TYPE numc4.

    lv_num4 = iv_number.
    CONCATENATE 'DCP-' iv_year '-' lv_num4 INTO rv_id.
  ENDMETHOD.

  METHOD build_panel_id.
    CONCATENATE iv_dcp_id '-' iv_panel_number INTO rv_panel_id.
  ENDMETHOD.

  METHOD get_next.
    DATA: lv_number TYPE char20,
          lv_toyear TYPE nryear.

    IF iv_year IS NOT INITIAL.
      lv_toyear = iv_year.
    ENDIF.

    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr             = '01'
        object                  = iv_object
        toyear                  = lv_toyear
      IMPORTING
        number                  = lv_number
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
      zcx_cp_error=>raise( iv_msgno = '019' ).
    ENDIF.

    rv_number = lv_number.
  ENDMETHOD.

  METHOD next_color_code.
    DATA: lv_number TYPE i.

    lv_number = get_next( iv_object = 'ZCP_COLOR' ).
    rv_code   = format_color_code( lv_number ).
  ENDMETHOD.

  METHOD next_request_id.
    DATA: lv_number TYPE i,
          lv_year   TYPE numc4.

    lv_year   = sy-datum(4).
    lv_number = get_next( iv_object = 'ZCP_REQ' iv_year = lv_year ).
    rv_id     = format_request_id( iv_year = lv_year iv_number = lv_number ).
  ENDMETHOD.

  METHOD next_dcp_id.
    DATA: lv_number TYPE i,
          lv_year   TYPE numc4.

    lv_year   = sy-datum(4).
    lv_number = get_next( iv_object = 'ZCP_DCP' iv_year = lv_year ).
    rv_id     = format_dcp_id( iv_year = lv_year iv_number = lv_number ).
  ENDMETHOD.

  METHOD next_photo_id.
    DATA: lv_number TYPE i,
          lv_num9   TYPE numc9.

    lv_number = get_next( iv_object = 'ZCP_PHOTO' ).
    lv_num9   = lv_number.
    CONCATENATE 'PH' lv_num9 INTO rv_id.
  ENDMETHOD.

  METHOD next_log_id.
    DATA: lv_number TYPE i,
          lv_num12  TYPE numc12.

    lv_number = get_next( iv_object = 'ZCP_AUDIT' ).
    lv_num12  = lv_number.
    CONCATENATE 'LOG' lv_num12 INTO rv_id.
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 5: Jalankan test lagi**

Run: SE24 &rarr; `ZCL_CP_NUMBER` &rarr; `Ctrl+Shift+F10`
Expected: PASS, 5 dari 5 test hijau, 0 error.

- [ ] **Step 6: Commit**

```bash
git add src/02_classes/zcx_cp_error.abap src/02_classes/zcl_cp_number.abap
git commit -m "feat(class): ZCX_CP_ERROR dan ZCL_CP_NUMBER dengan unit test format ID"
```

---

### Task 5: ZCL_CP_AUDIT

**Files:**
- Create: `src/02_classes/zcl_cp_audit.abap`

**Interfaces:**
- Consumes: `ZCL_CP_NUMBER=>next_log_id( )`, tabel `ZCP_AUDIT_LOG`
- Produces: `ZCL_CP_AUDIT=>log( iv_ref_type TYPE char4 iv_ref_id TYPE char20 iv_action TYPE char20 iv_user_id TYPE char20 iv_panel_number TYPE numc3 OPTIONAL iv_old TYPE char200 OPTIONAL iv_new TYPE char200 OPTIONAL iv_desc TYPE char200 OPTIONAL iv_ip TYPE char45 OPTIONAL )`

`log( )` sengaja tidak melempar exception. Kegagalan menulis jejak tidak boleh membatalkan transaksi bisnis yang sudah sah; kalau `INSERT` gagal, method diam saja. Ini keputusan sadar, bukan kelalaian.

- [ ] **Step 1: Tulis `src/02_classes/zcl_cp_audit.abap`**

```abap
CLASS zcl_cp_audit DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS: c_ref_req  TYPE char4 VALUE 'REQ',
               c_ref_dcp  TYPE char4 VALUE 'DCP',
               c_ref_user TYPE char4 VALUE 'USER',
               c_ref_auth TYPE char4 VALUE 'AUTH'.

    CONSTANTS: c_act_login      TYPE char20 VALUE 'LOGIN',
               c_act_login_fail TYPE char20 VALUE 'LOGIN_FAIL',
               c_act_create     TYPE char20 VALUE 'CREATE',
               c_act_approve    TYPE char20 VALUE 'APPROVE',
               c_act_reject     TYPE char20 VALUE 'REJECT',
               c_act_activate   TYPE char20 VALUE 'ACTIVATE',
               c_act_submit     TYPE char20 VALUE 'SUBMIT',
               c_act_undo       TYPE char20 VALUE 'UNDO',
               c_act_close      TYPE char20 VALUE 'CLOSE'.

    CLASS-METHODS log
      IMPORTING iv_ref_type     TYPE char4
                iv_ref_id       TYPE char20
                iv_action       TYPE char20
                iv_user_id      TYPE char20
                iv_panel_number TYPE numc3  OPTIONAL
                iv_old          TYPE char200 OPTIONAL
                iv_new          TYPE char200 OPTIONAL
                iv_desc         TYPE char200 OPTIONAL
                iv_ip           TYPE char45 OPTIONAL.

ENDCLASS.


CLASS zcl_cp_audit IMPLEMENTATION.

  METHOD log.
    DATA: ls_log TYPE zcp_audit_log,
          lv_id  TYPE char20.

    TRY.
        lv_id = zcl_cp_number=>next_log_id( ).
      CATCH zcx_cp_error.
        RETURN.
    ENDTRY.

    ls_log-log_id       = lv_id.
    ls_log-ref_type     = iv_ref_type.
    ls_log-ref_id       = iv_ref_id.
    ls_log-panel_number = iv_panel_number.
    ls_log-action       = iv_action.
    ls_log-old_value    = iv_old.
    ls_log-new_value    = iv_new.
    ls_log-description  = iv_desc.
    ls_log-action_by    = iv_user_id.
    ls_log-ip_address   = iv_ip.

    GET TIME STAMP FIELD ls_log-action_at.

    INSERT zcp_audit_log FROM ls_log.
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 2: Buat kelas di SE24 dan aktifkan**

Buat `ZCL_CP_AUDIT` di SE24, paste isi file, aktifkan.
Expected: aktivasi tanpa error sintaks.

- [ ] **Step 3: Verifikasi menulis baris**

Buat report sementara di SE38 (`ZCP_TMP_AUDIT`, jangan disimpan ke repo):

```abap
REPORT zcp_tmp_audit.

zcl_cp_audit=>log( iv_ref_type = 'DCP'
                   iv_ref_id   = 'DCP-2026-0001'
                   iv_action   = 'CREATE'
                   iv_user_id  = 'ARYA'
                   iv_desc     = 'Uji tulis audit' ).
COMMIT WORK.
WRITE 'selesai'.
```

Run: SE38 &rarr; `ZCP_TMP_AUDIT` &rarr; F8, lalu SE16N &rarr; `ZCP_AUDIT_LOG`.
Expected: satu baris dengan `LOG_ID` berformat `LOG000000000001`, `ACTION_BY` = `ARYA`, dan `ACTION_AT` terisi. Perhatikan `ACTION_BY` berisi `ARYA`, bukan `auto_email` &mdash; ini yang membuktikan pola identitas benar. Hapus report sementara setelah verifikasi.

- [ ] **Step 4: Commit**

```bash
git add src/02_classes/zcl_cp_audit.abap
git commit -m "feat(class): ZCL_CP_AUDIT penulis jejak aksi"
```

---

### Task 6: ZCL_CP_AUTH

**Files:**
- Create: `src/02_classes/zcl_cp_auth.abap`

**Interfaces:**
- Consumes: tabel `ZCP_USER`, `ZCL_CP_AUDIT=>log( )`, `ZCX_CP_ERROR`
- Produces:
  - `ZCL_CP_AUTH=>hash_password( iv_user_id TYPE char20 iv_password TYPE string ) RETURNING VALUE(rv_hash) TYPE char64`
  - `ZCL_CP_AUTH=>login( iv_user_id TYPE char20 iv_password TYPE string iv_ip TYPE char45 ) RETURNING VALUE(rs_session) TYPE ty_session RAISING zcx_cp_error`
  - `ZCL_CP_AUTH=>save_session( iv_session_id TYPE string is_session TYPE ty_session )`
  - `ZCL_CP_AUTH=>read_session( iv_session_id TYPE string ) RETURNING VALUE(rs_session) TYPE ty_session RAISING zcx_cp_error`
  - `ZCL_CP_AUTH=>clear_session( iv_session_id TYPE string )`
  - `ZCL_CP_AUTH=>require_role( iv_session_id TYPE string iv_roles TYPE string ) RETURNING VALUE(rs_session) TYPE ty_session RAISING zcx_cp_error`
  - Tipe publik `ty_session`: `user_id TYPE char20`, `full_name TYPE char60`, `role TYPE char10`, `buyer_id TYPE char10`

Hash diberi garam dengan `USER_ID` (`USER_ID|password`) supaya dua user berpassword sama tidak menghasilkan hash identik. Konsekuensinya `USER_ID` tidak boleh diubah setelah dibuat &mdash; itu primary key, jadi memang tidak bisa.

- [ ] **Step 1: Tulis test class untuk hash lebih dulu**

Bagian Local Test Classes pada `ZCL_CP_AUTH`. Hanya menguji `hash_password` karena method itu satu-satunya yang tidak menyentuh database maupun runtime BSP.

```abap
*"* LOCAL TEST CLASSES - paste ke tab "Local Test Classes" di SE24

CLASS ltc_auth DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS hash_is_deterministic FOR TESTING.
    METHODS hash_differs_per_user FOR TESTING.
    METHODS hash_differs_per_password FOR TESTING.
    METHODS hash_is_not_plaintext FOR TESTING.

ENDCLASS.

CLASS ltc_auth IMPLEMENTATION.

  METHOD hash_is_deterministic.
    DATA: lv_a TYPE char64,
          lv_b TYPE char64.

    lv_a = zcl_cp_auth=>hash_password( iv_user_id = 'ARYA' iv_password = 'rahasia123' ).
    lv_b = zcl_cp_auth=>hash_password( iv_user_id = 'ARYA' iv_password = 'rahasia123' ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_a
      exp = lv_b
      msg = 'Input sama harus menghasilkan hash sama' ).
  ENDMETHOD.

  METHOD hash_differs_per_user.
    DATA: lv_a TYPE char64,
          lv_b TYPE char64.

    lv_a = zcl_cp_auth=>hash_password( iv_user_id = 'ARYA' iv_password = 'rahasia123' ).
    lv_b = zcl_cp_auth=>hash_password( iv_user_id = 'YOGI' iv_password = 'rahasia123' ).

    cl_abap_unit_assert=>assert_differs(
      act = lv_a
      exp = lv_b
      msg = 'Password sama pada user berbeda tidak boleh menghasilkan hash sama' ).
  ENDMETHOD.

  METHOD hash_differs_per_password.
    DATA: lv_a TYPE char64,
          lv_b TYPE char64.

    lv_a = zcl_cp_auth=>hash_password( iv_user_id = 'ARYA' iv_password = 'rahasia123' ).
    lv_b = zcl_cp_auth=>hash_password( iv_user_id = 'ARYA' iv_password = 'rahasia124' ).

    cl_abap_unit_assert=>assert_differs(
      act = lv_a
      exp = lv_b
      msg = 'Password berbeda harus menghasilkan hash berbeda' ).
  ENDMETHOD.

  METHOD hash_is_not_plaintext.
    DATA: lv_hash TYPE char64,
          lv_pos  TYPE i.

    lv_hash = zcl_cp_auth=>hash_password( iv_user_id = 'ARYA' iv_password = 'rahasia123' ).

    FIND 'rahasia123' IN lv_hash MATCH OFFSET lv_pos.

    cl_abap_unit_assert=>assert_subrc(
      exp = 4
      msg = 'Hash tidak boleh mengandung password apa adanya' ).
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 2: Buat kelas dengan method kosong dan jalankan test**

Buat `ZCL_CP_AUTH` di SE24 dengan seluruh signature dari blok Interfaces, semua body kosong, paste test class, aktifkan.
Run: SE24 &rarr; `ZCL_CP_AUTH` &rarr; `Ctrl+Shift+F10`
Expected: FAIL. `hash_differs_per_user` dan `hash_differs_per_password` gagal karena keduanya mengembalikan nilai kosong yang sama.

- [ ] **Step 3: Tulis implementasi ZCL_CP_AUTH**

```abap
CLASS zcl_cp_auth DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_session,
             user_id   TYPE char20,
             full_name TYPE char60,
             role      TYPE char10,
             buyer_id  TYPE char10,
           END OF ty_session.

    CONSTANTS: c_role_sales TYPE char10 VALUE 'SALES',
               c_role_admin TYPE char10 VALUE 'ADMIN',
               c_role_it    TYPE char10 VALUE 'IT'.

    CLASS-METHODS hash_password
      IMPORTING iv_user_id     TYPE char20
                iv_password    TYPE string
      RETURNING VALUE(rv_hash) TYPE char64.

    CLASS-METHODS login
      IMPORTING iv_user_id        TYPE char20
                iv_password       TYPE string
                iv_ip             TYPE char45 OPTIONAL
      RETURNING VALUE(rs_session) TYPE ty_session
      RAISING   zcx_cp_error.

    CLASS-METHODS save_session
      IMPORTING iv_session_id TYPE string
                is_session    TYPE ty_session.

    CLASS-METHODS read_session
      IMPORTING iv_session_id     TYPE string
      RETURNING VALUE(rs_session) TYPE ty_session
      RAISING   zcx_cp_error.

    CLASS-METHODS clear_session
      IMPORTING iv_session_id TYPE string.

    CLASS-METHODS require_role
      IMPORTING iv_session_id     TYPE string
                iv_roles          TYPE string
      RETURNING VALUE(rs_session) TYPE ty_session
      RAISING   zcx_cp_error.

  PRIVATE SECTION.

    CONSTANTS: c_cookie_name TYPE string VALUE 'CP_SESSION',
               c_app_name    TYPE string VALUE 'zbsp_color_panel',
               c_app_ns      TYPE string VALUE 'sap',
               c_data_name   TYPE string VALUE 'SESSION',
               c_expiry_sec  TYPE i      VALUE 28800.

ENDCLASS.


CLASS zcl_cp_auth IMPLEMENTATION.

  METHOD hash_password.
    DATA: lv_input      TYPE string,
          lv_hashstring TYPE string.

    CONCATENATE iv_user_id '|' iv_password INTO lv_input.

    CALL METHOD cl_abap_message_digest=>calculate_hash_for_char
      EXPORTING
        if_algorithm  = 'SHA256'
        if_data       = lv_input
      IMPORTING
        ef_hashstring = lv_hashstring.

    rv_hash = lv_hashstring.
  ENDMETHOD.

  METHOD login.
    DATA: ls_user TYPE zcp_user,
          lv_hash TYPE char64,
          lv_now  TYPE timestamp,
          lv_uid  TYPE char20.

    lv_uid = iv_user_id.
    TRANSLATE lv_uid TO UPPER CASE.

    SELECT SINGLE * INTO ls_user FROM zcp_user
      WHERE user_id = lv_uid.

    IF sy-subrc <> 0.
      zcl_cp_audit=>log( iv_ref_type = 'AUTH'
                         iv_ref_id   = lv_uid
                         iv_action   = 'LOGIN_FAIL'
                         iv_user_id  = lv_uid
                         iv_desc     = 'User tidak ditemukan'
                         iv_ip       = iv_ip ).
      COMMIT WORK.
      zcx_cp_error=>raise( iv_msgno = '006' ).
    ENDIF.

    IF ls_user-is_active <> 'X'.
      zcl_cp_audit=>log( iv_ref_type = 'AUTH'
                         iv_ref_id   = lv_uid
                         iv_action   = 'LOGIN_FAIL'
                         iv_user_id  = lv_uid
                         iv_desc     = 'User non-aktif'
                         iv_ip       = iv_ip ).
      COMMIT WORK.
      zcx_cp_error=>raise( iv_msgno = '006' ).
    ENDIF.

    lv_hash = hash_password( iv_user_id  = lv_uid
                             iv_password = iv_password ).

    IF lv_hash <> ls_user-password_hash.
      zcl_cp_audit=>log( iv_ref_type = 'AUTH'
                         iv_ref_id   = lv_uid
                         iv_action   = 'LOGIN_FAIL'
                         iv_user_id  = lv_uid
                         iv_desc     = 'Password salah'
                         iv_ip       = iv_ip ).
      COMMIT WORK.
      zcx_cp_error=>raise( iv_msgno = '006' ).
    ENDIF.

    GET TIME STAMP FIELD lv_now.
    UPDATE zcp_user SET last_login = lv_now WHERE user_id = lv_uid.

    zcl_cp_audit=>log( iv_ref_type = 'AUTH'
                       iv_ref_id   = lv_uid
                       iv_action   = 'LOGIN'
                       iv_user_id  = lv_uid
                       iv_ip       = iv_ip ).
    COMMIT WORK.

    rs_session-user_id   = ls_user-user_id.
    rs_session-full_name = ls_user-full_name.
    rs_session-role      = ls_user-role.
    rs_session-buyer_id  = ls_user-buyer_id.
  ENDMETHOD.

  METHOD save_session.
    CALL METHOD cl_bsp_server_side_cookie=>set_server_cookie
      EXPORTING
        name                  = c_cookie_name
        application_name      = c_app_name
        application_namespace = c_app_ns
        username              = is_session-user_id
        session_id            = iv_session_id
        data_name             = c_data_name
        data_value            = is_session
        expiry_time_rel       = c_expiry_sec.
  ENDMETHOD.

  METHOD read_session.
    DATA: ls_session TYPE ty_session.

    CALL METHOD cl_bsp_server_side_cookie=>get_server_cookie
      EXPORTING
        name                  = c_cookie_name
        application_name      = c_app_name
        application_namespace = c_app_ns
        session_id            = iv_session_id
        data_name             = c_data_name
      CHANGING
        data_value            = ls_session.

    IF ls_session-user_id IS INITIAL.
      zcx_cp_error=>raise( iv_msgno = '007' ).
    ENDIF.

    rs_session = ls_session.
  ENDMETHOD.

  METHOD clear_session.
    CALL METHOD cl_bsp_server_side_cookie=>delete_server_cookie
      EXPORTING
        name                  = c_cookie_name
        application_name      = c_app_name
        application_namespace = c_app_ns
        session_id            = iv_session_id
        data_name             = c_data_name.
  ENDMETHOD.

  METHOD require_role.
    DATA: ls_session TYPE ty_session,
          lv_pos     TYPE i,
          lv_role    TYPE string.

    ls_session = read_session( iv_session_id ).

    lv_role = ls_session-role.
    FIND lv_role IN iv_roles MATCH OFFSET lv_pos.

    IF sy-subrc <> 0.
      zcx_cp_error=>raise( iv_msgno = '008' ).
    ENDIF.

    rs_session = ls_session.
  ENDMETHOD.

ENDCLASS.
```

`require_role` menerima daftar role sebagai satu string, contoh `'SALES,ADMIN'`. Karena `ROLE` memakai domain fixed-value, tidak ada nilai yang menjadi substring nilai lain, sehingga pencarian substring aman.

- [ ] **Step 4: Jalankan test lagi**

Run: SE24 &rarr; `ZCL_CP_AUTH` &rarr; `Ctrl+Shift+F10`
Expected: PASS, 4 dari 4 test hijau.

- [ ] **Step 5: Buat satu user uji lewat report sementara**

Karena SM30 tidak bisa meng-hash password, user pertama harus dibuat lewat report. Buat `ZCP_TMP_USER` di SE38 (jangan disimpan ke repo):

```abap
REPORT zcp_tmp_user.

DATA: ls_user TYPE zcp_user,
      lv_now  TYPE timestamp.

GET TIME STAMP FIELD lv_now.

ls_user-user_id       = 'ARYA'.
ls_user-full_name     = 'Arya - IT'.
ls_user-password_hash = zcl_cp_auth=>hash_password( iv_user_id  = 'ARYA'
                                                    iv_password = 'Init1234' ).
ls_user-role          = 'IT'.
ls_user-is_active     = 'X'.
ls_user-created_by    = 'SYSTEM'.
ls_user-created_at    = lv_now.

MODIFY zcp_user FROM ls_user.
COMMIT WORK.
WRITE 'user ARYA dibuat'.
```

Run: SE38 &rarr; `ZCP_TMP_USER` &rarr; F8, lalu SE16N &rarr; `ZCP_USER`.
Expected: satu baris `ARYA` dengan `PASSWORD_HASH` berisi string base64 sepanjang 44 karakter, bukan `Init1234`. Hapus report sementara setelah verifikasi.

- [ ] **Step 6: Commit**

```bash
git add src/02_classes/zcl_cp_auth.abap
git commit -m "feat(class): ZCL_CP_AUTH hash SHA256, login, session, guard role"
```

---

### Task 7: ZCL_CP_SO_READER dan Report Uji

**Files:**
- Create: `src/02_classes/zcl_cp_so_reader.abap`
- Create: `src/03_reports/zcp_test_so_reader.abap`

**Interfaces:**
- Consumes: `VBAK`, `VBAP`, `MARA`, `MAKT`, `ZCP_COLOR_CODE`, `ZCP_SO_IMPORT`, `ZCX_CP_ERROR`
- Produces:
  - Tipe publik `ty_so_item`: `so_item TYPE posnr`, `matnr TYPE matnr`, `maktx TYPE maktx`, `menge TYPE menge_d`, `meins TYPE meins`, `eligible TYPE abap_bool`, `reason TYPE char200`
  - Tipe publik `tt_so_item TYPE STANDARD TABLE OF ty_so_item WITH DEFAULT KEY`
  - `ZCL_CP_SO_READER=>read_so( iv_so_number TYPE vbeln ) RETURNING VALUE(rt_items) TYPE tt_so_item RAISING zcx_cp_error`

Method mengembalikan **seluruh** item SO, termasuk yang tidak layak, beserta alasannya. Item tidak layak sengaja tidak disembunyikan: Sales perlu bisa membedakan "SO salah ketik" dari "material ini memang sudah pernah dibuat". Exception hanya dilempar bila SO sama sekali tidak ada.

- [ ] **Step 1: Tulis `src/02_classes/zcl_cp_so_reader.abap`**

```abap
CLASS zcl_cp_so_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_so_item,
             so_item  TYPE posnr,
             matnr    TYPE matnr,
             maktx    TYPE maktx,
             menge    TYPE menge_d,
             meins    TYPE meins,
             eligible TYPE abap_bool,
             reason   TYPE char200,
           END OF ty_so_item.

    TYPES: tt_so_item TYPE STANDARD TABLE OF ty_so_item WITH DEFAULT KEY.

    CLASS-METHODS read_so
      IMPORTING iv_so_number    TYPE vbeln
      RETURNING VALUE(rt_items) TYPE tt_so_item
      RAISING   zcx_cp_error.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_vbap,
             posnr TYPE posnr,
             matnr TYPE matnr,
             kwmeng TYPE kwmeng,
             vrkme TYPE vrkme,
           END OF ty_vbap.

    TYPES: tt_vbap TYPE STANDARD TABLE OF ty_vbap WITH DEFAULT KEY.

ENDCLASS.


CLASS zcl_cp_so_reader IMPLEMENTATION.

  METHOD read_so.
    DATA: lv_vbeln     TYPE vbeln,
          lv_exists    TYPE vbeln,
          lt_vbap      TYPE tt_vbap,
          ls_vbap      TYPE ty_vbap,
          ls_item      TYPE ty_so_item,
          lv_mtart     TYPE mtart,
          lv_maktx     TYPE maktx,
          lv_cc        TYPE char20,
          lv_dcp       TYPE char20,
          lv_so_string TYPE string.

    lv_vbeln = iv_so_number.

    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING input  = lv_vbeln
      IMPORTING output = lv_vbeln.

    SELECT SINGLE vbeln INTO lv_exists FROM vbak
      WHERE vbeln = lv_vbeln.

    IF sy-subrc <> 0.
      lv_so_string = iv_so_number.
      zcx_cp_error=>raise( iv_msgno = '001' iv_v1 = lv_so_string ).
    ENDIF.

    SELECT posnr matnr kwmeng vrkme
      INTO TABLE lt_vbap
      FROM vbap
      WHERE vbeln = lv_vbeln
      ORDER BY posnr.

    LOOP AT lt_vbap INTO ls_vbap.

      CLEAR ls_item.
      ls_item-so_item = ls_vbap-posnr.
      ls_item-matnr   = ls_vbap-matnr.
      ls_item-menge   = ls_vbap-kwmeng.
      ls_item-meins   = ls_vbap-vrkme.

      CLEAR lv_maktx.
      SELECT SINGLE maktx INTO lv_maktx FROM makt
        WHERE matnr = ls_vbap-matnr AND spras = sy-langu.
      ls_item-maktx = lv_maktx.

      CLEAR lv_mtart.
      SELECT SINGLE mtart INTO lv_mtart FROM mara
        WHERE matnr = ls_vbap-matnr.

      IF lv_mtart <> 'FERT'.
        ls_item-eligible = abap_false.
        ls_item-reason   = 'Material bukan tipe FERT'.
        APPEND ls_item TO rt_items.
        CONTINUE.
      ENDIF.

      CLEAR lv_cc.
      SELECT SINGLE color_code INTO lv_cc FROM zcp_color_code
        WHERE matnr = ls_vbap-matnr.

      IF sy-subrc = 0.
        ls_item-eligible = abap_false.
        CONCATENATE 'Sudah memiliki Color Code' lv_cc
          INTO ls_item-reason SEPARATED BY space.
        APPEND ls_item TO rt_items.
        CONTINUE.
      ENDIF.

      CLEAR lv_dcp.
      SELECT SINGLE dcp_id INTO lv_dcp FROM zcp_so_import
        WHERE so_number = lv_vbeln AND so_item = ls_vbap-posnr.

      IF sy-subrc = 0.
        ls_item-eligible = abap_false.
        CONCATENATE 'SO item sudah diproses menjadi' lv_dcp
          INTO ls_item-reason SEPARATED BY space.
        APPEND ls_item TO rt_items.
        CONTINUE.
      ENDIF.

      ls_item-eligible = abap_true.
      ls_item-reason   = 'Layak dijadikan DCP'.
      APPEND ls_item TO rt_items.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
```

Perhatikan urutan pemeriksaan: tipe material, lalu Color Code, lalu kunci SO import. Urutan ini menghasilkan alasan yang paling spesifik lebih dulu &mdash; kalau material bukan FERT, tidak ada gunanya memberitahu bahwa SO item-nya belum dipakai.

- [ ] **Step 2: Tulis `src/03_reports/zcp_test_so_reader.abap`**

```abap
*&---------------------------------------------------------------------*
*& Report ZCP_TEST_SO_READER
*& Harness uji untuk ZCL_CP_SO_READER tanpa membuka browser.
*& Masukkan nomor SO nyata di sandbox, lihat hasil saring kelayakannya.
*&---------------------------------------------------------------------*
REPORT zcp_test_so_reader.

PARAMETERS: p_vbeln TYPE vbeln OBLIGATORY.

DATA: lt_items TYPE zcl_cp_so_reader=>tt_so_item,
      ls_item  TYPE zcl_cp_so_reader=>ty_so_item,
      lo_error TYPE REF TO zcx_cp_error,
      lv_text  TYPE string,
      lv_ok    TYPE i,
      lv_no    TYPE i.

START-OF-SELECTION.

  TRY.
      lt_items = zcl_cp_so_reader=>read_so( p_vbeln ).
    CATCH zcx_cp_error INTO lo_error.
      lv_text = lo_error->get_text_message( ).
      WRITE: / 'GAGAL:', lv_text.
      RETURN.
  ENDTRY.

  IF lt_items IS INITIAL.
    WRITE: / 'SO ditemukan tetapi tidak memiliki item.'.
    RETURN.
  ENDIF.

  WRITE: / 'Item', 12 'Material', 32 'Qty', 45 'UoM', 52 'Layak', 60 'Alasan'.
  ULINE.

  LOOP AT lt_items INTO ls_item.
    WRITE: /  ls_item-so_item,
           12 ls_item-matnr,
           32 ls_item-menge,
           45 ls_item-meins,
           52 ls_item-eligible,
           60 ls_item-reason.

    IF ls_item-eligible = abap_true.
      lv_ok = lv_ok + 1.
    ELSE.
      lv_no = lv_no + 1.
    ENDIF.
  ENDLOOP.

  ULINE.
  WRITE: / 'Layak  :', lv_ok.
  WRITE: / 'Tidak  :', lv_no.
```

- [ ] **Step 3: Buat kelas dan report di sistem, lalu uji SO yang tidak ada**

Buat `ZCL_CP_SO_READER` di SE24 dan `ZCP_TEST_SO_READER` di SE38, aktifkan keduanya.
Run: SE38 &rarr; `ZCP_TEST_SO_READER` &rarr; isi `P_VBELN` = `9999999999` &rarr; F8
Expected: `GAGAL: SO 9999999999 tidak ditemukan`. Ini membuktikan pesan error nomor 001 tersambung ke message class dengan benar.

- [ ] **Step 4: Uji SO color panel yang nyata**

Run: SE38 &rarr; `ZCP_TEST_SO_READER` &rarr; isi nomor SO color panel nyata dari sandbox &rarr; F8
Expected: daftar item SO dengan kolom Material, Qty, UoM terisi sesuai isi VBAP, kolom Layak berisi `X` untuk material FERT yang belum punya Color Code, dan ringkasan jumlah Layak/Tidak di bawah. Bandingkan langsung dengan VA03 untuk SO yang sama &mdash; jumlah item dan qty harus persis sama.

- [ ] **Step 5: Commit**

```bash
git add src/02_classes/zcl_cp_so_reader.abap src/03_reports/zcp_test_so_reader.abap
git commit -m "feat(class): ZCL_CP_SO_READER baca VBAK/VBAP dan saring kelayakan material"
```

---

### Task 8: ZCL_CP_DCP &mdash; Logic Murni (State Machine dan Perhitungan Tanggal)

**Files:**
- Create: `src/02_classes/zcl_cp_dcp.abap` (bagian pertama: hanya method tanpa akses database)

**Interfaces:**
- Consumes: tidak ada (sengaja &mdash; seluruh method di task ini murni)
- Produces:
  - Konstanta status panel: `c_st_na`, `c_st_ak`, `c_st_sb`, `c_st_ap`, `c_st_rj`, `c_st_ob` (semua `TYPE char2`)
  - Tipe `tt_status TYPE STANDARD TABLE OF char2 WITH DEFAULT KEY`
  - `ZCL_CP_DCP=>is_valid_transition( iv_from TYPE char2 iv_to TYPE char2 ) RETURNING VALUE(rv_ok) TYPE abap_bool`
  - `ZCL_CP_DCP=>can_close( it_status TYPE tt_status ) RETURNING VALUE(rv_ok) TYPE abap_bool`
  - `ZCL_CP_DCP=>add_months( iv_date TYPE datum iv_months TYPE i ) RETURNING VALUE(rv_date) TYPE datum`
  - `ZCL_CP_DCP=>calc_expire_date( iv_mfg_date TYPE datum ) RETURNING VALUE(rv_date) TYPE datum`
  - `ZCL_CP_DCP=>calc_reminder_date( iv_created TYPE datum ) RETURNING VALUE(rv_date) TYPE datum`

Task ini dipisah dari Task 9 karena inilah satu-satunya bagian siklus DCP yang bisa diuji otomatis sungguhan. Semua aturan transisi status dan perhitungan tanggal tinggal di sini, tanpa satu pun `SELECT`, sehingga bug di aturan bisnis tertangkap ABAP Unit dan bukan oleh user di produksi.

- [ ] **Step 1: Tulis test class lebih dulu**

Bagian Local Test Classes pada `ZCL_CP_DCP`.

```abap
*"* LOCAL TEST CLASSES - paste ke tab "Local Test Classes" di SE24

CLASS ltc_dcp_logic DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS activate_from_na_allowed FOR TESTING.
    METHODS submit_skipping_activation_blocked FOR TESTING.
    METHODS approve_from_submitted_allowed FOR TESTING.
    METHODS undo_from_approved_allowed FOR TESTING.
    METHODS undo_from_rejected_allowed FOR TESTING.
    METHODS obsolete_from_active_allowed FOR TESTING.
    METHODS approve_from_obsolete_blocked FOR TESTING.

    METHODS close_needs_one_approved FOR TESTING.
    METHODS close_blocked_without_approved FOR TESTING.
    METHODS close_blocked_when_empty FOR TESTING.

    METHODS expire_adds_one_year FOR TESTING.
    METHODS expire_clamps_leap_day FOR TESTING.
    METHODS reminder_adds_two_months FOR TESTING.
    METHODS reminder_clamps_short_month FOR TESTING.
    METHODS reminder_crosses_year FOR TESTING.

ENDCLASS.

CLASS ltc_dcp_logic IMPLEMENTATION.

  METHOD activate_from_na_allowed.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>is_valid_transition( iv_from = 'NA' iv_to = 'AK' )
      exp = abap_true
      msg = 'Panel non-aktif harus bisa diaktifkan' ).
  ENDMETHOD.

  METHOD submit_skipping_activation_blocked.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>is_valid_transition( iv_from = 'NA' iv_to = 'SB' )
      exp = abap_false
      msg = 'Panel polos tidak boleh langsung submit tanpa diaktifkan' ).
  ENDMETHOD.

  METHOD approve_from_submitted_allowed.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>is_valid_transition( iv_from = 'SB' iv_to = 'AP' )
      exp = abap_true
      msg = 'Panel submitted harus bisa di-approve' ).
  ENDMETHOD.

  METHOD undo_from_approved_allowed.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>is_valid_transition( iv_from = 'AP' iv_to = 'SB' )
      exp = abap_true
      msg = 'Undo mengembalikan panel approved ke submitted' ).
  ENDMETHOD.

  METHOD undo_from_rejected_allowed.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>is_valid_transition( iv_from = 'RJ' iv_to = 'SB' )
      exp = abap_true
      msg = 'Undo mengembalikan panel rejected ke submitted' ).
  ENDMETHOD.

  METHOD obsolete_from_active_allowed.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>is_valid_transition( iv_from = 'AK' iv_to = 'OB' )
      exp = abap_true
      msg = 'Panel aktif menjadi obsolete saat header di-close' ).
  ENDMETHOD.

  METHOD approve_from_obsolete_blocked.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>is_valid_transition( iv_from = 'OB' iv_to = 'AP' )
      exp = abap_false
      msg = 'Panel obsolete tidak boleh dihidupkan kembali' ).
  ENDMETHOD.

  METHOD close_needs_one_approved.
    DATA: lt_status TYPE zcl_cp_dcp=>tt_status,
          lv_status TYPE char2.

    lv_status = 'NA'. APPEND lv_status TO lt_status.
    lv_status = 'AK'. APPEND lv_status TO lt_status.
    lv_status = 'AP'. APPEND lv_status TO lt_status.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>can_close( lt_status )
      exp = abap_true
      msg = 'Satu panel approved sudah cukup untuk close DCP' ).
  ENDMETHOD.

  METHOD close_blocked_without_approved.
    DATA: lt_status TYPE zcl_cp_dcp=>tt_status,
          lv_status TYPE char2.

    lv_status = 'NA'. APPEND lv_status TO lt_status.
    lv_status = 'AK'. APPEND lv_status TO lt_status.
    lv_status = 'SB'. APPEND lv_status TO lt_status.
    lv_status = 'RJ'. APPEND lv_status TO lt_status.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>can_close( lt_status )
      exp = abap_false
      msg = 'Tanpa panel approved, DCP tidak boleh di-close' ).
  ENDMETHOD.

  METHOD close_blocked_when_empty.
    DATA: lt_status TYPE zcl_cp_dcp=>tt_status.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>can_close( lt_status )
      exp = abap_false
      msg = 'DCP tanpa panel sama sekali tidak boleh di-close' ).
  ENDMETHOD.

  METHOD expire_adds_one_year.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>calc_expire_date( '20260315' )
      exp = '20270315'
      msg = 'Expire adalah tanggal manufaktur plus satu tahun' ).
  ENDMETHOD.

  METHOD expire_clamps_leap_day.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>calc_expire_date( '20240229' )
      exp = '20250228'
      msg = '29 Februari harus jatuh ke 28 Februari di tahun bukan kabisat' ).
  ENDMETHOD.

  METHOD reminder_adds_two_months.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>calc_reminder_date( '20260728' )
      exp = '20260928'
      msg = 'Reminder adalah tanggal dibuat plus dua bulan' ).
  ENDMETHOD.

  METHOD reminder_clamps_short_month.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>calc_reminder_date( '20251231' )
      exp = '20260228'
      msg = '31 Desember plus dua bulan jatuh ke akhir Februari' ).
  ENDMETHOD.

  METHOD reminder_crosses_year.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_dcp=>calc_reminder_date( '20261115' )
      exp = '20270115'
      msg = 'Perhitungan bulan harus benar saat melewati pergantian tahun' ).
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 2: Buat kelas dengan method kosong dan jalankan test**

Buat `ZCL_CP_DCP` di SE24 dengan seluruh signature dari blok Interfaces, semua body kosong, paste test class, aktifkan.
Run: SE24 &rarr; `ZCL_CP_DCP` &rarr; `Ctrl+Shift+F10`
Expected: FAIL. Kelima belas test gagal; test tanggal menunjukkan nilai aktual `00000000`.

- [ ] **Step 3: Tulis implementasi logic murni**

```abap
CLASS zcl_cp_dcp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS: c_st_na TYPE char2 VALUE 'NA',
               c_st_ak TYPE char2 VALUE 'AK',
               c_st_sb TYPE char2 VALUE 'SB',
               c_st_ap TYPE char2 VALUE 'AP',
               c_st_rj TYPE char2 VALUE 'RJ',
               c_st_ob TYPE char2 VALUE 'OB'.

    CONSTANTS: c_hdr_open     TYPE char1 VALUE 'O',
               c_hdr_closed   TYPE char1 VALUE 'C',
               c_hdr_rejected TYPE char1 VALUE 'R'.

    CONSTANTS: c_expire_years   TYPE i VALUE 1,
               c_reminder_month TYPE i VALUE 2,
               c_min_photo      TYPE i VALUE 2.

    TYPES: tt_status TYPE STANDARD TABLE OF char2 WITH DEFAULT KEY.

    CLASS-METHODS is_valid_transition
      IMPORTING iv_from      TYPE char2
                iv_to        TYPE char2
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    CLASS-METHODS can_close
      IMPORTING it_status    TYPE tt_status
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    CLASS-METHODS add_months
      IMPORTING iv_date        TYPE datum
                iv_months      TYPE i
      RETURNING VALUE(rv_date) TYPE datum.

    CLASS-METHODS calc_expire_date
      IMPORTING iv_mfg_date    TYPE datum
      RETURNING VALUE(rv_date) TYPE datum.

    CLASS-METHODS calc_reminder_date
      IMPORTING iv_created     TYPE datum
      RETURNING VALUE(rv_date) TYPE datum.

  PRIVATE SECTION.

    CLASS-METHODS last_day_of_month
      IMPORTING iv_year       TYPE i
                iv_month      TYPE i
      RETURNING VALUE(rv_day) TYPE i.

ENDCLASS.


CLASS zcl_cp_dcp IMPLEMENTATION.

  METHOD is_valid_transition.
    rv_ok = abap_false.

    CASE iv_from.
      WHEN c_st_na.
        IF iv_to = c_st_ak OR iv_to = c_st_ob.
          rv_ok = abap_true.
        ENDIF.

      WHEN c_st_ak.
        IF iv_to = c_st_sb OR iv_to = c_st_ob.
          rv_ok = abap_true.
        ENDIF.

      WHEN c_st_sb.
        IF iv_to = c_st_ap OR iv_to = c_st_rj OR iv_to = c_st_ob.
          rv_ok = abap_true.
        ENDIF.

      WHEN c_st_ap.
        IF iv_to = c_st_sb.
          rv_ok = abap_true.
        ENDIF.

      WHEN c_st_rj.
        IF iv_to = c_st_sb OR iv_to = c_st_ob.
          rv_ok = abap_true.
        ENDIF.

      WHEN c_st_ob.
        rv_ok = abap_false.

      WHEN OTHERS.
        rv_ok = abap_false.
    ENDCASE.
  ENDMETHOD.

  METHOD can_close.
    DATA: lv_status TYPE char2.

    rv_ok = abap_false.

    LOOP AT it_status INTO lv_status.
      IF lv_status = c_st_ap.
        rv_ok = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD last_day_of_month.
    CASE iv_month.
      WHEN 1 OR 3 OR 5 OR 7 OR 8 OR 10 OR 12.
        rv_day = 31.
      WHEN 4 OR 6 OR 9 OR 11.
        rv_day = 30.
      WHEN 2.
        IF iv_year MOD 400 = 0.
          rv_day = 29.
        ELSEIF iv_year MOD 100 = 0.
          rv_day = 28.
        ELSEIF iv_year MOD 4 = 0.
          rv_day = 29.
        ELSE.
          rv_day = 28.
        ENDIF.
      WHEN OTHERS.
        rv_day = 30.
    ENDCASE.
  ENDMETHOD.

  METHOD add_months.
    DATA: lv_y    TYPE i,
          lv_m    TYPE i,
          lv_d    TYPE i,
          lv_last TYPE i,
          lv_cy   TYPE numc4,
          lv_cm   TYPE numc2,
          lv_cd   TYPE numc2.

    lv_y = iv_date(4).
    lv_m = iv_date+4(2).
    lv_d = iv_date+6(2).

    lv_m = lv_m + iv_months.

    WHILE lv_m > 12.
      lv_m = lv_m - 12.
      lv_y = lv_y + 1.
    ENDWHILE.

    WHILE lv_m < 1.
      lv_m = lv_m + 12.
      lv_y = lv_y - 1.
    ENDWHILE.

    lv_last = last_day_of_month( iv_year = lv_y iv_month = lv_m ).

    IF lv_d > lv_last.
      lv_d = lv_last.
    ENDIF.

    lv_cy = lv_y.
    lv_cm = lv_m.
    lv_cd = lv_d.

    CONCATENATE lv_cy lv_cm lv_cd INTO rv_date.
  ENDMETHOD.

  METHOD calc_expire_date.
    DATA: lv_months TYPE i.

    lv_months = c_expire_years * 12.
    rv_date = add_months( iv_date = iv_mfg_date iv_months = lv_months ).
  ENDMETHOD.

  METHOD calc_reminder_date.
    rv_date = add_months( iv_date = iv_created iv_months = c_reminder_month ).
  ENDMETHOD.

ENDCLASS.
```

`calc_expire_date` sengaja lewat `add_months( 12 )`, bukan sekadar menambah komponen tahun. Dengan begitu penanganan 29 Februari memakai jalur kode yang sama dengan reminder, dan hanya ada satu tempat yang perlu benar.

- [ ] **Step 4: Jalankan test lagi**

Run: SE24 &rarr; `ZCL_CP_DCP` &rarr; `Ctrl+Shift+F10`
Expected: PASS, 15 dari 15 test hijau.

- [ ] **Step 5: Commit**

```bash
git add src/02_classes/zcl_cp_dcp.abap
git commit -m "feat(class): state machine panel dan perhitungan tanggal DCP dengan 15 unit test"
```

---

### Task 9: ZCL_CP_DCP &mdash; Operasi Database

**Files:**
- Modify: `src/02_classes/zcl_cp_dcp.abap` (tambahkan method berikut ke kelas dari Task 8)

**Interfaces:**
- Consumes: `ZCL_CP_NUMBER=>next_color_code( )`, `ZCL_CP_NUMBER=>next_dcp_id( )`, `ZCL_CP_NUMBER=>build_panel_id( )`, `ZCL_CP_AUDIT=>log( )`, `ZCL_CP_PHOTO=>count_photos( )` (Task 10), method murni dari Task 8
- Produces:
  - Tipe `ty_create_input`: `request_id TYPE char20`, `so_number TYPE vbeln`, `so_item TYPE posnr`, `matnr TYPE matnr`, `maktx TYPE maktx`, `menge TYPE menge_d`, `meins TYPE meins`, `buyer_id TYPE char10`, `sales_user TYPE char20`, `user_id TYPE char20`
  - Tipe `ty_create_result`: `dcp_id TYPE char20`, `color_code TYPE char20`
  - `create_from_so_item( is_input TYPE ty_create_input ) RETURNING VALUE(rs_result) TYPE ty_create_result RAISING zcx_cp_error`
  - `activate_panel( iv_dcp_id TYPE char20 iv_panel_number TYPE numc3 iv_mfg_date TYPE datum iv_user_id TYPE char20 ) RAISING zcx_cp_error`
  - `submit_panel( iv_dcp_id iv_panel_number iv_user_id ) RAISING zcx_cp_error`
  - `approve_panel( iv_dcp_id iv_panel_number iv_user_id ) RAISING zcx_cp_error`
  - `reject_panel( iv_dcp_id iv_panel_number iv_reason TYPE char200 iv_user_id ) RAISING zcx_cp_error`
  - `undo_panel( iv_dcp_id iv_panel_number iv_user_id ) RAISING zcx_cp_error`
  - `close_header( iv_dcp_id iv_user_id ) RAISING zcx_cp_error`
  - `reject_header( iv_dcp_id iv_reason iv_user_id ) RAISING zcx_cp_error`

Tidak ada method di task ini yang memanggil `COMMIT WORK`. Pemanggil yang memutuskan batas transaksi &mdash; itulah yang membuat approve beberapa item dalam satu SO bisa dibatalkan utuh bila salah satunya gagal.

- [ ] **Step 1: Tambahkan deklarasi method ke PUBLIC SECTION**

Sisipkan setelah deklarasi `calc_reminder_date` di `ZCL_CP_DCP`:

```abap
    TYPES: BEGIN OF ty_create_input,
             request_id TYPE char20,
             so_number  TYPE vbeln,
             so_item    TYPE posnr,
             matnr      TYPE matnr,
             maktx      TYPE maktx,
             menge      TYPE menge_d,
             meins      TYPE meins,
             buyer_id   TYPE char10,
             sales_user TYPE char20,
             user_id    TYPE char20,
           END OF ty_create_input.

    TYPES: BEGIN OF ty_create_result,
             dcp_id     TYPE char20,
             color_code TYPE char20,
           END OF ty_create_result.

    CLASS-METHODS create_from_so_item
      IMPORTING is_input         TYPE ty_create_input
      RETURNING VALUE(rs_result) TYPE ty_create_result
      RAISING   zcx_cp_error.

    CLASS-METHODS activate_panel
      IMPORTING iv_dcp_id       TYPE char20
                iv_panel_number TYPE numc3
                iv_mfg_date     TYPE datum
                iv_user_id      TYPE char20
      RAISING   zcx_cp_error.

    CLASS-METHODS submit_panel
      IMPORTING iv_dcp_id       TYPE char20
                iv_panel_number TYPE numc3
                iv_user_id      TYPE char20
      RAISING   zcx_cp_error.

    CLASS-METHODS approve_panel
      IMPORTING iv_dcp_id       TYPE char20
                iv_panel_number TYPE numc3
                iv_user_id      TYPE char20
      RAISING   zcx_cp_error.

    CLASS-METHODS reject_panel
      IMPORTING iv_dcp_id       TYPE char20
                iv_panel_number TYPE numc3
                iv_reason       TYPE char200
                iv_user_id      TYPE char20
      RAISING   zcx_cp_error.

    CLASS-METHODS undo_panel
      IMPORTING iv_dcp_id       TYPE char20
                iv_panel_number TYPE numc3
                iv_user_id      TYPE char20
      RAISING   zcx_cp_error.

    CLASS-METHODS close_header
      IMPORTING iv_dcp_id  TYPE char20
                iv_user_id TYPE char20
      RAISING   zcx_cp_error.

    CLASS-METHODS reject_header
      IMPORTING iv_dcp_id  TYPE char20
                iv_reason  TYPE char200
                iv_user_id TYPE char20
      RAISING   zcx_cp_error.
```

Dan ke PRIVATE SECTION:

```abap
    CLASS-METHODS change_panel_status
      IMPORTING iv_dcp_id       TYPE char20
                iv_panel_number TYPE numc3
                iv_to           TYPE char2
                iv_user_id      TYPE char20
      RETURNING VALUE(rv_from)  TYPE char2
      RAISING   zcx_cp_error.

    CLASS-METHODS require_open_header
      IMPORTING iv_dcp_id       TYPE char20
      RETURNING VALUE(rs_hdr)   TYPE zcp_dcp_hdr
      RAISING   zcx_cp_error.
```

- [ ] **Step 2: Implementasikan pembuatan DCP dari satu SO item**

```abap
  METHOD create_from_so_item.
    DATA: ls_hdr      TYPE zcp_dcp_hdr,
          ls_item     TYPE zcp_dcp_item,
          ls_cc       TYPE zcp_color_code,
          ls_imp      TYPE zcp_so_import,
          lv_now      TYPE timestamp,
          lv_qty      TYPE i,
          lv_idx      TYPE i,
          lv_panel_no TYPE numc3,
          lv_exist_cc TYPE char20,
          lv_exist_dc TYPE char20,
          lv_matnr_s  TYPE string,
          lv_item_s   TYPE string.

    GET TIME STAMP FIELD lv_now.

    " Pemeriksaan diulang di dalam kunci pemanggil. Jeda antara Sales submit
    " dan Admin approve bisa berhari-hari, kondisinya bisa sudah berubah.
    SELECT SINGLE color_code INTO lv_exist_cc FROM zcp_color_code
      WHERE matnr = is_input-matnr.

    IF sy-subrc = 0.
      lv_matnr_s = is_input-matnr.
      zcx_cp_error=>raise( iv_msgno = '003'
                           iv_v1    = lv_matnr_s
                           iv_v2    = lv_exist_cc ).
    ENDIF.

    SELECT SINGLE dcp_id INTO lv_exist_dc FROM zcp_so_import
      WHERE so_number = is_input-so_number AND so_item = is_input-so_item.

    IF sy-subrc = 0.
      lv_item_s = is_input-so_item.
      zcx_cp_error=>raise( iv_msgno = '004'
                           iv_v1    = lv_item_s
                           iv_v2    = lv_exist_dc ).
    ENDIF.

    rs_result-color_code = zcl_cp_number=>next_color_code( ).
    rs_result-dcp_id     = zcl_cp_number=>next_dcp_id( ).

    ls_cc-color_code    = rs_result-color_code.
    ls_cc-matnr         = is_input-matnr.
    ls_cc-maktx         = is_input-maktx.
    ls_cc-buyer_id      = is_input-buyer_id.
    ls_cc-color_name    = is_input-maktx.
    ls_cc-status        = 'A'.
    ls_cc-source_dcp_id = rs_result-dcp_id.
    ls_cc-created_by    = is_input-user_id.
    ls_cc-created_at    = lv_now.
    INSERT zcp_color_code FROM ls_cc.

    IF sy-subrc <> 0.
      zcx_cp_error=>raise( iv_msgno = '019' ).
    ENDIF.

    lv_qty = is_input-menge.

    ls_hdr-dcp_id        = rs_result-dcp_id.
    ls_hdr-request_id    = is_input-request_id.
    ls_hdr-so_number     = is_input-so_number.
    ls_hdr-so_item       = is_input-so_item.
    ls_hdr-matnr         = is_input-matnr.
    ls_hdr-maktx         = is_input-maktx.
    ls_hdr-color_code    = rs_result-color_code.
    ls_hdr-buyer_id      = is_input-buyer_id.
    ls_hdr-sales_user    = is_input-sales_user.
    ls_hdr-qty_total     = lv_qty.
    ls_hdr-reminder_date = calc_reminder_date( sy-datum ).
    ls_hdr-status        = c_hdr_open.
    ls_hdr-created_by    = is_input-user_id.
    ls_hdr-created_at    = lv_now.
    INSERT zcp_dcp_hdr FROM ls_hdr.

    IF sy-subrc <> 0.
      zcx_cp_error=>raise( iv_msgno = '019' ).
    ENDIF.

    lv_idx = 1.
    WHILE lv_idx <= lv_qty.
      CLEAR ls_item.
      lv_panel_no = lv_idx.

      ls_item-dcp_id       = rs_result-dcp_id.
      ls_item-panel_number = lv_panel_no.
      ls_item-panel_id     = zcl_cp_number=>build_panel_id(
                               iv_dcp_id       = rs_result-dcp_id
                               iv_panel_number = lv_panel_no ).
      ls_item-qr_token     = cl_system_uuid=>create_uuid_c32_static( ).
      ls_item-status       = c_st_na.
      ls_item-created_at   = lv_now.
      INSERT zcp_dcp_item FROM ls_item.

      IF sy-subrc <> 0.
        zcx_cp_error=>raise( iv_msgno = '019' ).
      ENDIF.

      lv_idx = lv_idx + 1.
    ENDWHILE.

    ls_imp-so_number   = is_input-so_number.
    ls_imp-so_item     = is_input-so_item.
    ls_imp-matnr       = is_input-matnr.
    ls_imp-menge       = is_input-menge.
    ls_imp-meins       = is_input-meins.
    ls_imp-request_id  = is_input-request_id.
    ls_imp-dcp_id      = rs_result-dcp_id.
    ls_imp-color_code  = rs_result-color_code.
    ls_imp-imported_by = is_input-user_id.
    ls_imp-imported_at = lv_now.
    INSERT zcp_so_import FROM ls_imp.

    IF sy-subrc <> 0.
      zcx_cp_error=>raise( iv_msgno = '019' ).
    ENDIF.

    zcl_cp_audit=>log( iv_ref_type = 'DCP'
                       iv_ref_id   = rs_result-dcp_id
                       iv_action   = 'CREATE'
                       iv_user_id  = is_input-user_id
                       iv_new      = rs_result-color_code
                       iv_desc     = 'DCP dibuat dari SO item' ).
  ENDMETHOD.
```

- [ ] **Step 3: Implementasikan helper transisi status dan penjaga header**

```abap
  METHOD require_open_header.
    DATA: lv_id_s TYPE string.

    SELECT SINGLE * INTO rs_hdr FROM zcp_dcp_hdr
      WHERE dcp_id = iv_dcp_id.

    IF sy-subrc <> 0.
      lv_id_s = iv_dcp_id.
      zcx_cp_error=>raise( iv_msgno = '018' iv_v1 = lv_id_s ).
    ENDIF.

    IF rs_hdr-status <> c_hdr_open.
      lv_id_s = iv_dcp_id.
      zcx_cp_error=>raise( iv_msgno = '012' iv_v1 = lv_id_s ).
    ENDIF.
  ENDMETHOD.

  METHOD change_panel_status.
    DATA: lv_from    TYPE char2,
          lv_panel_s TYPE string,
          lv_from_s  TYPE string,
          lv_to_s    TYPE string.

    SELECT SINGLE status INTO lv_from FROM zcp_dcp_item
      WHERE dcp_id = iv_dcp_id AND panel_number = iv_panel_number.

    IF sy-subrc <> 0.
      lv_panel_s = iv_panel_number.
      zcx_cp_error=>raise( iv_msgno = '009'
                           iv_v1    = lv_panel_s
                           iv_v2    = '-'
                           iv_v3    = iv_to ).
    ENDIF.

    IF is_valid_transition( iv_from = lv_from iv_to = iv_to ) = abap_false.
      lv_panel_s = iv_panel_number.
      lv_from_s  = lv_from.
      lv_to_s    = iv_to.
      zcx_cp_error=>raise( iv_msgno = '009'
                           iv_v1    = lv_panel_s
                           iv_v2    = lv_from_s
                           iv_v3    = lv_to_s ).
    ENDIF.

    rv_from = lv_from.
  ENDMETHOD.
```

- [ ] **Step 4: Implementasikan aksi per panel**

```abap
  METHOD activate_panel.
    DATA: ls_hdr  TYPE zcp_dcp_hdr,
          lv_now  TYPE timestamp,
          lv_from TYPE char2.

    ls_hdr = require_open_header( iv_dcp_id ).

    IF iv_mfg_date > sy-datum.
      zcx_cp_error=>raise( iv_msgno = '013' ).
    ENDIF.

    lv_from = change_panel_status( iv_dcp_id       = iv_dcp_id
                                   iv_panel_number = iv_panel_number
                                   iv_to           = c_st_ak
                                   iv_user_id      = iv_user_id ).

    GET TIME STAMP FIELD lv_now.

    UPDATE zcp_dcp_item
      SET status       = c_st_ak
          mfg_date     = iv_mfg_date
          activated_by = iv_user_id
          activated_at = lv_now
          changed_by   = iv_user_id
          changed_at   = lv_now
      WHERE dcp_id = iv_dcp_id AND panel_number = iv_panel_number.

    " Panel pertama yang diaktifkan menentukan masa berlaku header.
    IF ls_hdr-mfg_date IS INITIAL.
      UPDATE zcp_dcp_hdr
        SET mfg_date    = iv_mfg_date
            expire_date = calc_expire_date( iv_mfg_date )
            changed_by  = iv_user_id
            changed_at  = lv_now
        WHERE dcp_id = iv_dcp_id.
    ENDIF.

    zcl_cp_audit=>log( iv_ref_type     = 'DCP'
                       iv_ref_id       = iv_dcp_id
                       iv_panel_number = iv_panel_number
                       iv_action       = 'ACTIVATE'
                       iv_user_id      = iv_user_id
                       iv_old          = lv_from
                       iv_new          = c_st_ak ).
  ENDMETHOD.

  METHOD submit_panel.
    DATA: lv_count   TYPE i,
          lv_now     TYPE timestamp,
          lv_from    TYPE char2,
          lv_panel_s TYPE string.

    require_open_header( iv_dcp_id ).

    lv_count = zcl_cp_photo=>count_photos( iv_ref_type     = 'DCP'
                                           iv_ref_id       = iv_dcp_id
                                           iv_panel_number = iv_panel_number ).

    IF lv_count < c_min_photo.
      lv_panel_s = iv_panel_number.
      zcx_cp_error=>raise( iv_msgno = '010' iv_v1 = lv_panel_s ).
    ENDIF.

    lv_from = change_panel_status( iv_dcp_id       = iv_dcp_id
                                   iv_panel_number = iv_panel_number
                                   iv_to           = c_st_sb
                                   iv_user_id      = iv_user_id ).

    GET TIME STAMP FIELD lv_now.

    UPDATE zcp_dcp_item
      SET status       = c_st_sb
          submitted_by = iv_user_id
          submitted_at = lv_now
          changed_by   = iv_user_id
          changed_at   = lv_now
      WHERE dcp_id = iv_dcp_id AND panel_number = iv_panel_number.

    zcl_cp_audit=>log( iv_ref_type     = 'DCP'
                       iv_ref_id       = iv_dcp_id
                       iv_panel_number = iv_panel_number
                       iv_action       = 'SUBMIT'
                       iv_user_id      = iv_user_id
                       iv_old          = lv_from
                       iv_new          = c_st_sb ).
  ENDMETHOD.

  METHOD approve_panel.
    DATA: lv_now  TYPE timestamp,
          lv_from TYPE char2.

    require_open_header( iv_dcp_id ).

    lv_from = change_panel_status( iv_dcp_id       = iv_dcp_id
                                   iv_panel_number = iv_panel_number
                                   iv_to           = c_st_ap
                                   iv_user_id      = iv_user_id ).

    GET TIME STAMP FIELD lv_now.

    UPDATE zcp_dcp_item
      SET status      = c_st_ap
          approved_by = iv_user_id
          approved_at = lv_now
          changed_by  = iv_user_id
          changed_at  = lv_now
      WHERE dcp_id = iv_dcp_id AND panel_number = iv_panel_number.

    zcl_cp_audit=>log( iv_ref_type     = 'DCP'
                       iv_ref_id       = iv_dcp_id
                       iv_panel_number = iv_panel_number
                       iv_action       = 'APPROVE'
                       iv_user_id      = iv_user_id
                       iv_old          = lv_from
                       iv_new          = c_st_ap ).
  ENDMETHOD.

  METHOD reject_panel.
    DATA: lv_now  TYPE timestamp,
          lv_from TYPE char2.

    require_open_header( iv_dcp_id ).

    IF iv_reason IS INITIAL.
      zcx_cp_error=>raise( iv_msgno = '016' ).
    ENDIF.

    lv_from = change_panel_status( iv_dcp_id       = iv_dcp_id
                                   iv_panel_number = iv_panel_number
                                   iv_to           = c_st_rj
                                   iv_user_id      = iv_user_id ).

    GET TIME STAMP FIELD lv_now.

    UPDATE zcp_dcp_item
      SET status        = c_st_rj
          rejected_by   = iv_user_id
          rejected_at   = lv_now
          reject_reason = iv_reason
          changed_by    = iv_user_id
          changed_at    = lv_now
      WHERE dcp_id = iv_dcp_id AND panel_number = iv_panel_number.

    zcl_cp_audit=>log( iv_ref_type     = 'DCP'
                       iv_ref_id       = iv_dcp_id
                       iv_panel_number = iv_panel_number
                       iv_action       = 'REJECT'
                       iv_user_id      = iv_user_id
                       iv_old          = lv_from
                       iv_new          = c_st_rj
                       iv_desc         = iv_reason ).
  ENDMETHOD.

  METHOD undo_panel.
    DATA: lv_now   TYPE timestamp,
          lv_from  TYPE char2,
          lv_count TYPE i.

    " require_open_header melempar pesan 012 bila header sudah di-close.
    " Panel AP yang sudah di-close mengalir ke MCP di sub-proyek 2;
    " menariknya kembali akan merusak data hilir.
    require_open_header( iv_dcp_id ).

    lv_from = change_panel_status( iv_dcp_id       = iv_dcp_id
                                   iv_panel_number = iv_panel_number
                                   iv_to           = c_st_sb
                                   iv_user_id      = iv_user_id ).

    SELECT SINGLE undo_count INTO lv_count FROM zcp_dcp_item
      WHERE dcp_id = iv_dcp_id AND panel_number = iv_panel_number.

    lv_count = lv_count + 1.

    GET TIME STAMP FIELD lv_now.

    UPDATE zcp_dcp_item
      SET status        = c_st_sb
          undo_count    = lv_count
          approved_by   = ''
          approved_at   = '00000000000000'
          rejected_by   = ''
          rejected_at   = '00000000000000'
          reject_reason = ''
          changed_by    = iv_user_id
          changed_at    = lv_now
      WHERE dcp_id = iv_dcp_id AND panel_number = iv_panel_number.

    zcl_cp_audit=>log( iv_ref_type     = 'DCP'
                       iv_ref_id       = iv_dcp_id
                       iv_panel_number = iv_panel_number
                       iv_action       = 'UNDO'
                       iv_user_id      = iv_user_id
                       iv_old          = lv_from
                       iv_new          = c_st_sb ).
  ENDMETHOD.
```

- [ ] **Step 5: Implementasikan close dan reject header**

```abap
  METHOD close_header.
    DATA: lt_status TYPE tt_status,
          lv_now    TYPE timestamp,
          lv_id_s   TYPE string.

    require_open_header( iv_dcp_id ).

    SELECT status INTO TABLE lt_status FROM zcp_dcp_item
      WHERE dcp_id = iv_dcp_id.

    IF can_close( lt_status ) = abap_false.
      lv_id_s = iv_dcp_id.
      zcx_cp_error=>raise( iv_msgno = '011' iv_v1 = lv_id_s ).
    ENDIF.

    GET TIME STAMP FIELD lv_now.

    " Semua panel selain approved menjadi obsolete.
    UPDATE zcp_dcp_item
      SET status     = c_st_ob
          changed_by = iv_user_id
          changed_at = lv_now
      WHERE dcp_id = iv_dcp_id AND status <> c_st_ap.

    UPDATE zcp_dcp_hdr
      SET status     = c_hdr_closed
          closed_by  = iv_user_id
          closed_at  = lv_now
          changed_by = iv_user_id
          changed_at = lv_now
      WHERE dcp_id = iv_dcp_id.

    zcl_cp_audit=>log( iv_ref_type = 'DCP'
                       iv_ref_id   = iv_dcp_id
                       iv_action   = 'CLOSE'
                       iv_user_id  = iv_user_id
                       iv_old      = 'O'
                       iv_new      = 'C' ).
  ENDMETHOD.

  METHOD reject_header.
    DATA: lv_now TYPE timestamp.

    require_open_header( iv_dcp_id ).

    IF iv_reason IS INITIAL.
      zcx_cp_error=>raise( iv_msgno = '016' ).
    ENDIF.

    GET TIME STAMP FIELD lv_now.

    UPDATE zcp_dcp_item
      SET status     = c_st_ob
          changed_by = iv_user_id
          changed_at = lv_now
      WHERE dcp_id = iv_dcp_id.

    UPDATE zcp_dcp_hdr
      SET status       = c_hdr_rejected
          close_reason = iv_reason
          closed_by    = iv_user_id
          closed_at    = lv_now
          changed_by   = iv_user_id
          changed_at   = lv_now
      WHERE dcp_id = iv_dcp_id.

    zcl_cp_audit=>log( iv_ref_type = 'DCP'
                       iv_ref_id   = iv_dcp_id
                       iv_action   = 'REJECT'
                       iv_user_id  = iv_user_id
                       iv_old      = 'O'
                       iv_new      = 'R'
                       iv_desc     = iv_reason ).
  ENDMETHOD.
```

- [ ] **Step 6: Aktifkan dan pastikan unit test Task 8 masih hijau**

Aktifkan `ZCL_CP_DCP` di SE24. Kelas ini sekarang memanggil `ZCL_CP_PHOTO` yang belum ada, jadi Task 10 harus sudah dibuat lebih dulu, atau buat `ZCL_CP_PHOTO` sebagai kelas kosong dengan method `count_photos` yang mengembalikan `0` supaya aktivasi lolos, lalu isi di Task 10.
Run: SE24 &rarr; `ZCL_CP_DCP` &rarr; `Ctrl+Shift+F10`
Expected: PASS, 15 dari 15 test dari Task 8 tetap hijau. Penambahan method database tidak boleh mengubah perilaku logic murni.

- [ ] **Step 7: Commit**

```bash
git add src/02_classes/zcl_cp_dcp.abap
git commit -m "feat(class): operasi database siklus DCP - create, aktivasi, submit, approve, reject, undo, close"
```

---

### Task 10: ZCL_CP_PHOTO

**Files:**
- Create: `src/02_classes/zcl_cp_photo.abap`

**Interfaces:**
- Consumes: `ZCL_CP_NUMBER=>next_photo_id( )`, tabel `ZCP_PHOTO`, `ZCX_CP_ERROR`
- Produces:
  - `ZCL_CP_PHOTO=>is_allowed_mime( iv_mime TYPE string ) RETURNING VALUE(rv_ok) TYPE abap_bool`
  - `ZCL_CP_PHOTO=>upload( iv_ref_type TYPE char4 iv_ref_id TYPE char20 iv_panel_number TYPE numc3 iv_file_name TYPE string iv_mime_type TYPE string iv_data TYPE xstring iv_user_id TYPE char20 ) RETURNING VALUE(rv_photo_id) TYPE char20 RAISING zcx_cp_error`
  - `ZCL_CP_PHOTO=>count_photos( iv_ref_type iv_ref_id iv_panel_number ) RETURNING VALUE(rv_count) TYPE i`
  - `ZCL_CP_PHOTO=>delete_panel_photos( iv_ref_type iv_ref_id iv_panel_number )`
  - Konstanta `c_max_size TYPE i VALUE 2097152`

Kelas ini adalah satu-satunya tempat yang tahu bagaimana foto disimpan. Di sub-proyek 4 isinya diganti memanggil BAPI DMS; kolom `DMS_*` sudah ada dan pemanggil tidak perlu berubah sama sekali.

- [ ] **Step 1: Tulis test class untuk validasi MIME**

```abap
*"* LOCAL TEST CLASSES - paste ke tab "Local Test Classes" di SE24

CLASS ltc_photo DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS jpeg_allowed FOR TESTING.
    METHODS png_allowed FOR TESTING.
    METHODS pdf_rejected FOR TESTING.
    METHODS empty_rejected FOR TESTING.

ENDCLASS.

CLASS ltc_photo IMPLEMENTATION.

  METHOD jpeg_allowed.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_photo=>is_allowed_mime( 'image/jpeg' )
      exp = abap_true
      msg = 'JPEG harus diizinkan' ).
  ENDMETHOD.

  METHOD png_allowed.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_photo=>is_allowed_mime( 'image/png' )
      exp = abap_true
      msg = 'PNG harus diizinkan' ).
  ENDMETHOD.

  METHOD pdf_rejected.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_photo=>is_allowed_mime( 'application/pdf' )
      exp = abap_false
      msg = 'PDF bukan foto panel, harus ditolak' ).
  ENDMETHOD.

  METHOD empty_rejected.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_photo=>is_allowed_mime( '' )
      exp = abap_false
      msg = 'MIME kosong harus ditolak' ).
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 2: Buat kelas dengan method kosong dan jalankan test**

Run: SE24 &rarr; `ZCL_CP_PHOTO` &rarr; `Ctrl+Shift+F10`
Expected: FAIL. `jpeg_allowed` dan `png_allowed` gagal karena mengembalikan `abap_false`.

- [ ] **Step 3: Tulis implementasi**

```abap
CLASS zcl_cp_photo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS: c_max_size TYPE i VALUE 2097152.

    CLASS-METHODS is_allowed_mime
      IMPORTING iv_mime      TYPE string
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    CLASS-METHODS upload
      IMPORTING iv_ref_type        TYPE char4
                iv_ref_id          TYPE char20
                iv_panel_number    TYPE numc3
                iv_file_name       TYPE string
                iv_mime_type       TYPE string
                iv_data            TYPE xstring
                iv_user_id         TYPE char20
      RETURNING VALUE(rv_photo_id) TYPE char20
      RAISING   zcx_cp_error.

    CLASS-METHODS count_photos
      IMPORTING iv_ref_type     TYPE char4
                iv_ref_id       TYPE char20
                iv_panel_number TYPE numc3
      RETURNING VALUE(rv_count) TYPE i.

    CLASS-METHODS delete_panel_photos
      IMPORTING iv_ref_type     TYPE char4
                iv_ref_id       TYPE char20
                iv_panel_number TYPE numc3.

ENDCLASS.


CLASS zcl_cp_photo IMPLEMENTATION.

  METHOD is_allowed_mime.
    rv_ok = abap_false.

    IF iv_mime = 'image/jpeg' OR iv_mime = 'image/jpg' OR iv_mime = 'image/png'.
      rv_ok = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD count_photos.
    SELECT COUNT( * ) FROM zcp_photo
      WHERE ref_type = iv_ref_type
        AND ref_id   = iv_ref_id
        AND panel_number = iv_panel_number.

    rv_count = sy-dbcnt.
  ENDMETHOD.

  METHOD upload.
    DATA: ls_photo TYPE zcp_photo,
          lv_size  TYPE i,
          lv_seq   TYPE i,
          lv_now   TYPE timestamp,
          lv_name  TYPE string.

    IF is_allowed_mime( iv_mime_type ) = abap_false.
      zcx_cp_error=>raise( iv_msgno = '015' iv_v1 = iv_mime_type ).
    ENDIF.

    lv_size = xstrlen( iv_data ).

    IF lv_size > c_max_size.
      lv_name = iv_file_name.
      zcx_cp_error=>raise( iv_msgno = '014' iv_v1 = lv_name ).
    ENDIF.

    lv_seq = count_photos( iv_ref_type     = iv_ref_type
                           iv_ref_id       = iv_ref_id
                           iv_panel_number = iv_panel_number ).
    lv_seq = lv_seq + 1.

    rv_photo_id = zcl_cp_number=>next_photo_id( ).

    GET TIME STAMP FIELD lv_now.

    ls_photo-photo_id     = rv_photo_id.
    ls_photo-ref_type     = iv_ref_type.
    ls_photo-ref_id       = iv_ref_id.
    ls_photo-panel_number = iv_panel_number.
    ls_photo-photo_seq    = lv_seq.
    ls_photo-file_name    = iv_file_name.
    ls_photo-mime_type    = iv_mime_type.
    ls_photo-file_size    = lv_size.
    ls_photo-photo_data   = iv_data.
    ls_photo-uploaded_by  = iv_user_id.
    ls_photo-uploaded_at  = lv_now.

    INSERT zcp_photo FROM ls_photo.

    IF sy-subrc <> 0.
      zcx_cp_error=>raise( iv_msgno = '019' ).
    ENDIF.
  ENDMETHOD.

  METHOD delete_panel_photos.
    DELETE FROM zcp_photo
      WHERE ref_type = iv_ref_type
        AND ref_id   = iv_ref_id
        AND panel_number = iv_panel_number.
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 4: Jalankan test lagi**

Run: SE24 &rarr; `ZCL_CP_PHOTO` &rarr; `Ctrl+Shift+F10`
Expected: PASS, 4 dari 4 test hijau.

- [ ] **Step 5: Aktifkan ulang ZCL_CP_DCP**

Setelah `ZCL_CP_PHOTO` lengkap, aktifkan ulang `ZCL_CP_DCP` supaya panggilan `count_photos` terikat ke implementasi sungguhan.
Run: SE24 &rarr; `ZCL_CP_DCP` &rarr; Activate, lalu `Ctrl+Shift+F10`
Expected: aktivasi tanpa error, 15 test tetap hijau.

- [ ] **Step 6: Commit**

```bash
git add src/02_classes/zcl_cp_photo.abap
git commit -m "feat(class): ZCL_CP_PHOTO upload dan validasi foto panel"
```

---

### Task 11: ZCL_CP_REQUEST

**Files:**
- Create: `src/02_classes/zcl_cp_request.abap`

**Interfaces:**
- Consumes: `ZCL_CP_NUMBER=>next_request_id( )`, `ZCL_CP_DCP=>create_from_so_item( )`, `ZCL_CP_SO_READER=>tt_so_item`, `ZCL_CP_AUDIT=>log( )`, FM `ENQUEUE_EZCP_SO` / `DEQUEUE_EZCP_SO`
- Produces:
  - Tipe `tt_posnr TYPE STANDARD TABLE OF posnr WITH DEFAULT KEY`
  - Tipe `ty_decision`: `so_item TYPE posnr`, `success TYPE abap_bool`, `message TYPE string`, `dcp_id TYPE char20`, `color_code TYPE char20`
  - Tipe `tt_decision TYPE STANDARD TABLE OF ty_decision WITH DEFAULT KEY`
  - `calc_header_status( it_item_status TYPE tt_status ) RETURNING VALUE(rv_status) TYPE char1`
  - `create( iv_so_number TYPE vbeln iv_sales_user TYPE char20 iv_buyer_id TYPE char10 it_items TYPE zcl_cp_so_reader=>tt_so_item iv_remarks TYPE char200 ) RETURNING VALUE(rv_request_id) TYPE char20 RAISING zcx_cp_error`
  - `approve_items( iv_request_id TYPE char20 it_so_items TYPE tt_posnr iv_user_id TYPE char20 ) RETURNING VALUE(rt_result) TYPE tt_decision RAISING zcx_cp_error`
  - `reject_items( iv_request_id TYPE char20 it_so_items TYPE tt_posnr iv_reason TYPE char200 iv_user_id TYPE char20 ) RAISING zcx_cp_error`
  - `tt_status TYPE STANDARD TABLE OF char1 WITH DEFAULT KEY`

`approve_items` mengembalikan hasil per item alih-alih melempar exception pada kegagalan pertama. Dengan partial approve, satu material yang gagal tidak boleh membatalkan material lain yang sah &mdash; Admin perlu melihat mana yang berhasil dan mana yang tidak beserta alasannya.

- [ ] **Step 1: Tulis test class untuk perhitungan status header**

```abap
*"* LOCAL TEST CLASSES - paste ke tab "Local Test Classes" di SE24

CLASS ltc_request DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS pending_when_any_item_pending FOR TESTING.
    METHODS closed_when_all_decided FOR TESTING.
    METHODS closed_when_all_rejected FOR TESTING.
    METHODS pending_when_no_item FOR TESTING.

ENDCLASS.

CLASS ltc_request IMPLEMENTATION.

  METHOD pending_when_any_item_pending.
    DATA: lt_st TYPE zcl_cp_request=>tt_status,
          lv_st TYPE char1.

    lv_st = 'A'. APPEND lv_st TO lt_st.
    lv_st = 'R'. APPEND lv_st TO lt_st.
    lv_st = 'P'. APPEND lv_st TO lt_st.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_request=>calc_header_status( lt_st )
      exp = 'P'
      msg = 'Satu item pending membuat header tetap pending' ).
  ENDMETHOD.

  METHOD closed_when_all_decided.
    DATA: lt_st TYPE zcl_cp_request=>tt_status,
          lv_st TYPE char1.

    lv_st = 'A'. APPEND lv_st TO lt_st.
    lv_st = 'A'. APPEND lv_st TO lt_st.
    lv_st = 'R'. APPEND lv_st TO lt_st.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_request=>calc_header_status( lt_st )
      exp = 'C'
      msg = 'Semua item sudah diputuskan berarti header closed' ).
  ENDMETHOD.

  METHOD closed_when_all_rejected.
    DATA: lt_st TYPE zcl_cp_request=>tt_status,
          lv_st TYPE char1.

    lv_st = 'R'. APPEND lv_st TO lt_st.
    lv_st = 'R'. APPEND lv_st TO lt_st.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_request=>calc_header_status( lt_st )
      exp = 'C'
      msg = 'Request yang seluruh itemnya ditolak juga closed' ).
  ENDMETHOD.

  METHOD pending_when_no_item.
    DATA: lt_st TYPE zcl_cp_request=>tt_status.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_cp_request=>calc_header_status( lt_st )
      exp = 'P'
      msg = 'Request tanpa item tidak boleh dianggap closed' ).
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 2: Buat kelas dengan method kosong dan jalankan test**

Run: SE24 &rarr; `ZCL_CP_REQUEST` &rarr; `Ctrl+Shift+F10`
Expected: FAIL. `closed_when_all_decided` dan `closed_when_all_rejected` gagal karena mengembalikan nilai kosong.

- [ ] **Step 3: Tulis implementasi**

```abap
CLASS zcl_cp_request DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS: c_itm_pending  TYPE char1 VALUE 'P',
               c_itm_approved TYPE char1 VALUE 'A',
               c_itm_rejected TYPE char1 VALUE 'R',
               c_hdr_pending  TYPE char1 VALUE 'P',
               c_hdr_closed   TYPE char1 VALUE 'C'.

    TYPES: tt_status TYPE STANDARD TABLE OF char1 WITH DEFAULT KEY.
    TYPES: tt_posnr  TYPE STANDARD TABLE OF posnr WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_decision,
             so_item    TYPE posnr,
             success    TYPE abap_bool,
             message    TYPE string,
             dcp_id     TYPE char20,
             color_code TYPE char20,
           END OF ty_decision.

    TYPES: tt_decision TYPE STANDARD TABLE OF ty_decision WITH DEFAULT KEY.

    CLASS-METHODS calc_header_status
      IMPORTING it_item_status   TYPE tt_status
      RETURNING VALUE(rv_status) TYPE char1.

    CLASS-METHODS create
      IMPORTING iv_so_number        TYPE vbeln
                iv_sales_user       TYPE char20
                iv_buyer_id         TYPE char10
                it_items            TYPE zcl_cp_so_reader=>tt_so_item
                iv_remarks          TYPE char200 OPTIONAL
      RETURNING VALUE(rv_request_id) TYPE char20
      RAISING   zcx_cp_error.

    CLASS-METHODS approve_items
      IMPORTING iv_request_id    TYPE char20
                it_so_items      TYPE tt_posnr
                iv_user_id       TYPE char20
      RETURNING VALUE(rt_result) TYPE tt_decision
      RAISING   zcx_cp_error.

    CLASS-METHODS reject_items
      IMPORTING iv_request_id TYPE char20
                it_so_items   TYPE tt_posnr
                iv_reason     TYPE char200
                iv_user_id    TYPE char20
      RAISING   zcx_cp_error.

  PRIVATE SECTION.

    CLASS-METHODS refresh_header_status
      IMPORTING iv_request_id TYPE char20.

ENDCLASS.


CLASS zcl_cp_request IMPLEMENTATION.

  METHOD calc_header_status.
    DATA: lv_status TYPE char1.

    IF it_item_status IS INITIAL.
      rv_status = c_hdr_pending.
      RETURN.
    ENDIF.

    rv_status = c_hdr_closed.

    LOOP AT it_item_status INTO lv_status.
      IF lv_status = c_itm_pending.
        rv_status = c_hdr_pending.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD refresh_header_status.
    DATA: lt_status TYPE tt_status,
          lv_status TYPE char1.

    SELECT status INTO TABLE lt_status FROM zcp_request_itm
      WHERE request_id = iv_request_id.

    lv_status = calc_header_status( lt_status ).

    UPDATE zcp_request SET status = lv_status
      WHERE request_id = iv_request_id.
  ENDMETHOD.

  METHOD create.
    DATA: ls_hdr   TYPE zcp_request,
          ls_itm   TYPE zcp_request_itm,
          ls_item  TYPE zcl_cp_so_reader=>ty_so_item,
          lv_now   TYPE timestamp,
          lv_count TYPE i,
          lv_so_s  TYPE string.

    " Hanya item yang layak yang menjadi baris request. Item tidak layak
    " sudah ditampilkan beserta alasannya di halaman, tidak perlu disimpan.
    LOOP AT it_items INTO ls_item WHERE eligible = abap_true.
      lv_count = lv_count + 1.
    ENDLOOP.

    IF lv_count = 0.
      lv_so_s = iv_so_number.
      zcx_cp_error=>raise( iv_msgno = '002' iv_v1 = lv_so_s ).
    ENDIF.

    GET TIME STAMP FIELD lv_now.

    rv_request_id = zcl_cp_number=>next_request_id( ).

    ls_hdr-request_id   = rv_request_id.
    ls_hdr-so_number    = iv_so_number.
    ls_hdr-sales_user   = iv_sales_user.
    ls_hdr-buyer_id     = iv_buyer_id.
    ls_hdr-request_date = sy-datum.
    ls_hdr-status       = c_hdr_pending.
    ls_hdr-remarks      = iv_remarks.
    ls_hdr-created_by   = iv_sales_user.
    ls_hdr-created_at   = lv_now.
    INSERT zcp_request FROM ls_hdr.

    IF sy-subrc <> 0.
      zcx_cp_error=>raise( iv_msgno = '019' ).
    ENDIF.

    LOOP AT it_items INTO ls_item WHERE eligible = abap_true.
      CLEAR ls_itm.
      ls_itm-request_id = rv_request_id.
      ls_itm-so_item    = ls_item-so_item.
      ls_itm-matnr      = ls_item-matnr.
      ls_itm-maktx      = ls_item-maktx.
      ls_itm-menge      = ls_item-menge.
      ls_itm-meins      = ls_item-meins.
      ls_itm-status     = c_itm_pending.
      ls_itm-created_at = lv_now.
      INSERT zcp_request_itm FROM ls_itm.

      IF sy-subrc <> 0.
        zcx_cp_error=>raise( iv_msgno = '019' ).
      ENDIF.
    ENDLOOP.

    zcl_cp_audit=>log( iv_ref_type = 'REQ'
                       iv_ref_id   = rv_request_id
                       iv_action   = 'CREATE'
                       iv_user_id  = iv_sales_user
                       iv_new      = iv_so_number
                       iv_desc     = 'Request DCP dibuat dari SO' ).
  ENDMETHOD.

  METHOD approve_items.
    DATA: ls_hdr      TYPE zcp_request,
          ls_itm      TYPE zcp_request_itm,
          ls_input    TYPE zcl_cp_dcp=>ty_create_input,
          ls_created  TYPE zcl_cp_dcp=>ty_create_result,
          ls_result   TYPE ty_decision,
          lv_posnr    TYPE posnr,
          lv_now      TYPE timestamp,
          lo_error    TYPE REF TO zcx_cp_error,
          lv_req_s    TYPE string.

    SELECT SINGLE * INTO ls_hdr FROM zcp_request
      WHERE request_id = iv_request_id.

    IF sy-subrc <> 0.
      lv_req_s = iv_request_id.
      zcx_cp_error=>raise( iv_msgno = '017' iv_v1 = lv_req_s ).
    ENDIF.

    CALL FUNCTION 'ENQUEUE_EZCP_SO'
      EXPORTING
        so_number      = ls_hdr-so_number
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.

    IF sy-subrc <> 0.
      lv_req_s = ls_hdr-so_number.
      zcx_cp_error=>raise( iv_msgno = '005'
                           iv_v1    = lv_req_s
                           iv_v2    = sy-msgv1
                           iv_v3    = '-' ).
    ENDIF.

    GET TIME STAMP FIELD lv_now.

    LOOP AT it_so_items INTO lv_posnr.

      CLEAR ls_result.
      ls_result-so_item = lv_posnr.

      SELECT SINGLE * INTO ls_itm FROM zcp_request_itm
        WHERE request_id = iv_request_id AND so_item = lv_posnr.

      IF sy-subrc <> 0 OR ls_itm-status <> c_itm_pending.
        ls_result-success = abap_false.
        ls_result-message = 'Item tidak ditemukan atau sudah diputuskan'.
        APPEND ls_result TO rt_result.
        CONTINUE.
      ENDIF.

      CLEAR ls_input.
      ls_input-request_id = iv_request_id.
      ls_input-so_number  = ls_hdr-so_number.
      ls_input-so_item    = ls_itm-so_item.
      ls_input-matnr      = ls_itm-matnr.
      ls_input-maktx      = ls_itm-maktx.
      ls_input-menge      = ls_itm-menge.
      ls_input-meins      = ls_itm-meins.
      ls_input-buyer_id   = ls_hdr-buyer_id.
      ls_input-sales_user = ls_hdr-sales_user.
      ls_input-user_id    = iv_user_id.

      TRY.
          ls_created = zcl_cp_dcp=>create_from_so_item( ls_input ).

          UPDATE zcp_request_itm
            SET status     = c_itm_approved
                decided_by = iv_user_id
                decided_at = lv_now
                dcp_id     = ls_created-dcp_id
                color_code = ls_created-color_code
            WHERE request_id = iv_request_id AND so_item = lv_posnr.

          ls_result-success    = abap_true.
          ls_result-dcp_id     = ls_created-dcp_id.
          ls_result-color_code = ls_created-color_code.
          ls_result-message    = 'Berhasil'.

        CATCH zcx_cp_error INTO lo_error.
          ls_result-success = abap_false.
          ls_result-message = lo_error->get_text_message( ).
      ENDTRY.

      APPEND ls_result TO rt_result.
    ENDLOOP.

    refresh_header_status( iv_request_id ).

    COMMIT WORK AND WAIT.

    CALL FUNCTION 'DEQUEUE_EZCP_SO'
      EXPORTING so_number = ls_hdr-so_number.

    zcl_cp_audit=>log( iv_ref_type = 'REQ'
                       iv_ref_id   = iv_request_id
                       iv_action   = 'APPROVE'
                       iv_user_id  = iv_user_id ).
    COMMIT WORK.
  ENDMETHOD.

  METHOD reject_items.
    DATA: lv_posnr TYPE posnr,
          lv_now   TYPE timestamp.

    IF iv_reason IS INITIAL.
      zcx_cp_error=>raise( iv_msgno = '016' ).
    ENDIF.

    GET TIME STAMP FIELD lv_now.

    LOOP AT it_so_items INTO lv_posnr.
      " Sengaja tidak menulis ZCP_SO_IMPORT. Item yang ditolak harus bisa
      " diajukan ulang di request baru dengan nomor SO yang sama.
      UPDATE zcp_request_itm
        SET status        = c_itm_rejected
            reject_reason = iv_reason
            decided_by    = iv_user_id
            decided_at    = lv_now
        WHERE request_id = iv_request_id
          AND so_item    = lv_posnr
          AND status     = c_itm_pending.
    ENDLOOP.

    refresh_header_status( iv_request_id ).

    zcl_cp_audit=>log( iv_ref_type = 'REQ'
                       iv_ref_id   = iv_request_id
                       iv_action   = 'REJECT'
                       iv_user_id  = iv_user_id
                       iv_desc     = iv_reason ).

    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 4: Jalankan test lagi**

Run: SE24 &rarr; `ZCL_CP_REQUEST` &rarr; `Ctrl+Shift+F10`
Expected: PASS, 4 dari 4 test hijau.

- [ ] **Step 5: Uji alur create dan approve lewat report sementara**

Buat `ZCP_TMP_FLOW` di SE38 (jangan disimpan ke repo), ganti nomor SO dengan SO nyata di sandbox:

```abap
REPORT zcp_tmp_flow.

PARAMETERS: p_vbeln TYPE vbeln OBLIGATORY.

DATA: lt_items  TYPE zcl_cp_so_reader=>tt_so_item,
      ls_item   TYPE zcl_cp_so_reader=>ty_so_item,
      lt_posnr  TYPE zcl_cp_request=>tt_posnr,
      lt_result TYPE zcl_cp_request=>tt_decision,
      ls_result TYPE zcl_cp_request=>ty_decision,
      lv_req    TYPE char20,
      lo_error  TYPE REF TO zcx_cp_error,
      lv_text   TYPE string.

START-OF-SELECTION.

  TRY.
      lt_items = zcl_cp_so_reader=>read_so( p_vbeln ).

      lv_req = zcl_cp_request=>create( iv_so_number  = p_vbeln
                                       iv_sales_user = 'ARYA'
                                       iv_buyer_id   = 'B001'
                                       it_items      = lt_items ).
      COMMIT WORK AND WAIT.
      WRITE: / 'Request dibuat:', lv_req.

      LOOP AT lt_items INTO ls_item WHERE eligible = abap_true.
        APPEND ls_item-so_item TO lt_posnr.
      ENDLOOP.

      lt_result = zcl_cp_request=>approve_items( iv_request_id = lv_req
                                                 it_so_items   = lt_posnr
                                                 iv_user_id    = 'ARYA' ).

      LOOP AT lt_result INTO ls_result.
        WRITE: / ls_result-so_item, ls_result-success,
                 ls_result-dcp_id, ls_result-color_code, ls_result-message.
      ENDLOOP.

    CATCH zcx_cp_error INTO lo_error.
      lv_text = lo_error->get_text_message( ).
      WRITE: / 'GAGAL:', lv_text.
  ENDTRY.
```

Run: SE38 &rarr; `ZCP_TMP_FLOW` &rarr; isi SO nyata &rarr; F8, lalu periksa SE16N.
Expected: `ZCP_REQUEST` berisi satu baris berstatus `C`; `ZCP_REQUEST_ITM` seluruh itemnya `A`; `ZCP_COLOR_CODE` bertambah satu baris per material dengan kode `KW00001` dan seterusnya; `ZCP_DCP_HDR` bertambah satu baris per material; `ZCP_DCP_ITEM` berisi panel sebanyak qty SO semuanya berstatus `NA`; `ZCP_SO_IMPORT` terisi.

Jalankan report yang sama sekali lagi dengan SO yang sama.
Expected: kolom `message` berisi `Material ... sudah memiliki Color Code KW00001` untuk setiap item, dan tidak ada baris baru di `ZCP_DCP_HDR`. Ini membuktikan kunci anti-duplikat bekerja. Hapus report sementara setelah verifikasi.

- [ ] **Step 6: Commit**

```bash
git add src/02_classes/zcl_cp_request.abap
git commit -m "feat(class): ZCL_CP_REQUEST create dan approve/reject per material dengan kunci SO"
```

---

### Task 12: Aplikasi BSP, Halaman Login, dan Router

**Files:**
- Create: `src/04_bsp/zbsp_color_panel/_shared/head.htm.txt`
- Create: `src/04_bsp/zbsp_color_panel/login/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/login/oninputprocessing.abap.txt`
- Create: `src/04_bsp/zbsp_color_panel/login/layout.htm.txt`
- Create: `src/04_bsp/zbsp_color_panel/main/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/main/onrequest.abap.txt`
- Create: `src/04_bsp/zbsp_color_panel/main/layout.htm.txt`

**Interfaces:**
- Consumes: `ZCL_CP_AUTH=>login( )`, `save_session( )`, `read_session( )`, `clear_session( )`
- Produces: aplikasi BSP `ZBSP_COLOR_PANEL` yang hidup di `/sap/bc/bsp/sap/zbsp_color_panel/login.htm`, dan pola potongan `head` yang dipakai ulang semua halaman berikutnya

- [ ] **Step 1: Buat aplikasi BSP dan service SICF**

SE80 &rarr; BSP Application &rarr; buat `ZBSP_COLOR_PANEL`, package `$TMP`. Buat dua Page with Flow Logic: `login.htm` dan `main.htm`. Untuk masing-masing, buka tab Properties dan centang **Stateful**.
SICF &rarr; buka `/sap/bc/bsp/sap/zbsp_color_panel` &rarr; tab Logon Data &rarr; Procedure `Alternative Logon Procedure` dengan user `auto_email`, client sesuai sistem &rarr; aktifkan service.
Expected: `http://<host>:<port>/sap/bc/bsp/sap/zbsp_color_panel/login.htm` terbuka tanpa dialog login SAP.

- [ ] **Step 2: Tulis potongan head bersama**

`src/04_bsp/zbsp_color_panel/_shared/head.htm.txt` &mdash; disalin ke bagian atas setiap halaman. Bukan include BSP, melainkan potongan yang di-copy, karena BSP di 1809 tidak punya mekanisme partial yang nyaman.

```html
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"/>
```

- [ ] **Step 3: Tulis halaman login**

`src/04_bsp/zbsp_color_panel/login/attributes.txt`:

```
Page Attributes untuk login.htm

Name        Type Ref    Associated Type    Auto
--------------------------------------------------
gv_error    TYPE        STRING             (kosong)
```

`src/04_bsp/zbsp_color_panel/login/oninputprocessing.abap.txt`:

```abap
DATA: lv_user    TYPE char20,
      lv_pass    TYPE string,
      lv_ip      TYPE char45,
      lv_sid     TYPE string,
      ls_session TYPE zcl_cp_auth=>ty_session,
      lo_error   TYPE REF TO zcx_cp_error.

lv_user = request->get_form_field( 'user_id' ).
lv_pass = request->get_form_field( 'password' ).

IF lv_user IS INITIAL AND lv_pass IS INITIAL.
  RETURN.
ENDIF.

TRANSLATE lv_user TO UPPER CASE.

lv_ip  = request->get_header_field( '~remote_addr' ).
lv_sid = runtime->session_id.

TRY.
    ls_session = zcl_cp_auth=>login( iv_user_id  = lv_user
                                     iv_password = lv_pass
                                     iv_ip       = lv_ip ).

    zcl_cp_auth=>save_session( iv_session_id = lv_sid
                               is_session    = ls_session ).

    navigation->goto_page( 'main.htm' ).

  CATCH zcx_cp_error INTO lo_error.
    gv_error = lo_error->get_text_message( ).
ENDTRY.
```

`src/04_bsp/zbsp_color_panel/login/layout.htm.txt`:

```html
<%@page language="abap"%>
<html>
<head>
<title>Color Panel &mdash; Login</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"/>
</head>
<body class="bg-slate-100 min-h-screen flex items-center justify-center">

<form method="post" class="bg-white w-full max-w-sm rounded-xl shadow p-8">

  <h1 class="text-xl font-semibold text-slate-800 mb-1">Color Panel</h1>
  <p class="text-sm text-slate-500 mb-6">PT. Kayu Mebel Indonesia</p>

  <% IF gv_error IS NOT INITIAL. %>
  <div class="mb-4 rounded border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
    <%= gv_error %>
  </div>
  <% ENDIF. %>

  <label class="block text-sm text-slate-600 mb-1">User ID</label>
  <input type="text" name="user_id" autofocus
         class="w-full rounded border border-slate-300 px-3 py-2 mb-4 text-sm"/>

  <label class="block text-sm text-slate-600 mb-1">Password</label>
  <input type="password" name="password"
         class="w-full rounded border border-slate-300 px-3 py-2 mb-6 text-sm"/>

  <button type="submit"
          class="w-full rounded bg-slate-800 px-3 py-2 text-sm font-medium text-white">
    Masuk
  </button>

</form>

</body>
</html>
```

- [ ] **Step 4: Tulis halaman router**

`src/04_bsp/zbsp_color_panel/main/attributes.txt`:

```
Page Attributes untuk main.htm

Name          Type Ref    Associated Type              Auto
--------------------------------------------------------------
gs_session    TYPE        ZCL_CP_AUTH=>TY_SESSION      (kosong)
```

`src/04_bsp/zbsp_color_panel/main/onrequest.abap.txt`:

```abap
DATA: lv_sid   TYPE string,
      lv_logout TYPE string.

lv_sid = runtime->session_id.

lv_logout = request->get_form_field( 'logout' ).

IF lv_logout = 'X'.
  zcl_cp_auth=>clear_session( lv_sid ).
  navigation->goto_page( 'login.htm' ).
  RETURN.
ENDIF.

TRY.
    gs_session = zcl_cp_auth=>read_session( lv_sid ).
  CATCH zcx_cp_error.
    navigation->goto_page( 'login.htm' ).
    RETURN.
ENDTRY.
```

`src/04_bsp/zbsp_color_panel/main/layout.htm.txt`:

```html
<%@page language="abap"%>
<html>
<head>
<title>Color Panel</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"/>
</head>
<body class="bg-slate-100 min-h-screen">

<header class="bg-white border-b border-slate-200">
  <div class="max-w-5xl mx-auto px-6 py-4 flex items-center justify-between">
    <div>
      <div class="text-base font-semibold text-slate-800">Color Panel</div>
      <div class="text-xs text-slate-500">
        <%= gs_session-full_name %> &mdash; <%= gs_session-role %>
      </div>
    </div>
    <form method="post">
      <input type="hidden" name="logout" value="X"/>
      <button type="submit" class="text-sm text-slate-600">Keluar</button>
    </form>
  </div>
</header>

<main class="max-w-5xl mx-auto px-6 py-8">
  <div class="grid gap-4 sm:grid-cols-2">

  <% IF gs_session-role = 'SALES'. %>
    <a href="req_list.htm" class="block rounded-xl bg-white p-5 shadow">
      <div class="text-sm font-medium text-slate-800">Request DCP</div>
      <div class="text-xs text-slate-500 mt-1">Ajukan pembuatan DCP dari nomor SO</div>
    </a>
  <% ENDIF. %>

  <% IF gs_session-role = 'ADMIN'. %>
    <a href="req_list.htm" class="block rounded-xl bg-white p-5 shadow">
      <div class="text-sm font-medium text-slate-800">Inbox Request</div>
      <div class="text-xs text-slate-500 mt-1">Approve atau reject request dari Sales</div>
    </a>
    <a href="dcp_list.htm" class="block rounded-xl bg-white p-5 shadow">
      <div class="text-sm font-medium text-slate-800">Daftar DCP</div>
      <div class="text-xs text-slate-500 mt-1">Aktivasi panel, submit foto, approve</div>
    </a>
  <% ENDIF. %>

  <% IF gs_session-role = 'IT'. %>
    <a href="dcp_list.htm" class="block rounded-xl bg-white p-5 shadow">
      <div class="text-sm font-medium text-slate-800">Daftar DCP</div>
      <div class="text-xs text-slate-500 mt-1">Pantau seluruh DCP</div>
    </a>
    <a href="admin_user.htm" class="block rounded-xl bg-white p-5 shadow">
      <div class="text-sm font-medium text-slate-800">Kelola User</div>
      <div class="text-xs text-slate-500 mt-1">Tambah user dan atur password</div>
    </a>
  <% ENDIF. %>

  </div>
</main>

</body>
</html>
```

- [ ] **Step 5: Paste ke SE80 dan uji login**

Salin isi tiap file ke tab yang sesuai di SE80 (Layout, Event Handler OnInputProcessing / OnRequest, Page Attributes), aktifkan aplikasi.
Run: buka `/sap/bc/bsp/sap/zbsp_color_panel/login.htm`, login dengan `ARYA` / `Init1234`.
Expected: berpindah ke `main.htm`, header menampilkan `Arya - IT &mdash; IT`, dan hanya kartu milik role IT yang tampil. Login dengan password salah menampilkan kotak merah `User atau password salah` tanpa membocorkan apakah user-nya ada. Klik Keluar mengembalikan ke halaman login; menekan tombol Back lalu memuat ulang `main.htm` juga mengembalikan ke login karena session sudah dihapus.

- [ ] **Step 6: Periksa audit trail login**

SE16N &rarr; `ZCP_AUDIT_LOG`.
Expected: ada baris `LOGIN_FAIL` dan `LOGIN` dengan `ACTION_BY` = `ARYA` dan `IP_ADDRESS` terisi. Sekali lagi: `ACTION_BY` harus `ARYA`, bukan `auto_email`.

- [ ] **Step 7: Commit**

```bash
git add src/04_bsp/zbsp_color_panel/_shared src/04_bsp/zbsp_color_panel/login src/04_bsp/zbsp_color_panel/main
git commit -m "feat(bsp): aplikasi ZBSP_COLOR_PANEL dengan login custom dan router role"
```

---

### Task 13: Halaman Daftar Request dan Form Request Sales

**Files:**
- Create: `src/04_bsp/zbsp_color_panel/req_list/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/req_list/onrequest.abap.txt`
- Create: `src/04_bsp/zbsp_color_panel/req_list/layout.htm.txt`
- Create: `src/04_bsp/zbsp_color_panel/req_form/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/req_form/oninputprocessing.abap.txt`
- Create: `src/04_bsp/zbsp_color_panel/req_form/layout.htm.txt`

**Interfaces:**
- Consumes: `ZCL_CP_AUTH=>require_role( )`, `ZCL_CP_SO_READER=>read_so( )`, `ZCL_CP_REQUEST=>create( )`
- Produces: halaman `req_list.htm` dan `req_form.htm`

`req_form.htm` bekerja dua tahap dalam satu halaman: POST pertama mengambil isi SO dan menampilkannya, POST kedua menyimpan request. Item tidak layak tetap ditampilkan dengan alasannya, tidak disembunyikan.

- [ ] **Step 1: Tulis `req_list`**

`attributes.txt`:

```
Page Attributes untuk req_list.htm

Name          Type Ref    Associated Type              Auto
--------------------------------------------------------------
gs_session    TYPE        ZCL_CP_AUTH=>TY_SESSION      (kosong)
gt_request    TYPE        ZCP_REQUEST_T                (kosong)

Catatan: buat table type ZCP_REQUEST_T di SE11 dengan row type ZCP_REQUEST.
```

`onrequest.abap.txt`:

```abap
DATA: lv_sid TYPE string.

lv_sid = runtime->session_id.

TRY.
    gs_session = zcl_cp_auth=>require_role( iv_session_id = lv_sid
                                            iv_roles      = 'SALES,ADMIN' ).
  CATCH zcx_cp_error.
    navigation->goto_page( 'login.htm' ).
    RETURN.
ENDTRY.

IF gs_session-role = 'SALES'.
  SELECT * INTO TABLE gt_request FROM zcp_request
    WHERE sales_user = gs_session-user_id
    ORDER BY request_id DESCENDING.
ELSE.
  SELECT * INTO TABLE gt_request FROM zcp_request
    ORDER BY status ASCENDING request_id DESCENDING.
ENDIF.
```

`layout.htm.txt`:

```html
<%@page language="abap"%>
<html>
<head>
<title>Color Panel &mdash; Request</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-slate-100 min-h-screen">

<header class="bg-white border-b border-slate-200">
  <div class="max-w-5xl mx-auto px-6 py-4 flex items-center justify-between">
    <a href="main.htm" class="text-sm text-slate-600">&lt; Beranda</a>
    <% IF gs_session-role = 'SALES'. %>
    <a href="req_form.htm"
       class="rounded bg-slate-800 px-3 py-2 text-sm font-medium text-white">
       Request Baru</a>
    <% ENDIF. %>
  </div>
</header>

<main class="max-w-5xl mx-auto px-6 py-8">
<div class="bg-white rounded-xl shadow overflow-x-auto">
<table class="min-w-full text-sm">
  <thead class="bg-slate-50 text-slate-600">
    <tr>
      <th class="px-4 py-3 text-left">Request</th>
      <th class="px-4 py-3 text-left">SO</th>
      <th class="px-4 py-3 text-left">Tanggal</th>
      <th class="px-4 py-3 text-left">Status</th>
      <th class="px-4 py-3"></th>
    </tr>
  </thead>
  <tbody>
  <% DATA: ls_req TYPE zcp_request. %>
  <% LOOP AT gt_request INTO ls_req. %>
    <tr class="border-t border-slate-100">
      <td class="px-4 py-3 font-medium text-slate-800"><%= ls_req-request_id %></td>
      <td class="px-4 py-3"><%= ls_req-so_number %></td>
      <td class="px-4 py-3"><%= ls_req-request_date %></td>
      <td class="px-4 py-3">
        <% IF ls_req-status = 'P'. %>
          <span class="rounded bg-amber-100 px-2 py-1 text-xs text-amber-800">Pending</span>
        <% ELSE. %>
          <span class="rounded bg-emerald-100 px-2 py-1 text-xs text-emerald-800">Closed</span>
        <% ENDIF. %>
      </td>
      <td class="px-4 py-3 text-right">
        <% IF gs_session-role = 'ADMIN'. %>
        <a class="text-slate-700 underline"
           href="req_detail.htm?request_id=<%= ls_req-request_id %>">Buka</a>
        <% ENDIF. %>
      </td>
    </tr>
  <% ENDLOOP. %>
  <% IF gt_request IS INITIAL. %>
    <tr><td colspan="5" class="px-4 py-8 text-center text-slate-500">
      Belum ada request.</td></tr>
  <% ENDIF. %>
  </tbody>
</table>
</div>
</main>

</body>
</html>
```

- [ ] **Step 2: Tulis `req_form`**

`attributes.txt`:

```
Page Attributes untuk req_form.htm

Name           Type Ref    Associated Type                    Auto
-------------------------------------------------------------------
gs_session     TYPE        ZCL_CP_AUTH=>TY_SESSION            (kosong)
gt_items       TYPE        ZCL_CP_SO_READER=>TT_SO_ITEM       (kosong)
gv_so_number   TYPE        VBELN                              (kosong)
gv_buyer_id    TYPE        CHAR10                             (kosong)
gv_remarks     TYPE        CHAR200                            (kosong)
gv_error       TYPE        STRING                             (kosong)
gv_loaded      TYPE        ABAP_BOOL                          (kosong)
gv_eligible    TYPE        I                                  (kosong)
```

`oninputprocessing.abap.txt`:

```abap
DATA: lv_sid    TYPE string,
      lv_action TYPE string,
      lv_req    TYPE char20,
      ls_item   TYPE zcl_cp_so_reader=>ty_so_item,
      lo_error  TYPE REF TO zcx_cp_error.

lv_sid = runtime->session_id.

TRY.
    gs_session = zcl_cp_auth=>require_role( iv_session_id = lv_sid
                                            iv_roles      = 'SALES' ).
  CATCH zcx_cp_error.
    navigation->goto_page( 'login.htm' ).
    RETURN.
ENDTRY.

lv_action    = request->get_form_field( 'action' ).
gv_so_number = request->get_form_field( 'so_number' ).
gv_buyer_id  = request->get_form_field( 'buyer_id' ).
gv_remarks   = request->get_form_field( 'remarks' ).

CLEAR: gv_error, gv_loaded, gv_eligible, gt_items.

IF lv_action IS INITIAL.
  RETURN.
ENDIF.

TRY.
    gt_items  = zcl_cp_so_reader=>read_so( gv_so_number ).
    gv_loaded = abap_true.

    LOOP AT gt_items INTO ls_item WHERE eligible = abap_true.
      gv_eligible = gv_eligible + 1.
    ENDLOOP.

    IF lv_action = 'SUBMIT'.
      lv_req = zcl_cp_request=>create( iv_so_number  = gv_so_number
                                       iv_sales_user = gs_session-user_id
                                       iv_buyer_id   = gv_buyer_id
                                       it_items      = gt_items
                                       iv_remarks    = gv_remarks ).
      COMMIT WORK AND WAIT.
      navigation->goto_page( 'req_list.htm' ).
      RETURN.
    ENDIF.

  CATCH zcx_cp_error INTO lo_error.
    gv_error = lo_error->get_text_message( ).
ENDTRY.
```

`layout.htm.txt`:

```html
<%@page language="abap"%>
<html>
<head>
<title>Color Panel &mdash; Request Baru</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-slate-100 min-h-screen">

<main class="max-w-4xl mx-auto px-6 py-8">

<a href="req_list.htm" class="text-sm text-slate-600">&lt; Daftar Request</a>

<form method="post" class="bg-white rounded-xl shadow p-6 mt-4">

  <h1 class="text-lg font-semibold text-slate-800 mb-4">Request DCP Baru</h1>

  <% IF gv_error IS NOT INITIAL. %>
  <div class="mb-4 rounded border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
    <%= gv_error %>
  </div>
  <% ENDIF. %>

  <div class="grid gap-4 sm:grid-cols-3">
    <div>
      <label class="block text-sm text-slate-600 mb-1">Nomor SO</label>
      <input type="text" name="so_number" value="<%= gv_so_number %>"
             class="w-full rounded border border-slate-300 px-3 py-2 text-sm"/>
    </div>
    <div>
      <label class="block text-sm text-slate-600 mb-1">Buyer</label>
      <input type="text" name="buyer_id" value="<%= gv_buyer_id %>"
             class="w-full rounded border border-slate-300 px-3 py-2 text-sm"/>
    </div>
    <div class="flex items-end">
      <button type="submit" name="action" value="LOAD"
              class="rounded bg-slate-200 px-4 py-2 text-sm font-medium text-slate-800">
        Ambil Isi SO
      </button>
    </div>
  </div>

  <% IF gv_loaded = abap_true. %>

  <div class="mt-6 overflow-x-auto">
  <table class="min-w-full text-sm">
    <thead class="bg-slate-50 text-slate-600">
      <tr>
        <th class="px-3 py-2 text-left">Item</th>
        <th class="px-3 py-2 text-left">Material</th>
        <th class="px-3 py-2 text-left">Deskripsi</th>
        <th class="px-3 py-2 text-right">Qty</th>
        <th class="px-3 py-2 text-left">Keterangan</th>
      </tr>
    </thead>
    <tbody>
    <% DATA: ls_row TYPE zcl_cp_so_reader=>ty_so_item. %>
    <% LOOP AT gt_items INTO ls_row. %>
      <tr class="border-t border-slate-100">
        <td class="px-3 py-2"><%= ls_row-so_item %></td>
        <td class="px-3 py-2 font-medium text-slate-800"><%= ls_row-matnr %></td>
        <td class="px-3 py-2"><%= ls_row-maktx %></td>
        <td class="px-3 py-2 text-right"><%= ls_row-menge %> <%= ls_row-meins %></td>
        <td class="px-3 py-2">
          <% IF ls_row-eligible = abap_true. %>
            <span class="text-emerald-700"><%= ls_row-reason %></span>
          <% ELSE. %>
            <span class="text-slate-500"><%= ls_row-reason %></span>
          <% ENDIF. %>
        </td>
      </tr>
    <% ENDLOOP. %>
    </tbody>
  </table>
  </div>

  <div class="mt-4">
    <label class="block text-sm text-slate-600 mb-1">Catatan</label>
    <input type="text" name="remarks" value="<%= gv_remarks %>"
           class="w-full rounded border border-slate-300 px-3 py-2 text-sm"/>
  </div>

  <div class="mt-6 flex items-center justify-between">
    <div class="text-sm text-slate-600">
      Material layak dijadikan DCP: <strong><%= gv_eligible %></strong>
    </div>
    <% IF gv_eligible > 0. %>
    <button type="submit" name="action" value="SUBMIT"
            class="rounded bg-slate-800 px-4 py-2 text-sm font-medium text-white">
      Kirim Request
    </button>
    <% ELSE. %>
    <span class="text-sm text-slate-500">
      Tidak ada material yang bisa diajukan dari SO ini.
    </span>
    <% ENDIF. %>
  </div>

  <% ENDIF. %>

</form>
</main>

</body>
</html>
```

- [ ] **Step 3: Buat table type dan kedua halaman di SE80**

SE11 &rarr; Data Type &rarr; Table Type `ZCP_REQUEST_T`, row type `ZCP_REQUEST`, aktifkan.
SE80 &rarr; buat page `req_list.htm` dan `req_form.htm`, keduanya Stateful, paste isi tiap file ke tab yang sesuai, aktifkan aplikasi.
Expected: aktivasi tanpa error sintaks.

- [ ] **Step 4: Uji sebagai Sales**

Buat user Sales lewat report sementara seperti pola di Task 6, dengan `ROLE` = `SALES`. Login sebagai user itu, buka Request Baru, isi nomor SO nyata, klik Ambil Isi SO.
Expected: tabel menampilkan seluruh item SO. Material FERT yang belum punya Color Code bertulisan hijau `Layak dijadikan DCP`; sisanya abu-abu dengan alasannya. Angka "Material layak dijadikan DCP" cocok dengan jumlah baris hijau.

Klik Kirim Request.
Expected: kembali ke daftar request, muncul satu baris berstatus Pending. SE16N `ZCP_REQUEST_ITM` berisi hanya item yang layak.

Isi nomor SO yang tidak ada, klik Ambil Isi SO.
Expected: kotak merah `SO ... tidak ditemukan`, tabel tidak muncul.

- [ ] **Step 5: Commit**

```bash
git add src/04_bsp/zbsp_color_panel/req_list src/04_bsp/zbsp_color_panel/req_form
git commit -m "feat(bsp): halaman daftar request dan form request DCP untuk Sales"
```

---

### Task 14: Halaman Approval Admin (Partial Approve)

**Files:**
- Create: `src/04_bsp/zbsp_color_panel/req_detail/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/req_detail/oninputprocessing.abap.txt`
- Create: `src/04_bsp/zbsp_color_panel/req_detail/layout.htm.txt`

**Interfaces:**
- Consumes: `ZCL_CP_REQUEST=>approve_items( )`, `ZCL_CP_REQUEST=>reject_items( )`, `ZCL_CP_AUTH=>require_role( )`
- Produces: halaman `req_detail.htm`

Admin mencentang material yang hendak diputuskan, lalu menekan Approve atau Reject. Hasil per item ditampilkan kembali di halaman, bukan sekadar satu pesan sukses/gagal &mdash; dengan partial approve, sebagian bisa berhasil dan sebagian gagal dalam satu klik.

- [ ] **Step 1: Tulis `attributes.txt`**

```
Page Attributes untuk req_detail.htm

Name           Type Ref    Associated Type                   Auto
--------------------------------------------------------------------
request_id     TYPE        CHAR20                            X
gs_session     TYPE        ZCL_CP_AUTH=>TY_SESSION           (kosong)
gs_request     TYPE        ZCP_REQUEST                       (kosong)
gt_items       TYPE        ZCP_REQUEST_ITM_T                 (kosong)
gt_result      TYPE        ZCL_CP_REQUEST=>TT_DECISION       (kosong)
gv_error       TYPE        STRING                            (kosong)

Catatan: kolom Auto dicentang untuk request_id supaya terisi otomatis dari
URL parameter req_detail.htm?request_id=REQ-2026-0001
Buat table type ZCP_REQUEST_ITM_T di SE11 dengan row type ZCP_REQUEST_ITM.
```

- [ ] **Step 2: Tulis `oninputprocessing.abap.txt`**

```abap
DATA: lv_sid    TYPE string,
      lv_action TYPE string,
      lv_reason TYPE char200,
      lv_field  TYPE string,
      lv_value  TYPE string,
      lv_posnr  TYPE posnr,
      lt_posnr  TYPE zcl_cp_request=>tt_posnr,
      ls_itm    TYPE zcp_request_itm,
      lo_error  TYPE REF TO zcx_cp_error.

lv_sid = runtime->session_id.

TRY.
    gs_session = zcl_cp_auth=>require_role( iv_session_id = lv_sid
                                            iv_roles      = 'ADMIN' ).
  CATCH zcx_cp_error.
    navigation->goto_page( 'login.htm' ).
    RETURN.
ENDTRY.

lv_action = request->get_form_field( 'action' ).
lv_reason = request->get_form_field( 'reason' ).

CLEAR: gv_error, gt_result.

IF lv_action IS NOT INITIAL.

  " Kumpulkan item yang dicentang. Nama checkbox: sel_000010
  SELECT * INTO TABLE gt_items FROM zcp_request_itm
    WHERE request_id = request_id
    ORDER BY so_item.

  LOOP AT gt_items INTO ls_itm.
    CLEAR: lv_field, lv_value.
    CONCATENATE 'sel_' ls_itm-so_item INTO lv_field.
    lv_value = request->get_form_field( lv_field ).

    IF lv_value = 'X' AND ls_itm-status = 'P'.
      lv_posnr = ls_itm-so_item.
      APPEND lv_posnr TO lt_posnr.
    ENDIF.
  ENDLOOP.

  IF lt_posnr IS INITIAL.
    gv_error = 'Pilih minimal satu material terlebih dahulu'.
  ELSE.
    TRY.
        IF lv_action = 'APPROVE'.
          gt_result = zcl_cp_request=>approve_items(
                        iv_request_id = request_id
                        it_so_items   = lt_posnr
                        iv_user_id    = gs_session-user_id ).
        ELSEIF lv_action = 'REJECT'.
          zcl_cp_request=>reject_items(
            iv_request_id = request_id
            it_so_items   = lt_posnr
            iv_reason     = lv_reason
            iv_user_id    = gs_session-user_id ).
        ENDIF.

      CATCH zcx_cp_error INTO lo_error.
        gv_error = lo_error->get_text_message( ).
    ENDTRY.
  ENDIF.

ENDIF.

SELECT SINGLE * INTO gs_request FROM zcp_request
  WHERE request_id = request_id.

SELECT * INTO TABLE gt_items FROM zcp_request_itm
  WHERE request_id = request_id
  ORDER BY so_item.
```

- [ ] **Step 3: Tulis `layout.htm.txt`**

```html
<%@page language="abap"%>
<html>
<head>
<title>Color Panel &mdash; Detail Request</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-slate-100 min-h-screen">

<main class="max-w-4xl mx-auto px-6 py-8">

<a href="req_list.htm" class="text-sm text-slate-600">&lt; Daftar Request</a>

<div class="bg-white rounded-xl shadow p-6 mt-4">

  <div class="flex items-start justify-between">
    <div>
      <h1 class="text-lg font-semibold text-slate-800"><%= gs_request-request_id %></h1>
      <p class="text-sm text-slate-500">
        SO <%= gs_request-so_number %> &mdash; diajukan oleh <%= gs_request-sales_user %>
        pada <%= gs_request-request_date %>
      </p>
    </div>
    <% IF gs_request-status = 'P'. %>
      <span class="rounded bg-amber-100 px-2 py-1 text-xs text-amber-800">Pending</span>
    <% ELSE. %>
      <span class="rounded bg-emerald-100 px-2 py-1 text-xs text-emerald-800">Closed</span>
    <% ENDIF. %>
  </div>

  <% IF gv_error IS NOT INITIAL. %>
  <div class="mt-4 rounded border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
    <%= gv_error %>
  </div>
  <% ENDIF. %>

  <% IF gt_result IS NOT INITIAL. %>
  <div class="mt-4 rounded border border-slate-200 bg-slate-50 px-3 py-3 text-sm">
    <div class="font-medium text-slate-700 mb-2">Hasil pemrosesan</div>
    <% DATA: ls_res TYPE zcl_cp_request=>ty_decision. %>
    <% LOOP AT gt_result INTO ls_res. %>
      <div class="py-1">
        <span class="text-slate-500">Item <%= ls_res-so_item %>:</span>
        <% IF ls_res-success = abap_true. %>
          <span class="text-emerald-700">
            DCP <%= ls_res-dcp_id %>, Color Code <%= ls_res-color_code %>
          </span>
        <% ELSE. %>
          <span class="text-red-700"><%= ls_res-message %></span>
        <% ENDIF. %>
      </div>
    <% ENDLOOP. %>
  </div>
  <% ENDIF. %>

  <form method="post" class="mt-6">

  <div class="overflow-x-auto">
  <table class="min-w-full text-sm">
    <thead class="bg-slate-50 text-slate-600">
      <tr>
        <th class="px-3 py-2 w-8"></th>
        <th class="px-3 py-2 text-left">Item</th>
        <th class="px-3 py-2 text-left">Material</th>
        <th class="px-3 py-2 text-left">Deskripsi</th>
        <th class="px-3 py-2 text-right">Qty</th>
        <th class="px-3 py-2 text-left">Status</th>
        <th class="px-3 py-2 text-left">Hasil</th>
      </tr>
    </thead>
    <tbody>
    <% DATA: ls_row TYPE zcp_request_itm. %>
    <% LOOP AT gt_items INTO ls_row. %>
      <tr class="border-t border-slate-100">
        <td class="px-3 py-2">
          <% IF ls_row-status = 'P'. %>
          <input type="checkbox" value="X"
                 name="sel_<%= ls_row-so_item %>"/>
          <% ENDIF. %>
        </td>
        <td class="px-3 py-2"><%= ls_row-so_item %></td>
        <td class="px-3 py-2 font-medium text-slate-800"><%= ls_row-matnr %></td>
        <td class="px-3 py-2"><%= ls_row-maktx %></td>
        <td class="px-3 py-2 text-right"><%= ls_row-menge %> <%= ls_row-meins %></td>
        <td class="px-3 py-2">
          <% IF ls_row-status = 'P'. %>Pending<% ENDIF. %>
          <% IF ls_row-status = 'A'. %>
            <span class="text-emerald-700">Approved</span>
          <% ENDIF. %>
          <% IF ls_row-status = 'R'. %>
            <span class="text-red-700">Rejected</span>
          <% ENDIF. %>
        </td>
        <td class="px-3 py-2 text-slate-500">
          <% IF ls_row-status = 'A'. %>
            <a class="underline" href="dcp_list.htm"><%= ls_row-dcp_id %></a>
            <%= ls_row-color_code %>
          <% ENDIF. %>
          <% IF ls_row-status = 'R'. %><%= ls_row-reject_reason %><% ENDIF. %>
        </td>
      </tr>
    <% ENDLOOP. %>
    </tbody>
  </table>
  </div>

  <% IF gs_request-status = 'P'. %>
  <div class="mt-6 border-t border-slate-100 pt-4">
    <label class="block text-sm text-slate-600 mb-1">Alasan (wajib untuk Reject)</label>
    <input type="text" name="reason"
           class="w-full rounded border border-slate-300 px-3 py-2 text-sm mb-4"/>
    <div class="flex gap-3">
      <button type="submit" name="action" value="APPROVE"
              class="rounded bg-slate-800 px-4 py-2 text-sm font-medium text-white">
        Approve Terpilih
      </button>
      <button type="submit" name="action" value="REJECT"
              class="rounded border border-red-300 px-4 py-2 text-sm font-medium text-red-700">
        Reject Terpilih
      </button>
    </div>
  </div>
  <% ENDIF. %>

  </form>
</div>
</main>

</body>
</html>
```

- [ ] **Step 4: Buat halaman di SE80 dan uji partial approve**

SE11 &rarr; Table Type `ZCP_REQUEST_ITM_T`. SE80 &rarr; page `req_detail.htm` Stateful, paste ketiga file, aktifkan.
Login sebagai Admin, buka request dari Task 13 lewat tombol Buka. Centang dua material, klik Approve Terpilih.
Expected: kotak hasil menampilkan dua baris hijau berisi nomor DCP dan Color Code. Kedua baris tabel berubah menjadi Approved. Baris ketiga tetap Pending dan header masih Pending.

Centang material ketiga, isi alasan, klik Reject Terpilih.
Expected: baris berubah Rejected dengan alasan tertampil, dan status header berubah menjadi Closed karena tidak ada lagi item pending.

Klik Approve Terpilih tanpa mencentang apa pun.
Expected: pesan `Pilih minimal satu material terlebih dahulu`, tidak ada perubahan data.

Klik Reject Terpilih dengan alasan kosong pada request lain yang masih pending.
Expected: pesan `Alasan wajib diisi`, status item tidak berubah.

- [ ] **Step 5: Commit**

```bash
git add src/04_bsp/zbsp_color_panel/req_detail
git commit -m "feat(bsp): halaman approval Admin dengan approve/reject per material"
```

---

### Task 15: Halaman Daftar DCP

**Files:**
- Create: `src/04_bsp/zbsp_color_panel/dcp_list/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/dcp_list/onrequest.abap.txt`
- Create: `src/04_bsp/zbsp_color_panel/dcp_list/layout.htm.txt`

**Interfaces:**
- Consumes: `ZCL_CP_AUTH=>require_role( )`, tabel `ZCP_DCP_HDR` dan `ZCP_DCP_ITEM`
- Produces: halaman `dcp_list.htm`

Jumlah panel per status dihitung dari `ZCP_DCP_ITEM` saat render, bukan dibaca dari kolom penghitung di header. Inilah alasan kolom `QTY_APPROVED` dan kawan-kawan dibuang di spec: satu sumber kebenaran saja.

- [ ] **Step 1: Tulis `attributes.txt`**

```
Page Attributes untuk dcp_list.htm

Name          Type Ref    Associated Type            Auto
--------------------------------------------------------------
gs_session    TYPE        ZCL_CP_AUTH=>TY_SESSION    (kosong)
gt_rows       TYPE        ZCP_DCP_ROW_T              (kosong)
gv_filter     TYPE        CHAR1                      X

Catatan: buat structure ZCP_DCP_ROW di SE11 berisi seluruh field ZCP_DCP_HDR
melalui .INCLUDE, ditambah:
  CNT_TOTAL     INT4
  CNT_ACTIVE    INT4
  CNT_APPROVED  INT4
Lalu buat table type ZCP_DCP_ROW_T dengan row type ZCP_DCP_ROW.
```

- [ ] **Step 2: Tulis `onrequest.abap.txt`**

```abap
DATA: lv_sid   TYPE string,
      lt_hdr   TYPE STANDARD TABLE OF zcp_dcp_hdr,
      ls_hdr   TYPE zcp_dcp_hdr,
      ls_row   TYPE zcp_dcp_row,
      lv_count TYPE i.

lv_sid = runtime->session_id.

TRY.
    gs_session = zcl_cp_auth=>require_role( iv_session_id = lv_sid
                                            iv_roles      = 'ADMIN,IT' ).
  CATCH zcx_cp_error.
    navigation->goto_page( 'login.htm' ).
    RETURN.
ENDTRY.

IF gv_filter IS INITIAL.
  SELECT * INTO TABLE lt_hdr FROM zcp_dcp_hdr
    ORDER BY dcp_id DESCENDING.
ELSE.
  SELECT * INTO TABLE lt_hdr FROM zcp_dcp_hdr
    WHERE status = gv_filter
    ORDER BY dcp_id DESCENDING.
ENDIF.

CLEAR gt_rows.

LOOP AT lt_hdr INTO ls_hdr.
  CLEAR ls_row.
  MOVE-CORRESPONDING ls_hdr TO ls_row.

  SELECT COUNT( * ) FROM zcp_dcp_item WHERE dcp_id = ls_hdr-dcp_id.
  ls_row-cnt_total = sy-dbcnt.

  SELECT COUNT( * ) FROM zcp_dcp_item
    WHERE dcp_id = ls_hdr-dcp_id AND status = 'AK'.
  ls_row-cnt_active = sy-dbcnt.

  SELECT COUNT( * ) FROM zcp_dcp_item
    WHERE dcp_id = ls_hdr-dcp_id AND status = 'AP'.
  ls_row-cnt_approved = sy-dbcnt.

  APPEND ls_row TO gt_rows.
ENDLOOP.
```

- [ ] **Step 3: Tulis `layout.htm.txt`**

```html
<%@page language="abap"%>
<html>
<head>
<title>Color Panel &mdash; Daftar DCP</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-slate-100 min-h-screen">

<header class="bg-white border-b border-slate-200">
  <div class="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between">
    <a href="main.htm" class="text-sm text-slate-600">&lt; Beranda</a>
    <div class="flex gap-2 text-sm">
      <a href="dcp_list.htm" class="rounded px-3 py-1 bg-slate-200">Semua</a>
      <a href="dcp_list.htm?gv_filter=O" class="rounded px-3 py-1 bg-white border">Open</a>
      <a href="dcp_list.htm?gv_filter=C" class="rounded px-3 py-1 bg-white border">Closed</a>
      <a href="dcp_list.htm?gv_filter=R" class="rounded px-3 py-1 bg-white border">Rejected</a>
    </div>
  </div>
</header>

<main class="max-w-6xl mx-auto px-6 py-8">
<div class="bg-white rounded-xl shadow overflow-x-auto">
<table class="min-w-full text-sm">
  <thead class="bg-slate-50 text-slate-600">
    <tr>
      <th class="px-4 py-3 text-left">DCP</th>
      <th class="px-4 py-3 text-left">Color Code</th>
      <th class="px-4 py-3 text-left">Material</th>
      <th class="px-4 py-3 text-left">SO</th>
      <th class="px-4 py-3 text-center">Panel</th>
      <th class="px-4 py-3 text-left">Expired</th>
      <th class="px-4 py-3 text-left">Reminder</th>
      <th class="px-4 py-3 text-left">Status</th>
      <th class="px-4 py-3"></th>
    </tr>
  </thead>
  <tbody>
  <% DATA: ls_r TYPE zcp_dcp_row. %>
  <% LOOP AT gt_rows INTO ls_r. %>
    <tr class="border-t border-slate-100">
      <td class="px-4 py-3 font-medium text-slate-800"><%= ls_r-dcp_id %></td>
      <td class="px-4 py-3"><%= ls_r-color_code %></td>
      <td class="px-4 py-3"><%= ls_r-matnr %><br/>
        <span class="text-xs text-slate-500"><%= ls_r-maktx %></span></td>
      <td class="px-4 py-3"><%= ls_r-so_number %> / <%= ls_r-so_item %></td>
      <td class="px-4 py-3 text-center">
        <span class="text-emerald-700"><%= ls_r-cnt_approved %></span>
        /
        <span class="text-slate-700"><%= ls_r-cnt_active %></span>
        /
        <span class="text-slate-400"><%= ls_r-cnt_total %></span>
      </td>
      <td class="px-4 py-3"><%= ls_r-expire_date %></td>
      <td class="px-4 py-3">
        <% IF ls_r-status = 'O' AND ls_r-reminder_date <= sy-datum. %>
          <span class="rounded bg-red-100 px-2 py-1 text-xs text-red-800">
            <%= ls_r-reminder_date %></span>
        <% ELSE. %>
          <%= ls_r-reminder_date %>
        <% ENDIF. %>
      </td>
      <td class="px-4 py-3">
        <% IF ls_r-status = 'O'. %>
          <span class="rounded bg-amber-100 px-2 py-1 text-xs text-amber-800">Open</span>
        <% ENDIF. %>
        <% IF ls_r-status = 'C'. %>
          <span class="rounded bg-emerald-100 px-2 py-1 text-xs text-emerald-800">Closed</span>
        <% ENDIF. %>
        <% IF ls_r-status = 'R'. %>
          <span class="rounded bg-red-100 px-2 py-1 text-xs text-red-800">Rejected</span>
        <% ENDIF. %>
      </td>
      <td class="px-4 py-3 text-right">
        <a class="text-slate-700 underline"
           href="dcp_detail.htm?dcp_id=<%= ls_r-dcp_id %>">Buka</a>
      </td>
    </tr>
  <% ENDLOOP. %>
  <% IF gt_rows IS INITIAL. %>
    <tr><td colspan="9" class="px-4 py-8 text-center text-slate-500">
      Belum ada DCP.</td></tr>
  <% ENDIF. %>
  </tbody>
</table>
</div>
<p class="mt-3 text-xs text-slate-500">
  Kolom Panel dibaca sebagai approved / aktif / total.
</p>
</main>

</body>
</html>
```

- [ ] **Step 4: Buat structure, table type, dan halaman, lalu uji**

SE11 &rarr; Structure `ZCP_DCP_ROW` dan Table Type `ZCP_DCP_ROW_T`. SE80 &rarr; page `dcp_list.htm` Stateful, paste ketiga file, aktifkan.
Login sebagai Admin, buka Daftar DCP.
Expected: baris DCP hasil approve di Task 14 muncul dengan Color Code `KW00001` dan seterusnya, kolom Panel menampilkan `0 / 0 / N` di mana N sama dengan qty SO. Kolom Reminder menampilkan tanggal dua bulan dari hari ini. Klik tab Open menampilkan hanya yang berstatus Open.

- [ ] **Step 5: Commit**

```bash
git add src/04_bsp/zbsp_color_panel/dcp_list
git commit -m "feat(bsp): halaman daftar DCP dengan hitung panel dan filter status"
```

---

### Task 16: Halaman Detail DCP &mdash; Siklus Panel

**Files:**
- Create: `src/04_bsp/zbsp_color_panel/dcp_detail/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/dcp_detail/oninputprocessing.abap.txt`
- Create: `src/04_bsp/zbsp_color_panel/dcp_detail/layout.htm.txt`

**Interfaces:**
- Consumes: seluruh method aksi `ZCL_CP_DCP` dari Task 9, `ZCL_CP_PHOTO=>upload( )` dan `delete_panel_photos( )`
- Produces: halaman `dcp_detail.htm`

Ini halaman terpenting di sub-proyek 1. Upload foto dan submit dijalankan sebagai **satu aksi yang tidak bisa setengah jadi**: bila salah satu foto gagal, seluruh foto panel itu dihapus dan status tetap `AK`. Tanpa itu, akan ada panel `SB` berfoto satu yang tidak pernah bisa ditelusuri asal masalahnya.

- [ ] **Step 1: Tulis `attributes.txt`**

```
Page Attributes untuk dcp_detail.htm

Name          Type Ref    Associated Type            Auto
--------------------------------------------------------------
dcp_id        TYPE        CHAR20                     X
gs_session    TYPE        ZCL_CP_AUTH=>TY_SESSION    (kosong)
gs_hdr        TYPE        ZCP_DCP_HDR                (kosong)
gt_panel      TYPE        ZCP_DCP_ITEM_T             (kosong)
gv_error      TYPE        STRING                     (kosong)
gv_info       TYPE        STRING                     (kosong)

Catatan: buat table type ZCP_DCP_ITEM_T di SE11 dengan row type ZCP_DCP_ITEM.
```

- [ ] **Step 2: Tulis `oninputprocessing.abap.txt`**

```abap
DATA: lv_sid     TYPE string,
      lv_action  TYPE string,
      lv_panel_c TYPE string,
      lv_panel   TYPE numc3,
      lv_date_c  TYPE string,
      lv_date    TYPE datum,
      lv_reason  TYPE char200,
      lv_num     TYPE i,
      lv_idx     TYPE i,
      lv_upload  TYPE i,
      lo_entity  TYPE REF TO if_http_entity,
      lv_fname   TYPE string,
      lv_mime    TYPE string,
      lv_xdata   TYPE xstring,
      lo_error   TYPE REF TO zcx_cp_error.

lv_sid = runtime->session_id.

TRY.
    gs_session = zcl_cp_auth=>require_role( iv_session_id = lv_sid
                                            iv_roles      = 'ADMIN' ).
  CATCH zcx_cp_error.
    navigation->goto_page( 'login.htm' ).
    RETURN.
ENDTRY.

CLEAR: gv_error, gv_info.

lv_action  = request->get_form_field( 'action' ).
lv_panel_c = request->get_form_field( 'panel_number' ).
lv_date_c  = request->get_form_field( 'mfg_date' ).
lv_reason  = request->get_form_field( 'reason' ).

lv_panel = lv_panel_c.

IF lv_date_c IS NOT INITIAL.
  " Input type=date mengirim YYYY-MM-DD
  CONCATENATE lv_date_c(4) lv_date_c+5(2) lv_date_c+8(2) INTO lv_date.
ENDIF.

TRY.

    CASE lv_action.

      WHEN 'ACTIVATE'.
        zcl_cp_dcp=>activate_panel( iv_dcp_id       = dcp_id
                                    iv_panel_number = lv_panel
                                    iv_mfg_date     = lv_date
                                    iv_user_id      = gs_session-user_id ).
        COMMIT WORK AND WAIT.
        gv_info = 'Panel diaktifkan'.

      WHEN 'UPLOAD_SUBMIT'.
        " Semua foto harus tersimpan sebelum panel boleh berstatus SB.
        lv_num = request->num_multiparts( ).
        lv_idx = 1.

        WHILE lv_idx <= lv_num.
          lo_entity = request->get_multipart( lv_idx ).
          lv_fname  = lo_entity->get_header_field( '~content_filename' ).

          IF lv_fname IS NOT INITIAL.
            lv_mime  = lo_entity->get_header_field( 'content-type' ).
            lv_xdata = lo_entity->get_data( ).

            zcl_cp_photo=>upload( iv_ref_type     = 'DCP'
                                  iv_ref_id       = dcp_id
                                  iv_panel_number = lv_panel
                                  iv_file_name    = lv_fname
                                  iv_mime_type    = lv_mime
                                  iv_data         = lv_xdata
                                  iv_user_id      = gs_session-user_id ).
            lv_upload = lv_upload + 1.
          ENDIF.

          lv_idx = lv_idx + 1.
        ENDWHILE.

        zcl_cp_dcp=>submit_panel( iv_dcp_id       = dcp_id
                                  iv_panel_number = lv_panel
                                  iv_user_id      = gs_session-user_id ).
        COMMIT WORK AND WAIT.
        gv_info = 'Foto tersimpan dan panel disubmit'.

      WHEN 'APPROVE'.
        zcl_cp_dcp=>approve_panel( iv_dcp_id       = dcp_id
                                   iv_panel_number = lv_panel
                                   iv_user_id      = gs_session-user_id ).
        COMMIT WORK AND WAIT.
        gv_info = 'Panel di-approve'.

      WHEN 'REJECT'.
        zcl_cp_dcp=>reject_panel( iv_dcp_id       = dcp_id
                                  iv_panel_number = lv_panel
                                  iv_reason       = lv_reason
                                  iv_user_id      = gs_session-user_id ).
        COMMIT WORK AND WAIT.
        gv_info = 'Panel di-reject'.

      WHEN 'UNDO'.
        zcl_cp_dcp=>undo_panel( iv_dcp_id       = dcp_id
                                iv_panel_number = lv_panel
                                iv_user_id      = gs_session-user_id ).
        COMMIT WORK AND WAIT.
        gv_info = 'Keputusan panel dibatalkan'.

      WHEN 'CLOSE_HDR'.
        zcl_cp_dcp=>close_header( iv_dcp_id  = dcp_id
                                  iv_user_id = gs_session-user_id ).
        COMMIT WORK AND WAIT.
        gv_info = 'Siklus DCP ditutup'.

      WHEN 'REJECT_HDR'.
        zcl_cp_dcp=>reject_header( iv_dcp_id  = dcp_id
                                   iv_reason  = lv_reason
                                   iv_user_id = gs_session-user_id ).
        COMMIT WORK AND WAIT.
        gv_info = 'Siklus DCP ditolak'.

    ENDCASE.

  CATCH zcx_cp_error INTO lo_error.
    ROLLBACK WORK.

    " Aturan error nomor 4: tidak boleh ada panel submitted dengan foto
    " tidak lengkap. Bila upload sempat berjalan lalu gagal, bersihkan.
    IF lv_action = 'UPLOAD_SUBMIT' AND lv_upload > 0.
      zcl_cp_photo=>delete_panel_photos( iv_ref_type     = 'DCP'
                                         iv_ref_id       = dcp_id
                                         iv_panel_number = lv_panel ).
      COMMIT WORK AND WAIT.
    ENDIF.

    gv_error = lo_error->get_text_message( ).
ENDTRY.

SELECT SINGLE * INTO gs_hdr FROM zcp_dcp_hdr WHERE dcp_id = dcp_id.

SELECT * INTO TABLE gt_panel FROM zcp_dcp_item
  WHERE dcp_id = dcp_id
  ORDER BY panel_number.
```

- [ ] **Step 3: Tulis `layout.htm.txt`**

```html
<%@page language="abap"%>
<html>
<head>
<title>Color Panel &mdash; Detail DCP</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-slate-100 min-h-screen">

<main class="max-w-5xl mx-auto px-6 py-8">

<a href="dcp_list.htm" class="text-sm text-slate-600">&lt; Daftar DCP</a>

<div class="bg-white rounded-xl shadow p-6 mt-4">
  <div class="flex items-start justify-between">
    <div>
      <h1 class="text-lg font-semibold text-slate-800"><%= gs_hdr-dcp_id %></h1>
      <p class="text-sm text-slate-500">
        <%= gs_hdr-color_code %> &mdash; <%= gs_hdr-matnr %> &mdash; <%= gs_hdr-maktx %>
      </p>
      <p class="text-xs text-slate-500 mt-1">
        SO <%= gs_hdr-so_number %> / <%= gs_hdr-so_item %>
        &#8226; Manufaktur <%= gs_hdr-mfg_date %>
        &#8226; Expired <%= gs_hdr-expire_date %>
      </p>
    </div>
    <div class="text-right">
      <% IF gs_hdr-status = 'O'. %>
        <span class="rounded bg-amber-100 px-2 py-1 text-xs text-amber-800">Open</span>
      <% ENDIF. %>
      <% IF gs_hdr-status = 'C'. %>
        <span class="rounded bg-emerald-100 px-2 py-1 text-xs text-emerald-800">Closed</span>
      <% ENDIF. %>
      <% IF gs_hdr-status = 'R'. %>
        <span class="rounded bg-red-100 px-2 py-1 text-xs text-red-800">Rejected</span>
      <% ENDIF. %>
    </div>
  </div>

  <% IF gv_error IS NOT INITIAL. %>
  <div class="mt-4 rounded border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
    <%= gv_error %>
  </div>
  <% ENDIF. %>

  <% IF gv_info IS NOT INITIAL. %>
  <div class="mt-4 rounded border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
    <%= gv_info %>
  </div>
  <% ENDIF. %>
</div>

<div class="grid gap-4 mt-6 sm:grid-cols-2 lg:grid-cols-3">
<% DATA: ls_p TYPE zcp_dcp_item. %>
<% LOOP AT gt_panel INTO ls_p. %>

  <div class="bg-white rounded-xl shadow p-4">
    <div class="flex items-center justify-between">
      <div class="text-sm font-semibold text-slate-800">
        Panel <%= ls_p-panel_number %>
      </div>
      <% IF ls_p-status = 'NA'. %>
        <span class="rounded bg-slate-100 px-2 py-1 text-xs text-slate-600">Non-Aktif</span>
      <% ENDIF. %>
      <% IF ls_p-status = 'AK'. %>
        <span class="rounded bg-sky-100 px-2 py-1 text-xs text-sky-800">Aktif</span>
      <% ENDIF. %>
      <% IF ls_p-status = 'SB'. %>
        <span class="rounded bg-amber-100 px-2 py-1 text-xs text-amber-800">Submitted</span>
      <% ENDIF. %>
      <% IF ls_p-status = 'AP'. %>
        <span class="rounded bg-emerald-100 px-2 py-1 text-xs text-emerald-800">Approved</span>
      <% ENDIF. %>
      <% IF ls_p-status = 'RJ'. %>
        <span class="rounded bg-red-100 px-2 py-1 text-xs text-red-800">Rejected</span>
      <% ENDIF. %>
      <% IF ls_p-status = 'OB'. %>
        <span class="rounded bg-slate-200 px-2 py-1 text-xs text-slate-500">Obsolete</span>
      <% ENDIF. %>
    </div>

    <div class="text-xs text-slate-500 mt-1"><%= ls_p-panel_id %></div>
    <% IF ls_p-mfg_date IS NOT INITIAL. %>
    <div class="text-xs text-slate-500">Dibuat <%= ls_p-mfg_date %></div>
    <% ENDIF. %>
    <% IF ls_p-reject_reason IS NOT INITIAL. %>
    <div class="text-xs text-red-700 mt-1"><%= ls_p-reject_reason %></div>
    <% ENDIF. %>
    <% IF ls_p-undo_count > 0. %>
    <div class="text-xs text-slate-400 mt-1">Pernah di-undo <%= ls_p-undo_count %> kali</div>
    <% ENDIF. %>

    <% IF gs_hdr-status = 'O'. %>

      <% IF ls_p-status = 'NA'. %>
      <form method="post" class="mt-3">
        <input type="hidden" name="panel_number" value="<%= ls_p-panel_number %>"/>
        <label class="block text-xs text-slate-600 mb-1">Tanggal dibuat</label>
        <input type="date" name="mfg_date"
               class="w-full rounded border border-slate-300 px-2 py-1 text-sm mb-2"/>
        <button type="submit" name="action" value="ACTIVATE"
                class="w-full rounded bg-slate-800 px-3 py-2 text-sm text-white">
          Aktifkan
        </button>
      </form>
      <% ENDIF. %>

      <% IF ls_p-status = 'AK'. %>
      <form method="post" enctype="multipart/form-data" class="mt-3">
        <input type="hidden" name="panel_number" value="<%= ls_p-panel_number %>"/>
        <label class="block text-xs text-slate-600 mb-1">Foto panel (minimal 2)</label>
        <input type="file" name="photo" accept="image/jpeg,image/png" multiple
               class="w-full text-xs mb-2"/>
        <button type="submit" name="action" value="UPLOAD_SUBMIT"
                class="w-full rounded bg-slate-800 px-3 py-2 text-sm text-white">
          Upload dan Submit
        </button>
      </form>
      <% ENDIF. %>

      <% IF ls_p-status = 'SB'. %>
      <form method="post" class="mt-3">
        <input type="hidden" name="panel_number" value="<%= ls_p-panel_number %>"/>
        <input type="text" name="reason" placeholder="Alasan bila reject"
               class="w-full rounded border border-slate-300 px-2 py-1 text-sm mb-2"/>
        <div class="flex gap-2">
          <button type="submit" name="action" value="APPROVE"
                  class="flex-1 rounded bg-emerald-700 px-3 py-2 text-sm text-white">
            Approve
          </button>
          <button type="submit" name="action" value="REJECT"
                  class="flex-1 rounded border border-red-300 px-3 py-2 text-sm text-red-700">
            Reject
          </button>
        </div>
      </form>
      <% ENDIF. %>

      <% IF ls_p-status = 'AP' OR ls_p-status = 'RJ'. %>
      <form method="post" class="mt-3">
        <input type="hidden" name="panel_number" value="<%= ls_p-panel_number %>"/>
        <button type="submit" name="action" value="UNDO"
                class="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-700">
          Undo
        </button>
      </form>
      <% ENDIF. %>

    <% ENDIF. %>

  </div>

<% ENDLOOP. %>
</div>

<% IF gs_hdr-status = 'O'. %>
<div class="bg-white rounded-xl shadow p-6 mt-6">
  <form method="post">
    <label class="block text-sm text-slate-600 mb-1">Alasan (wajib untuk Reject Siklus)</label>
    <input type="text" name="reason"
           class="w-full rounded border border-slate-300 px-3 py-2 text-sm mb-4"/>
    <div class="flex gap-3">
      <button type="submit" name="action" value="CLOSE_HDR"
              class="rounded bg-slate-800 px-4 py-2 text-sm font-medium text-white">
        Close Siklus DCP
      </button>
      <button type="submit" name="action" value="REJECT_HDR"
              class="rounded border border-red-300 px-4 py-2 text-sm font-medium text-red-700">
        Reject Siklus DCP
      </button>
    </div>
    <p class="mt-3 text-xs text-slate-500">
      Close membutuhkan minimal satu panel approved. Panel selain approved
      akan menjadi obsolete dan tidak bisa dikembalikan.
    </p>
  </form>
</div>
<% ENDIF. %>

</main>

</body>
</html>
```

- [ ] **Step 4: Buat halaman dan uji seluruh siklus panel**

SE11 &rarr; Table Type `ZCP_DCP_ITEM_T`. SE80 &rarr; page `dcp_detail.htm` Stateful, paste ketiga file, aktifkan.
Login sebagai Admin, buka salah satu DCP.
Expected: kartu panel sebanyak qty SO, semuanya bertanda Non-Aktif dengan tombol Aktifkan.

Aktifkan satu panel dengan tanggal kemarin.
Expected: kartu berubah Aktif, tanggal tampil, dan header memperoleh Expired satu tahun setelah tanggal itu. Cek di `dcp_list.htm`, kolom Expired terisi.

Coba aktifkan panel lain dengan tanggal besok.
Expected: pesan merah `Tanggal pembuatan tidak boleh di masa depan`, status panel tidak berubah.

Pada panel Aktif, pilih satu file foto lalu Upload dan Submit.
Expected: pesan merah `Panel ... membutuhkan minimal 2 foto sebelum submit`, panel tetap Aktif, dan `ZCP_PHOTO` tidak menyisakan baris untuk panel itu &mdash; inilah pembersihan aturan error nomor 4.

Ulangi dengan dua file foto.
Expected: pesan hijau, panel berubah Submitted, `ZCP_PHOTO` berisi dua baris dengan `PHOTO_SEQ` 1 dan 2.

Approve satu panel, reject panel lain dengan alasan, lalu Undo keduanya.
Expected: keduanya kembali Submitted, `UNDO_COUNT` bertambah, `REJECT_REASON` terhapus, dan `ZCP_AUDIT_LOG` mencatat `APPROVE`, `REJECT`, dan `UNDO` dengan `ACTION_BY` berisi user Admin.

Approve satu panel, lalu Close Siklus DCP.
Expected: header Closed, seluruh panel selain yang approved menjadi Obsolete, dan tombol aksi per panel hilang. Tekan Undo lewat tombol Back browser lalu submit ulang.
Expected: pesan `Undo tidak diizinkan, DCP ... sudah di-close`.

Pada DCP lain yang belum punya panel approved, tekan Close Siklus DCP.
Expected: pesan `DCP ... tidak dapat di-close, belum ada panel yang approved`.

- [ ] **Step 5: Commit**

```bash
git add src/04_bsp/zbsp_color_panel/dcp_detail
git commit -m "feat(bsp): halaman detail DCP dengan aktivasi, upload foto, approve, undo, dan close"
```

---
