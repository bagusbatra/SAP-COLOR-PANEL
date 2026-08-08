# Report Checkpoint — Color Panel Sub-Proyek 1

Rekaman kemajuan per task dan per step. Diperbarui tiap kali ada step yang selesai.

- **Proyek:** Color Panel Management System — SAP S/4HANA 1809, PT. Kayu Mebel Indonesia
- **Plan sumber:**
  - Jalur DDIC &amp; Class: `docs/superpowers/plans/2026-07-28-color-panel-foundation-dcp.md`
  - Jalur BSP Pages: `docs/superpowers/plans/2026-08-06-bsp-foundation-dcp-pages.md`
- **Spec sumber:**
  - `docs/superpowers/specs/2026-07-28-color-panel-foundation-dcp-design.md` &mdash; **dengan revisi 6 Agustus di bagian akhir**
  - `docs/superpowers/specs/2026-08-06-role-capability-map.md` &mdash; peta kewenangan per role
- **Log harian:** `report/log_activity/` &mdash; satu file per tanggal, indeks di `report/log_activity/README.md`
- **Terakhir diperbarui:** 8 Agustus 2026

## Arti simbol status

| Simbol | Arti |
|:---:|---|
| ✅ | Selesai dan terverifikasi |
| 🟡 | Sedang dikerjakan / selesai sebagian |
| ⬜ | Belum mulai |
| ⤷ | Digantikan task lain, lihat keterangannya |

---

## Dua Jalur Pengerjaan

Sejak 6 Agustus 2026 pekerjaan berjalan di dua jalur paralel, bukan satu urutan lurus seperti rencana semula.

| Jalur | Isi | Plan |
|---|---|---|
| **A. DDIC &amp; Class** | Tabel, number range, message class, delapan ABAP class | Plan 28 Juli, Task 1&ndash;11 |
| **B. BSP Pages** | Delapan halaman `Page with Flow Logic` | Plan 6 Agustus |

Alasan dipecah: jalur B dibangun lebih dulu sebagai halaman yang membaca database langsung, supaya alur bisnis bisa diuji dari awal sampai akhir tanpa menunggu seluruh lapisan class selesai. Logic dipindahkan ke class pada Tahap 3 plan 6 Agustus.

Konsekuensinya beberapa halaman memuat OpenSQL yang kelak pindah ke class. Itu keputusan sadar, dan tiap tempatnya diberi komentar penunjuk.

---

## Ringkasan 16 Task

| Task | Judul | Status | Tanggal Selesai |
|:---:|---|:---:|---|
| 1 | Inisialisasi Repo dan Struktur Folder | ✅ | 28 Jul 2026 |
| 2 | Domain dan Data Element | ✅ | 28 Jul 2026 |
| 3 | Tabel, Lock Object, Number Range, Message Class | 🟡 | — |
| 4 | ZCX_CP_ERROR dan ZCL_CP_NUMBER | ⬜ | — |
| 5 | ZCL_CP_AUDIT | ⬜ | — |
| 6 | ZCL_CP_AUTH | ⬜ | — |
| 7 | ZCL_CP_SO_READER dan Report Uji | ⬜ | — |
| 8 | ZCL_CP_DCP — Logic Murni | ⬜ | — |
| 9 | ZCL_CP_DCP — Operasi Database | ⬜ | — |
| 10 | ZCL_CP_PHOTO | ⬜ | — |
| 11 | ZCL_CP_REQUEST | ⬜ | — |
| 12 | Aplikasi BSP, Halaman Login, dan Router | ⤷ | digantikan Jalur B |
| 13 | Halaman Daftar Request dan Form Request Sales | ⤷ | digantikan Jalur B |
| 14 | Halaman Approval Admin (Partial Approve) | ⤷ | digantikan Jalur B |
| 15 | Halaman Daftar DCP | ⤷ | digantikan Jalur B |
| 16 | Halaman Detail DCP — Siklus Panel | ⤷ | digantikan Jalur B |

**Progres Jalur A:** 2 dari 11 task tuntas, 1 berjalan. Task 12&ndash;16 digantikan Jalur B.

**Progres Jalur B:** fondasi tuntas, 3 dari 8 halaman aktif dan teruji, 2 halaman aktif menunggu data uji.

---

## Task 1 — Inisialisasi Repo dan Struktur Folder ✅

Selesai 28 Juli 2026. Commit `9ce9d97` dan `d7af600`.

| | Step | Status | Tanggal | Keterangan |
|:---:|---|:---:|---|---|
| 1 | Inisialisasi git dan buat struktur folder | ✅ | 28 Jul 2026 | `src/01_ddic/tables`, `02_classes`, `03_reports`, `04_bsp` |
| 2 | Buat `.gitignore` | ✅ | 28 Jul 2026 | |
| 3 | Buat `README.md` | ✅ | 28 Jul 2026 | Berisi 4 aturan teknis yang tidak boleh dilanggar |
| 4 | Verifikasi struktur terbentuk | ✅ | 28 Jul 2026 | |
| 5 | Commit | ✅ | 28 Jul 2026 | |

---

## Task 2 — Domain dan Data Element ✅

Selesai 28 Juli 2026. Seluruh objek Active di SE11, package `$TMP`.

| | Step | Status | Tanggal | Keterangan |
|:---:|---|:---:|---|---|
| 1 | Tulis `src/01_ddic/domains.txt` | ✅ | 28 Jul 2026 | 6 domain fixed-value |
| 2 | Tulis `src/01_ddic/data_elements.txt` | ✅ | 28 Jul 2026 | 18 data element `ZCP_DE_*` |
| 3 | Buat domain di SE11 | ✅ | 28 Jul 2026 | Semua Active |
| 4 | Buat data element di SE11 | ✅ | 28 Jul 2026 | Semua Active |
| 5 | Commit | ✅ | 28 Jul 2026 | |

**Objek yang dihasilkan:**

Domain — `ZCP_DOM_ROLE`, `ZCP_DOM_REQ_ST`, `ZCP_DOM_ITM_ST`, `ZCP_DOM_DCP_ST`, `ZCP_DOM_PANEL_ST`, `ZCP_DOM_CC_ST`

Data element — 18 buah, dari `ZCP_DE_USER_ID` sampai `ZCP_DE_HASH`. Terverifikasi seluruhnya terpakai di 10 file definisi tabel, tidak ada yang menganggur dan tidak ada tabel yang mereferensi data element di luar daftar.

---

## Task 3 — Tabel, Lock Object, Number Range, Message Class 🟡

Berjalan. Step 1–4 (penulisan file) selesai 28 Juli. Step 5 (pembuatan objek di SAP) baru sebagian.

| | Step | Status | Tanggal | Keterangan |
|:---:|---|:---:|---|---|
| 1 | Tulis file definisi sepuluh tabel | ✅ | 28 Jul 2026 | `src/01_ddic/tables/*.txt` |
| 2 | Tulis `lock_objects.txt` | ✅ | 28 Jul 2026 | |
| 3 | Tulis `snro.txt` | ✅ | 28 Jul 2026 | |
| 4 | Tulis `messages_zcp.txt` | ✅ | 28 Jul 2026 | 20 pesan |
| 5 | Buat semua objek di sistem SAP | 🟡 | — | Rincian di bawah |
| 6 | Commit | ⬜ | — | Menunggu Step 5 tuntas |

### Rincian Step 5

| | Objek | Status | Tanggal |
|:---:|---|:---:|---|
| 5a | Sepuluh tabel transparan di SE11 | ✅ | 29 Jul 2026 |
| 5b | Enam secondary index | ✅ | 29 Jul 2026 |
| 5c | Lock object `EZCP_SO` | ✅ | 29 Jul 2026 |
| 5d | Lima objek number range di SNRO + interval 01 | 🟡 | — |
| 5e | Message class `ZCP` di SE91 | ⬜ | — |
| 5f | Table Maintenance Generator `ZCP_BUYER` | ⬜ | — |

### Rincian Step 5d — number range

| | Bagian | Status | Tanggal |
|:---:|---|:---:|---|
| 5d-1 | Tentukan number length domain | ✅ | 29 Jul 2026 |
| 5d-2 | Buat lima objek number range | ✅ | 29 Jul 2026 |
| 5d-3 | Buat interval `01` untuk kelima objek | ⬜ | — |

Number length domain memakai bawaan SAP, bukan bikin sendiri:

| Object | Domain | Panjang | To-year flag |
|---|:---:|:---:|:---:|
| `ZCP_COLOR` | `NUM5` | 5 | tidak |
| `ZCP_REQ` | `NUM4` | 4 | **ya** |
| `ZCP_DCP` | `NUM4` | 4 | **ya** |
| `ZCP_PHOTO` | `NUM9` | 9 | tidak |
| `ZCP_AUDIT` | `NUM12` | 12 | tidak |

### Sepuluh tabel — semua Active, terverifikasi lewat SE16N

| Tabel | Data Class | Size | Keterangan |
|---|:---:|:---:|---|
| `ZCP_USER` | APPL1 | 1 | User dan role |
| `ZCP_BUYER` | APPL1 | 1 | Master buyer |
| `ZCP_COLOR_CODE` | APPL1 | 1 | Master color code |
| `ZCP_REQUEST` | APPL0 | 1 | Header request |
| `ZCP_REQUEST_ITM` | APPL0 | 1 | Item request per material |
| `ZCP_SO_IMPORT` | APPL0 | 1 | Kunci anti-duplikat SO item |
| `ZCP_DCP_HDR` | APPL0 | 1 | Header DCP |
| `ZCP_DCP_ITEM` | APPL0 | 1 | Panel fisik |
| `ZCP_PHOTO` | APPL0 | 3 | Foto panel |
| `ZCP_AUDIT_LOG` | APPL0 | 3 | Audit trail |

### Enam secondary index — semua Active

| Tabel | Index | Sifat | Field |
|---|:---:|:---:|---|
| `ZCP_COLOR_CODE` | `MAT` | **Unique** | MANDT, MATNR |
| `ZCP_REQUEST` | `SO` | Non-unique | MANDT, SO_NUMBER |
| `ZCP_DCP_HDR` | `REQ` | Non-unique | MANDT, REQUEST_ID |
| `ZCP_DCP_ITEM` | `PID` | **Unique** | MANDT, PANEL_ID |
| `ZCP_PHOTO` | `REF` | Non-unique | MANDT, REF_TYPE, REF_ID, PANEL_NUMBER |
| `ZCP_AUDIT_LOG` | `REF` | Non-unique | MANDT, REF_TYPE, REF_ID |

---

## Task 4 — ZCX_CP_ERROR dan ZCL_CP_NUMBER ⬜

| | Step | Status | Keterangan |
|:---:|---|:---:|---|
| 1 | Tulis `zcx_cp_error.abap` | ⬜ | Exception, satu-satunya jalur error |
| 2 | Tulis test class ZCL_CP_NUMBER lebih dulu | ⬜ | 5 test, TDD |
| 3 | Buat kelas method kosong, jalankan test — harus FAIL | ⬜ | |
| 4 | Tulis implementasi ZCL_CP_NUMBER | ⬜ | |
| 5 | Jalankan test lagi — harus PASS 5/5 | ⬜ | |
| 6 | Commit | ⬜ | |

## Task 5 — ZCL_CP_AUDIT ⬜

| | Step | Status | Keterangan |
|:---:|---|:---:|---|
| 1 | Tulis `zcl_cp_audit.abap` | ⬜ | |
| 2 | Buat kelas di SE24 dan aktifkan | ⬜ | |
| 3 | Verifikasi menulis baris | ⬜ | `ACTION_BY` harus `ARYA`, bukan `auto_email` |
| 4 | Commit | ⬜ | |

## Task 6 — ZCL_CP_AUTH ⬜

| | Step | Status | Keterangan |
|:---:|---|:---:|---|
| 1 | Tulis test class untuk hash lebih dulu | ⬜ | 4 test |
| 2 | Buat kelas method kosong, jalankan test — harus FAIL | ⬜ | |
| 3 | Tulis implementasi ZCL_CP_AUTH | ⬜ | SHA256, login, session, guard role |
| 4 | Jalankan test lagi — harus PASS 4/4 | ⬜ | |
| 5 | Buat satu user uji lewat report sementara | ⬜ | User `ARYA`, role IT |
| 6 | Commit | ⬜ | |

## Task 7 — ZCL_CP_SO_READER dan Report Uji ⬜

| | Step | Status | Keterangan |
|:---:|---|:---:|---|
| 1 | Tulis `zcl_cp_so_reader.abap` | ⬜ | Baca VBAK/VBAP, saring kelayakan |
| 2 | Tulis `zcp_test_so_reader.abap` | ⬜ | Harness SE38 |
| 3 | Buat kelas dan report, uji SO yang tidak ada | ⬜ | |
| 4 | Uji SO color panel yang nyata | ⬜ | |
| 5 | Commit | ⬜ | |

## Task 8 — ZCL_CP_DCP, Logic Murni ⬜

| | Step | Status | Keterangan |
|:---:|---|:---:|---|
| 1 | Tulis test class lebih dulu | ⬜ | State machine dan perhitungan tanggal |
| 2 | Buat kelas method kosong, jalankan test — harus FAIL | ⬜ | |
| 3 | Tulis implementasi logic murni | ⬜ | |
| 4 | Jalankan test lagi | ⬜ | |
| 5 | Commit | ⬜ | |

## Task 9 — ZCL_CP_DCP, Operasi Database ⬜

| | Step | Status | Keterangan |
|:---:|---|:---:|---|
| 1 | Tambahkan deklarasi method ke PUBLIC SECTION | ⬜ | |
| 2 | Implementasi pembuatan DCP dari satu SO item | ⬜ | |
| 3 | Implementasi helper transisi status dan penjaga header | ⬜ | |
| 4 | Implementasi aksi per panel | ⬜ | Activate, submit, approve, reject, undo |
| 5 | Implementasi close dan reject header | ⬜ | |
| 6 | Aktifkan, pastikan unit test Task 8 masih hijau | ⬜ | |
| 7 | Commit | ⬜ | |

## Task 10 — ZCL_CP_PHOTO ⬜

| | Step | Status | Keterangan |
|:---:|---|:---:|---|
| 1 | Tulis test class untuk validasi MIME | ⬜ | |
| 2 | Buat kelas method kosong, jalankan test — harus FAIL | ⬜ | |
| 3 | Tulis implementasi | ⬜ | Batas 2 MB, hanya JPEG dan PNG |
| 4 | Jalankan test lagi | ⬜ | |
| 5 | Aktifkan ulang ZCL_CP_DCP | ⬜ | |
| 6 | Commit | ⬜ | |

## Task 11 — ZCL_CP_REQUEST ⬜

| | Step | Status | Keterangan |
|:---:|---|:---:|---|
| 1 | Tulis test class untuk perhitungan status header | ⬜ | |
| 2 | Buat kelas method kosong, jalankan test — harus FAIL | ⬜ | |
| 3 | Tulis implementasi | ⬜ | Create + approve/reject per item |
| 4 | Jalankan test lagi | ⬜ | |
| 5 | Uji alur create dan approve lewat report sementara | ⬜ | |
| 6 | Commit | ⬜ | |

## Task 12 — Aplikasi BSP, Halaman Login, dan Router ⤷

> **Digantikan.** Halaman ini dibangun lewat Jalur B dengan rancangan berbeda: autentikasi SAP standar, tanpa `login.htm`, dan halaman membaca database langsung sebelum logic dipindah ke class. Lihat bagian *Jalur B* di bawah dan plan 6 Agustus.


| | Step | Status | Keterangan |
|:---:|---|:---:|---|
| 1 | Buat aplikasi BSP dan service SICF | ⬜ | `ZBSP_COLOR_PANEL` |
| 2 | Tulis potongan head bersama | ⬜ | Tailwind CDN + SweetAlert2 |
| 3 | Tulis halaman login | ⬜ | |
| 4 | Tulis halaman router | ⬜ | |
| 5 | Paste ke SE80 dan uji login | ⬜ | |
| 6 | Periksa audit trail login | ⬜ | |
| 7 | Commit | ⬜ | |

## Task 13 — Halaman Daftar Request dan Form Request Sales ⤷

> **Digantikan.** Halaman ini dibangun lewat Jalur B dengan rancangan berbeda: autentikasi SAP standar, tanpa `login.htm`, dan halaman membaca database langsung sebelum logic dipindah ke class. Lihat bagian *Jalur B* di bawah dan plan 6 Agustus.


| | Step | Status | Keterangan |
|:---:|---|:---:|---|
| 1 | Tulis `req_list` | ⬜ | |
| 2 | Tulis `req_form` | ⬜ | |
| 3 | Buat table type dan kedua halaman di SE80 | ⬜ | |
| 4 | Uji sebagai Sales | ⬜ | |
| 5 | Commit | ⬜ | |

## Task 14 — Halaman Approval Admin (Partial Approve) ⤷

> **Digantikan.** Halaman ini dibangun lewat Jalur B dengan rancangan berbeda: autentikasi SAP standar, tanpa `login.htm`, dan halaman membaca database langsung sebelum logic dipindah ke class. Lihat bagian *Jalur B* di bawah dan plan 6 Agustus.


| | Step | Status | Keterangan |
|:---:|---|:---:|---|
| 1 | Tulis `attributes.txt` | ⬜ | |
| 2 | Tulis `oninputprocessing.abap.txt` | ⬜ | |
| 3 | Tulis `layout.htm.txt` | ⬜ | |
| 4 | Buat halaman di SE80 dan uji partial approve | ⬜ | Sebagian approved, sebagian rejected |
| 5 | Commit | ⬜ | |

## Task 15 — Halaman Daftar DCP ⤷

> **Digantikan.** Halaman ini dibangun lewat Jalur B dengan rancangan berbeda: autentikasi SAP standar, tanpa `login.htm`, dan halaman membaca database langsung sebelum logic dipindah ke class. Lihat bagian *Jalur B* di bawah dan plan 6 Agustus.


| | Step | Status | Keterangan |
|:---:|---|:---:|---|
| 1 | Tulis `attributes.txt` | ⬜ | |
| 2 | Tulis `onrequest.abap.txt` | ⬜ | |
| 3 | Tulis `layout.htm.txt` | ⬜ | |
| 4 | Buat structure, table type, dan halaman, lalu uji | ⬜ | |
| 5 | Commit | ⬜ | |

## Task 16 — Halaman Detail DCP, Siklus Panel ⤷

> **Digantikan.** Halaman ini dibangun lewat Jalur B dengan rancangan berbeda: autentikasi SAP standar, tanpa `login.htm`, dan halaman membaca database langsung sebelum logic dipindah ke class. Lihat bagian *Jalur B* di bawah dan plan 6 Agustus.


| | Step | Status | Keterangan |
|:---:|---|:---:|---|
| 1 | Tulis `attributes.txt` | ⬜ | |
| 2 | Tulis `oninputprocessing.abap.txt` | ⬜ | |
| 3 | Tulis `layout.htm.txt` | ⬜ | |
| 4 | Buat halaman dan uji seluruh siklus panel | ⬜ | Aktivasi sampai close header |
| 5 | Commit | ⬜ | |

---

## Jalur B &mdash; BSP Pages (mulai 6 Agustus 2026)

Plan: `docs/superpowers/plans/2026-08-06-bsp-foundation-dcp-pages.md`
Sumber halaman: `src/04_bsp/zbsp_color_panel/` &mdash; struktur DATAR, satu file per tab SE80. Baca `README.txt` di folder itu lebih dulu.

### Fondasi

| | Objek | Status | Tanggal |
|:---:|---|:---:|---|
| B1 | Aplikasi BSP `ZBSP_COLOR_PANEL` di SE80 | ✅ | 6 Agu 2026 |
| B2 | Service SICF aktif, autentikasi SAP standar | ✅ | 6 Agu 2026 |
| B3 | Role PFCG `ZCP_IT` dibuat + User Comparison | ✅ | 6 Agu 2026 |
| B4 | Role PFCG `ZCP_SALES`, `ZCP_ADMIN`, `ZCP_QC` | ⬜ | &mdash; |
| B5 | `ZCP_USER` direvisi: `PASSWORD_HASH` dan `ROLE` dibuang | ✅ | 6 Agu 2026 |
| B6 | Potongan bersama `_shared/` (head, nav, role_detect) | ✅ | 6 Agu 2026 |

### Halaman

| | Halaman | Peran | Status | Tanggal |
|:---:|---|---|:---:|---|
| B7 | `noaccess.htm` | Penolakan, membedakan tiga sebab | ✅ | 6 Agu 2026 |
| B8 | `main.htm` | Dashboard + router role | ✅ | 6 Agu 2026 |
| B9 | `admin_user.htm` | Pemetaan SAP user ke buyer (IT) | ✅ | 6 Agu 2026 |
| B10 | `req_list.htm` | Daftar request | 🟡 | aktif, belum diuji dengan data |
| B11 | `req_form.htm` | Input SO, pilih material, submit | 🟡 | aktif, tersendat prasyarat data |
| B12 | `req_detail.htm` | Approval Admin per item | ⬜ | &mdash; |
| B13 | `dcp_list.htm` | Daftar DCP | ⬜ | &mdash; |
| B14 | `dcp_detail.htm` | Grid panel DCP | ⬜ | &mdash; |

### Report bantu

| | Report | Guna | Status |
|:---:|---|---|:---:|
| B15 | `ZCP_FIX_USER` | Pemulihan saat user mengunci dirinya sendiri | ✅ dipakai |
| B16 | ~~`ZCP_ADD_BUYER`~~ | Batal &mdash; `ZCP_BUYER` dipensiunkan 8 Agu, filenya dihapus | ⤷ |

---

## Keputusan yang Membatalkan Rancangan Sebelumnya

Tiga keputusan pada 6 Agustus 2026 mengubah rancangan di spec 28 Juli. Dicatat di sini supaya tidak perlu ditelusuri ulang dari riwayat percakapan.

### 1. Autentikasi pindah ke SAP standar

Membatalkan keputusan desain nomor 2. Tidak ada `login.htm`, tidak ada password yang dikelola aplikasi, SICF tab Logon Data dikosongkan. Role dibaca dari PFCG lewat `AGR_USERS`.

**Aturan wajib nomor 5 gugur** &mdash; `SY-UNAME` sekarang justru satu-satunya identitas yang sah.

Harga yang dibayar: setiap pemakai wajib punya SAP dialog user, dengan biaya lisensi per orang. Rinciannya di `src/01_ddic/pfcg_roles.txt`.

### 2. `BUYER_ID` = `KUNNR`, dan `ZCP_BUYER` dipensiunkan (8 Agustus)

Nomor pelanggan SAP dipakai apa adanya sebagai `BUYER_ID`. Panjangnya sudah cocok CHAR10, dan `VBAK-KUNNR` langsung menyambung ke `ZCP_BUYER` tanpa tabel perantara. Tidak ada perubahan DDIC.

**Ditindaklanjuti 8 Agustus:** `ZCP_BUYER` dipensiunkan seluruhnya. Dari empat belas kolomnya, kode hanya memakai dua &mdash; `BUYER_NAME` yang kini dibaca dari `KNA1-NAME1`, dan `IS_ACTIVE` yang digantikan penanda blokir SAP sendiri (`KNA1-LOEVM` dan `KNA1-AUFSD`).

Tidak ada lagi pendaftaran buyer. Nama yang tampil selalu terkini, bukan salinan yang dibuat sekali lalu tidak pernah disegarkan. Daftar tandingan seperti `ZCP_BUYER` justru berbahaya: ia bisa ketinggalan dari master SD, dan yang ketinggalan akan tetap dipercaya karena kelihatan lebih dekat.

Ikut batal: TMG `ZCP_BUYER` (Task 3 Step 5f) dan report `ZCP_ADD_BUYER`. `ZCP_DE_BUYER_ID` di `ZCP_USER`, `ZCP_REQUEST`, `ZCP_DCP_HDR`, dan `ZCP_COLOR_CODE` tidak berubah &mdash; keempatnya tetap berisi `KUNNR`.

### 3. IT memegang akses penuh &mdash; SEMENTARA

Pemegang `ZCP_IT` boleh menjalankan seluruh alur bisnis dari awal sampai akhir. Berlaku selama pembangunan, **wajib dicabut sebelum go-live**.

Kewenangan dipisahkan dari identitas: `gv_role` menjawab "dia siapa", empat flag `gv_as_sales` / `gv_as_admin` / `gv_as_qc` / `gv_as_it` menjawab "dia boleh apa". Seluruh halaman memeriksa flag, bukan `gv_role`.

Pencabutannya cukup menghapus satu blok bertanda `SEMENTARA: IT memegang akses penuh` di `_shared/role_detect.abap` lalu disebarkan. Rinciannya di `docs/superpowers/specs/2026-08-06-role-capability-map.md` bagian 8.

**Selama ini berlaku, menguji sebagai IT tidak membuktikan pembatasan role bekerja.**

---

## Enam Pertanyaan yang Menunggu Keputusan Yogi

Ditemukan saat memetakan kewenangan. Rincian dan pilihannya di `docs/superpowers/specs/2026-08-06-role-capability-map.md` bagian 5.

| # | Pertanyaan | Menghambat |
|:---:|---|---|
| 1 | **QC boleh approve panel atau tidak?** Di prototype QC tidak bisa menekan apa pun, bertentangan dengan aturan bisnis | `dcp_detail.htm`, `mcp_detail.htm` |
| 2 | Master User: ADMIN ikut, atau IT saja? | `admin_user.htm`, murah diubah sekarang |
| 3 | Sales perlu halaman pemantauan hasil requestnya? | Halaman baru di luar delapan |
| 4 | Color Code: QC lihat saja atau boleh ubah? | &mdash; |
| 5 | Reject DCP header cukup wewenang ADMIN sendirian? | &mdash; |
| 6 | Prioritas role membuat ADMIN+QC selalu jadi ADMIN. Masalah? | &mdash; |

---

## Titik Lanjut Berikutnya

Tiga hal yang menghambat pengujian `req_form.htm` sampai tuntas, urut dari yang paling menghambat.

### 1. Interval number range di SNRO &mdash; MENGHAMBAT SUBMIT

Tanpa ini `REQ-2026-0001` tidak bisa dibangkitkan dan tombol Submit selalu gagal.

`SNRO -> Object -> Number ranges -> Change Intervals -> Insert Interval -> Save`

| Object | No | From number | To number | Year |
|---|:---:|---|---|:---:|
| `ZCP_COLOR` | `01` | `00001` | `99999` | &mdash; |
| `ZCP_REQ` | `01` | `0001` | `9999` | `2026` |
| `ZCP_DCP` | `01` | `0001` | `9999` | `2026` |
| `ZCP_PHOTO` | `01` | `000000001` | `999999999` | &mdash; |
| `ZCP_AUDIT` | `01` | `000000000001` | `999999999999` | &mdash; |

Kolom `Ext` jangan dicentang. Interval belum jadi sampai tombol Save ditekan &mdash; baris yang muncul di grid saja belum tersimpan.

### 2. Paste ulang lima file yang berubah 8 Agustus

Pemensiunan `ZCP_BUYER` menyentuh lima file. Semuanya perlu di-paste ulang ke SE80 sebelum diuji:

| Halaman | Tab | File |
|---|---|---|
| `req_form.htm` | Page Attributes | tipe `gv_so_name` jadi `KNA1-NAME1` |
| | OnInputProcessing | `req_form.oninputprocessing.abap` |
| `req_list.htm` | Type Definitions | `req_list.types.txt` |
| | OnInitialization | `req_list.oninit.abap` |
| `admin_user.htm` | Type Definitions | `admin_user.types.txt` |
| | Layout | `admin_user.htm` &mdash; dropdown Buyer jadi input KUNNR |
| | OnInitialization | `admin_user.oninit.abap` |
| | OnInputProcessing | `admin_user.oninputprocessing.abap` |

### 3. Sisa Task 3 yang tertunda sejak Juli

- SE91 message class `ZCP`
- ~~TMG `ZCP_BUYER`~~ &mdash; **batal**, tabelnya dipensiunkan

Setelah itu: uji `req_form.htm` sampai `REQ-2026-0001` terbentuk, lalu lanjut ke `req_detail.htm`.
