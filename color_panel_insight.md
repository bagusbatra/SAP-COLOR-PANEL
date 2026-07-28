# Color Panel SAP — Analysis & Insight

**Tanggal Awal:** 15 Juli 2026
**Update Terakhir:** 21 Juli 2026
**Sumber:** 
- Analisis repo `bagusbatra/color_trial_surabaya` (branch `feat/copy-qr-lifecycle`)
- Dokumen konsep dari Yogi (21 Jul 2026) — **MAJOR REVISION**
- Pengalaman project DMS/ECM KMI

---

## ⚠️ Catatan Revisi (21 Jul 2026)

Dokumen awal (15 Jul) banyak berdasarkan asumsi dari code Laravel. Konsep bisnis yang sebenarnya dijabarkan oleh Yogi dan **banyak berbeda** dari asumsi awal. Seluruh section di bawah ini adalah **konsep terbaru yang sudah dikonfirmasi**.

---

## 1. Entitas Utama (5 Entitas)

| # | Entitas | Fisik? | Fungsi |
|---|---------|--------|--------|
| 1 | **Color Code** | ❌ Info saja | Kode warna, rujukan utama semua panel. Tidak punya panel fisik. 1:1 dengan FERT Material Master |
| 2 | **Request-DCP** | ❌ Info saja | Pra-DCP. Sales Representative mengajukan request pembuatan DCP ke Admin Color |
| 3 | **DCP** (Development Color Panel) | ✅ Panel fisik | Siklus development warna. Fokus pada proses development sampai approve buyer |
| 4 | **MCP** (Master Color Panel) | ✅ Panel fisik | Siklus master panel warna. Fokus pada store/penyimpanan warna. Ada peminjaman tapi TANPA hitung mundur masa pakai (hanya expired utama) |
| 5 | **SP** (Station Panel) | ✅ Panel fisik | Siklus copy panel (nama baru dari "Copy Panel"). Fokus pada acuan produksi. Ada masa aktif, masa pakai, DAN peminjaman |

### Perbedaan Lama vs Baru

| Aspek | Asumsi Lama (15 Jul) | Konsep Baru (21 Jul) |
|-------|---------------------|---------------------|
| Entitas | 3 (DCP → MCP → CP) | 5 (Color Code, Request-DCP, DCP, MCP, SP) |
| CP/SP | Salinan dari MCP | SP = entitas mandiri, punya siklus hidup sendiri |
| Color Code | Tidak ada entitas tersendiri | Entitas mandiri, 1:1 dengan FERT |
| Request-DCP | Tidak ada | Pra-DCP, input dari Sales |
| SO | Tidak ada referensi SO | SO adalah sumber utama pembuatan DCP |
| Qty panel | Tidak spesifik | Standar 15 pcs per SO |
| Approve | Per item atau per DCP | Per panel (satu per satu), minimal 1 untuk close DCP, minimal 3 untuk close MCP |
| Material timing | Belum jelas | Material/SO sudah ada SEBELUM DCP dibuat |

---

## 2. Hubungan Color Code ↔ FERT Material

- **1 Color Code = 1 FERT Material** (1:1 mapping)
- Jika FERT belum punya Color Code entitas → statusnya **"Membuat Color Baru"**
- Jika FERT sudah punya Color Code → statusnya **"Renewal"** (ada halaman khusus input SO untuk renewal)
- Setiap penambahan QTY dari SO harus dicatat → perlu tabel **Import SO** untuk mencegah duplikat (1 SO hanya berlaku 1x transaksi per material)
- **DCP/MCP adalah tahapan berbeda dengan SO** — SO adalah input, DCP/MCP adalah proses

---

## 3. Material FERT & SO (Sales Order)

### Apa itu SO?
- SO = **surat permintaan ke Produksi** untuk bikin panel
- Panel butuh: **kayu + veneer + solid + pekerja**
- Tidak bisa minta produksi asal minta — harus ada SO
- **Sales yang request SO-nya**
- SO bukan bukti buyer mau lanjut, tapi dasar produksi bikin panel

### Alur Material
```
Sales request SO ke Produksi (15 pcs)
  → SO berisi material color yang belum terdaftar di Color Code
    → Admin Color approve → material jadi DCP + Color Code baru
```

### Rules SO
- 1 SO = 1 kali transaksi per material (anti duplikat)
- Perlu tabel tracking: `ZCP_SO_IMPORT` — mencatat SO mana yang sudah di-import
- SO adalah **referensi utama** pembuatan DCP
- Dari SO bisa didapat: material codes, quantities, dan informasi panel lainnya

---

## 4. Tahap A: DCP (Development Color Panel)

### Alur Lengkap
1. **Sales mengisi form DCP** → referensi kode SO color panel. SO berisi beberapa material color + quantity
2. **Admin Color approve** → material di SO jadi DCP + Color Code baru. Sistem cek: material di SO harus belum terdaftar di Color Code
3. **Panel default NON-AKTIF** → panel polos belum dicat. Tim station color yang ngecat. Admin bebas mengaktifkan sampai barang ready
4. **Aktivasi per panel** → admin bebas isi tanggal dibuat (bukan default hari ini)
5. **Standar 15 pcs per SO** → penggunaan terserah color room
6. **1 jenis material color** = 15 panel per pcs, dikontrol satu per satu. Dari 15 panel:
   - Bisa diaktifkan jadi DCP
   - Bisa jadi MCP langsung
   - Bisa tidak digunakan sama sekali
7. **Approve per panel** → submit satu per satu + upload foto fisik DCP yang sudah ditandatangani → **disimpan ke DMS type ZDCP**
8. **Close DCP** → Admin bisa close jika minimal 1 panel sudah approve, atau reject dengan alasan

### Stiker & Tanda Tangan
- Sistem mencetak stiker dengan kolom tanda tangan
- **3 penandatangan:** Buyer, RND, AkzoNobel
- Stiker ditempelkan di panel fisik
- Minimal **2 foto** per upload (foto panel yang sudah ditandatangani)
- Saat approve → stiker DCP **ditimpa** dengan stiker MCP (langsung jadi MCP)

### Status Panel DCP
```
NON-AKTIF (default, polos belum dicat)
  → AKTIF (admin aktifkan, bebas tentukan tanggal)
    → SUBMITTED (upload foto min 2 + submit)
      → APPROVED (langsung jadi MCP, stiker ditimpa)
      → REJECTED (buyer tidak jadi, tidak bisa reuse)
        → UNDO (fitur kembalikan jika admin salah pencet)
```

### Rules DCP
- 1 SO → banyak DCP (1 material = 1 DCP)
- Qty per material dari SO, bukan hardcode
- Admin approve = trigger buat DCP + Color Code + generate panel non-aktif
- DCP max **1 tahun** expired
- **Reminder admin** jika DCP sudah 2 bulan belum ditentukan statusnya
- **DCP → MCP = 2 tahap dalam 1 SO** (bukan siklus terpisah)
- Panel DCP yang sudah disetujui buyer → langsung jadi MCP (stiker ditimpa)

### Status Siklus DCP
```
OPEN → APPROVED (panel di-approve) / REJECTED (dengan alasan)
```

---

## 5. Tahap B: MCP (Master Color Panel)

### Alur Lengkap
1. **Panel DCP yang di-approve → langsung jadi MCP** (stiker ditimpa)
2. **Approve = admin upload foto panel yang sudah ditandatangani + submit**
3. **Minimal 3 panel approve** untuk close siklus MCP → **disimpan ke DMS type ZMCP**
4. **Tidak bisa kurang dari 3** — kalau cuma 2, MCP tidak bisa di-close, harus reject
5. **Siklus hidup MCP:** diperbarui setiap tahun, berhenti jika sudah tidak ada order

### Status Panel MCP
```
DCP-APPROVED (lanjutan dari DCP, stiker ditimpa)
  → SUBMITTED (upload foto + submit)
    → MCP-APPROVED (release, panel master hidup)
    → OBSOLETE (sisa saat MCP close, atau saat renewal)
```

### MCP Close
- Min 3 panel approve untuk close
- Sisa panel yang tidak approve = OBSOLETE
- Hanya MCP-APPROVED yang hidup (minimal 3)
- **3 MCP tersimpan sebagai master color panel**
- Diperbarui setiap tahun atau berhenti jika tidak ada order

### Status Siklus MCP
```
OPEN → APPROVED (min 3 panel) → sisa = OBSOLETE
```

### Renewal MCP (21 Jul — Konfirmasi Yogi)
- **Syarat:** Sales harus siapkan SO baru dulu
- **Alur:** Input kode SO → Sistem cek MCP yang dimaksud SO → Ketemu → Update data MCP → Data lama = OBSOLETE
- **Renewal = menggantikan entitas panel lama** → lama = OBSOLETE, baru = active
- **Beda dengan create dari DCP:** DCP = warna baru, Renewal = warna sama, refresh masa aktif
- Ada halaman khusus untuk proses renewal ini

---

## 6. Tahap C: SP (Station Panel)

_(Masih perlu dikembangkan lebih lanjut — konsep dari dokumen Yogi belum detail SP)_

### Yang Sudah Diketahui
- SP = entitas mandiri (bukan copy MCP)
- Punya: masa aktif, masa pakai, dan peminjaman
- Fokus: acuan produksi di workstation
- Istilah baru dari "Copy Panel"

### Yang Masih Perlu Diklarifikasi
- Apakah SP di-create dari MCP? Atau langsung dari SO?
- Berapa jumlah SP per material?
- Bagaimana alur peminjaman SP?
- Expired logic SP (masa aktif vs masa pakai)?

---

## 7. DMS Document Types

| Type | Untuk | Keterangan |
|------|-------|------------|
| `ZDCP` | DCP | Foto panel DCP yang sudah ditandatangani buyer |
| `ZMCP` | MCP | Foto panel MCP yang sudah di-approve |

---

## 8. Tabel SAP yang Dibutuhkan (Revisi)

| # | Tabel | Fungsi | Baru? |
|---|-------|--------|-------|
| 1 | `ZCP_COLOR_CODE` | Master Color Code (1:1 FERT) | ✅ BARU |
| 2 | `ZCP_REQUEST` | Request-DCP dari Sales | ✅ BARU |
| 3 | `ZCP_SO_IMPORT` | Tracking import dari SO (anti duplikat) | ✅ BARU |
| 4 | `ZCP_DCP_HDR` | Header DCP (referensi SO) | Revisi |
| 5 | `ZCP_DCP_ITEM` | Item DCP (per panel, 15 pcs) | Revisi |
| 6 | `ZCP_MCP_HDR` | Header MCP | ✅ BARU |
| 7 | `ZCP_MCP_ITEM` | Item MCP (per panel) | ✅ BARU |
| 8 | `ZCP_SP` | Station Panel | Revisi dari ZCP_CP |
| 9 | `ZCP_BORROW` | Transaksi peminjaman (MCP & SP) | Tetap |
| 10 | `ZCP_BORROW_ITM` | Detail peminjaman | Tetap |
| 11 | `ZCP_AUDIT_LOG` | Audit trail | Tetap |
| 12 | `ZCP_USER` | User & role management | Tetap |
| 13 | `ZCP_BUYER` | Master buyer | Tetap |
| 14 | `ZCP_WC` | Master work center | Tetap |

---

## 9. Open Questions (Updated 21 Jul)

| # | Pertanyaan | Status |
|---|-----------|--------|
| 1 | SP detail lifecycle — created from MCP or SO? | ⏳ Pending |
| 2 | WC pakai standard SAP (CRHD) atau custom ZCP_WC? | ⏳ Pending |
| 3 | DMS type ZDCP/ZMCP — perlu setup DOKAR baru? | ⏳ Pending |
| 4 | BSP app: gabung ECM atau terpisah? | ⏳ Pending |
| 5 | SO integration — BAPI atau manual input? | ⏳ Pending |
| 6 | Renewal MCP: Sales siapkan SO → input SO → sistem detect MCP lama → obsolete-kan → refresh | ✅ Locked (21 Jul) |
| 7 | MCP Close: sisa panel dari DCP = OBSOLETE, hanya approved yang hidup | ✅ Locked (21 Jul) |
| 8 | SP: siklus terpisah, detail nanti, 1 BSP | ⏳ Pending detail |

---

## 10. Keputusan yang Sudah Locked

| # | Keputusan | Tanggal |
|---|----------|---------|
| 1 | 5 entitas utama: Color Code, Request-DCP, DCP, MCP, SP | 21 Jul |
| 2 | Color Code 1:1 dengan FERT Material | 21 Jul |
| 3 | SO sebagai sumber utama pembuatan DCP | 21 Jul |
| 4 | Material/SO sudah ada SEBELUM DCP | 21 Jul |
| 5 | Standar 15 pcs per SO | 21 Jul |
| 6 | Approve DCP: per panel, min 1 untuk close | 21 Jul |
| 7 | Approve MCP: per panel, min 3 untuk close | 21 Jul |
| 8 | DCP default non-aktif (panel polos) | 21 Jul |
| 9 | Admin bebas tentukan tanggal aktivasi | 21 Jul |
| 10 | DCP → DMS type ZDCP, MCP → DMS type ZMCP | 21 Jul |
| 11 | MCP expired → Renewal di halaman khusus | 21 Jul |
| 12 | MCP close → sisa panel = OBSOLETE | 21 Jul |
| 13 | Approach: Pure Custom Z-Table + BSP | 15 Jul |
| 14 | 1 SO → banyak DCP (1 material = 1 DCP) | 21 Jul |
| 15 | Qty per material dari SO, bukan hardcode | 21 Jul |
| 16 | Admin approve = trigger DCP + Color Code + panel non-aktif | 21 Jul |
| 17 | DCP → MCP = 2 tahap dalam 1 SO (stiker ditimpa) | 21 Jul |
| 18 | Stiker: kolom ttd Buyer, RND, AkzoNobel | 21 Jul |
| 19 | Min 2 foto per upload | 21 Jul |
| 20 | Panel reject tidak bisa reuse, tapi ada fitur undo | 21 Jul |
| 21 | DCP max 1 tahun, reminder 2 bulan belum ditentukan | 21 Jul |
| 22 | MCP min 3 panel approve untuk close | 21 Jul |
| 23 | MCP diperbarui setiap tahun, berhenti jika tidak ada order | 21 Jul |
| 24 | Renewal = ganti panel lama (OBSOLETE) dengan panel baru | 21 Jul |

---

## 11. Legacy Info (Sebelum Revisi 21 Jul)

_(Disimpan untuk referensi, tapi sudah tidak berlaku)_

### Konsep Lama: 3 Tahap
| Konsep | Lama |
|--------|------|
| DCP | Lab dip → Review → Approve |
| MCP | 3 subtipe: Golden Standard, Production Master, Buyer-Approved |
| CP | Salinan Production Master, distribusi ke workstation |

### MCP Subtipe Lama (Sudah Tidak Berlaku)
- ~~Golden Standard~~
- ~~Production Master~~
- ~~Buyer-Approved Master~~

---

## 12. Repo Laravel (Reference)

- **Path di srv168:** `/mnt/data/files/sap-docs/Color_Panel/color_trial_surabaya`
- **Branch:** `feat/copy-qr-lifecycle`
- **GitHub:** `git@github.com:bagusbatra/color_trial_surabaya.git`
- **Catatan:** Code Laravel masih pakai konsep lama. Konsep baru (21 Jul) belum diimplementasikan di Laravel.

---

## 13. Decision Matrix (Masih Berlaku)

| Kriteria | Pure Custom Z+BSP |
|----------|-------------------|
| Setup effort | Low (langsung develop) |
| Master data | Z-table custom |
| Familiar | ✅ Sama kayak ECM BSP |
| Develop speed | Cepat |
| QM integration | Manual |
| Learning curve | Rendah |
