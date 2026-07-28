# Design Spec — Color Panel Sub-Proyek 1: Foundation + Request/DCP

**Proyek:** Color Panel Management System — PT. Kayu Mebel Indonesia (KMI)
**Platform:** SAP S/4HANA 1809 On-Premise (BASIS 753)
**BSP Application:** `ZBSP_COLOR_PANEL`
**Tanggal:** 28 Juli 2026
**Status:** Approved — siap masuk implementation plan

---

## 1. Ruang Lingkup

### 1.1 Posisi dalam Peta Proyek

Sistem penuh dipecah menjadi 5 sub-proyek berurutan. Dokumen ini hanya mencakup **sub-proyek 1**.

| # | Sub-proyek | Isi | Status |
|---|---|---|---|
| 1 | **Foundation + Request/DCP** | Data element, Z-table, SNRO, BSP skeleton, login/role, Request Sales, approval Admin, Color Code, siklus panel DCP | **Dokumen ini** |
| 2 | MCP + Renewal | Transisi DCP→MCP, close min 3 panel, obsolete, renewal via SO baru | Belum |
| 3 | SP + Peminjaman | Station Panel, masa aktif vs masa pakai, peminjaman | Konsep bisnis belum ada |
| 4 | DMS + Label/QR/Stiker | DOKAR ZDCP/ZMCP, migrasi foto, cetak stiker 3 kolom tanda tangan, QR | Belum |
| 5 | Dashboard + Monitoring + Audit UI | Statistik, reminder 2 bulan, tampilan audit trail | Belum |

### 1.2 Termasuk Sub-Proyek 1

- Data element, domain, dan 10 Z-table
- Number range (SNRO) untuk Color Code, Request, DCP, Panel ID
- Aplikasi BSP `ZBSP_COLOR_PANEL` dengan custom login dan router berbasis role
- Halaman Request: Sales input nomor SO, sistem menarik material dari VBAK/VBAP
- Halaman Approval: Admin approve/reject **per material** dalam satu SO
- Generate Color Code (KW + 5 digit), DCP header, dan panel sejumlah qty SO
- Siklus panel DCP: aktivasi, submit foto, approve/reject, undo, close/reject header
- Upload foto disimpan sebagai XSTRING di Z-table (kolom DMS disiapkan kosong)
- Audit trail
- Maintenance user (halaman BSP) dan buyer (SM30)

### 1.3 TIDAK Termasuk Sub-Proyek 1

MCP dan renewal, SP dan peminjaman, integrasi DMS/Content Server, cetak stiker dan QR code, dashboard dan monitoring, master Work Center.

### 1.4 Kondisi Awal

Greenfield. Belum ada Z-table, data element, maupun aplikasi BSP di sistem.

---

## 2. Keputusan Arsitektur

| # | Keputusan | Alasan |
|---|---|---|
| 1 | **Sumber SO: baca langsung VBAK/VBAP** | BSP berjalan di sistem yang sama dengan modul SD. Menghilangkan salah ketik dan memungkinkan validasi otomatis "material belum punya Color Code" |
| 2 | **Autentikasi: custom login Z-table (pola ECM)** | SICF pakai shared user `auto_email`, login form sendiri, password SHA256 di `ZCP_USER`, session via `cl_bsp_server_side_cookie`. User pabrik tidak perlu SAP user account |
| 3 | **Color Code: auto-generate `KW` + 5 digit** | Netral terhadap penamaan material. Via SNRO |
| 4 | **Foto: XSTRING di Z-table dulu** | Alur DCP lengkap tanpa menunggu setup DOKAR. Kolom DMS sudah ada, migrasi di sub-proyek 4 tinggal mengisi `dms_docnum` |
| 5 | **Arsitektur: halaman BSP tipis + ABAP Class** | Aturan bisnis dipakai ulang lintas sub-proyek; satu rumah per aturan; logic bisa diuji tanpa browser |
| 6 | **Approve per material, bukan per SO** | Satu material bermasalah tidak menahan seluruh SO |
| 7 | **Qty panel dari `VBAP-KWMENG`, bukan konstanta 15** | "15 pcs" adalah kebiasaan Sales saat membuat SO, bukan aturan sistem ini |

### 2.1 Konsekuensi Penting Keputusan #2

Karena SICF memakai shared user `auto_email`, `SY-UNAME` **tidak pernah** menunjukkan pelaku sebenarnya. Maka:

- Semua kolom `created_by`, `changed_by`, `approved_by`, `activated_by`, dan sejenisnya bertipe **`CHAR20`** (berisi `ZCP_USER-USER_ID`), **bukan `SYUNAME`**.
- Deklarasi `TYPES` tanggal 21 Juli 2026 memakai `SYUNAME` di hampir semua tabel. Itu harus dikoreksi sebelum tabel dibuat.
- Semua penulisan audit mengambil `USER_ID` dari session, bukan dari `SY-UNAME`.

### 2.2 Dokumen Lama yang Tidak Berlaku

`tech_design_color_panel.md` (15 Juli 2026) masih memakai konsep lama 3 entitas: DCP→MCP→CP, MCP bersubtipe Golden/Production/Buyer-Approved, expired 6 bulan, header berbasis PO. Daftar 20 halaman BSP dan 11 tabel di dokumen tersebut **tidak dipakai**. Bagian yang masih berlaku dan diadopsi ke sini: pola autentikasi ECM, aturan encoding BSP, gaya OpenSQL 1809, dan format Color Code.

---

## 3. Data Model

Sepuluh tabel. Semua bertipe transparent table, delivery class `A`, data browser/table view maintenance `X` (display/maintenance allowed).

Konvensi umum yang berlaku di semua tabel:

- Kolom pertama selalu `MANDT TYPE MANDT` (client-dependent).
- `CREATED_BY` / `CHANGED_BY`: `CHAR20` berisi `USER_ID`.
- `CREATED_AT` / `CHANGED_AT`: `TIMESTAMP` (TIMESTAMPL tidak dipakai; presisi detik cukup).

### 3.1 ZCP_USER — User & Role

| Field | Type | Key | Keterangan |
|---|---|---|---|
| MANDT | MANDT | PK | |
| USER_ID | CHAR20 | PK | ID login |
| FULL_NAME | CHAR60 | | Nama lengkap |
| PASSWORD_HASH | CHAR64 | | SHA256 hex |
| ROLE | CHAR10 | | `SALES` / `ADMIN` / `IT` (domain fixed value) |
| BUYER_ID | CHAR10 | | Diisi khusus role SALES; membatasi request ke buyer tsb |
| EMAIL | CHAR100 | | |
| PHONE | CHAR20 | | |
| IS_ACTIVE | CHAR1 | | `X` = aktif |
| LAST_LOGIN | TIMESTAMP | | |
| CREATED_BY | CHAR20 | | |
| CREATED_AT | TIMESTAMP | | |
| CHANGED_BY | CHAR20 | | |
| CHANGED_AT | TIMESTAMP | | |

Satu user satu role di sub-proyek 1. Multi-role tidak didukung; kalau nanti dibutuhkan, ditambahkan tabel penghubung, bukan string comma-separated.

### 3.2 ZCP_BUYER — Master Buyer

| Field | Type | Key | Keterangan |
|---|---|---|---|
| MANDT | MANDT | PK | |
| BUYER_ID | CHAR10 | PK | |
| BUYER_NAME | CHAR60 | | |
| COMPANY | CHAR60 | | |
| COUNTRY | LAND1 | | |
| CONTACT | CHAR60 | | |
| EMAIL | CHAR100 | | |
| PHONE | CHAR20 | | |
| IS_ACTIVE | CHAR1 | | `X` = aktif |
| REMARKS | CHAR200 | | |
| CREATED_BY | CHAR20 | | |
| CREATED_AT | TIMESTAMP | | |
| CHANGED_BY | CHAR20 | | |
| CHANGED_AT | TIMESTAMP | | |

Dimaintain lewat SM30 (TMG), tanpa halaman BSP.

### 3.3 ZCP_COLOR_CODE — Master Color Code

Entitas informasi, tanpa panel fisik. 1:1 dengan FERT Material.

| Field | Type | Key | Keterangan |
|---|---|---|---|
| MANDT | MANDT | PK | |
| COLOR_CODE | CHAR20 | PK | `KW` + 5 digit, mis. `KW00001` |
| MATNR | MATNR | | FERT Material Number |
| MAKTX | MAKTX | | Snapshot deskripsi material |
| BUYER_ID | CHAR10 | | |
| COLOR_NAME | CHAR60 | | |
| COLOR_HEX | CHAR7 | | `#RRGGBB`, opsional |
| COMPONENT | CHAR40 | | Solid / veneer / dll |
| STATUS | CHAR1 | | `A` aktif / `I` nonaktif / `O` obsolete |
| SOURCE_DCP_ID | CHAR20 | | DCP yang melahirkan Color Code ini |
| REMARKS | CHAR200 | | |
| CREATED_BY | CHAR20 | | |
| CREATED_AT | TIMESTAMP | | |
| CHANGED_BY | CHAR20 | | |
| CHANGED_AT | TIMESTAMP | | |

**Unique secondary index `MAT` pada (MANDT, MATNR)** — memaksa aturan 1:1 FERT di level database. Tanpa ini, dua proses paralel bisa membuat dua Color Code untuk satu material.

### 3.4 ZCP_REQUEST — Request-DCP (Header)

Satu request = satu nomor SO.

| Field | Type | Key | Keterangan |
|---|---|---|---|
| MANDT | MANDT | PK | |
| REQUEST_ID | CHAR20 | PK | `REQ-YYYY-NNNN` |
| SO_NUMBER | VBELN | | Nomor SO referensi |
| SALES_USER | CHAR20 | | `ZCP_USER-USER_ID` (role SALES) |
| BUYER_ID | CHAR10 | | |
| REQUEST_DATE | DATUM | | |
| STATUS | CHAR1 | | `P` pending / `C` closed — **dihitung dari item, lihat 5.1** |
| REMARKS | CHAR200 | | |
| CREATED_BY | CHAR20 | | |
| CREATED_AT | TIMESTAMP | | |
| CHANGED_BY | CHAR20 | | |
| CHANGED_AT | TIMESTAMP | | |

Secondary index `SO` pada (MANDT, SO_NUMBER) — non-unique, karena material yang ditolak boleh diajukan ulang dalam request baru dengan SO yang sama.

### 3.5 ZCP_REQUEST_ITM — Item Request (Keputusan per Material)

Menyimpan keputusan Admin untuk tiap material dalam satu SO.

| Field | Type | Key | Keterangan |
|---|---|---|---|
| MANDT | MANDT | PK | |
| REQUEST_ID | CHAR20 | PK | FK → ZCP_REQUEST |
| SO_ITEM | POSNR | PK | Nomor item SO (`000010`, ...) |
| MATNR | MATNR | | Material dari VBAP |
| MAKTX | MAKTX | | Snapshot deskripsi |
| MENGE | MENGE_D | | Qty dari `VBAP-KWMENG` |
| MEINS | MEINS | | Satuan |
| STATUS | CHAR1 | | `P` pending / `A` approved / `R` rejected |
| REJECT_REASON | CHAR200 | | Wajib diisi bila `R` |
| DECIDED_BY | CHAR20 | | Admin yang memutuskan |
| DECIDED_AT | TIMESTAMP | | |
| DCP_ID | CHAR20 | | Terisi bila `A` |
| COLOR_CODE | CHAR20 | | Terisi bila `A` |
| CREATED_AT | TIMESTAMP | | |

### 3.6 ZCP_SO_IMPORT — Kunci Anti-Duplikat

**Peran tunggal: mengunci SO item yang sudah pernah menjadi DCP.** Hanya berisi item yang **approved**. Item yang ditolak sengaja tidak ditulis ke sini supaya bisa diajukan ulang.

| Field | Type | Key | Keterangan |
|---|---|---|---|
| MANDT | MANDT | PK | |
| SO_NUMBER | VBELN | PK | |
| SO_ITEM | POSNR | PK | |
| MATNR | MATNR | | |
| MENGE | MENGE_D | | |
| MEINS | MEINS | | |
| REQUEST_ID | CHAR20 | | |
| DCP_ID | CHAR20 | | |
| COLOR_CODE | CHAR20 | | |
| IMPORTED_BY | CHAR20 | | |
| IMPORTED_AT | TIMESTAMP | | |

### 3.7 ZCP_DCP_HDR — Header DCP

Satu baris per material. Satu request menghasilkan N DCP header.

| Field | Type | Key | Keterangan |
|---|---|---|---|
| MANDT | MANDT | PK | |
| DCP_ID | CHAR20 | PK | `DCP-YYYY-NNNN` |
| REQUEST_ID | CHAR20 | | FK → ZCP_REQUEST |
| SO_NUMBER | VBELN | | |
| SO_ITEM | POSNR | | |
| MATNR | MATNR | | |
| MAKTX | MAKTX | | |
| COLOR_CODE | CHAR20 | | FK → ZCP_COLOR_CODE |
| BUYER_ID | CHAR10 | | |
| SALES_USER | CHAR20 | | |
| QTY_TOTAL | INT4 | | Dari `VBAP-KWMENG` |
| MFG_DATE | DATUM | | Tanggal aktivasi panel pertama |
| EXPIRE_DATE | DATUM | | `MFG_DATE` + 1 tahun |
| REMINDER_DATE | DATUM | | `CREATED_AT` + 2 bulan |
| STATUS | CHAR1 | | `O` open / `C` closed / `R` rejected |
| CLOSE_REASON | CHAR200 | | Wajib diisi bila `R` |
| CLOSED_BY | CHAR20 | | |
| CLOSED_AT | TIMESTAMP | | |
| REMARKS | CHAR200 | | |
| CREATED_BY | CHAR20 | | |
| CREATED_AT | TIMESTAMP | | |
| CHANGED_BY | CHAR20 | | |
| CHANGED_AT | TIMESTAMP | | |

Kolom `QTY_ACTIVE` / `QTY_APPROVED` / `QTY_REJECTED` dari deklarasi 21 Juli **tidak dipakai**. Angka-angka itu dihitung dari `ZCP_DCP_ITEM` saat dibutuhkan, agar tidak pernah ada keadaan di mana penghitung dan kenyataan berbeda.

### 3.8 ZCP_DCP_ITEM — Panel Fisik DCP

| Field | Type | Key | Keterangan |
|---|---|---|---|
| MANDT | MANDT | PK | |
| DCP_ID | CHAR20 | PK | FK → ZCP_DCP_HDR |
| PANEL_NUMBER | NUMC3 | PK | `001`..`NNN` sesuai qty |
| PANEL_ID | CHAR30 | | `DCP-YYYY-NNNN-001` |
| QR_TOKEN | CHAR64 | | Dibuat sekarang, dipakai di sub-proyek 4 |
| STATUS | CHAR2 | | `NA` / `AK` / `SB` / `AP` / `RJ` / `OB` |
| MFG_DATE | DATUM | | Diisi bebas oleh Admin saat aktivasi |
| ACTIVATED_BY | CHAR20 | | |
| ACTIVATED_AT | TIMESTAMP | | |
| SUBMITTED_BY | CHAR20 | | |
| SUBMITTED_AT | TIMESTAMP | | |
| APPROVED_BY | CHAR20 | | |
| APPROVED_AT | TIMESTAMP | | |
| REJECTED_BY | CHAR20 | | |
| REJECTED_AT | TIMESTAMP | | |
| REJECT_REASON | CHAR200 | | |
| UNDO_COUNT | INT4 | | Berapa kali panel ini di-undo |
| REMARKS | CHAR200 | | |
| CREATED_AT | TIMESTAMP | | |
| CHANGED_BY | CHAR20 | | |
| CHANGED_AT | TIMESTAMP | | |

**Unique secondary index `PID` pada (MANDT, PANEL_ID)** — PANEL_ID tercetak di stiker fisik, tidak boleh kembar.

Kolom `MCP_ID` menyusul di sub-proyek 2.

### 3.9 ZCP_PHOTO — Foto Panel

| Field | Type | Key | Keterangan |
|---|---|---|---|
| MANDT | MANDT | PK | |
| PHOTO_ID | CHAR20 | PK | |
| REF_TYPE | CHAR4 | | `DCP` (`MCP` menyusul) |
| REF_ID | CHAR20 | | DCP_ID |
| PANEL_NUMBER | NUMC3 | | |
| PHOTO_SEQ | INT4 | | Urutan 1, 2, 3, ... |
| FILE_NAME | CHAR100 | | Nama file asli |
| MIME_TYPE | CHAR40 | | `image/jpeg`, `image/png` |
| FILE_SIZE | INT4 | | Byte |
| PHOTO_DATA | RAWSTRING | | Isi file (sementara, sampai sub-proyek 4) |
| DMS_DOC_TYPE | CHAR4 | | Kosong sampai sub-proyek 4 (`ZDCP`) |
| DMS_DOCNUM | CHAR25 | | Kosong sampai sub-proyek 4 |
| DMS_DOCPART | CHAR3 | | Kosong sampai sub-proyek 4 |
| DMS_DOCVERS | CHAR2 | | Kosong sampai sub-proyek 4 |
| UPLOADED_BY | CHAR20 | | |
| UPLOADED_AT | TIMESTAMP | | |

Secondary index `REF` pada (MANDT, REF_TYPE, REF_ID, PANEL_NUMBER).

Batas ukuran: maksimum 2 MB per foto, divalidasi di sisi klien dan diulang di server.

### 3.10 ZCP_AUDIT_LOG — Audit Trail

| Field | Type | Key | Keterangan |
|---|---|---|---|
| MANDT | MANDT | PK | |
| LOG_ID | CHAR20 | PK | Berurutan via SNRO |
| REF_TYPE | CHAR4 | | `REQ` / `DCP` / `USER` / `AUTH` |
| REF_ID | CHAR20 | | |
| PANEL_NUMBER | NUMC3 | | Diisi bila aksi menyangkut satu panel |
| ACTION | CHAR20 | | `LOGIN`, `LOGIN_FAIL`, `CREATE`, `APPROVE`, `REJECT`, `ACTIVATE`, `SUBMIT`, `UNDO`, `CLOSE` |
| OLD_VALUE | CHAR200 | | |
| NEW_VALUE | CHAR200 | | |
| DESCRIPTION | CHAR200 | | |
| ACTION_BY | CHAR20 | | `USER_ID`, bukan `SY-UNAME` |
| ACTION_AT | TIMESTAMP | | |
| IP_ADDRESS | CHAR45 | | Panjang 45 agar muat IPv6 |

### 3.11 Relasi

```
ZCP_REQUEST (1 SO)
   └─→ ZCP_REQUEST_ITM (N, satu per SO item)
          └─(bila approved)─→ ZCP_DCP_HDR (1)
                                 ├─→ ZCP_COLOR_CODE (1:1 dengan MATNR)
                                 ├─→ ZCP_SO_IMPORT  (kunci so_number + so_item)
                                 └─→ ZCP_DCP_ITEM   (N panel, sesuai qty SO)
                                        └─→ ZCP_PHOTO (min 2 saat submit)
```

### 3.12 Domain dengan Fixed Value

Status memakai domain berdaftar nilai tetap, bukan CHAR bebas. Efeknya: SM30 dan bantuan pencarian menampilkan teks, dan nilai salah tertangkap saat aktivasi tabel.

| Domain | Nilai |
|---|---|
| `ZCP_DOM_ROLE` | SALES, ADMIN, IT |
| `ZCP_DOM_REQ_ST` | P, C |
| `ZCP_DOM_ITM_ST` | P, A, R |
| `ZCP_DOM_DCP_ST` | O, C, R |
| `ZCP_DOM_PANEL_ST` | NA, AK, SB, AP, RJ, OB |
| `ZCP_DOM_CC_ST` | A, I, O |

### 3.13 Number Range (SNRO)

| Objek | Interval | Format hasil |
|---|---|---|
| `ZCP_COLOR` | 00001–99999 | `KW00001` |
| `ZCP_REQ` | 0001–9999 per tahun | `REQ-2026-0001` |
| `ZCP_DCP` | 0001–9999 per tahun | `DCP-2026-0001` |
| `ZCP_PHOTO` | 1–999999999 | `PH000000001` |
| `ZCP_AUDIT` | 1–999999999999 | `LOG000000000001` |

Pembentukan string dilakukan `ZCL_CP_NUMBER`; halaman dan kelas lain tidak pernah menyusun format ID sendiri.

---

## 4. Komponen

### 4.1 Kelas ABAP

| Kelas | Tanggung jawab | Alasan batas ini |
|---|---|---|
| `ZCL_CP_AUTH` | Login, hash SHA256, session cookie, guard halaman, cek role | Satu-satunya yang tahu soal session. Bila kelak pindah ke SAP user asli, hanya kelas ini yang berubah |
| `ZCL_CP_SO_READER` | Baca VBAK/VBAP, validasi SO, saring material yang belum punya Color Code dan belum terkunci di SO_IMPORT | Satu-satunya yang menyentuh tabel SD. Bisa diuji lewat SE38 dengan SO nyata |
| `ZCL_CP_REQUEST` | Buat request, approve/reject per item, hitung status header | |
| `ZCL_CP_DCP` | Generate Color Code + header + panel, aktivasi, submit, approve, reject, undo, close | Rumah seluruh aturan siklus DCP |
| `ZCL_CP_PHOTO` | Upload, validasi jumlah dan ukuran, simpan XSTRING | Titik tunggal yang diganti ke DMS di sub-proyek 4 |
| `ZCL_CP_NUMBER` | Pembungkus SNRO dan format ID | Format ID tidak tersebar |
| `ZCL_CP_AUDIT` | Tulis jejak aksi | Dipanggil semua kelas lain |

Semua method yang bisa gagal melempar exception kelas `ZCX_CP_ERROR` (subclass `CX_STATIC_CHECK`) dengan message class `ZCP`. Halaman menangkap exception dan menampilkan pesannya; tidak ada pesan error yang ditulis langsung sebagai literal di halaman.

### 4.2 Halaman BSP

Aplikasi `ZBSP_COLOR_PANEL`, semua halaman **stateful**.

| Halaman | Role | Isi |
|---|---|---|
| `login.htm` | — | Form login |
| `main.htm` | semua | Router berdasarkan role |
| `req_list.htm` | SALES, ADMIN | Sales: daftar request miliknya. Admin: inbox request pending |
| `req_form.htm` | SALES | Input nomor SO → tampilkan material dari VBAP dengan penanda kelayakan → submit |
| `req_detail.htm` | ADMIN | Daftar material request, centang mana yang di-approve, isi alasan bagi yang ditolak |
| `dcp_list.htm` | ADMIN, IT | Daftar DCP dengan filter status |
| `dcp_detail.htm` | ADMIN | Grid panel: aktivasi, upload foto + submit, approve/reject, undo, close header |
| `admin_user.htm` | IT | Maintenance `ZCP_USER` |

Master Buyer tidak dibuatkan halaman: datanya jarang berubah dan tanpa logic khusus, SM30 sudah cukup.

Master User **tidak bisa** lewat SM30, karena SM30 tidak dapat meng-hash password — yang tersimpan akan berupa teks polos dan login selalu gagal. Karena itu `admin_user.htm` wajib ada dan harus memanggil `ZCL_CP_AUTH` untuk menyusun hash.

### 4.3 Alur Navigasi

```
login.htm --> main.htm (router)
    |
    +-- SALES --> req_list.htm --> req_form.htm
    |
    +-- ADMIN --> req_list.htm --> req_detail.htm
    |                 |
    |                 +--> dcp_list.htm --> dcp_detail.htm
    |
    +-- IT ------> admin_user.htm
```

---

## 5. Aturan Bisnis dan State Machine

### 5.1 Status Request Header Dihitung, Bukan Disimpan Terpisah

`ZCP_REQUEST-STATUS` diperbarui dalam transaksi yang sama dengan keputusan item, memakai aturan: `C` bila tidak ada lagi item berstatus `P`, selain itu `P`. Ini mencegah keadaan di mana header berkata "closed" padahal masih ada item menggantung.

### 5.2 State Machine

```
Request item (ZCP_REQUEST_ITM)
  P ──approve──→ A   (menghasilkan Color Code + DCP header + panel)
  P ──reject───→ R   (wajib alasan; boleh diajukan ulang di request baru)

Request header (ZCP_REQUEST)
  P ──→ C   (dihitung: tidak ada item P tersisa)

DCP header (ZCP_DCP_HDR)
  O ──close──→ C    (syarat: minimal 1 panel berstatus AP)
  O ──reject─→ R    (wajib alasan; buyer batal)

Panel (ZCP_DCP_ITEM)
  NA ──aktivasi (Admin isi MFG_DATE bebas)──→ AK
  AK ──submit (minimal 2 foto)─────────────→ SB
  SB ──approve─────────────────────────────→ AP
  SB ──reject (wajib alasan)────────────────→ RJ
  AP/RJ ──undo──→ SB    (hanya selama DCP header masih O)
  panel selain AP saat header di-close ──→ OB
```

### 5.3 Aturan Rinci

**R1 — Kelayakan material.** Material dari SO layak menjadi DCP hanya bila belum punya baris di `ZCP_COLOR_CODE` (cek `MATNR`) **dan** SO item-nya belum ada di `ZCP_SO_IMPORT`. Material yang tidak layak tetap ditampilkan di `req_form.htm` dengan alasan ketidaklayakannya, tidak disembunyikan — Sales perlu tahu bedanya "SO salah" dan "material ini memang sudah pernah dibuat".

**R2 — Jumlah panel.** Saat approve, dibuat panel sebanyak `VBAP-KWMENG` (dibulatkan ke bilangan bulat), semuanya berstatus `NA`.

**R3 — Aktivasi.** Admin bebas mengisi `MFG_DATE`, tidak dipaksa hari ini. `MFG_DATE` tidak boleh di masa depan. `ZCP_DCP_HDR-MFG_DATE` dan `EXPIRE_DATE` diisi dari aktivasi panel pertama; `EXPIRE_DATE` = `MFG_DATE` + 1 tahun.

**R4 — Submit.** Panel hanya bisa disubmit dari status `AK` dan hanya bila memiliki minimal 2 foto yang tersimpan lengkap.

**R5 — Undo.** Panel `AP` atau `RJ` dapat dikembalikan ke `SB` selama header masih `O`. `UNDO_COUNT` bertambah dan aksinya masuk audit log. Setelah header di-close, undo ditolak — panel `AP` sudah mengalir ke MCP di sub-proyek 2 dan menariknya kembali merusak data hilir.

**R6 — Close header.** Butuh minimal 1 panel `AP`. Saat close, semua panel selain `AP` menjadi `OB`.

**R7 — Reject header.** Wajib alasan. Semua panel menjadi `OB`.

**R8 — Reminder.** `REMINDER_DATE` = tanggal pembuatan + 2 bulan. Sub-proyek 1 hanya mengisi dan menampilkan kolomnya di `dcp_list.htm`; notifikasi aktif menyusul di sub-proyek 5.

**R9 — Cakupan Sales.** Sales dengan `BUYER_ID` terisi hanya melihat dan membuat request untuk buyer tersebut.

### 5.4 Alur Kritis: Admin Approve Item Request

Dijalankan dalam satu unit kerja per SO:

```
ENQUEUE lock atas SO_NUMBER
  untuk tiap SO item yang dicentang:
    cek ulang: belum ada di ZCP_SO_IMPORT      -> bila ada, tolak item ini
    cek ulang: MATNR belum ada di ZCP_COLOR_CODE -> bila ada, tolak item ini
    buat ZCP_COLOR_CODE  (KW + 5 digit dari SNRO)
    buat ZCP_DCP_HDR     (DCP-YYYY-NNNN)
    buat N ZCP_DCP_ITEM  status NA sebanyak qty SO
    tulis ZCP_SO_IMPORT
    perbarui ZCP_REQUEST_ITM -> A
  hitung ulang status ZCP_REQUEST
  COMMIT WORK   (atau ROLLBACK WORK bila ada kegagalan)
DEQUEUE
```

Pengecekan diulang di dalam kunci meskipun sudah dilakukan saat Sales input, karena jeda antara submit dan approve bisa berhari-hari dan kondisinya dapat berubah.

---

## 6. Penanganan Error

| # | Situasi | Perilaku |
|---|---|---|
| 1 | SO tidak ada di VBAK | Pesan spesifik "SO {nomor} tidak ditemukan" |
| 2 | SO ada tapi semua materialnya sudah punya Color Code | Pesan berbeda dari no.1, disertai daftar Color Code yang sudah ada. Sales harus bisa membedakan salah ketik dan material yang memang sudah pernah dibuat |
| 3 | Dua Admin approve SO yang sama bersamaan | ENQUEUE; yang kalah menerima "SO item ini sudah diproses oleh {user} pada {waktu}", bukan short dump |
| 4 | Upload foto gagal di tengah | Submit hanya sah bila seluruh foto tersimpan. Bila foto kedua gagal, panel tetap `AK` dan foto pertama dihapus — tidak boleh ada panel `SB` dengan satu foto |
| 5 | Foto melebihi 2 MB atau bukan JPEG/PNG | Ditolak di klien, divalidasi ulang di server |
| 6 | Session kedaluwarsa | Redirect ke `login.htm` dengan pesan, bukan halaman error |
| 7 | Login gagal | Pesan seragam "User atau password salah" tanpa membedakan mana yang salah; dicatat sebagai `LOGIN_FAIL` di audit log |

---

## 7. Cara Verifikasi

**Bisa diuji otomatis (ABAP Unit).** Method tanpa akses database dipisahkan agar dapat diuji langsung: `ZCL_CP_DCP=>can_close( )`, `ZCL_CP_DCP=>is_valid_transition( )`, `ZCL_CP_NUMBER=>format_color_code( )`, perhitungan `EXPIRE_DATE` dan `REMINDER_DATE`, serta perhitungan status request header di 5.1.

**Diuji lewat report SE38 di sandbox.** `ZCP_TEST_SO_READER` menjalankan `ZCL_CP_SO_READER` dengan nomor SO nyata dan menampilkan hasil saringnya. Ini cara tercepat memastikan pembacaan VBAK/VBAP benar tanpa membuka browser.

**Manual.** Seluruh halaman BSP. Tidak ada cara uji otomatis yang masuk akal untuk BSP di 1809; ini disebutkan terbuka agar tidak diklaim lebih dari kenyataannya.

**Skenario uji end-to-end yang harus lulus sebelum sub-proyek 1 dinyatakan selesai:**

1. Sales login, input SO valid, melihat material layak dan tidak layak beserta alasannya, submit request
2. Admin login, approve 2 dari 3 material, reject 1 dengan alasan
3. Color Code, DCP header, dan panel sejumlah qty SO terbentuk untuk yang di-approve
4. Sales membuat request baru dengan SO sama untuk material yang tadi ditolak — harus diterima
5. Sales membuat request untuk material yang tadi di-approve — harus ditolak dengan alasan jelas
6. Admin mengaktifkan 3 panel dengan tanggal mundur, upload 2 foto, submit, approve 1 dan reject 1
7. Admin melakukan undo pada panel yang di-reject, lalu approve
8. Admin close DCP header; panel selain `AP` menjadi `OB`
9. Undo setelah close ditolak
10. Audit log memuat seluruh aksi di atas dengan `USER_ID` yang benar, bukan `auto_email`

---

## 8. Konfigurasi SAP yang Dibutuhkan

| Konfigurasi | T-Code | Keterangan |
|---|---|---|
| Package `ZCOLOR` | SE80 | Awal boleh `$TMP`, dipindah sebelum transport |
| Domain & Data Element `ZCP_*` | SE11 | Lihat 3.12 |
| 10 Z-Table | SE11 | Lihat bagian 3 |
| Number Range | SNRO | Lihat 3.13 |
| Table Maintenance Generator | SE11/SE55 | `ZCP_BUYER` saja; auth group `&NC&` |
| Message Class `ZCP` | SE91 | Seluruh pesan error |
| Aplikasi BSP `ZBSP_COLOR_PANEL` | SE80 | Semua halaman stateful |
| SICF Service | SICF | `/sap/bc/bsp/sap/zbsp_color_panel`, default user `auto_email` |

---

## 9. Aturan Teknis Wajib

Diadopsi dari pengalaman ECM BSP di sistem yang sama:

1. **Nol karakter non-ASCII di seluruh sumber BSP.** BSP merusak semua karakter di atas U+007F. Pakai HTML entity (`&mdash;`, `&#8226;`, `&#10003;`). Gejala kerusakannya menyesatkan — halaman rusak di tempat yang tidak berhubungan dengan perubahan terakhir.
2. **OpenSQL gaya lama tanpa `@`.** `SELECT f1 f2 INTO TABLE lt_data FROM ztab WHERE f = lv_var.` Tidak ada inline `DATA(...)`, tidak ada `VALUE #( )`. Semua variabel dideklarasikan eksplisit.
3. **Semua halaman stateful.**
4. **Atribut `class` dalam string JavaScript harus satu baris**, jangan dipecah antar baris.
5. **Tidak ada `SY-UNAME` sebagai identitas pelaku.** Selalu `USER_ID` dari session.

---

## 10. Pertanyaan Terbuka (Tidak Menghambat Sub-Proyek 1)

| # | Pertanyaan | Dampak |
|---|---|---|
| 1 | Konsep bisnis SP: dibuat dari MCP atau dari SO? Berapa pcs? Beda masa aktif dan masa pakai? Alur peminjaman? | Menghambat sub-proyek 3; perlu sesi brainstorming terpisah dengan Yogi |
| 2 | Setup DOKAR `ZDCP` / `ZMCP` di DC10 dan Content Server | Menghambat sub-proyek 4 |
| 3 | Work Center: pakai standar SAP (CRHD) atau `ZCP_WC` custom? | Menghambat sub-proyek 3 |
| 4 | Apakah SO color panel punya penanda khusus (jenis dokumen, divisi, atau kelompok material) agar `ZCL_CP_SO_READER` bisa menolak SO non-color-panel? | Memperbaiki pesan error no.1 di bagian 6; sub-proyek 1 tetap jalan tanpa ini |
