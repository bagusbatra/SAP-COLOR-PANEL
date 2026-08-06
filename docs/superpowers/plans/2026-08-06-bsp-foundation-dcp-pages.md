# BSP Foundation-DCP &mdash; Implementation Plan (Pages with Flow Logic)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun delapan Page with Flow Logic di aplikasi BSP `ZBSP_COLOR_PANEL` sampai alur Request-DCP dan siklus panel DCP berjalan penuh di SE80.

**Architecture:** Tiga tahap. Tahap 1 membangun kedelapan halaman sebagai layout statis tanpa panggilan class, sehingga bisa langsung di-activate dan navigasinya diuji di browser. Tahap 2 menuntaskan fondasi DDIC dan membangun delapan ABAP Class dengan TDD. Tahap 3 mengganti data hardcode di tiap halaman dengan panggilan class. Halaman BSP tetap tipis &mdash; seluruh aturan bisnis tinggal di class, supaya bisa dipakai ulang sub-proyek berikutnya dan bisa diuji tanpa browser.

**Tech Stack:** SAP S/4HANA 1809, BSP Application (Page with Flow Logic, stateful), ABAP OO (SE24), ABAP Unit, Tailwind CSS via CDN, SweetAlert2, Font Awesome.

---

## Global Constraints

Lima aturan berikut berlaku di **setiap** task. Disalin apa adanya dari `docs/superpowers/specs/2026-07-28-color-panel-foundation-dcp-design.md` bagian 9.

1. **Nol karakter non-ASCII di seluruh sumber BSP.** BSP merusak semua karakter di atas U+007F. Pakai HTML entity (`&mdash;`, `&#8226;`, `&#10003;`). Gejala kerusakannya menyesatkan &mdash; halaman rusak di tempat yang tidak berhubungan dengan perubahan terakhir.
2. **OpenSQL gaya lama tanpa `@`.** `SELECT f1 f2 INTO TABLE lt_data FROM ztab WHERE f = lv_var.` Tidak ada inline `DATA(...)`, tidak ada `VALUE #( )`. Semua variabel dideklarasikan eksplisit.
3. **Semua halaman stateful.** Centang di tab Properties tiap halaman.
4. **Atribut `class` dalam string JavaScript harus satu baris**, jangan dipecah antar baris.
5. **Tidak ada `SY-UNAME` sebagai identitas pelaku.** Selalu `USER_ID` dari session.

Tambahan yang berlaku sepanjang plan ini:

- Package seluruh objek: `$TMP`
- Repo adalah sumber kebenaran. Tulis file di `src/` dulu, baru paste ke SE80 &mdash; jangan sebaliknya.
- Nama aplikasi BSP: `ZBSP_COLOR_PANEL`. URL: `/sap/bc/bsp/sap/zbsp_color_panel/<page>.htm`

---

## Keadaan Awal (per 6 Agustus 2026)

Diverifikasi terhadap isi repo dan `report/report.md`, bukan diasumsikan.

| Bagian | Status |
|---|---|
| Domain dan data element | Selesai &mdash; 6 domain, 18 data element, semua Active |
| Sepuluh tabel + 6 index + lock object `EZCP_SO` | Selesai, Active |
| Lima objek SNRO | Objeknya ada, **interval `01` belum diisi** |
| Message class `ZCP` (SE91) | Belum |
| TMG `ZCP_BUYER` | Belum |
| ABAP Class | **Nol.** `src/02_classes/` kosong |
| Aplikasi BSP | **Belum ada** |
| Tabel MCP (`ZCP_MCP_HDR`, `ZCP_MCP_ITEM`) | **Tidak ada.** Di luar cakupan plan ini |

Konsekuensi yang harus disadari sejak awal: **halaman Tahap 1 tidak memanggil satu pun class**, justru supaya bisa di-activate sekarang. Halaman yang memanggil `ZCL_CP_AUTH` sebelum class-nya ada akan gagal aktivasi dengan syntax error.

---

## Peta File

Delapan halaman, masing-masing satu folder di `src/04_bsp/zbsp_color_panel/`. Folder sudah dibuat.

```
src/04_bsp/zbsp_color_panel/
  _shared/
    head.htm.txt            Potongan <head> yang di-copy ke semua halaman
    nav.htm.txt             Potongan sidebar, di-copy ke halaman selain login
  login/                    Form login
  main/                     Router berbasis role
  req_list/                 Daftar request (Sales: miliknya; Admin: inbox pending)
  req_form/                 Input SO, pilih material, submit request
  req_detail/               Approval Admin per item (partial approve)
  dcp_list/                 Daftar DCP + filter status
  dcp_detail/               Grid panel DCP: aktivasi, submit, approve, close
  admin_user/               Maintenance ZCP_USER (IT)
```

Setiap folder halaman berisi tiga file dengan nama seragam:

| File | Isi | Dipaste ke SE80 di |
|---|---|---|
| `attributes.txt` | Daftar Page Attribute | Tab **Page Attributes** |
| `layout.htm.txt` | Sumber layout | Tab **Layout** |
| `oninputprocessing.abap.txt` | Handler submit form | Tab **Event Handler** &rarr; `OnInputProcessing` |
| `onrequest.abap.txt` | Pemuatan data saat halaman diminta | Tab **Event Handler** &rarr; `OnRequest` |

Halaman yang tidak punya form tidak perlu `oninputprocessing.abap.txt`. Halaman statis di Tahap 1 belum punya `onrequest.abap.txt` &mdash; file itu lahir di Tahap 3.

**Kenapa potongan di-copy, bukan di-include:** BSP di 1809 tidak punya mekanisme partial yang nyaman. Page Fragment ada tapi merepotkan untuk konten yang mengandung ABAP. Menyalin adalah pilihan sadar, bukan kemalasan &mdash; konsekuensinya perubahan pada `head.htm.txt` harus disebar manual ke delapan halaman, dan itu dicatat sebagai langkah eksplisit di task yang mengubahnya.

---

## Ringkasan Tahap

| Tahap | Task | Hasil yang bisa dilihat |
|---|:---:|---|
| **1** | 1&ndash;6 | Delapan halaman aktif di SE80, navigasi antar halaman jalan, data masih hardcode |
| **2** | 7&ndash;14 | Fondasi DDIC tuntas, delapan class Active, unit test hijau |
| **3** | 15&ndash;20 | Data hardcode diganti panggilan class; alur end-to-end nyata |

Tahap 2 sengaja tidak mengulang isi `docs/superpowers/plans/2026-07-28-color-panel-foundation-dcp.md`, yang sudah memuat kode lengkap tiap class beserta test class-nya. Task 7&ndash;14 di sini menunjuk ke nomor task di dokumen itu. Menyalin ulang dua ribu baris ABAP ke sini hanya akan melahirkan dua sumber kebenaran yang lambat laun berbeda isi.

---

# TAHAP 1 &mdash; Skeleton yang Bisa Di-Activate

Tujuan tahap ini satu: **hari ini juga ada delapan halaman yang bisa dibuka di browser.** Semua data dituliskan langsung di layout. Tidak ada `SELECT`, tidak ada panggilan class, tidak ada session.

Data hardcode di tahap ini bukan sampah yang akan dibuang percuma &mdash; ia mengunci struktur HTML dan nama field form, sehingga Tahap 3 tinggal mengganti sumber datanya tanpa menyentuh markup.

---

### Task 1: Aplikasi BSP, SICF, dan Potongan Bersama

**Files:**
- Create: `src/04_bsp/zbsp_color_panel/_shared/head.htm.txt`
- Create: `src/04_bsp/zbsp_color_panel/_shared/nav.htm.txt`

**Interfaces:**
- Consumes: tidak ada
- Produces: aplikasi BSP `ZBSP_COLOR_PANEL` yang hidup di `/sap/bc/bsp/sap/zbsp_color_panel/`, dan dua potongan HTML yang disalin oleh Task 2&ndash;6

- [ ] **Step 1: Buat aplikasi BSP di SE80**

SE80 &rarr; pilih **BSP Application** di dropdown &rarr; ketik `ZBSP_COLOR_PANEL` &rarr; Enter &rarr; jawab Yes saat ditanya apakah ingin membuat objek baru.

Short description: `Color Panel Management System`. Package: `$TMP`. Simpan.

Expected: node `ZBSP_COLOR_PANEL` muncul di object tree kiri, dengan sub-node Pages, Controllers, Views, Navigation, MIME Repository.

- [ ] **Step 2: Aktifkan service SICF**

SICF &rarr; Hierarchy Type `SERVICE` &rarr; Execute &rarr; telusuri `default_host` &rarr; `sap` &rarr; `bc` &rarr; `bsp` &rarr; `sap` &rarr; `zbsp_color_panel`.

Klik kanan &rarr; **Activate Service**.

Lalu klik kanan &rarr; Change &rarr; tab **Logon Data**:

```
Procedure          : Alternative Logon Procedure
Client             : <client sistem Anda>
User               : auto_email
Password           : <password user auto_email>
```

Simpan.

Expected: service tampil hitam (aktif), bukan abu-abu.

Kalau user `auto_email` belum ada di sistem, buat lewat SU01 sebagai tipe **Service** (bukan Dialog), tanpa profil apa pun. Fungsinya hanya melewati dialog login SAP &mdash; autentikasi sebenarnya dikerjakan `login.htm` terhadap `ZCP_USER`.

- [ ] **Step 3: Tulis potongan head bersama**

`src/04_bsp/zbsp_color_panel/_shared/head.htm.txt`:

```html
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"/>
<script>
tailwind.config = {
  theme: {
    extend: {
      colors: {
        navy:      '#1E3A8A',
        navydark:  '#1E293B',
        navylight: '#3B4E9E'
      }
    }
  }
}
</script>
```

Tiga warna itu disalin dari design token prototype (`prototype/assets/css/style.css` baris 8&ndash;10) supaya BSP dan prototype terlihat sebagai satu aplikasi yang sama saat dibandingkan berdampingan dengan user.

- [ ] **Step 4: Tulis potongan sidebar bersama**

`src/04_bsp/zbsp_color_panel/_shared/nav.htm.txt`:

```html
<aside class="w-64 bg-navydark text-white flex flex-col min-h-screen">
  <div class="px-5 py-5 border-b border-white border-opacity-10">
    <div class="text-lg font-bold">Color Panel</div>
    <div class="text-xs text-gray-400">PT. Kayu Mebel Indonesia</div>
  </div>
  <nav class="flex-1 py-3">
    <a href="main.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-gauge w-4"></i> Dashboard
    </a>
    <a href="req_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-envelope-open-text w-4"></i> Request DCP
    </a>
    <a href="dcp_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-flask w-4"></i> DCP
    </a>
    <a href="admin_user.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-users w-4"></i> User
    </a>
  </nav>
  <div class="px-5 py-4 border-t border-white border-opacity-10">
    <a href="login.htm" class="block text-center text-sm text-gray-300 hover:text-white">
      <i class="fa-solid fa-right-from-bracket"></i> Logout
    </a>
  </div>
</aside>
```

Di Tahap 1 seluruh menu ditampilkan tanpa penyaringan role. Penyembunyian per role masuk di Task 15.

- [ ] **Step 5: Commit**

```bash
git add src/04_bsp/zbsp_color_panel/_shared/
git commit -m "feat(bsp): aplikasi ZBSP_COLOR_PANEL, service SICF, dan potongan head/nav bersama"
```

---

### Task 2: Halaman Login dan Router (Skeleton)

**Files:**
- Create: `src/04_bsp/zbsp_color_panel/login/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/login/layout.htm.txt`
- Create: `src/04_bsp/zbsp_color_panel/login/oninputprocessing.abap.txt`
- Create: `src/04_bsp/zbsp_color_panel/main/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/main/layout.htm.txt`

**Interfaces:**
- Consumes: `_shared/head.htm.txt` dan `_shared/nav.htm.txt` dari Task 1
- Produces: halaman `login.htm` dan `main.htm`; pola atribut `gv_error` dan pola `navigation->goto_page( )` yang dipakai Task 3&ndash;6

- [ ] **Step 1: Tulis Page Attributes login**

`src/04_bsp/zbsp_color_panel/login/attributes.txt`:

```
Page Attributes untuk login.htm

Name        Type Ref    Associated Type    Auto
--------------------------------------------------
gv_error    TYPE        STRING             (kosong)
gv_user     TYPE        STRING             (kosong)
```

`gv_user` menyimpan kembali user id yang barusan diketik, supaya saat login gagal field-nya tidak kosong lagi dan user tidak perlu mengetik ulang.

- [ ] **Step 2: Tulis layout login**

`src/04_bsp/zbsp_color_panel/login/layout.htm.txt`:

```html
<%@page language="abap"%>
<html>
<head>
<title>Login &mdash; Color Panel</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"/>
<script>
tailwind.config = { theme: { extend: { colors: {
  navy: '#1E3A8A', navydark: '#1E293B', navylight: '#3B4E9E' } } } }
</script>
</head>
<body class="bg-slate-100 min-h-screen flex items-center justify-center">

<form method="post" class="bg-white rounded-xl shadow-lg w-full max-w-sm p-8">

  <div class="text-center mb-6">
    <div class="w-14 h-14 bg-navy rounded-xl mx-auto flex items-center justify-center mb-3">
      <i class="fa-solid fa-palette text-white text-2xl"></i>
    </div>
    <div class="text-xl font-bold text-slate-800">Color Panel</div>
    <div class="text-xs text-slate-500">PT. Kayu Mebel Indonesia</div>
  </div>

  <% IF gv_error IS NOT INITIAL. %>
  <div class="mb-4 px-3 py-2 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700">
    <i class="fa-solid fa-circle-exclamation"></i> <%= gv_error %>
  </div>
  <% ENDIF. %>

  <label class="block text-sm font-medium text-slate-700 mb-1">User ID</label>
  <input type="text" name="user_id" value="<%= gv_user %>" autofocus
         class="w-full px-3 py-2 border border-slate-300 rounded-lg mb-4 focus:outline-none focus:ring-2 focus:ring-navy"/>

  <label class="block text-sm font-medium text-slate-700 mb-1">Password</label>
  <input type="password" name="password"
         class="w-full px-3 py-2 border border-slate-300 rounded-lg mb-6 focus:outline-none focus:ring-2 focus:ring-navy"/>

  <button type="submit" name="onInputProcessing" value="login"
          class="w-full bg-navy hover:bg-navylight text-white py-2 rounded-lg font-medium">
    Masuk
  </button>

</form>

</body>
</html>
```

- [ ] **Step 3: Tulis OnInputProcessing login &mdash; versi Tahap 1**

`src/04_bsp/zbsp_color_panel/login/oninputprocessing.abap.txt`:

```abap
DATA: lv_user TYPE string,
      lv_pass TYPE string.

lv_user = request->get_form_field( 'user_id' ).
lv_pass = request->get_form_field( 'password' ).

IF lv_user IS INITIAL AND lv_pass IS INITIAL.
  RETURN.
ENDIF.

TRANSLATE lv_user TO UPPER CASE.
gv_user = lv_user.

* TAHAP 1: belum ada ZCL_CP_AUTH. Kredensial apa pun diterima asal
* keduanya terisi, semata supaya navigasi ke main.htm bisa diuji.
* Task 15 mengganti seluruh blok ini dengan panggilan class.
IF lv_pass IS INITIAL.
  gv_error = 'Password wajib diisi'.
  RETURN.
ENDIF.

navigation->goto_page( 'main.htm' ).
```

Komentar itu wajib ditulis. Tanpa penanda eksplisit, kode yang menerima password apa pun mudah lolos ke tahap berikutnya tanpa ada yang sadar.

- [ ] **Step 4: Buat halaman login.htm di SE80**

SE80 &rarr; klik kanan node **Pages** di bawah `ZBSP_COLOR_PANEL` &rarr; Create &rarr; Page.

```
Page Name    : login.htm
Description  : Halaman Login Color Panel
Page Type    : Page with Flow Logic
```

Setelah halaman terbuka: tab **Properties** &rarr; centang **Stateful**. Simpan.

Tab **Page Attributes** &rarr; isi `gv_error` dan `gv_user` sesuai `attributes.txt`.
Tab **Layout** &rarr; paste isi `layout.htm.txt`.
Tab **Event Handler** &rarr; pilih `OnInputProcessing` &rarr; paste isi `oninputprocessing.abap.txt`.

Aktifkan (Ctrl+F3).

Expected: aktivasi sukses tanpa error. Kalau muncul error tentang karakter tidak dikenal, cari karakter non-ASCII yang lolos &mdash; biasanya tanda kutip melengkung hasil copy-paste dari dokumen.

- [ ] **Step 5: Tulis Page Attributes dan layout main.htm**

`src/04_bsp/zbsp_color_panel/main/attributes.txt`:

```
Page Attributes untuk main.htm

Name          Type Ref    Associated Type    Auto
----------------------------------------------------
gv_user_name  TYPE        STRING             (kosong)
gv_role       TYPE        STRING             (kosong)
```

`src/04_bsp/zbsp_color_panel/main/layout.htm.txt`:

```html
<%@page language="abap"%>
<html>
<head>
<title>Dashboard &mdash; Color Panel</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"/>
<script>
tailwind.config = { theme: { extend: { colors: {
  navy: '#1E3A8A', navydark: '#1E293B', navylight: '#3B4E9E' } } } }
</script>
</head>
<body class="bg-slate-100">
<div class="flex">

<aside class="w-64 bg-navydark text-white flex flex-col min-h-screen">
  <div class="px-5 py-5 border-b border-white border-opacity-10">
    <div class="text-lg font-bold">Color Panel</div>
    <div class="text-xs text-gray-400">PT. Kayu Mebel Indonesia</div>
  </div>
  <nav class="flex-1 py-3">
    <a href="main.htm" class="flex items-center gap-3 px-5 py-2 text-sm bg-navy text-white">
      <i class="fa-solid fa-gauge w-4"></i> Dashboard
    </a>
    <a href="req_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-envelope-open-text w-4"></i> Request DCP
    </a>
    <a href="dcp_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-flask w-4"></i> DCP
    </a>
    <a href="admin_user.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-users w-4"></i> User
    </a>
  </nav>
  <div class="px-5 py-4 border-t border-white border-opacity-10">
    <a href="login.htm" class="block text-center text-sm text-gray-300 hover:text-white">
      <i class="fa-solid fa-right-from-bracket"></i> Logout
    </a>
  </div>
</aside>

<main class="flex-1">
  <div class="bg-white border-b border-slate-200 px-8 py-5">
    <h1 class="text-2xl font-bold text-slate-800">Dashboard</h1>
    <p class="text-sm text-slate-500">Ringkasan Color Panel</p>
  </div>

  <div class="p-8">
    <div class="grid grid-cols-4 gap-5 mb-6">
      <div class="bg-white rounded-xl p-5 shadow-sm">
        <div class="text-2xl font-bold text-slate-800">0</div>
        <div class="text-xs text-slate-500">Request Pending</div>
      </div>
      <div class="bg-white rounded-xl p-5 shadow-sm">
        <div class="text-2xl font-bold text-slate-800">0</div>
        <div class="text-xs text-slate-500">DCP Open</div>
      </div>
      <div class="bg-white rounded-xl p-5 shadow-sm">
        <div class="text-2xl font-bold text-slate-800">0</div>
        <div class="text-xs text-slate-500">Panel Submitted</div>
      </div>
      <div class="bg-white rounded-xl p-5 shadow-sm">
        <div class="text-2xl font-bold text-slate-800">0</div>
        <div class="text-xs text-slate-500">DCP Expired</div>
      </div>
    </div>

    <div class="bg-white rounded-xl p-5 shadow-sm text-sm text-slate-500">
      Angka di atas masih hardcode. Task 15 menggantinya dengan hasil SELECT.
    </div>
  </div>
</main>

</div>
</body>
</html>
```

- [ ] **Step 6: Buat main.htm di SE80 dan uji navigasi**

Ulangi prosedur Step 4 untuk `main.htm` (Page with Flow Logic, Stateful), dengan Page Attributes dan Layout dari Step 5. Halaman ini belum punya event handler. Aktifkan.

Buka `http://<host>:<port>/sap/bc/bsp/sap/zbsp_color_panel/login.htm`

Expected: form login tampil dengan kartu putih di tengah dan ikon palet navy. Isi user id apa saja dan password apa saja &rarr; klik Masuk &rarr; berpindah ke `main.htm` yang menampilkan sidebar dan empat kartu statistik bernilai 0.

Uji juga jalur gagalnya: kosongkan password &rarr; klik Masuk &rarr; kotak merah "Password wajib diisi" muncul, dan user id yang tadi diketik masih ada di field-nya.

- [ ] **Step 7: Commit**

```bash
git add src/04_bsp/zbsp_color_panel/login/ src/04_bsp/zbsp_color_panel/main/
git commit -m "feat(bsp): halaman login dan main skeleton, navigasi antar halaman jalan"
```

---

### Task 3: Halaman Daftar Request dan Form Request (Skeleton)

**Files:**
- Create: `src/04_bsp/zbsp_color_panel/req_list/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/req_list/layout.htm.txt`
- Create: `src/04_bsp/zbsp_color_panel/req_form/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/req_form/layout.htm.txt`
- Create: `src/04_bsp/zbsp_color_panel/req_form/oninputprocessing.abap.txt`

**Interfaces:**
- Consumes: potongan sidebar dari Task 1; pola halaman dari Task 2
- Produces: halaman `req_list.htm` dan `req_form.htm`; nama field form `so_number` dan `remarks` yang dipakai Task 16

- [ ] **Step 1: Tulis Page Attributes req_list**

`src/04_bsp/zbsp_color_panel/req_list/attributes.txt`:

```
Page Attributes untuk req_list.htm

Name        Type Ref    Associated Type      Auto
------------------------------------------------------
gt_req      TYPE        ZCP_REQUEST_T        (kosong)
gv_role     TYPE        STRING               (kosong)
```

`ZCP_REQUEST_T` adalah table type dengan row type `ZCP_REQUEST`. Buat di SE11 &rarr; Data Type &rarr; Table Type sebelum mengisi atribut ini, kalau tidak aktivasi halaman akan gagal karena tipe tidak dikenal.

Di Tahap 1 `gt_req` sengaja dibiarkan kosong &mdash; layout menampilkan baris hardcode, bukan isi tabel internal ini. Atributnya tetap dideklarasikan sekarang supaya Task 16 tidak perlu mengubah tab Page Attributes lagi.

- [ ] **Step 2: Tulis layout req_list**

`src/04_bsp/zbsp_color_panel/req_list/layout.htm.txt`:

```html
<%@page language="abap"%>
<html>
<head>
<title>Request DCP &mdash; Color Panel</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"/>
<script>
tailwind.config = { theme: { extend: { colors: {
  navy: '#1E3A8A', navydark: '#1E293B', navylight: '#3B4E9E' } } } }
</script>
</head>
<body class="bg-slate-100">
<div class="flex">

<aside class="w-64 bg-navydark text-white flex flex-col min-h-screen">
  <div class="px-5 py-5 border-b border-white border-opacity-10">
    <div class="text-lg font-bold">Color Panel</div>
    <div class="text-xs text-gray-400">PT. Kayu Mebel Indonesia</div>
  </div>
  <nav class="flex-1 py-3">
    <a href="main.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-gauge w-4"></i> Dashboard
    </a>
    <a href="req_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm bg-navy text-white">
      <i class="fa-solid fa-envelope-open-text w-4"></i> Request DCP
    </a>
    <a href="dcp_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-flask w-4"></i> DCP
    </a>
    <a href="admin_user.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-users w-4"></i> User
    </a>
  </nav>
  <div class="px-5 py-4 border-t border-white border-opacity-10">
    <a href="login.htm" class="block text-center text-sm text-gray-300 hover:text-white">
      <i class="fa-solid fa-right-from-bracket"></i> Logout
    </a>
  </div>
</aside>

<main class="flex-1">
  <div class="bg-white border-b border-slate-200 px-8 py-5 flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-slate-800">Request DCP</h1>
      <p class="text-sm text-slate-500">Daftar permintaan pembuatan Color Panel</p>
    </div>
    <a href="req_form.htm" class="bg-navy hover:bg-navylight text-white px-4 py-2 rounded-lg text-sm font-medium">
      <i class="fa-solid fa-plus"></i> Request Baru
    </a>
  </div>

  <div class="p-8">
    <div class="bg-white rounded-xl shadow-sm overflow-hidden">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-slate-600">
          <tr>
            <th class="text-left px-5 py-3 font-semibold">Request ID</th>
            <th class="text-left px-5 py-3 font-semibold">Nomor SO</th>
            <th class="text-left px-5 py-3 font-semibold">Tanggal</th>
            <th class="text-left px-5 py-3 font-semibold">Status</th>
            <th class="text-left px-5 py-3 font-semibold">Aksi</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr>
            <td class="px-5 py-3 font-mono">REQ-2026-0001</td>
            <td class="px-5 py-3 font-mono">SO-2026-1001</td>
            <td class="px-5 py-3">01.07.2026</td>
            <td class="px-5 py-3">
              <span class="px-2 py-1 rounded text-xs bg-amber-100 text-amber-800">Pending</span>
            </td>
            <td class="px-5 py-3">
              <a href="req_detail.htm" class="text-navy hover:underline">Detail</a>
            </td>
          </tr>
          <tr>
            <td class="px-5 py-3 font-mono">REQ-2026-0002</td>
            <td class="px-5 py-3 font-mono">SO-2026-1002</td>
            <td class="px-5 py-3">05.07.2026</td>
            <td class="px-5 py-3">
              <span class="px-2 py-1 rounded text-xs bg-emerald-100 text-emerald-800">Approved</span>
            </td>
            <td class="px-5 py-3">
              <a href="req_detail.htm" class="text-navy hover:underline">Detail</a>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p class="mt-4 text-sm text-slate-500">
      Dua baris di atas masih hardcode. Task 16 menggantinya dengan loop atas <span class="font-mono">gt_req</span>.
    </p>
  </div>
</main>

</div>
</body>
</html>
```

- [ ] **Step 3: Tulis Page Attributes dan layout req_form**

`src/04_bsp/zbsp_color_panel/req_form/attributes.txt`:

```
Page Attributes untuk req_form.htm

Name          Type Ref    Associated Type      Auto
--------------------------------------------------------
gv_so_number  TYPE        STRING               (kosong)
gv_error      TYPE        STRING               (kosong)
gv_info       TYPE        STRING               (kosong)
gt_items      TYPE        ZCP_SO_ITEM_T        (kosong)
```

`ZCP_SO_ITEM_T` adalah table type baru yang harus dibuat di SE11. Row type-nya struktur `ZCP_S_SO_ITEM` yang juga harus dibuat, dengan field: `SO_ITEM` (POSNR), `MATNR` (MATNR), `MAKTX` (MAKTX), `MENGE` (MENGE_D, reference field `MEINS`), `MEINS` (MEINS), `ELIGIBLE` (CHAR1), `REASON` (STRING).

`ELIGIBLE` menyimpan `X` bila material itu belum punya Color Code, dan `REASON` menyimpan sebabnya bila tidak. Keduanya diisi `ZCL_CP_SO_READER` di Task 16; di Tahap 1 tidak ada yang mengisinya.

`src/04_bsp/zbsp_color_panel/req_form/layout.htm.txt`:

```html
<%@page language="abap"%>
<html>
<head>
<title>Request Baru &mdash; Color Panel</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"/>
<script>
tailwind.config = { theme: { extend: { colors: {
  navy: '#1E3A8A', navydark: '#1E293B', navylight: '#3B4E9E' } } } }
</script>
</head>
<body class="bg-slate-100">
<div class="flex">

<aside class="w-64 bg-navydark text-white flex flex-col min-h-screen">
  <div class="px-5 py-5 border-b border-white border-opacity-10">
    <div class="text-lg font-bold">Color Panel</div>
    <div class="text-xs text-gray-400">PT. Kayu Mebel Indonesia</div>
  </div>
  <nav class="flex-1 py-3">
    <a href="main.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-gauge w-4"></i> Dashboard
    </a>
    <a href="req_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm bg-navy text-white">
      <i class="fa-solid fa-envelope-open-text w-4"></i> Request DCP
    </a>
    <a href="dcp_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-flask w-4"></i> DCP
    </a>
    <a href="admin_user.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-users w-4"></i> User
    </a>
  </nav>
  <div class="px-5 py-4 border-t border-white border-opacity-10">
    <a href="login.htm" class="block text-center text-sm text-gray-300 hover:text-white">
      <i class="fa-solid fa-right-from-bracket"></i> Logout
    </a>
  </div>
</aside>

<main class="flex-1">
  <div class="bg-white border-b border-slate-200 px-8 py-5">
    <h1 class="text-2xl font-bold text-slate-800">Request DCP Baru</h1>
    <p class="text-sm text-slate-500">Masukkan nomor SO, lalu pilih material yang akan dibuatkan Color Panel</p>
  </div>

  <div class="p-8">
    <form method="post">

      <% IF gv_error IS NOT INITIAL. %>
      <div class="mb-4 px-4 py-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700">
        <i class="fa-solid fa-circle-exclamation"></i> <%= gv_error %>
      </div>
      <% ENDIF. %>

      <div class="bg-white rounded-xl shadow-sm p-5 mb-5">
        <label class="block text-sm font-medium text-slate-700 mb-1">Nomor Sales Order</label>
        <div class="flex gap-3">
          <input type="text" name="so_number" value="<%= gv_so_number %>"
                 class="flex-1 max-w-xs px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-navy"/>
          <button type="submit" name="onInputProcessing" value="lookup"
                  class="bg-slate-700 hover:bg-slate-800 text-white px-4 py-2 rounded-lg text-sm font-medium">
            <i class="fa-solid fa-magnifying-glass"></i> Cari SO
          </button>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-sm overflow-hidden mb-5">
        <table class="w-full text-sm">
          <thead class="bg-slate-50 text-slate-600">
            <tr>
              <th class="text-left px-5 py-3 font-semibold">Item</th>
              <th class="text-left px-5 py-3 font-semibold">Material</th>
              <th class="text-left px-5 py-3 font-semibold">Deskripsi</th>
              <th class="text-right px-5 py-3 font-semibold">Qty</th>
              <th class="text-left px-5 py-3 font-semibold">Kelayakan</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr>
              <td class="px-5 py-3 font-mono">000010</td>
              <td class="px-5 py-3 font-mono">MAT-C-00001</td>
              <td class="px-5 py-3">Panel Color Walnut Dark</td>
              <td class="px-5 py-3 text-right">15</td>
              <td class="px-5 py-3">
                <span class="px-2 py-1 rounded text-xs bg-emerald-100 text-emerald-800">Layak</span>
              </td>
            </tr>
            <tr>
              <td class="px-5 py-3 font-mono">000020</td>
              <td class="px-5 py-3 font-mono">MAT-C-00002</td>
              <td class="px-5 py-3">Panel Color Oak Natural</td>
              <td class="px-5 py-3 text-right">15</td>
              <td class="px-5 py-3">
                <span class="px-2 py-1 rounded text-xs bg-red-100 text-red-800">Sudah punya Color Code</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="bg-white rounded-xl shadow-sm p-5 mb-5">
        <label class="block text-sm font-medium text-slate-700 mb-1">Remarks</label>
        <textarea name="remarks" rows="3"
                  class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-navy"></textarea>
      </div>

      <div class="flex gap-3">
        <button type="submit" name="onInputProcessing" value="submit"
                class="bg-navy hover:bg-navylight text-white px-5 py-2 rounded-lg text-sm font-medium">
          <i class="fa-solid fa-paper-plane"></i> Submit Request
        </button>
        <a href="req_list.htm" class="bg-slate-200 hover:bg-slate-300 text-slate-700 px-5 py-2 rounded-lg text-sm font-medium">
          Batal
        </a>
      </div>

    </form>

    <p class="mt-4 text-sm text-slate-500">
      Dua baris material di atas masih hardcode. Task 16 menggantinya dengan hasil
      <span class="font-mono">ZCL_CP_SO_READER</span> atas VBAK/VBAP.
    </p>
  </div>
</main>

</div>
</body>
</html>
```

- [ ] **Step 4: Tulis OnInputProcessing req_form &mdash; versi Tahap 1**

`src/04_bsp/zbsp_color_panel/req_form/oninputprocessing.abap.txt`:

```abap
DATA: lv_event TYPE string.

lv_event = request->get_form_field( 'onInputProcessing' ).

gv_so_number = request->get_form_field( 'so_number' ).
TRANSLATE gv_so_number TO UPPER CASE.

CASE lv_event.

  WHEN 'lookup'.
*   TAHAP 1: belum ada ZCL_CP_SO_READER. Layout menampilkan dua baris
*   hardcode, jadi di sini cukup validasi nomor SO tidak kosong.
*   Task 16 mengganti blok ini dengan pembacaan VBAK/VBAP.
    IF gv_so_number IS INITIAL.
      gv_error = 'Nomor SO wajib diisi'.
    ELSE.
      CLEAR gv_error.
    ENDIF.

  WHEN 'submit'.
*   TAHAP 1: belum ada ZCL_CP_REQUEST. Langsung kembali ke daftar.
*   Task 16 mengganti blok ini dengan pembuatan request sungguhan.
    IF gv_so_number IS INITIAL.
      gv_error = 'Nomor SO wajib diisi'.
    ELSE.
      navigation->goto_page( 'req_list.htm' ).
    ENDIF.

ENDCASE.
```

- [ ] **Step 5: Buat table type di SE11**

SE11 &rarr; Data Type &rarr; `ZCP_REQUEST_T` &rarr; Create &rarr; Table Type. Row type: `ZCP_REQUEST`. Aktifkan.

SE11 &rarr; Data Type &rarr; `ZCP_S_SO_ITEM` &rarr; Create &rarr; Structure. Isi tujuh field sesuai Step 3.

Untuk field `MENGE` bertipe `MENGE_D`: buka tab **Currency/Quantity Fields**, baris MENGE, isi Reference table `ZCP_S_SO_ITEM` dan Ref. field `MEINS`. Tanpa ini aktivasi gagal dengan pesan "Quantity field MENGE requires a reference field". Aktifkan.

SE11 &rarr; Data Type &rarr; `ZCP_SO_ITEM_T` &rarr; Create &rarr; Table Type. Row type: `ZCP_S_SO_ITEM`. Aktifkan.

Expected: ketiga objek Active. `ZCP_S_SO_ITEM` punya tujuh field.

- [ ] **Step 6: Buat kedua halaman di SE80 dan uji**

Buat `req_list.htm` dan `req_form.htm` sebagai Page with Flow Logic, keduanya Stateful, dengan Page Attributes, Layout, dan Event Handler dari langkah di atas. Aktifkan keduanya.

Buka `req_list.htm`. Expected: tabel dua baris dengan badge Pending kuning dan Approved hijau; menu Request DCP tersorot di sidebar.

Klik **Request Baru**. Expected: pindah ke `req_form.htm`.

Kosongkan nomor SO, klik **Cari SO**. Expected: kotak merah "Nomor SO wajib diisi".

Isi nomor SO apa saja, klik **Submit Request**. Expected: kembali ke `req_list.htm`.

- [ ] **Step 7: Commit**

```bash
git add src/04_bsp/zbsp_color_panel/req_list/ src/04_bsp/zbsp_color_panel/req_form/
git commit -m "feat(bsp): halaman req_list dan req_form skeleton beserta table type ZCP_SO_ITEM_T"
```

---

### Task 4: Halaman Approval Admin (Skeleton)

**Files:**
- Create: `src/04_bsp/zbsp_color_panel/req_detail/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/req_detail/layout.htm.txt`
- Create: `src/04_bsp/zbsp_color_panel/req_detail/oninputprocessing.abap.txt`

**Interfaces:**
- Consumes: pola halaman dari Task 3
- Produces: halaman `req_detail.htm`; nama field form `sel_<so_item>` dan `reason_<so_item>` yang dipakai Task 17

Halaman inilah yang membedakan sistem sebenarnya dari prototype. Prototype membatalkan seluruh approve begitu satu material bentrok; di sini Admin memutuskan **per item**, sehingga satu material yang gagal tidak menjatuhkan material lain yang sah.

- [ ] **Step 1: Tulis Page Attributes**

`src/04_bsp/zbsp_color_panel/req_detail/attributes.txt`:

```
Page Attributes untuk req_detail.htm

Name          Type Ref    Associated Type       Auto
---------------------------------------------------------
gv_request_id TYPE        ZCP_DE_REQUEST_ID     X
gv_error      TYPE        STRING                (kosong)
gt_items      TYPE        ZCP_REQUEST_ITM_T     (kosong)
gt_result     TYPE        ZCP_APPROVE_RES_T     (kosong)
```

Kolom Auto dicentang untuk `gv_request_id` supaya nilainya terisi otomatis dari parameter URL `?gv_request_id=REQ-2026-0001`. Ini cara BSP menerima parameter tanpa menulis kode.

`ZCP_REQUEST_ITM_T`: table type dengan row type `ZCP_REQUEST_ITM`.
`ZCP_APPROVE_RES_T`: table type dengan row type struktur `ZCP_S_APPROVE_RES` berisi `SO_ITEM` (POSNR), `MATNR` (MATNR), `SUCCESS` (CHAR1), `MESSAGE` (STRING). Struktur ini yang membuat hasil per item bisa ditampilkan kembali &mdash; dengan partial approve, satu klik bisa menghasilkan sebagian sukses dan sebagian gagal.

- [ ] **Step 2: Tulis layout**

`src/04_bsp/zbsp_color_panel/req_detail/layout.htm.txt`:

```html
<%@page language="abap"%>
<html>
<head>
<title>Approval Request &mdash; Color Panel</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"/>
<script>
tailwind.config = { theme: { extend: { colors: {
  navy: '#1E3A8A', navydark: '#1E293B', navylight: '#3B4E9E' } } } }
</script>
</head>
<body class="bg-slate-100">
<div class="flex">

<aside class="w-64 bg-navydark text-white flex flex-col min-h-screen">
  <div class="px-5 py-5 border-b border-white border-opacity-10">
    <div class="text-lg font-bold">Color Panel</div>
    <div class="text-xs text-gray-400">PT. Kayu Mebel Indonesia</div>
  </div>
  <nav class="flex-1 py-3">
    <a href="main.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-gauge w-4"></i> Dashboard
    </a>
    <a href="req_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm bg-navy text-white">
      <i class="fa-solid fa-envelope-open-text w-4"></i> Request DCP
    </a>
    <a href="dcp_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-flask w-4"></i> DCP
    </a>
    <a href="admin_user.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-users w-4"></i> User
    </a>
  </nav>
  <div class="px-5 py-4 border-t border-white border-opacity-10">
    <a href="login.htm" class="block text-center text-sm text-gray-300 hover:text-white">
      <i class="fa-solid fa-right-from-bracket"></i> Logout
    </a>
  </div>
</aside>

<main class="flex-1">
  <div class="bg-white border-b border-slate-200 px-8 py-5">
    <h1 class="text-2xl font-bold text-slate-800">Approval Request</h1>
    <p class="text-sm text-slate-500">
      Request <span class="font-mono">REQ-2026-0001</span> &mdash; SO <span class="font-mono">SO-2026-1001</span>
    </p>
  </div>

  <div class="p-8">
    <form method="post">

      <div class="mb-4 px-4 py-3 rounded-lg bg-blue-50 border border-blue-200 text-sm text-blue-800">
        <i class="fa-solid fa-circle-info"></i>
        Centang material yang hendak diputuskan, lalu tekan Approve atau Reject.
        Material yang tidak dicentang tidak berubah statusnya.
      </div>

      <div class="bg-white rounded-xl shadow-sm overflow-hidden mb-5">
        <table class="w-full text-sm">
          <thead class="bg-slate-50 text-slate-600">
            <tr>
              <th class="px-5 py-3 w-10"></th>
              <th class="text-left px-5 py-3 font-semibold">Item</th>
              <th class="text-left px-5 py-3 font-semibold">Material</th>
              <th class="text-left px-5 py-3 font-semibold">Deskripsi</th>
              <th class="text-right px-5 py-3 font-semibold">Qty</th>
              <th class="text-left px-5 py-3 font-semibold">Status</th>
              <th class="text-left px-5 py-3 font-semibold">Alasan bila ditolak</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr>
              <td class="px-5 py-3 text-center">
                <input type="checkbox" name="sel_000010" value="X" class="w-4 h-4"/>
              </td>
              <td class="px-5 py-3 font-mono">000010</td>
              <td class="px-5 py-3 font-mono">MAT-C-00001</td>
              <td class="px-5 py-3">Panel Color Walnut Dark</td>
              <td class="px-5 py-3 text-right">15</td>
              <td class="px-5 py-3">
                <span class="px-2 py-1 rounded text-xs bg-amber-100 text-amber-800">Pending</span>
              </td>
              <td class="px-5 py-3">
                <input type="text" name="reason_000010"
                       class="w-full px-2 py-1 border border-slate-300 rounded text-xs"/>
              </td>
            </tr>
            <tr>
              <td class="px-5 py-3 text-center">
                <input type="checkbox" name="sel_000020" value="X" class="w-4 h-4"/>
              </td>
              <td class="px-5 py-3 font-mono">000020</td>
              <td class="px-5 py-3 font-mono">MAT-C-00002</td>
              <td class="px-5 py-3">Panel Color Oak Natural</td>
              <td class="px-5 py-3 text-right">15</td>
              <td class="px-5 py-3">
                <span class="px-2 py-1 rounded text-xs bg-amber-100 text-amber-800">Pending</span>
              </td>
              <td class="px-5 py-3">
                <input type="text" name="reason_000020"
                       class="w-full px-2 py-1 border border-slate-300 rounded text-xs"/>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="flex gap-3">
        <button type="submit" name="onInputProcessing" value="approve"
                class="bg-emerald-600 hover:bg-emerald-700 text-white px-5 py-2 rounded-lg text-sm font-medium">
          <i class="fa-solid fa-check"></i> Approve Terpilih
        </button>
        <button type="submit" name="onInputProcessing" value="reject"
                class="bg-red-600 hover:bg-red-700 text-white px-5 py-2 rounded-lg text-sm font-medium">
          <i class="fa-solid fa-xmark"></i> Reject Terpilih
        </button>
        <a href="req_list.htm" class="bg-slate-200 hover:bg-slate-300 text-slate-700 px-5 py-2 rounded-lg text-sm font-medium">
          Kembali
        </a>
      </div>

    </form>

    <p class="mt-4 text-sm text-slate-500">
      Dua baris di atas masih hardcode. Task 17 menggantinya dengan loop atas
      <span class="font-mono">gt_items</span> dan menampilkan hasil per item di
      <span class="font-mono">gt_result</span>.
    </p>
  </div>
</main>

</div>
</body>
</html>
```

- [ ] **Step 3: Tulis OnInputProcessing &mdash; versi Tahap 1**

`src/04_bsp/zbsp_color_panel/req_detail/oninputprocessing.abap.txt`:

```abap
DATA: lv_event TYPE string,
      lv_sel1  TYPE string,
      lv_sel2  TYPE string,
      lv_cnt   TYPE i.

lv_event = request->get_form_field( 'onInputProcessing' ).

lv_sel1 = request->get_form_field( 'sel_000010' ).
lv_sel2 = request->get_form_field( 'sel_000020' ).

CLEAR lv_cnt.
IF lv_sel1 = 'X'.
  lv_cnt = lv_cnt + 1.
ENDIF.
IF lv_sel2 = 'X'.
  lv_cnt = lv_cnt + 1.
ENDIF.

IF lv_cnt = 0.
  gv_error = 'Centang minimal satu material'.
  RETURN.
ENDIF.

CLEAR gv_error.

* TAHAP 1: belum ada ZCL_CP_REQUEST. Nama checkbox sengaja dibaca satu per
* satu karena daftar item masih hardcode dua baris. Task 17 menggantinya
* dengan LOOP AT gt_items dan penyusunan nama field secara dinamis.
CASE lv_event.
  WHEN 'approve'.
    navigation->goto_page( 'dcp_list.htm' ).
  WHEN 'reject'.
    navigation->goto_page( 'req_list.htm' ).
ENDCASE.
```

- [ ] **Step 4: Buat struktur dan table type di SE11**

`ZCP_REQUEST_ITM_T` &mdash; Table Type, row type `ZCP_REQUEST_ITM`. Aktifkan.

`ZCP_S_APPROVE_RES` &mdash; Structure dengan empat field: `SO_ITEM` (POSNR), `MATNR` (MATNR), `SUCCESS` (CHAR1), `MESSAGE` (STRING). Aktifkan.

`ZCP_APPROVE_RES_T` &mdash; Table Type, row type `ZCP_S_APPROVE_RES`. Aktifkan.

- [ ] **Step 5: Buat halaman di SE80 dan uji**

Buat `req_detail.htm` sebagai Page with Flow Logic, Stateful. Aktifkan.

Buka `req_list.htm` &rarr; klik **Detail** pada baris pertama. Expected: pindah ke `req_detail.htm` dengan tabel dua baris bercheckbox.

Tanpa mencentang apa pun, klik **Approve Terpilih**. Expected: pesan "Centang minimal satu material" &mdash; catat bahwa di Tahap 1 pesan ini belum tampil di layar karena layout belum menampilkan `gv_error`; verifikasi lewat debugger atau tambahkan sementara `<%= gv_error %>` di layout. Task 17 menambahkan blok tampilan error permanen.

Centang salah satu, klik **Approve Terpilih**. Expected: pindah ke `dcp_list.htm` (halamannya belum ada sampai Task 5 &mdash; error 404 di titik ini wajar dan hilang setelah Task 5).

- [ ] **Step 6: Commit**

```bash
git add src/04_bsp/zbsp_color_panel/req_detail/
git commit -m "feat(bsp): halaman req_detail skeleton dengan checkbox partial approve per item"
```

---

### Task 5: Halaman Daftar dan Detail DCP (Skeleton)

**Files:**
- Create: `src/04_bsp/zbsp_color_panel/dcp_list/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/dcp_list/layout.htm.txt`
- Create: `src/04_bsp/zbsp_color_panel/dcp_detail/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/dcp_detail/layout.htm.txt`
- Create: `src/04_bsp/zbsp_color_panel/dcp_detail/oninputprocessing.abap.txt`

**Interfaces:**
- Consumes: pola halaman dari Task 3
- Produces: halaman `dcp_list.htm` dan `dcp_detail.htm`; nama field form `panel_number`, `mfg_date`, dan nilai event `activate`/`submit`/`approve`/`reject`/`undo`/`close` yang dipakai Task 18 dan 19

- [ ] **Step 1: Tulis Page Attributes kedua halaman**

`src/04_bsp/zbsp_color_panel/dcp_list/attributes.txt`:

```
Page Attributes untuk dcp_list.htm

Name          Type Ref    Associated Type     Auto
-------------------------------------------------------
gt_dcp        TYPE        ZCP_DCP_HDR_T       (kosong)
gv_filter     TYPE        STRING              X
```

`src/04_bsp/zbsp_color_panel/dcp_detail/attributes.txt`:

```
Page Attributes untuk dcp_detail.htm

Name          Type Ref    Associated Type     Auto
-------------------------------------------------------
gv_dcp_id     TYPE        ZCP_DE_DCP_ID       X
gs_hdr        TYPE        ZCP_DCP_HDR         (kosong)
gt_panel      TYPE        ZCP_DCP_ITEM_T      (kosong)
gv_error      TYPE        STRING              (kosong)
gv_info       TYPE        STRING              (kosong)
```

Table type yang perlu dibuat di SE11: `ZCP_DCP_HDR_T` (row type `ZCP_DCP_HDR`) dan `ZCP_DCP_ITEM_T` (row type `ZCP_DCP_ITEM`).

- [ ] **Step 2: Tulis layout dcp_list**

`src/04_bsp/zbsp_color_panel/dcp_list/layout.htm.txt`:

```html
<%@page language="abap"%>
<html>
<head>
<title>DCP &mdash; Color Panel</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"/>
<script>
tailwind.config = { theme: { extend: { colors: {
  navy: '#1E3A8A', navydark: '#1E293B', navylight: '#3B4E9E' } } } }
</script>
</head>
<body class="bg-slate-100">
<div class="flex">

<aside class="w-64 bg-navydark text-white flex flex-col min-h-screen">
  <div class="px-5 py-5 border-b border-white border-opacity-10">
    <div class="text-lg font-bold">Color Panel</div>
    <div class="text-xs text-gray-400">PT. Kayu Mebel Indonesia</div>
  </div>
  <nav class="flex-1 py-3">
    <a href="main.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-gauge w-4"></i> Dashboard
    </a>
    <a href="req_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-envelope-open-text w-4"></i> Request DCP
    </a>
    <a href="dcp_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm bg-navy text-white">
      <i class="fa-solid fa-flask w-4"></i> DCP
    </a>
    <a href="admin_user.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-users w-4"></i> User
    </a>
  </nav>
  <div class="px-5 py-4 border-t border-white border-opacity-10">
    <a href="login.htm" class="block text-center text-sm text-gray-300 hover:text-white">
      <i class="fa-solid fa-right-from-bracket"></i> Logout
    </a>
  </div>
</aside>

<main class="flex-1">
  <div class="bg-white border-b border-slate-200 px-8 py-5">
    <h1 class="text-2xl font-bold text-slate-800">DCP</h1>
    <p class="text-sm text-slate-500">Development Color Panel</p>
  </div>

  <div class="p-8">
    <div class="bg-white rounded-xl shadow-sm overflow-hidden">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-slate-600">
          <tr>
            <th class="text-left px-5 py-3 font-semibold">DCP ID</th>
            <th class="text-left px-5 py-3 font-semibold">Color Code</th>
            <th class="text-left px-5 py-3 font-semibold">Material</th>
            <th class="text-right px-5 py-3 font-semibold">Panel</th>
            <th class="text-left px-5 py-3 font-semibold">Status</th>
            <th class="text-left px-5 py-3 font-semibold">Aksi</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr>
            <td class="px-5 py-3 font-mono">DCP-2026-0001</td>
            <td class="px-5 py-3 font-mono">KW00001</td>
            <td class="px-5 py-3">Panel Color Walnut Dark</td>
            <td class="px-5 py-3 text-right">15</td>
            <td class="px-5 py-3">
              <span class="px-2 py-1 rounded text-xs bg-blue-100 text-blue-800">Open</span>
            </td>
            <td class="px-5 py-3">
              <a href="dcp_detail.htm" class="text-navy hover:underline">Detail</a>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p class="mt-4 text-sm text-slate-500">
      Baris di atas masih hardcode. Task 18 menggantinya dengan loop atas <span class="font-mono">gt_dcp</span>.
    </p>
  </div>
</main>

</div>
</body>
</html>
```

- [ ] **Step 3: Tulis layout dcp_detail**

`src/04_bsp/zbsp_color_panel/dcp_detail/layout.htm.txt`:

```html
<%@page language="abap"%>
<html>
<head>
<title>Detail DCP &mdash; Color Panel</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"/>
<script>
tailwind.config = { theme: { extend: { colors: {
  navy: '#1E3A8A', navydark: '#1E293B', navylight: '#3B4E9E' } } } }
</script>
</head>
<body class="bg-slate-100">
<div class="flex">

<aside class="w-64 bg-navydark text-white flex flex-col min-h-screen">
  <div class="px-5 py-5 border-b border-white border-opacity-10">
    <div class="text-lg font-bold">Color Panel</div>
    <div class="text-xs text-gray-400">PT. Kayu Mebel Indonesia</div>
  </div>
  <nav class="flex-1 py-3">
    <a href="main.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-gauge w-4"></i> Dashboard
    </a>
    <a href="req_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-envelope-open-text w-4"></i> Request DCP
    </a>
    <a href="dcp_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm bg-navy text-white">
      <i class="fa-solid fa-flask w-4"></i> DCP
    </a>
    <a href="admin_user.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-users w-4"></i> User
    </a>
  </nav>
  <div class="px-5 py-4 border-t border-white border-opacity-10">
    <a href="login.htm" class="block text-center text-sm text-gray-300 hover:text-white">
      <i class="fa-solid fa-right-from-bracket"></i> Logout
    </a>
  </div>
</aside>

<main class="flex-1">
  <div class="bg-white border-b border-slate-200 px-8 py-5 flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-slate-800">DCP-2026-0001</h1>
      <p class="text-sm text-slate-500">KW00001 &mdash; Panel Color Walnut Dark</p>
    </div>
    <form method="post" class="flex gap-3">
      <button type="submit" name="onInputProcessing" value="close"
              class="bg-emerald-600 hover:bg-emerald-700 text-white px-4 py-2 rounded-lg text-sm font-medium">
        <i class="fa-solid fa-lock"></i> Close DCP
      </button>
      <a href="dcp_list.htm" class="bg-slate-200 hover:bg-slate-300 text-slate-700 px-4 py-2 rounded-lg text-sm font-medium">
        Kembali
      </a>
    </form>
  </div>

  <div class="p-8">

    <div class="bg-white rounded-xl shadow-sm p-5 mb-6">
      <div class="grid grid-cols-4 gap-5 text-sm">
        <div>
          <div class="text-slate-500 text-xs">Nomor SO</div>
          <div class="font-mono">SO-2026-1001</div>
        </div>
        <div>
          <div class="text-slate-500 text-xs">Buyer</div>
          <div>Ashley Furniture Ltd.</div>
        </div>
        <div>
          <div class="text-slate-500 text-xs">Tanggal Dibuat</div>
          <div>01.08.2026</div>
        </div>
        <div>
          <div class="text-slate-500 text-xs">Expired</div>
          <div>01.08.2027</div>
        </div>
      </div>
    </div>

    <div class="bg-white rounded-xl shadow-sm p-5">
      <div class="flex items-center justify-between mb-4">
        <h2 class="font-bold text-slate-800">Panel Grid</h2>
        <div class="text-xs text-slate-500">
          NA Non-Aktif &#8226; AK Aktif &#8226; SB Submitted &#8226; AP Approved &#8226; RJ Rejected
        </div>
      </div>

      <div class="grid grid-cols-5 gap-3">

        <form method="post" class="border border-slate-200 rounded-lg p-3">
          <div class="text-xs text-slate-500 mb-1">Panel #01</div>
          <div class="font-mono text-xs mb-2">DCP-2026-0001-01</div>
          <span class="inline-block px-2 py-1 rounded text-xs bg-slate-100 text-slate-700 mb-2">NA</span>
          <input type="hidden" name="panel_number" value="1"/>
          <input type="date" name="mfg_date"
                 class="w-full px-2 py-1 border border-slate-300 rounded text-xs mb-2"/>
          <button type="submit" name="onInputProcessing" value="activate"
                  class="w-full bg-navy hover:bg-navylight text-white py-1 rounded text-xs">
            Aktivasi
          </button>
        </form>

        <form method="post" class="border border-slate-200 rounded-lg p-3">
          <div class="text-xs text-slate-500 mb-1">Panel #02</div>
          <div class="font-mono text-xs mb-2">DCP-2026-0001-02</div>
          <span class="inline-block px-2 py-1 rounded text-xs bg-blue-100 text-blue-800 mb-2">AK</span>
          <input type="hidden" name="panel_number" value="2"/>
          <button type="submit" name="onInputProcessing" value="submit"
                  class="w-full bg-amber-500 hover:bg-amber-600 text-white py-1 rounded text-xs">
            Submit
          </button>
        </form>

        <form method="post" class="border border-slate-200 rounded-lg p-3">
          <div class="text-xs text-slate-500 mb-1">Panel #03</div>
          <div class="font-mono text-xs mb-2">DCP-2026-0001-03</div>
          <span class="inline-block px-2 py-1 rounded text-xs bg-amber-100 text-amber-800 mb-2">SB</span>
          <input type="hidden" name="panel_number" value="3"/>
          <div class="flex gap-1">
            <button type="submit" name="onInputProcessing" value="approve"
                    class="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white py-1 rounded text-xs">
              Approve
            </button>
            <button type="submit" name="onInputProcessing" value="reject"
                    class="flex-1 bg-red-600 hover:bg-red-700 text-white py-1 rounded text-xs">
              Reject
            </button>
          </div>
        </form>

        <form method="post" class="border border-slate-200 rounded-lg p-3">
          <div class="text-xs text-slate-500 mb-1">Panel #04</div>
          <div class="font-mono text-xs mb-2">DCP-2026-0001-04</div>
          <span class="inline-block px-2 py-1 rounded text-xs bg-emerald-100 text-emerald-800 mb-2">AP</span>
          <input type="hidden" name="panel_number" value="4"/>
          <div class="text-xs text-slate-400">Tidak ada aksi</div>
        </form>

        <form method="post" class="border border-slate-200 rounded-lg p-3">
          <div class="text-xs text-slate-500 mb-1">Panel #05</div>
          <div class="font-mono text-xs mb-2">DCP-2026-0001-05</div>
          <span class="inline-block px-2 py-1 rounded text-xs bg-red-100 text-red-800 mb-2">RJ</span>
          <input type="hidden" name="panel_number" value="5"/>
          <button type="submit" name="onInputProcessing" value="undo"
                  class="w-full bg-slate-600 hover:bg-slate-700 text-white py-1 rounded text-xs">
            Undo
          </button>
        </form>

      </div>
    </div>

    <p class="mt-4 text-sm text-slate-500">
      Lima kartu di atas mewakili lima status panel dan masih hardcode.
      Task 19 menggantinya dengan loop atas <span class="font-mono">gt_panel</span>,
      dengan tombol yang muncul menyesuaikan status tiap panel.
    </p>

  </div>
</main>

</div>
</body>
</html>
```

Kelima kartu sengaja mewakili kelima status berbeda, bukan lima panel yang sama. Dengan begitu markup untuk setiap cabang status sudah ada dan teruji tampilannya sebelum Task 19 menyambungkannya ke data nyata.

- [ ] **Step 4: Tulis OnInputProcessing dcp_detail &mdash; versi Tahap 1**

`src/04_bsp/zbsp_color_panel/dcp_detail/oninputprocessing.abap.txt`:

```abap
DATA: lv_event  TYPE string,
      lv_panel  TYPE string,
      lv_mfg    TYPE string.

lv_event = request->get_form_field( 'onInputProcessing' ).
lv_panel = request->get_form_field( 'panel_number' ).
lv_mfg   = request->get_form_field( 'mfg_date' ).

CLEAR: gv_error, gv_info.

* TAHAP 1: belum ada ZCL_CP_DCP. Handler hanya memantulkan kembali aksi
* yang diterima supaya penamaan field form dan nilai event terbukti
* sampai ke server dengan benar. Task 19 mengganti seluruh CASE ini
* dengan panggilan method yang sesuai.
CASE lv_event.
  WHEN 'activate'.
    IF lv_mfg IS INITIAL.
      gv_error = 'Tanggal manufaktur wajib diisi'.
    ELSE.
      CONCATENATE 'Aktivasi panel' lv_panel 'tanggal' lv_mfg
             INTO gv_info SEPARATED BY space.
    ENDIF.
  WHEN 'submit'.
    CONCATENATE 'Submit panel' lv_panel INTO gv_info SEPARATED BY space.
  WHEN 'approve'.
    CONCATENATE 'Approve panel' lv_panel INTO gv_info SEPARATED BY space.
  WHEN 'reject'.
    CONCATENATE 'Reject panel' lv_panel INTO gv_info SEPARATED BY space.
  WHEN 'undo'.
    CONCATENATE 'Undo panel' lv_panel INTO gv_info SEPARATED BY space.
  WHEN 'close'.
    gv_info = 'Close DCP header'.
ENDCASE.
```

- [ ] **Step 5: Tambahkan blok tampilan pesan di layout dcp_detail**

Sisipkan tepat setelah `<div class="p-8">` di `layout.htm.txt`:

```html
    <% IF gv_error IS NOT INITIAL. %>
    <div class="mb-4 px-4 py-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700">
      <i class="fa-solid fa-circle-exclamation"></i> <%= gv_error %>
    </div>
    <% ENDIF. %>

    <% IF gv_info IS NOT INITIAL. %>
    <div class="mb-4 px-4 py-3 rounded-lg bg-blue-50 border border-blue-200 text-sm text-blue-800">
      <i class="fa-solid fa-circle-info"></i> <%= gv_info %>
    </div>
    <% ENDIF. %>
```

Tanpa blok ini, Step 4 tidak bisa diverifikasi &mdash; handler mengisi `gv_info` tapi tidak ada yang menampilkannya.

- [ ] **Step 6: Buat table type dan kedua halaman, lalu uji tiap tombol**

SE11: buat `ZCP_DCP_HDR_T` dan `ZCP_DCP_ITEM_T`, aktifkan.

SE80: buat `dcp_list.htm` dan `dcp_detail.htm`, keduanya Page with Flow Logic dan Stateful. Aktifkan.

Buka `dcp_list.htm` &rarr; klik **Detail**. Expected: halaman detail dengan lima kartu panel berwarna berbeda.

Uji satu per satu, setiap kali memeriksa kotak biru yang muncul:

| Aksi | Expected |
|---|---|
| Panel #01, kosongkan tanggal, klik Aktivasi | Kotak merah "Tanggal manufaktur wajib diisi" |
| Panel #01, isi tanggal, klik Aktivasi | Kotak biru "Aktivasi panel 1 tanggal 2026-08-06" |
| Panel #02 Submit | "Submit panel 2" |
| Panel #03 Approve | "Approve panel 3" |
| Panel #03 Reject | "Reject panel 3" |
| Panel #05 Undo | "Undo panel 5" |
| Close DCP di header | "Close DCP header" |

Kalau `panel_number` kembali kosong, penyebabnya hampir selalu tombol berada di luar `<form>` yang memuat input tersembunyinya. Tiap kartu punya `<form>` sendiri justru karena itu.

- [ ] **Step 7: Commit**

```bash
git add src/04_bsp/zbsp_color_panel/dcp_list/ src/04_bsp/zbsp_color_panel/dcp_detail/
git commit -m "feat(bsp): halaman dcp_list dan dcp_detail skeleton dengan lima varian status panel"
```

---

### Task 6: Halaman Maintenance User (Skeleton)

**Files:**
- Create: `src/04_bsp/zbsp_color_panel/admin_user/attributes.txt`
- Create: `src/04_bsp/zbsp_color_panel/admin_user/layout.htm.txt`
- Create: `src/04_bsp/zbsp_color_panel/admin_user/oninputprocessing.abap.txt`

**Interfaces:**
- Consumes: pola halaman dari Task 3
- Produces: halaman `admin_user.htm`; nama field form `user_id`, `full_name`, `role`, `password` yang dipakai Task 20

Halaman ini wajib ada dan tidak bisa digantikan SM30: SM30 tidak dapat meng-hash password, sehingga yang tersimpan akan berupa teks polos dan login selalu gagal.

- [ ] **Step 1: Tulis Page Attributes**

`src/04_bsp/zbsp_color_panel/admin_user/attributes.txt`:

```
Page Attributes untuk admin_user.htm

Name        Type Ref    Associated Type    Auto
----------------------------------------------------
gt_user     TYPE        ZCP_USER_T         (kosong)
gv_error    TYPE        STRING             (kosong)
gv_info     TYPE        STRING             (kosong)
```

`ZCP_USER_T` &mdash; Table Type di SE11, row type `ZCP_USER`.

- [ ] **Step 2: Tulis layout**

`src/04_bsp/zbsp_color_panel/admin_user/layout.htm.txt`:

```html
<%@page language="abap"%>
<html>
<head>
<title>User &mdash; Color Panel</title>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"/>
<script>
tailwind.config = { theme: { extend: { colors: {
  navy: '#1E3A8A', navydark: '#1E293B', navylight: '#3B4E9E' } } } }
</script>
</head>
<body class="bg-slate-100">
<div class="flex">

<aside class="w-64 bg-navydark text-white flex flex-col min-h-screen">
  <div class="px-5 py-5 border-b border-white border-opacity-10">
    <div class="text-lg font-bold">Color Panel</div>
    <div class="text-xs text-gray-400">PT. Kayu Mebel Indonesia</div>
  </div>
  <nav class="flex-1 py-3">
    <a href="main.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-gauge w-4"></i> Dashboard
    </a>
    <a href="req_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-envelope-open-text w-4"></i> Request DCP
    </a>
    <a href="dcp_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
      <i class="fa-solid fa-flask w-4"></i> DCP
    </a>
    <a href="admin_user.htm" class="flex items-center gap-3 px-5 py-2 text-sm bg-navy text-white">
      <i class="fa-solid fa-users w-4"></i> User
    </a>
  </nav>
  <div class="px-5 py-4 border-t border-white border-opacity-10">
    <a href="login.htm" class="block text-center text-sm text-gray-300 hover:text-white">
      <i class="fa-solid fa-right-from-bracket"></i> Logout
    </a>
  </div>
</aside>

<main class="flex-1">
  <div class="bg-white border-b border-slate-200 px-8 py-5">
    <h1 class="text-2xl font-bold text-slate-800">Master User</h1>
    <p class="text-sm text-slate-500">Password di-hash SHA256 sebelum disimpan</p>
  </div>

  <div class="p-8">

    <% IF gv_error IS NOT INITIAL. %>
    <div class="mb-4 px-4 py-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700">
      <i class="fa-solid fa-circle-exclamation"></i> <%= gv_error %>
    </div>
    <% ENDIF. %>

    <% IF gv_info IS NOT INITIAL. %>
    <div class="mb-4 px-4 py-3 rounded-lg bg-blue-50 border border-blue-200 text-sm text-blue-800">
      <i class="fa-solid fa-circle-info"></i> <%= gv_info %>
    </div>
    <% ENDIF. %>

    <form method="post" class="bg-white rounded-xl shadow-sm p-5 mb-6">
      <h2 class="font-bold text-slate-800 mb-4">Tambah User</h2>
      <div class="grid grid-cols-4 gap-4 mb-4">
        <div>
          <label class="block text-xs text-slate-500 mb-1">User ID</label>
          <input type="text" name="user_id"
                 class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm"/>
        </div>
        <div>
          <label class="block text-xs text-slate-500 mb-1">Nama Lengkap</label>
          <input type="text" name="full_name"
                 class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm"/>
        </div>
        <div>
          <label class="block text-xs text-slate-500 mb-1">Role</label>
          <select name="role" class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm">
            <option value="SALES">SALES</option>
            <option value="ADMIN">ADMIN</option>
            <option value="QC">QC</option>
            <option value="IT">IT</option>
          </select>
        </div>
        <div>
          <label class="block text-xs text-slate-500 mb-1">Password</label>
          <input type="password" name="password"
                 class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm"/>
        </div>
      </div>
      <button type="submit" name="onInputProcessing" value="create"
              class="bg-navy hover:bg-navylight text-white px-5 py-2 rounded-lg text-sm font-medium">
        <i class="fa-solid fa-plus"></i> Simpan User
      </button>
    </form>

    <div class="bg-white rounded-xl shadow-sm overflow-hidden">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-slate-600">
          <tr>
            <th class="text-left px-5 py-3 font-semibold">User ID</th>
            <th class="text-left px-5 py-3 font-semibold">Nama Lengkap</th>
            <th class="text-left px-5 py-3 font-semibold">Role</th>
            <th class="text-left px-5 py-3 font-semibold">Aktif</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr>
            <td class="px-5 py-3 font-mono">ARYA</td>
            <td class="px-5 py-3">Arya Nugraha</td>
            <td class="px-5 py-3">IT</td>
            <td class="px-5 py-3">&#10003;</td>
          </tr>
        </tbody>
      </table>
    </div>

    <p class="mt-4 text-sm text-slate-500">
      Baris di atas masih hardcode. Task 20 menggantinya dengan loop atas
      <span class="font-mono">gt_user</span> dan menyimpan lewat
      <span class="font-mono">ZCL_CP_AUTH=&gt;hash_password( )</span>.
    </p>

  </div>
</main>

</div>
</body>
</html>
```

- [ ] **Step 3: Tulis OnInputProcessing &mdash; versi Tahap 1**

`src/04_bsp/zbsp_color_panel/admin_user/oninputprocessing.abap.txt`:

```abap
DATA: lv_event TYPE string,
      lv_user  TYPE string,
      lv_name  TYPE string,
      lv_role  TYPE string,
      lv_pass  TYPE string.

lv_event = request->get_form_field( 'onInputProcessing' ).

CLEAR: gv_error, gv_info.

IF lv_event <> 'create'.
  RETURN.
ENDIF.

lv_user = request->get_form_field( 'user_id' ).
lv_name = request->get_form_field( 'full_name' ).
lv_role = request->get_form_field( 'role' ).
lv_pass = request->get_form_field( 'password' ).

TRANSLATE lv_user TO UPPER CASE.

IF lv_user IS INITIAL OR lv_name IS INITIAL OR lv_pass IS INITIAL.
  gv_error = 'User ID, Nama Lengkap, dan Password wajib diisi'.
  RETURN.
ENDIF.

* TAHAP 1: belum ada ZCL_CP_AUTH, jadi password TIDAK di-hash dan user
* TIDAK disimpan ke ZCP_USER. Halaman ini sengaja belum menulis apa pun
* ke database supaya tidak ada baris berpassword polos yang tertinggal.
* Task 20 mengganti blok ini dengan hash_password( ) + INSERT.
CONCATENATE 'Validasi lolos untuk user' lv_user 'role' lv_role
       INTO gv_info SEPARATED BY space.
```

Keputusan untuk tidak menulis ke `ZCP_USER` sama sekali di Tahap 1 disengaja. Menyimpan password polos "sementara" adalah cara paling umum baris berbahaya bertahan sampai produksi.

- [ ] **Step 4: Buat table type dan halaman, lalu uji**

SE11: buat `ZCP_USER_T`, row type `ZCP_USER`. Aktifkan.

SE80: buat `admin_user.htm`, Page with Flow Logic, Stateful. Aktifkan.

Buka `admin_user.htm`. Kosongkan semua field, klik **Simpan User**. Expected: kotak merah "User ID, Nama Lengkap, dan Password wajib diisi".

Isi User ID `budi`, nama `Budi Santoso`, role ADMIN, password apa saja. Klik Simpan. Expected: kotak biru "Validasi lolos untuk user BUDI role ADMIN" &mdash; perhatikan user id sudah menjadi huruf besar.

Verifikasi lewat SE16N bahwa `ZCP_USER` **tidak** bertambah baris. Ini yang diharapkan di Tahap 1.

- [ ] **Step 5: Commit**

```bash
git add src/04_bsp/zbsp_color_panel/admin_user/
git commit -m "feat(bsp): halaman admin_user skeleton, belum menulis ke ZCP_USER"
```

- [ ] **Step 6: Tandai Tahap 1 selesai di report**

Perbarui `report/report.md`: tambahkan bagian baru "Sub-Proyek 1B &mdash; BSP Pages" dengan Task 1&ndash;6 berstatus selesai dan tanggalnya.

```bash
git add report/report.md
git commit -m "docs(report): Tahap 1 BSP selesai, delapan halaman aktif di SE80"
```

**Titik henti Tahap 1.** Delapan halaman hidup, navigasi lengkap, setiap tombol terbukti sampai ke server. Halaman ini sudah bisa ditunjukkan ke Yogi untuk validasi tata letak sebelum satu baris logic pun ditulis.

---

# TAHAP 2 &mdash; Fondasi DDIC dan ABAP Class

Tahap ini **tidak** menulis ulang isi `docs/superpowers/plans/2026-07-28-color-panel-foundation-dcp.md`. Dokumen itu sudah memuat kode lengkap tiap class beserta test class-nya, dan menyalinnya ke sini hanya akan melahirkan dua sumber kebenaran yang lambat laun berbeda isi.

Task 7&ndash;14 di bawah adalah penunjuk ke task di dokumen tersebut, dengan tambahan yang khusus berlaku karena Tahap 1 sudah berjalan.

| Task di sini | Task di plan 28 Juli | Isi |
|:---:|:---:|---|
| 7 | Task 3 Step 5d&ndash;5f | Interval SNRO, message class `ZCP` di SE91, TMG `ZCP_BUYER` |
| 8 | Task 4 | `ZCX_CP_ERROR` dan `ZCL_CP_NUMBER` (TDD, 5 test) |
| 9 | Task 5 | `ZCL_CP_AUDIT` |
| 10 | Task 6 | `ZCL_CP_AUTH` (TDD, 4 test) &mdash; hash SHA256, login, session, guard role |
| 11 | Task 7 | `ZCL_CP_SO_READER` dan report uji `ZCP_TEST_SO_READER` |
| 12 | Task 8 | `ZCL_CP_DCP` logic murni (TDD) &mdash; state machine dan perhitungan tanggal |
| 13 | Task 9 | `ZCL_CP_DCP` operasi database |
| 14 | Task 10 dan 11 | `ZCL_CP_PHOTO` dan `ZCL_CP_REQUEST` |

**Urutan wajib dipertahankan.** `ZCL_CP_NUMBER` butuh interval SNRO dari Task 7; `ZCL_CP_DCP` butuh `ZCL_CP_NUMBER` dan `ZCL_CP_AUDIT`; `ZCL_CP_REQUEST` butuh hampir semuanya.

**Satu hal yang berbeda karena Tahap 1 sudah jalan:** setiap kali sebuah class selesai dan Active, jangan langsung menyambungkannya ke halaman. Penyambungan seluruhnya dikerjakan di Tahap 3, satu halaman satu task, supaya kalau ada yang rusak jelas halaman mana penyebabnya.

- [ ] **Task 7:** Kerjakan Task 3 Step 5d-3, 5e, dan 5f di plan 28 Juli. Setelah selesai, perbarui `report/report.md` menandai Task 3 tuntas.
- [ ] **Task 8:** Kerjakan Task 4 di plan 28 Juli. Expected: 5 unit test hijau.
- [ ] **Task 9:** Kerjakan Task 5 di plan 28 Juli. Expected: `ZCP_AUDIT_LOG` bertambah baris dengan `ACTION_BY` berisi USER_ID, bukan `auto_email`.
- [ ] **Task 10:** Kerjakan Task 6 di plan 28 Juli. Expected: 4 unit test hijau, dan satu user uji `ARYA` role IT tersimpan dengan password ter-hash.
- [ ] **Task 11:** Kerjakan Task 7 di plan 28 Juli.
- [ ] **Task 12:** Kerjakan Task 8 di plan 28 Juli.
- [ ] **Task 13:** Kerjakan Task 9 di plan 28 Juli. Expected: unit test Task 12 tetap hijau setelah penambahan method database.
- [ ] **Task 14:** Kerjakan Task 10 dan Task 11 di plan 28 Juli.

**Titik henti Tahap 2.** Delapan class Active, seluruh unit test hijau, dan alur create-approve request sudah bisa dibuktikan lewat report sementara tanpa menyentuh browser.

---

# TAHAP 3 &mdash; Menyambungkan Logic ke Halaman

Setiap task di tahap ini mengikuti bentuk yang sama: buang blok bertanda `TAHAP 1`, ganti data hardcode di layout dengan loop, tambahkan `OnRequest` untuk memuat data, uji di browser.

Markup tidak berubah. Yang berubah hanya sumber datanya. Itulah gunanya Tahap 1 mengunci struktur HTML lebih dulu.

### Task 15: Sambungkan login.htm dan main.htm

**Files:**
- Modify: `src/04_bsp/zbsp_color_panel/login/oninputprocessing.abap.txt`
- Create: `src/04_bsp/zbsp_color_panel/main/onrequest.abap.txt`
- Modify: `src/04_bsp/zbsp_color_panel/main/layout.htm.txt`
- Modify: `src/04_bsp/zbsp_color_panel/_shared/nav.htm.txt`

**Interfaces:**
- Consumes: `ZCL_CP_AUTH=>login( )`, `save_session( )`, `read_session( )` dari Task 10
- Produces: pola pembacaan session di `OnRequest` yang disalin Task 16&ndash;20

- [ ] **Step 1: Ganti OnInputProcessing login dengan panggilan class**

Isi lengkapnya ada di plan 28 Juli, Task 12 Step 3. Salin apa adanya.

Yang wajib dipastikan: blok berkomentar `TAHAP 1` beserta `IF lv_pass IS INITIAL` yang menerima password apa pun **hilang seluruhnya**. Cari string `TAHAP 1` di file untuk memastikan tidak ada sisa.

- [ ] **Step 2: Tulis OnRequest main.htm**

`src/04_bsp/zbsp_color_panel/main/onrequest.abap.txt`:

```abap
DATA: lv_sid     TYPE string,
      ls_session TYPE zcl_cp_auth=>ty_session,
      lv_count   TYPE i.

lv_sid = runtime->session_id.
ls_session = zcl_cp_auth=>read_session( lv_sid ).

IF ls_session-user_id IS INITIAL.
  navigation->goto_page( 'login.htm' ).
  RETURN.
ENDIF.

gv_user_name = ls_session-full_name.
gv_role      = ls_session-role.
```

Blok pemeriksaan session ini disalin ke `OnRequest` setiap halaman selain `login.htm`. Tanpa itu, halaman bisa dibuka langsung lewat URL tanpa login.

- [ ] **Step 3: Ganti angka hardcode di main.htm dengan SELECT COUNT**

Tambahkan ke `onrequest.abap.txt` setelah blok session, lalu ganti keempat angka `0` di layout dengan `<%= gv_stat_req %>` dan seterusnya. Deklarasikan empat atribut baru bertipe `I` di tab Page Attributes: `gv_stat_req`, `gv_stat_dcp`, `gv_stat_panel`, `gv_stat_exp`.

```abap
SELECT COUNT(*) INTO gv_stat_req
  FROM zcp_request
  WHERE status = 'P'.

SELECT COUNT(*) INTO gv_stat_dcp
  FROM zcp_dcp_hdr
  WHERE status = 'O'.

SELECT COUNT(*) INTO gv_stat_panel
  FROM zcp_dcp_item
  WHERE status = 'SB'.

SELECT COUNT(*) INTO gv_stat_exp
  FROM zcp_dcp_hdr
  WHERE status = 'O'
    AND expire_date < sy-datum.
```

- [ ] **Step 4: Sembunyikan menu yang tidak sesuai role**

Bungkus tiap `<a>` di sidebar dengan pemeriksaan `gv_role`. Contoh untuk menu DCP yang hanya untuk ADMIN dan IT:

```html
<% IF gv_role CS 'ADMIN' OR gv_role CS 'IT'. %>
<a href="dcp_list.htm" class="flex items-center gap-3 px-5 py-2 text-sm text-gray-300 hover:bg-navy hover:text-white">
  <i class="fa-solid fa-flask w-4"></i> DCP
</a>
<% ENDIF. %>
```

Peta role per menu: Dashboard semua role; Request DCP untuk SALES, ADMIN, IT; DCP untuk ADMIN, QC, IT; User untuk IT saja.

Sebarkan perubahan sidebar ini ke kedelapan layout. Ini konsekuensi dari keputusan menyalin potongan alih-alih meng-include-nya.

- [ ] **Step 5: Uji dan commit**

Login dengan user `ARYA` password yang diset di Task 10. Expected: masuk ke `main.htm`, nama muncul, sidebar hanya menampilkan menu untuk role IT.

Login dengan password salah. Expected: kotak merah berisi pesan dari `ZCX_CP_ERROR`, tetap di `login.htm`.

Buka `main.htm` langsung di tab baru tanpa login. Expected: dilempar ke `login.htm`.

```bash
git add src/04_bsp/zbsp_color_panel/
git commit -m "feat(bsp): sambungkan login dan main ke ZCL_CP_AUTH, sidebar per role"
```

### Task 16: Sambungkan req_list.htm dan req_form.htm

Ikuti plan 28 Juli Task 13 untuk isi `OnRequest` dan `OnInputProcessing` keduanya. Tambahan yang berlaku di sini: layout sudah ada dari Task 3, jadi yang dikerjakan hanya mengganti dua `<tr>` hardcode dengan `<% LOOP AT gt_req INTO ls_req. %>` dan menghapus paragraf penutup bertuliskan "masih hardcode".

Uji: Sales melihat hanya request miliknya; Admin melihat seluruh request pending. Masukkan nomor SO nyata di `req_form.htm`, tekan Cari SO, material dari VBAP muncul dengan penanda kelayakan yang benar.

### Task 17: Sambungkan req_detail.htm

Ikuti plan 28 Juli Task 14. Bagian yang paling perlu perhatian: penyusunan nama field checkbox secara dinamis, karena Tahap 1 membacanya satu per satu dengan nama tetap.

```abap
LOOP AT gt_items INTO ls_item.
  CONCATENATE 'sel_' ls_item-so_item INTO lv_field.
  lv_sel = request->get_form_field( lv_field ).
  IF lv_sel <> 'X'.
    CONTINUE.
  ENDIF.
  CONCATENATE 'reason_' ls_item-so_item INTO lv_field.
  lv_reason = request->get_form_field( lv_field ).
  " ... panggil zcl_cp_request=>approve_items( ) atau reject_items( )
ENDLOOP.
```

Uji partial approve: dari satu request berisi dua material, centang keduanya, approve. Bila satu material sudah punya Color Code, expected: satu baris hasil sukses dan satu baris hasil gagal beserta alasannya, ditampilkan berdampingan di `gt_result` &mdash; bukan seluruh operasi dibatalkan.

Inilah perilaku yang membedakan sistem sebenarnya dari prototype, dan uji ini adalah pembuktiannya.

### Task 18: Sambungkan dcp_list.htm

Ikuti plan 28 Juli Task 15. Ganti satu `<tr>` hardcode dengan loop atas `gt_dcp`, dan hidupkan dropdown filter status yang atribut `gv_filter`-nya sudah dideklarasikan sejak Task 5.

### Task 19: Sambungkan dcp_detail.htm

Ikuti plan 28 Juli Task 16. Ini task terbesar di Tahap 3: lima kartu hardcode diganti satu loop yang memilih tombol berdasarkan status tiap panel.

```html
<% LOOP AT gt_panel INTO ls_panel. %>
<form method="post" class="border border-slate-200 rounded-lg p-3">
  <div class="text-xs text-slate-500 mb-1">Panel #<%= ls_panel-panel_number %></div>
  <div class="font-mono text-xs mb-2"><%= ls_panel-panel_id %></div>
  <input type="hidden" name="panel_number" value="<%= ls_panel-panel_number %>"/>

  <% CASE ls_panel-status. %>

  <% WHEN 'NA'. %>
    <span class="inline-block px-2 py-1 rounded text-xs bg-slate-100 text-slate-700 mb-2">NA</span>
    <input type="date" name="mfg_date"
           class="w-full px-2 py-1 border border-slate-300 rounded text-xs mb-2"/>
    <button type="submit" name="onInputProcessing" value="activate"
            class="w-full bg-navy hover:bg-navylight text-white py-1 rounded text-xs">
      Aktivasi
    </button>

  <% WHEN 'AK'. %>
    <span class="inline-block px-2 py-1 rounded text-xs bg-blue-100 text-blue-800 mb-2">AK</span>
    <button type="submit" name="onInputProcessing" value="submit"
            class="w-full bg-amber-500 hover:bg-amber-600 text-white py-1 rounded text-xs">
      Submit
    </button>

  <% WHEN 'SB'. %>
    <span class="inline-block px-2 py-1 rounded text-xs bg-amber-100 text-amber-800 mb-2">SB</span>
    <div class="flex gap-1">
      <button type="submit" name="onInputProcessing" value="approve"
              class="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white py-1 rounded text-xs">
        Approve
      </button>
      <button type="submit" name="onInputProcessing" value="reject"
              class="flex-1 bg-red-600 hover:bg-red-700 text-white py-1 rounded text-xs">
        Reject
      </button>
    </div>

  <% WHEN 'AP'. %>
    <span class="inline-block px-2 py-1 rounded text-xs bg-emerald-100 text-emerald-800 mb-2">AP</span>
    <div class="text-xs text-slate-400">Tidak ada aksi</div>

  <% WHEN 'RJ'. %>
    <span class="inline-block px-2 py-1 rounded text-xs bg-red-100 text-red-800 mb-2">RJ</span>
    <button type="submit" name="onInputProcessing" value="undo"
            class="w-full bg-slate-600 hover:bg-slate-700 text-white py-1 rounded text-xs">
      Undo
    </button>

  <% WHEN 'OB'. %>
    <span class="inline-block px-2 py-1 rounded text-xs bg-slate-100 text-slate-500 mb-2">OB</span>
    <div class="text-xs text-slate-400">Obsolete</div>

  <% ENDCASE. %>
</form>
<% ENDLOOP. %>
```

Markup tiap cabang di atas identik dengan kartu yang bersesuaian di Task 5 Step 3 &mdash; itulah alasan kelima kartu di Tahap 1 sengaja dibuat mewakili lima status berbeda, bukan lima panel yang sama.

Cabang `OB` adalah satu-satunya yang tidak punya padanan di Tahap 1. Panel berstatus `OB` hanya lahir dari `reject_header( )`, yang tidak bisa dipicu dari halaman statis. Tanpa cabang ini, panel obsolete akan tampil sebagai kartu kosong tanpa badge.

Uji seluruh siklus pada satu DCP nyata: aktivasi panel &rarr; submit dengan foto &rarr; approve &rarr; close header. Lalu jalur gagalnya: submit tanpa foto ditolak, close header sebelum ada panel approved ditolak, reject lalu undo mengembalikan panel ke SB dengan `UNDO_FLAG` terisi `X`.

### Task 20: Sambungkan admin_user.htm

Ganti blok `TAHAP 1` dengan `ZCL_CP_AUTH=>hash_password( )` lalu `INSERT zcp_user`. Ganti baris tabel hardcode dengan loop atas `gt_user` yang diisi di `OnRequest`.

Uji: buat user baru lewat halaman ini, lalu logout dan login memakai user itu. Kalau berhasil, hash-nya benar. Periksa `ZCP_USER` lewat SE16N &mdash; kolom password harus berisi string heksadesimal 64 karakter, bukan teks yang bisa dibaca.

Uji terakhir yang menutup seluruh plan: buat user Sales baru lewat `admin_user.htm`, login sebagai user itu, buat request dari SO nyata, logout, login sebagai Admin, approve sebagian materialnya, buka DCP yang terbentuk, jalankan satu panel sampai approved, lalu close header.

```bash
git add src/04_bsp/zbsp_color_panel/admin_user/ report/report.md
git commit -m "feat(bsp): sambungkan admin_user ke ZCL_CP_AUTH, alur end-to-end lengkap"
```

---

## Yang Sengaja Tidak Dicakup

| Bagian | Alasan |
|---|---|
| Halaman MCP (list, detail, renewal) | Tabel `ZCP_MCP_HDR` dan `ZCP_MCP_ITEM` belum ada di DDIC. Perlu task DDIC tersendiri sebelum halamannya bisa disentuh |
| Master Buyer | SM30 lewat TMG sudah cukup; datanya jarang berubah dan tanpa logic khusus |
| Master Color Code | Dibuat otomatis saat approve request; belum ada kebutuhan maintenance manual di sub-proyek 1 |
| Halaman Audit Log | Tabelnya terisi sejak Task 9, tapi pembacanya belum dibutuhkan untuk menutup alur DCP |
| Stiker dan QR | Sub-proyek terpisah; butuh keputusan DOKAR dan Content Server dulu |
| SP (Station Panel) | Requirement bisnisnya belum ada &mdash; pertanyaan terbuka nomor 1 di spec |
| Uji otomatis halaman BSP | Tidak ada cara uji otomatis yang masuk akal untuk BSP di 1809. Seluruh verifikasi halaman bersifat manual dan langkahnya ditulis eksplisit di tiap task |
