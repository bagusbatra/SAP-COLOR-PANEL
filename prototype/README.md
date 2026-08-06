# Color Panel — Prototype (HTML/CSS/JS)

Prototype visual untuk sistem **Color Panel Management System** — PT. Kayu Mebel Indonesia (KMI).
Nantinya akan di-port ke **SAP BSP (S/4HANA 1809)** dengan nama app `ZBSP_COLOR_PANEL`.

Prototype ini dibangun untuk:
1. Mendemonstrasikan flow end-to-end ke user (Sales, Admin, QC, IT) sebelum eksekusi ABAP
2. Memvalidasi UX, business rule, dan state machine per panel
3. Jadi referensi struktur file 1:1 untuk BSP page nanti

---

## Cara Menjalankan

Buka `index.html` di browser. Data dummy akan di-seed otomatis pertama kali.

Kalau JavaScript block karena `file://`, jalankan lewat local server:

```bash
# Python 3
python3 -m http.server 8080

# Atau Node
npx serve
```

Lalu buka: `http://localhost:8080/`

---

## Akun Demo

| User ID | Password | Role   | Landing |
|---------|----------|--------|---------|
| sales01 | sales01  | SALES  | Request List (buyer: Ashley Furniture) |
| sales02 | sales02  | SALES  | Request List (buyer: IKEA Trading) |
| admin01 | admin01  | ADMIN  | Dashboard |
| qc01    | qc01     | QC     | MCP List |
| it01    | it01     | IT     | Dashboard |

Password default = User ID (plain text di prototype; nanti SHA256 di BSP).

---

## Struktur Folder

```
color-panel-prototype/
├── index.html            # Entry: redirect ke login / landing
├── login.html            # Login page (auto-fill demo credentials)
├── dashboard.html        # Dashboard (ADMIN/IT/QC)
├── pages/
│   ├── master_user.html
│   ├── master_buyer.html
│   ├── master_color.html
│   ├── request_list.html
│   ├── request_form.html
│   ├── request_detail.html
│   ├── dcp_list.html
│   ├── dcp_detail.html
│   ├── mcp_list.html
│   ├── mcp_detail.html
│   ├── mcp_renewal.html
│   └── audit_log.html
├── assets/
│   ├── css/style.css     # Corporate navy palette
│   └── js/
│       ├── config.js     # Constants, enums, roles
│       ├── utils.js      # Helper (format, DOM, alerts)
│       ├── db.js         # LocalStorage layer + seed data
│       ├── auth.js       # Login, session, guard
│       └── sidebar.js    # Sidebar renderer per role
└── README.md
```

Setiap file HTML di `pages/` akan 1:1 memetakan ke BSP page nanti.

---

## Data Storage

Prototype pakai **LocalStorage** dengan prefix `cp_db_`.

Tabel yang tersimpan (mirror Z-table di SAP):

| Prototype (LocalStorage) | SAP Z-Table       | Fungsi |
|--------------------------|-------------------|--------|
| users                    | ZCP_USER          | User & role |
| buyers                   | ZCP_BUYER         | Master buyer |
| materials                | (SAP MARA)        | Simulasi FERT |
| sales_orders             | (SAP VBAK/VBAP)   | Simulasi SO |
| color_codes              | ZCP_COLOR_CODE    | Color Code (1:1 FERT) |
| requests                 | ZCP_REQUEST       | Request-DCP |
| so_imports               | ZCP_SO_IMPORT     | Tracking SO (anti duplikat) |
| dcp_headers              | ZCP_DCP_HDR       | Header DCP |
| dcp_items                | ZCP_DCP_ITEM      | Panel DCP (15 pcs) |
| mcp_headers              | ZCP_MCP_HDR       | Header MCP |
| mcp_items                | ZCP_MCP_ITEM      | Panel MCP |
| photos                   | ZCP_PHOTO         | Foto (simulasi DMS) |
| audit_logs               | ZCP_AUDIT_LOG     | Audit trail |
| sequences                | (SAP SNRO)        | Auto-increment ID |

**Session** disimpan di `sessionStorage` — hilang saat browser tutup (sesuai keputusan).

**Reset data:** buka console browser, jalankan `DB.seed(true)` lalu reload.

**Dump semua data:** `console.log(DB.dump())`

---

## Business Rules Locked

Diambil dari `color_panel_insight.md` (revisi 21 Jul 2026):

1. **5 entitas:** Color Code, Request-DCP, DCP, MCP, SP *(SP skip di prototype)*
2. **1 Color Code = 1 FERT Material** (mapping 1:1)
3. **1 Request-DCP = 1 SO → banyak DCP** (1 material = 1 DCP header)
4. **15 pcs panel per DCP header** (dari qty di SO)
5. **Panel DCP default NON-AKTIF** (polos belum dicat)
6. **Admin bebas isi tanggal aktivasi** (bukan default hari ini)
7. **Submit panel butuh min 2 foto** (upload ke DMS ZDCP)
8. **DCP approve → langsung jadi MCP** (stiker ditimpa)
9. **Close DCP: min 1 panel approved**
10. **Close MCP: min 3 panel approved**, sisanya OBSOLETE
11. **DCP expired 1 tahun**, reminder 2 bulan
12. **MCP expired 1 tahun**, renewal via halaman khusus
13. **Renewal MCP:** input SO baru → MCP lama OBSOLETE → MCP baru active
14. **Stiker DCP/MCP:** 3 kolom ttd (Buyer, RND, AkzoNobel)
15. **Panel reject tidak bisa reuse**, tapi ada tombol UNDO

---

## Delivery Roadmap

| Batch | Scope | Status |
|-------|-------|--------|
| **1**  | Foundation: struktur, config, db, auth, sidebar, login, dashboard | ✅ Selesai |
| **2**  | Master data: user, buyer, color code | ✅ Selesai |
| **3**  | Request-DCP flow (Sales input SO → Admin approve) | ✅ Selesai |
| **4**  | DCP flow (aktivasi, submit, approve, close) | ✅ Selesai |
| **5**  | MCP flow (submit, approve, close, renewal) | ✅ Selesai |
| **6**  | Utility: audit log, sticker print (jsPDF), QR generator | ✅ Selesai |
| **later** | SP (Station Panel) — nunggu detail requirement | 🔒 Pending |

**Prototype Phase 1 COMPLETE.** Siap direview, dites, dan diiterasi lewat Claude Code sebelum port ke SAP BSP.

## Fitur Sticker & QR

- Tiap panel DCP/MCP yang statusnya bukan NA/BL punya **QR unik** (128-bit token)
- QR preview otomatis muncul di modal panel
- **Cetak Stiker (single)** — A6 landscape, berisi:
  - Header navy dengan tipe (DCP/MCP)
  - Info: Panel ID, Color Code, Material, Buyer, MFG Date, Expired
  - Color swatch (hex)
  - QR code untuk scan verifikasi
  - **3 kolom tanda tangan: Buyer | RND | AkzoNobel**
- **Bulk Stiker** — cetak semua panel dalam 1 DCP/MCP jadi 1 PDF multi-page

---

## Design Tokens

Palette: **Corporate Neutral (Navy)**

| Warna | Hex | Kegunaan |
|-------|-----|----------|
| Navy Primary | `#1E3A8A` | Sidebar active, tombol utama |
| Navy Dark | `#1E293B` | Sidebar background |
| Gray Light | `#F1F5F9` | Body background |
| Gray Medium | `#64748B` | Text sekunder |
| Success | `#10B981` | Approved |
| Warning | `#F59E0B` | Pending |
| Danger | `#EF4444` | Reject/Obsolete |
| Info | `#3B82F6` | Info & DCP-approved link |

Font: **Plus Jakarta Sans** (Google Fonts) + **JetBrains Mono** (ID/kode).

---

## Catatan Porting ke SAP BSP

Prototype ini disusun supaya mudah di-porting nanti:

- **1 HTML file = 1 BSP page** (`login.html` → `login.htm`, dst)
- **`sidebar.js`** akan jadi **page fragment** `sidebar.htm` di BSP
- **`db.js`** logic akan jadi **function module** di function group `ZFGP_COLOR_PANEL`
- **`auth.js`** akan pakai `cl_bsp_server_side_cookie` + auth via `ZCP_USER`
- **ID generator** (`Utils.generateId`) akan pakai SNRO real
- **LocalStorage** diganti dengan **SELECT/INSERT OpenSQL**
- **Foto (base64 di LocalStorage)** diganti dengan **BAPI_DOCUMENT_CREATE2 → DMS ZDCP/ZMCP**

---

## Author

- **Yogi Pratama** — Business analyst & concept owner (KMI)
- **Arya Nugraha** — ABAP Developer
- Prototype iteration: bersama Claude (Anthropic)
