# Technical Design — ZBSP_COLOR_PANEL (SAP BSP)

**Project:** Color Panel Management System
**Company:** PT. Kayu Mebel Indonesia (KMI)
**Platform:** SAP S/4HANA 1809 On-Premise (BASIS 753 SP03)
**BSP Application:** ZBSP_COLOR_PANEL
**Date:** 15 Juli 2026
**Author:** Arya (ABAP Developer) + AI Assistant SAP
**Status:** DRAFT — Pending Review

---

## 1. Overview

### 1.1 Background
KMI saat ini menggunakan aplikasi web PHP (Laravel) untuk mengelola panel warna furniture di pabrik Surabaya. Aplikasi ini akan dipindahkan ke SAP BSP agar terintegrasi dengan ekosistem SAP KMI (DMS, ECM, QM).

### 1.2 Scope
Migrasi lengkap sistem Color Panel dari Laravel ke SAP BSP, mencakup:
- **DCP** (Development Color Panel) — buyer request → review → approve/iterasi
- **MCP** (Master Color Panel) — approved, disimpan untuk QC
- **CP** (Copy Panel) — salinan MCP, distribusi ke workstation
- **Borrowing** — peminjaman/returning Copy Panel oleh operator
- **Dashboard** — monitoring real-time
- **Label & QR** — generate dan cetak label panel

### 1.3 Approach
**Custom Z-Table + BSP** (bukan PM Equipment).
Alasan: pattern proven (ECM BSP), business logic spesifik, cepat develop.

### 1.4 Reference
- Laravel source: `git@github.com:bagusbatra/color_trial_surabaya.git` (branch `feat/copy-qr-lifecycle`)
- Local copy: `/mnt/data/files/sap-docs/Color_Panel/color_trial_surabaya` di srv168
- Insight doc: `/mnt/data/files/sap-docs/Color_Panel/color_panel_insight.md`

---

## 2. Architecture

### 2.1 BSP Application

| Property | Value |
|----------|-------|
| BSP App Name | ZBSP_COLOR_PANEL |
| Package | $TMP (local), nanti dipindah ke ZCOLOR |
| Stateful | Yes (semua page) |
| Controller | Tidak ada (Pages + Event Handler only) |
| SICF Service | `/sap/bc/bsp/sap/zbsp_color_panel/` |
| SICF Default User | `auto_email` (shared login, sama kayak ECM) |

### 2.2 Custom Login
Sama kayak ZBSP_ECM_APP:
- SICF default user = `auto_email`
- BSP redirect ke login page custom
- Auth via Z-table (ZCP_USER) dengan SHA256 hash
- Session stored via `cl_bsp_server_side_cookie`

### 2.3 Frontend Stack
- Tailwind CSS CDN
- SweetAlert2
- Font Awesome 6
- Google Fonts (Plus Jakarta Sans)
- JavaScript QR: `html5-qrcode` (browser-based)
- Label PDF: `jsPDF` (client-side) atau SmartForm (server-side)

### 2.4 Backend Stack
- ABAP (OpenSQL old-style, no `@` prefix)
- BAPI: `BAPI_DOCUMENT_CHANGE2` (kalau DMS integration needed)
- FM: `CALCULATE_HASH_FOR_CHAR` (SHA256 password)

---

## 3. Z-Table Schemas

### 3.1 Overview Tables

| # | Table | Description | Source (Laravel) |
|---|-------|-------------|------------------|
| 1 | ZCP_USER | User & role management | it_users + borrower_users + qc_users |
| 2 | ZCP_BUYER | Master buyer | buyers |
| 3 | ZCP_WC | Master work center | wc_master |
| 4 | ZCP_DCP_HDR | Header DCP | dcp_headers |
| 5 | ZCP_DCP_ITEM | Item DCP | dcp_items |
| 6 | ZCP_MCP | Master Color Panel | master_color_panel |
| 7 | ZCP_CP | Copy Panel | color_stock_items |
| 8 | ZCP_BORROW | Transaksi peminjaman header | stock_transactions |
| 9 | ZCP_BORROW_ITM | Detail peminjaman | transaction_items |
| 10 | ZCP_BORROW_ARC | Arsip peminjaman selesai | peminjaman_selesai |
| 11 | ZCP_AUDIT_LOG | Audit trail | audit_logs |

---

### 3.2 ZCP_USER — User & Role

**Purpose:** Autentikasi dan otorisasi semua role. Replaces: it_users, borrower_users, qc_users, admin_users, approval_users.

| Field | Type | Key | Description |
|-------|------|-----|-------------|
| MANDT | CLNT 3 | PK | Client |
| USER_ID | CHAR 20 | PK | User ID (login) |
| FULL_NAME | CHAR 50 | | Nama lengkap |
| PASSWORD | CHAR 64 | | SHA256 hash |
| EMAIL | CHAR 80 | | Email |
| NIK | CHAR 16 | | Nomor induk karyawan |
| ROLE | CHAR 30 | | Multi-role comma-separated: IT, BORROWER, QC, ADMIN, APPROVAL |
| WC_ID | CHAR 8 | | Work Center (khusus BORROWER) |
| STATUS | CHAR 1 | | Y=active, N=nonactive |
| LAST_LOGIN | DATS 8 | | Tanggal login terakhir |
| CREATED_DATE | DATS 8 | | Tanggal dibuat |
| CREATED_BY | CHAR 20 | | Dibuat oleh |

**TMG:** SM30 via &NC&
**Note:** Sama pattern dengan ZECM_USER di ECM project.

---

### 3.3 ZCP_BUYER — Master Buyer

**Purpose:** Data buyer/customer. Replaces: buyers table.

| Field | Type | Key | Description |
|-------|------|-----|-------------|
| MANDT | CLNT 3 | PK | Client |
| BUYER_ID | NUMC 8 | PK | Auto-number |
| KODE_BUYER | CHAR 20 | | Kode buyer (unik) |
| NAMA_BUYER | CHAR 100 | | Nama buyer |
| CREATED_DATE | DATS 8 | | |

---

### 3.4 ZCP_WC — Work Center

**Purpose:** Master workstation. Replaces: wc_master.

| Field | Type | Key | Description |
|-------|------|-----|-------------|
| MANDT | CLNT 3 | PK | Client |
| WC_ID | NUMC 8 | PK | Auto-number |
| WC_CODE | CHAR 20 | | Kode WC (unik) |
| WC_DESC | CHAR 100 | | Deskripsi WC |
| CATEGORY | CHAR 20 | | PAINTING / QC_PACKING / QC_INSPECT |
| PARENT_WC_ID | NUMC 8 | | Parent WC (hierarchy, nullable) |
| IS_ACTIVE | CHAR 1 | | Y/N |
| CREATED_DATE | DATS 8 | | |

---

### 3.5 ZCP_DCP_HDR — Header DCP

**Purpose:** Header Development Color Panel. 1 header = 1 PO/request. Replaces: dcp_headers.

| Field | Type | Key | Description |
|-------|------|-----|-------------|
| MANDT | CLNT 3 | PK | Client |
| DCP_ID | NUMC 8 | PK | Auto-number (SNRO) |
| NO_PO | CHAR 60 | | No PO format: {no}/KMI/{romawi}/{tahun} |
| PO_NUMBER | CHAR 20 | | Angka PO (input manual) |
| PO_MONTH | NUMC 2 | | 1-12 |
| PO_YEAR | NUMC 4 | | Tahun 4 digit |
| BUYER_ID | NUMC 8 | | FK → ZCP_BUYER |
| CUSTOMER_NAME | CHAR 100 | | Snapshot nama customer |
| NOTES | CHAR 255 | | Catatan |
| IS_MANUAL | CHAR 1 | | Y=hard-create (tanpa approval), N=normal |
| STATUS | CHAR 12 | | DRAFT / IN_PROGRESS / REVIEW / APPROVED / REJECTED |
| CREATED_BY | CHAR 20 | | FK → ZCP_USER |
| CREATED_DATE | DATS 8 | | |
| CREATED_TIME | TIMS 6 | | |

**SNRO:** ZCP_DCP (number range 01, external atau internal)

---

### 3.6 ZCP_DCP_ITEM — Item DCP

**Purpose:** Detail item per DCP. 1 DCP bisa punya banyak item (material + finish code). Replaces: dcp_items.

| Field | Type | Key | Description |
|-------|------|-----|-------------|
| MANDT | CLNT 3 | PK | Client |
| ITEM_ID | NUMC 8 | PK | Auto-number |
| DCP_ID | NUMC 8 | FK | FK → ZCP_DCP_HDR |
| KODE_MATERIAL | CHAR 40 | | Kode material |
| FINISH_CODE | CHAR 100 | | Finish code |
| SOLID | CHAR 100 | | Finish code solid (nullable) |
| VENEER | CHAR 100 | | Finish code veneer (nullable) |
| COLOR_CODE | CHAR 10 | | Auto: KW + 5 digit (KW00001) |
| QTY | INT 4 | | Jumlah lembar kartu |
| QR_TOKEN | CHAR 64 | | Token unik untuk QR (128-bit hex) |
| QR_DATA | STRING | | Base64 PNG QR code (nullable) |
| IS_LOCKED | CHAR 1 | | Y=locked (sudah diturunkan MCP) |
| SEQ_ORDER | INT 4 | | Urutan item |
| CREATED_DATE | DATS 8 | | |

**Color Code Logic:**
- Prefix: `KW` (dulu `WC`, migrasi ke `KW`)
- 5 digit: KW00001, KW00002, ...
- Auto-generate: MAX(SUBSTRING(color_code, 3)) + 1
- Unik per item, tidak boleh reuse setelah delete

---

### 3.7 ZCP_MCP — Master Color Panel

**Purpose:** MCP = turunan dari DCP item yang sudah approved. Replaces: master_color_panel (filtered: is_master_only=1 AND dcp_item_id IS NOT NULL).

| Field | Type | Key | Description |
|-------|------|-----|-------------|
| MANDT | CLNT 3 | PK | Client |
| MCP_ID | NUMC 8 | PK | Auto-number |
| PANEL_CODE | CHAR 20 | | Format: MCP-{itemId}-R{rev} |
| DCP_ITEM_ID | NUMC 8 | | FK → ZCP_DCP_ITEM |
| BUYER_ID | NUMC 8 | | FK → ZCP_BUYER |
| COLOR_NAME | CHAR 100 | | Nama warna |
| PANEL_TYPE | CHAR 15 | | GOLDEN / PRODUCTION / BUYER_APPROVED |
| LEMARI | CHAR 2 | | A-Y |
| RACK_NUMBER | CHAR 2 | | 01-32 |
| MFG_DATE | DATS 8 | | Tanggal produksi |
| EXPIRED_DATE | DATS 8 | | MFG_DATE + 6 bulan (MCP_VALID_MONTHS) |
| IS_ACTIVE | CHAR 1 | | Y=aktif, N=nonaktif |
| RENEW_WINDOW | NUMC 2 | | 30 hari sebelum expired (MCP_RENEW_DAYS) |
| REVISION_NUM | INT 4 | | Revisi 0, 1, 2, ...
| PARENT_MCP_ID | NUMC 8 | | FK → ZCP_MCP (revisi sebelumnya) |
| QR_TOKEN | CHAR 64 | | Token unik untuk QR scan QC |
| QR_DATA | STRING | | Base64 PNG QR |
| CHECKOUT_STATUS | CHAR 3 | | IN / OUT |
| CHECKED_OUT_BY | CHAR 20 | | FK → ZCP_USER (QC yang checkout) |
| CHECKED_OUT_AT | TIMESTAMP | | Waktu checkout |
| DEACTIVATED_AT | TIMESTAMP | | Waktu nonaktif |
| DEACTIVATED_BY | CHAR 20 | | Siapa yang nonaktifkan |
| NOTES | CHAR 255 | | |
| CREATED_DATE | DATS 8 | | |
| CREATED_BY | CHAR 20 | | |

**Business Rules:**
- GOLDEN: tidak boleh dipinjam, tidak boleh jadi sumber copy
- PRODUCTION: satu-satunya sumber sah pembuatan copy
- BUYER_APPROVED: dikirim ke buyer
- Expired: MFG_DATE + 6 bulan
- Renew window: 30 hari terakhir sebelum expired
- Checkout: hanya oleh user role QC, hanya dari WC kategori QC
- Rack capacity: max 3 MCP per rack

---

### 3.8 ZCP_CP — Copy Panel

**Purpose:** Copy panel = turunan dari MCP, distribusi ke workstation. Replaces: color_stock_items (filtered: mcp_id IS NOT NULL).

| Field | Type | Key | Description |
|-------|------|-----|-------------|
| MANDT | CLNT 3 | PK | Client |
| CP_ID | NUMC 8 | PK | Auto-number |
| MCP_ID | NUMC 8 | | FK → ZCP_MCP |
| COLOR_CODE | CHAR 10 | | {NNN}-{color_name} |
| COLOR_NAME | CHAR 100 | | Nama warna |
| BUYER_ID | NUMC 8 | | FK → ZCP_BUYER |
| LEMARI | CHAR 2 | | A-Y |
| RACK_NUMBER | CHAR 2 | | 01-32 |
| COMPONENT_TYPE | CHAR 15 | | PANEL_STEP / FINISH_STEP |
| MFG_DATE | DATS 8 | | Tanggal produksi |
| EXPIRED_DATE | DATS 8 | | MFG_DATE + 90 hari (COPY_VALID_DAYS) |
| RENEW_WINDOW | NUMC 2 | | 10 hari sebelum expired (COPY_RENEW_DAYS) |
| STATUS | CHAR 12 | | AVAILABLE / BORROWED / UNAVAILABLE / EXPIRED / RENEW / FINISHED / INACTIVE |
| QR_TOKEN | CHAR 64 | | Token unik |
| QR_DATA | STRING | | Base64 PNG QR |
| PDF_DOWNLOADED | CHAR 1 | | Y/N (label sudah pernah di-download) |
| DEACTIVATED_AT | TIMESTAMP | | |
| DEACTIVATED_BY | CHAR 20 | | |
| CREATED_DATE | DATS 8 | | |
| CREATED_BY | CHAR 20 | | |

**Status ENUM:**
- AVAILABLE: siap dipinjam, QR aktif
- BORROWED: sedang dipinjam
- UNAVAILABLE: sudah dikembalikan, QR dikosongkan (perlu IT regenerate)
- EXPIRED: expired (dihitung dari expired_date)
- RENEW: dalam window renew (10 hari terakhir)
- FINISHED: selesai (semua item dikembalikan)
- INACTIVE: nonaktif/arsip

**Effective Status Logic (saat render):**
```
IF status IN (INACTIVE, FINISHED, BORROWED, UNAVAILABLE)
  → return status as-is
ELSE
  → hitung dari expired_date:
    IF NOW > expired_date → EXPIRED
    IF NOW > expired_date - RENEW_WINDOW → RENEW
    ELSE → AVAILABLE
```

---

### 3.9 ZCP_BORROW — Transaksi Peminjaman Header

**Purpose:** Header transaksi peminjaman. Replaces: stock_transactions.

| Field | Type | Key | Description |
|-------|------|-----|-------------|
| MANDT | CLNT 3 | PK | Client |
| BORROW_ID | NUMC 8 | PK | Auto-number |
| TRX_NUMBER | CHAR 20 | | Format: TRX/{week}/{seq} |
| BORROWER_ID | CHAR 20 | | FK → ZCP_USER |
| BORROWER_NAME | CHAR 50 | | Snapshot nama borrower |
| BORROWER_NIK | CHAR 16 | | Snapshot NIK |
| BORROWER_WC | CHAR 20 | | Snapshot WC code |
| TRX_DATE | DATS 8 | | Tanggal transaksi |
| TRX_TIME | TIMS 6 | | Jam transaksi |
| EXPECTED_RETURN | DATS 8 | | TRX_DATE + 90 hari |
| STATUS | CHAR 10 | | APPROVED / OVERDUE / COMPLETED |
| NOTES | CHAR 255 | | |
| IS_ROTATED | CHAR 1 | | Y=pernah dirotasi |
| ROTATION_ID | NUMC 8 | | FK → rotation table (jika ada) |

---

### 3.10 ZCP_BORROW_ITM — Detail Peminjaman

**Purpose:** Item per transaksi peminjaman. Replaces: transaction_items.

| Field | Type | Key | Description |
|-------|------|-----|-------------|
| MANDT | CLNT 3 | PK | Client |
| BORROW_ITM_ID | NUMC 8 | PK | Auto-number |
| BORROW_ID | NUMC 8 | FK | FK → ZCP_BORROW |
| CP_ID | NUMC 8 | | FK → ZCP_CP |
| COLOR_CODE | CHAR 10 | | Snapshot code_color |
| BORROWER_ID | CHAR 20 | | FK → ZCP_USER |
| BORROW_DATE | DATS 8 | | Tanggal pinjam |
| EXPECTED_RETURN | DATS 8 | | Borrow + 90 hari |
| EXPIRED_BEFORE | DATS 8 | | expired_date sebelum dipinjam |
| EXPIRED_AFTER | DATS 8 | | expired_date setelah dipinjam (borrow + 90) |
| BORROW_STATUS | CHAR 10 | | BORROWED / RETURNED |
| ACTUAL_RETURN | DATS 8 | | Tanggal kembali aktual |

---

### 3.11 ZCP_BORROW_ARC — Arsip Peminjaman

**Purpose:** Arsip transaksi selesai (semua item returned). Replaces: peminjaman_selesai.

| Field | Type | Key | Description |
|-------|------|-----|-------------|
| MANDT | CLNT 3 | PK | Client |
| ARCHIVE_ID | NUMC 8 | PK | Auto-number |
| BORROW_ID | NUMC 8 | | Original borrow ID |
| TRX_NUMBER | CHAR 20 | | Original TRX number |
| BORROWER_ID | CHAR 20 | | |
| BORROWER_NAME | CHAR 50 | | |
| BORROWER_NIK | CHAR 16 | | |
| TRX_DATE | DATS 8 | | |
| ACTUAL_RETURN | DATS 8 | | |
| TOTAL_ITEMS | INT 4 | | Jumlah item |
| TOTAL_DAYS | INT 4 | | Total hari pinjam |
| ITEMS_SNAPSHOT | STRING | | JSON snapshot semua item |
| ARCHIVED_BY | CHAR 20 | | |
| ARCHIVED_DATE | DATS 8 | | |

---

### 3.12 ZCP_AUDIT_LOG — Audit Trail

**Purpose:** Log semua aksi. Replaces: audit_logs.

| Field | Type | Key | Description |
|-------|------|-----|-------------|
| MANDT | CLNT 3 | PK | Client |
| LOG_ID | NUMC 12 | PK | Auto-number |
| ACTION_TYPE | CHAR 30 | | LOGIN / LOGOUT / CREATE_DCP / DERIVE_MCP / DERIVE_CP / BORROW / RETURN / CHECKOUT_MCP / RETURN_MCP / RENEW / DEACTIVATE / WC_ROTATION |
| USER_ID | CHAR 20 | | FK → ZCP_USER |
| USER_ROLE | CHAR 15 | | IT / BORROWER / QC |
| DETAILS | CHAR 255 | | Deskripsi aksi |
| TIMESTAMP | TIMESTAMP | | Waktu aksi |
| IP_ADDR | CHAR 15 | | IP address |

---

## 4. Business Rules & Status Flows

### 4.1 DCP Status Flow

```
DRAFT ──→ IN_PROGRESS ──→ REVIEW ──→ APPROVED
                                    ↘ REJECTED ──→ IN_PROGRESS (loop)
```

| Transition | Trigger | Who |
|-----------|---------|-----|
| → DRAFT | Buat DCP baru | IT |
| DRAFT → IN_PROGRESS | Mulai kerjakan | IT |
| IN_PROGRESS → REVIEW | Submit review | IT |
| REVIEW → APPROVED | Approve | Approver |
| REVIEW → REJECTED | Reject (dengan alasan) | Approver |
| REJECTED → IN_PROGRESS | Iterasi | Auto (setelah reject) |

### 4.2 MCP Lifecycle

```
[Created dari DCP APPROVED] ──→ ACTIVE ──→ RENEW (30 hari sebelum exp) ──→ EXPIRED
                                              ↓
                                         RENEWED ──→ ACTIVE (reset timer)
```

- Created: DCP item APPROVED → derive ke MCP (wajib lemari + rack)
- Expired: MFG_DATE + 6 bulan (MCP_VALID_MONTHS = 6)
- Renew: 30 hari terakhir (MCP_RENEW_DAYS = 30)
- Nonaktif: manual oleh IT (IS_ACTIVE = N)
- Checkout QC: QC scan → checkout (IN→OUT), return (OUT→IN)

### 4.3 CP Status Flow

```
[Created dari MCP] ──→ AVAILABLE ──→ BORROWED ──→ UNAVAILABLE (return) ──→ [IT regenerate QR]
                       ↓                                    ↓
                    EXPIRED (idle 90 hari)            EXPIRED (borrowed 90 hari)
                       ↓
                    RENEW (10 hari sebelum exp)
                       ↓
                    RENEWED ──→ AVAILABLE (reset timer)
```

**Effective Status (dihitung saat render, bukan disimpan):**
- INACTIVE/FINISHED/BORROWED/UNAVAILABLE: tampilkan apa adanya
- Seleksinya: hitung dari expired_date
  - NOW > expired_date → EXPIRED
  - NOW > expired_date - 10 → RENEW
  - ELSE → AVAILABLE

### 4.4 Borrowing Rules

1. **Scan QR** → cek status AVAILABLE + tidak expired + tidak sedang dipinjam
2. **Cart** → session-based (bisa pinjam beberapa sekaligus)
3. **Submit** → auto-approved, buat TRX/{week}/{seq}
4. **Race condition guard** → UPDATE WHERE status='available' + check affected_rows
5. **Expected return** → borrow_date + 90 hari (COPY_MAX_BORROW_DAYS)
6. **Return per item** → status BORROWED → UNAVAILABLE, QR dikosongkan
7. **All returned** → arsipkan ke ZCP_BORROW_ARC (JSON snapshot), hapus data live
8. **WC Rotation** → pindahkan pinjaman ke WC lain (temporary/permanent)

### 4.5 Expiry Rules

| Entity | Idle Expiry | Borrowed Expiry | Renew Window |
|--------|------------|-----------------|--------------|
| MCP | 6 bulan dari MFG_DATE | N/A (tidak dipinjam) | 30 hari |
| CP | 90 hari dari MFG_DATE | 90 hari dari BORROW_DATE | 10 hari |

### 4.6 Rack Capacity

- Max 3 panel per rack (per domain: MCP dan CP terpisah)
- Lemari: A-Y
- Rack: 01-32

### 4.7 Color Code

- Format: `KW` + 5 digit (KW00001, KW00002, ...)
- Auto-generate, unik per DCP item
- Tidak boleh reuse setelah delete (fisik sudah tercetak)
- Prefix lama `WC` masih dihitung untuk mencegah duplikat

---

## 5. BSP Pages & Navigation

### 5.1 Page Structure

| Page | Role | Description |
|------|------|-------------|
| `login.htm` | ALL | Login page custom |
| `main.htm` | ALL | Router berdasarkan role |
| `dashboard_it.htm` | IT | Dashboard admin (stats, quick actions) |
| `dcp_list.htm` | IT | Daftar semua DCP |
| `dcp_form.htm` | IT | Buat/edit DCP |
| `dcp_detail.htm` | IT | Detail DCP + items + derive MCP |
| `mcp_list.htm` | IT | Daftar MCP |
| `mcp_detail.htm` | IT | Detail MCP + checkout QC |
| `cp_list.htm` | IT | Daftar Copy Panel |
| `cp_form.htm` | IT | Derive CP dari MCP |
| `borrower_dash.htm` | BORROWER | Dashboard borrower |
| `borrower_scan.htm` | BORROWER | Scan QR + cart + submit |
| `borrower_history.htm` | BORROWER | History peminjaman |
| `borrower_profile.htm` | BORROWER | Profile & password |
| `qc_dashboard.htm` | QC | Dashboard QC |
| `qc_checkout.htm` | QC | Checkout/return MCP |
| `monitoring.htm` | PUBLIC | Dashboard monitoring (tanpa login) |
| `label_print.htm` | IT | Generate & print label |
| `admin_users.htm` | ADMIN | Kelola user |
| `admin_wc.htm` | ADMIN | Kelola Work Center |
| `admin_buyer.htm` | ADMIN | Kelola buyer |

### 5.2 Navigation Flow

```
login.htm → main.htm (router)
  ├── IT → dashboard_it.htm
  │   ├── DCP → dcp_list.htm → dcp_form.htm / dcp_detail.htm
  │   ├── MCP → mcp_list.htm → mcp_detail.htm
  │   ├── CP → cp_list.htm → cp_form.htm
  │   ├── Label → label_print.htm
  │   └── Admin → admin_users.htm / admin_wc.htm / admin_buyer.htm
  │
  ├── BORROWER → borrower_dash.htm
  │   ├── Scan → borrower_scan.htm
  │   ├── History → borrower_history.htm
  │   └── Profile → borrower_profile.htm
  │
  ├── QC → qc_dashboard.htm
  │   └── Checkout → qc_checkout.htm
  │
  └── monitoring.htm (public, no login)
```

### 5.3 Page Components (Per Page)

Each BSP page consists of 3 source files:
1. **Type Definitions** — TYPES, constants
2. **Event Handler (OnInputProcessing)** — ABAP logic, SELECT queries, actions
3. **Layout (.htm)** — HTML + inline ABAP + JavaScript

---

## 6. Role-Based Access Control

| Role | DCP | MCP | CP | Borrow | Label | Admin | Monitor |
|------|-----|-----|-----|--------|-------|-------|---------|
| IT | CRUD | CRUD+derive | CRUD+derive | - | CRUD | - | View |
| BORROWER | - | - | View available | Scan+Return | - | - | View |
| QC | - | Checkout/Return | - | - | - | - | View |
| ADMIN | - | - | - | - | - | CRUD users/wc/buyer | View |
| APPROVAL | View | - | - | - | - | - | View |
| PUBLIC | - | - | - | - | - | - | View |

---

## 7. Technical Implementation

### 7.1 Authentication

**Pattern:** Sama kayak ZBSP_ECM_APP.

1. SICF default user = `auto_email`
2. User buka BSP → redirect ke `login.htm`
3. Login form: USER_ID + PASSWORD
4. Auth: SELECT from ZCP_USER WHERE user_id = ? AND password = SHA256(?) AND status = 'Y'
5. Session: store USER_ID, ROLE, FULL_NAME via `cl_bsp_server_side_cookie`
6. Guard: setiap page cek session, redirect ke login kalau expired

### 7.2 QR Code Generation

**Approach:** Client-side JavaScript (browser).

Library: `html5-qrcode` (sama kayak Laravel borrower scan).

**Generate QR (IT page):**
```javascript
// Generate QR code as base64 PNG
QRCode.toDataURL(qrContent, { width: 200, margin: 1 })
  .then(url => {
    // url = data:image/png;base64,...
    // Send to server via AJAX to save in ZCP_DCP_ITEM.QR_DATA
  });
```

**Scan QR (Borrower page):**
```javascript
const scanner = new Html5QrcodeScanner("qr-reader", { fps: 10 });
scanner.render(onScanSuccess);
function onScanSuccess(decodedText) {
  // decodedText = token or color_code
  // AJAX to server to add to cart
}
```

**QR Content:**
- DCP item: URL `{base_url}/sap/bc/bsp/sap/zbsp_color_panel/dcp_detail.htm?t={qr_token}`
- MCP: URL `{base_url}/sap/bc/bsp/sap/zbsp_color_panel/mcp_detail.htm?t={qr_token}`
- CP: `code_color` value (e.g., "001-Walnut Dark")

### 7.3 Label Printing

**Approach:** Client-side jsPDF (tidak butuh SmartForm).

```javascript
// jsPDF + autoPrint
const doc = new jsPDF({ format: 'a4' });
// 4 labels per A4 (2x2 grid)
for (let i = 0; i < items.length; i++) {
  if (i > 0 && i % 4 === 0) doc.addPage();
  const x = (i % 2) * 105;
  const y = Math.floor((i % 4) / 2) * 148;
  drawLabel(doc, items[i], x, y);
}
doc.autoPrint();
window.open(doc.output('bloburl'));
```

### 7.4 Transaction Number Format

```
TRX/{ISO_week}/{sequence}
Contoh: TRX/29/0001, TRX/29/0002
```

Logic:
1. Get ISO week: `date('W')`
2. Query MAX sequence for current week
3. Increment: `seq + 1`
4. Format: `TRX/{week}/{seq padded 4 digit}`

### 7.5 Color Code Generation

```
Prefix: KW
Format: KW{5 digit}
Contoh: KW00001, KW00002, KW00003
```

Logic:
1. Query MAX of SUBSTRING(color_code, 3) casted to number
2. Where color_code REGEXP '^(KW|WC)[0-9]+$' (include old WC prefix)
3. Next = MAX + 1
4. Format: 'KW' + padded 5 digit

### 7.6 BSP Encoding

**CRITICAL:** BSP corrupts ALL non-ASCII characters (> U+007F).

Rule: ZERO non-ASCII in BSP source files. Replace with HTML entities:
- `—` → `&mdash;`
- `•` → `&#8226;`
- `✓` → `&#10003;`
- Emoji → `&#NNNNN;`
- dll.

### 7.7 OpenSQL Rules (S/4HANA 1809)

**Use old-style syntax (no `@` prefix):**
- `SELECT field1, field2 INTO TABLE lt_data FROM zcp_table WHERE field = lv_var.`
- NOT: `SELECT field1, field2 INTO TABLE @lt_data FROM zcp_table WHERE field = @lv_var.`
- Declare all variables explicitly in DATA section
- No inline DATA(...), no VALUE string_table(...)

---

## 8. Phased Development Plan

### Phase 1: Foundation (Minggu 1-2)
- [ ] Z-table creation (SE11) — semua 11 tabel
- [ ] TMG untuk tabel master (ZCP_USER, ZCP_BUYER, ZCP_WC)
- [ ] SNRO number range (ZCP_DCP, ZCP_MCP, ZCP_CP, ZCP_BORROW, ZCP_AUDIT)
- [ ] Data Element creation (ZCP_* custom DE)
- [ ] BSP application creation (SE80)
- [ ] Login page + auth (reuse ECM pattern)
- [ ] Main router page

### Phase 2: DCP Module (Minggu 3-4)
- [ ] DCP list page (ALV-style table)
- [ ] DCP form (create/edit)
- [ ] DCP detail + items
- [ ] Color code auto-generation
- [ ] QR generation (client-side JS)
- [ ] DCP card/PDF printing

### Phase 3: MCP Module (Minggu 5-6)
- [ ] MCP list page
- [ ] Derive MCP from DCP item
- [ ] MCP detail (status, checkout QC)
- [ ] Rack management (capacity check)
- [ ] Revision logic (R+1)
- [ ] MCP card/PDF printing

### Phase 4: CP & Borrowing (Minggu 7-9)
- [ ] CP list page
- [ ] Derive CP from MCP
- [ ] Borrower scan page (QR → cart → submit)
- [ ] Borrower return page
- [ ] Race condition guard
- [ ] Archive logic
- [ ] WC rotation

### Phase 5: Dashboard & Label (Minggu 10-11)
- [ ] IT dashboard (stats, charts, recent items)
- [ ] Monitoring dashboard (public, no login)
- [ ] Label printing (batch mode, 4 per A4)
- [ ] Label download (ZIP/merged PDF)

### Phase 6: Polish & PRO (Minggu 12)
- [ ] Audit trail logging
- [ ] Expiry check (batch job or on-load)
- [ ] Renew flow (MCP + CP)
- [ ] QC dashboard + checkout flow
- [ ] Admin pages (users, WC, buyer)
- [ ] Testing & bug fixes
- [ ] Transport to QAS → PRD

---

## 9. SAP Configuration Required

| Config | T-Code | Description |
|--------|--------|-------------|
| Number Range | SNRO | ZCP_DCP, ZCP_MCP, ZCP_CP, ZCP_BORROW, ZCP_AUDIT |
| Data Elements | SE11 | ZCP_* (custom labels for SM30) |
| Function Group | SE80 | ZFGP_COLOR_PANEL (for TMG) |
| SICF Service | SICF | /sap/bc/bsp/sap/zbsp_color_panel |
| Content Server | OAC0 | Reuse existing (kmiserver.kayumebel.com:1090) atau inline |

---

## 10. Pitfalls & Lessons Learned

Dari pengalaman ECM BSP, apply ke project ini:

1. **BSP encoding** — ZERO non-ASCII, pakai HTML entities
2. **OpenSQL consistency** — old-style tanpa `@`
3. **SICF auto_email** — shared SAP user, auth via Z-table
4. **Stateful pages** — semua page wajib Stateful
5. **Page Attributes .txt** — referensi saja, SE80 mungkin beda
6. **JavaScript line break** — class attribute dalam JS string harus 1 baris
7. **File delivery** — .txt extension, upload ke srv168 via SCP
8. **Version control** — V{major}_{minor} ({Label}), folder per version
9. **TMG auth group** — pakai &NC& untuk SM30 access
10. **read_file line numbers** — strip sebelum write

---

## Appendix A: Laravel → SAP Table Mapping

| Laravel Table | SAP Table | Notes |
|---------------|-----------|-------|
| it_users | ZCP_USER (ROLE=IT) | Merged ke 1 tabel |
| borrower_users | ZCP_USER (ROLE=BORROWER) | Merged |
| qc_users | ZCP_USER (ROLE=QC) | Merged |
| admin_users | ZCP_USER (ROLE=ADMIN) | Merged |
| approval_users | ZCP_USER (ROLE=APPROVAL) | Merged |
| buyers | ZCP_BUYER | Direct mapping |
| wc_master | ZCP_WC | Direct mapping |
| dcp_headers | ZCP_DCP_HDR | Direct mapping |
| dcp_items | ZCP_DCP_ITEM | + COLOR_CODE, QR_TOKEN |
| master_color_panel | ZCP_MCP | Filtered: is_master_only=1 |
| color_stock_items | ZCP_CP | Filtered: mcp_id IS NOT NULL |
| stock_transactions | ZCP_BORROW | Direct mapping |
| transaction_items | ZCP_BORROW_ITM | Direct mapping |
| peminjaman_selesai | ZCP_BORROW_ARC | Direct mapping |
| audit_logs | ZCP_AUDIT_LOG | Direct mapping |
| collections | ZCP_BUYER (field) | Atau tabel terpisah jika needed |
| color_components | - | Belum dipetakan (opsional) |
| color_panel_components | - | Belum dipetakan (opsional) |
| deleted_borrower_users | - | Belum dipetakan (archive di ZCP_USER) |
| borrower_wc_rotation | - | Belum dipetakan (Phase 2) |
| expired_code_history | - | Belum dipetakan (audit log cukup) |
| renew_code_history | - | Belum dipetakan (audit log cukup) |

## Appendix B: Constants (ZCP_POLICY)

Sama kayak Laravel `config/dcp_policy.php`:

| Constant | Value | Description |
|----------|-------|-------------|
| COPY_MAX_BORROW_DAYS | 90 | Max hari pinjam |
| COPY_VALID_DAYS | 90 | Masa berlaku QR CP |
| COPY_RENEW_DAYS | 10 | Window renew CP |
| MCP_VALID_MONTHS | 6 | Masa berlaku MCP |
| MCP_RENEW_DAYS | 30 | Window renew MCP |
| RACK_CAPACITY | 3 | Max panel per rack |
| COLOR_CODE_PREFIX | KW | Prefix color code |
| COLOR_CODE_MAX | 99999 | Max nomor color code |
