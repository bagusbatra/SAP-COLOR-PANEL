# Design Spec — Halaman "Alur Sistem" (Flowchart) di Prototype

**Proyek:** Color Panel Management System — PT. Kayu Mebel Indonesia (KMI)
**Target:** Prototype HTML/CSS/JS (`prototype/`), bukan BSP
**Tanggal:** 6 Agustus 2026
**Status:** Approved — siap masuk implementation plan

---

## 1. Ruang Lingkup

Menambahkan satu halaman baru ke prototype yang menggambarkan alur sistem Color Panel secara visual: alur bisnis end-to-end antar role, dan state machine status panel DCP/MCP.

### 1.1 Termasuk

- File baru `prototype/pages/flowchart.html`
- Satu entri menu baru di `NAV_MENU` (`prototype/assets/js/config.js`)
- Empat diagram inline SVG dalam satu halaman
- Style diagram di `prototype/assets/css/style.css` (kelas baru, tidak mengubah kelas lama)

### 1.2 TIDAK Termasuk (YAGNI)

Interaktivitas (klik node → navigasi ke halaman terkait), animasi, export PNG/PDF, dan SP (Station Panel — requirement bisnisnya belum ada). Tidak ada perubahan pada logika `biz.js`, `db.js`, atau `auth.js`.

### 1.3 Kondisi Awal

Prototype Phase 1 sudah lengkap (Batch 1–6). Navigasi antar role baru saja diperbaiki: `Utils.path()`, redirect guard, highlight sidebar aktif, dan penyembunyian tombol lintas-role. Halaman ini dibangun di atas kondisi tersebut.

---

## 2. Keputusan Desain

| # | Keputusan | Alasan |
|---|---|---|
| 1 | Halaman di dalam prototype, bukan dokumen terpisah | Ikut terlihat saat demo aplikasi ke user, dan ikut ter-port ke BSP sebagai `flowchart.htm` |
| 2 | Inline SVG, bukan Mermaid.js | Nol dependency CDN baru — aman di jaringan internal SAP saat port ke BSP. Warna bisa persis mengikuti design token prototype |
| 3 | Warna node lewat `class` + CSS variable, bukan hex di atribut SVG | Kalau palette `style.css` berubah, diagram ikut berubah otomatis |
| 4 | Angka aturan dibaca dari `CONFIG`, tidak diketik manual | Mencegah diagram berbohong kalau threshold diubah. Lihat §5 |
| 5 | Menu terlihat untuk semua role | Halaman orientasi/referensi. SALES saat ini hanya punya 1 menu, sidebar-nya terasa kosong |
| 6 | Menu diletakkan paling atas, sebelum Dashboard | Ini titik masuk untuk memahami sistem, bukan menu transaksi |

---

## 3. Penempatan & Akses

### 3.1 Entri Menu

Ditambahkan sebagai elemen **pertama** array `NAV_MENU` di `config.js`:

```js
{
  label: 'Alur Sistem',
  icon: 'fa-diagram-project',
  href: 'pages/flowchart.html',
  roles: [ROLES.SALES, ROLES.ADMIN, ROLES.QC, ROLES.IT],
},
```

Tidak perlu properti `match` — halaman ini tidak punya halaman detail turunan.

### 3.2 Guard

`Auth.guard([])` — hanya memeriksa login, tanpa batasan role. Ini satu-satunya halaman di prototype yang boleh diakses semua role.

### 3.3 Struktur File

Mengikuti pola halaman `pages/` yang sudah ada: sidebar container, `page-header`, urutan `<script>` yang sama (`config` → `utils` → `db` → `auth` → `sidebar`). `biz.js` tidak perlu di-load karena halaman ini tidak memanggil logika bisnis.

---

## 4. Isi Halaman — Empat Section

Semua alur di bawah ini sudah diverifikasi terhadap implementasi `prototype/assets/js/biz.js`.

### 4.1 Section 1 — Alur End-to-End (swimlane)

Tiga lajur horizontal berlabel SALES / ADMIN / QC.

| Tahap | Pelaku | Aksi | Hasil |
|---|---|---|---|
| 1 | SALES | Input nomor SO + remarks | Request status `P` (Pending) |
| 2 | ADMIN | Reject + alasan | Request status `R` — alur berhenti |
| 3 | ADMIN | Approve | Per item SO: Color Code `KW#####` + DCP header `O` + panel sebanyak qty item SO, semua status `NA` (lihat §5.5) |
| 4 | ADMIN | Aktivasi panel (isi tanggal manufaktur) | Panel `NA` → `AK` |
| 5 | ADMIN | Submit panel + foto | Panel `AK` → `SB` |
| 6 | QC | Approve panel | Panel `SB` → `AP`; panel approved pertama memicu auto-create MCP header |
| 7 | ADMIN | Close DCP | DCP header → `C` |
| 8 | QC/ADMIN | Siklus panel MCP (lihat §4.3) | — |
| 9 | ADMIN | Close MCP | MCP header → `A` (Closed/Released) |

**Validasi pada tahap 3** yang harus muncul di diagram sebagai cabang keputusan: sebelum approve, sistem menolak bila material sudah punya Color Code, atau kombinasi SO+material sudah pernah di-import. Pesan errornya mengarahkan user ke halaman Renewal. Cabang ini digambar sebagai panah putus-putus menuju Section 4.

### 4.2 Section 2 — State Machine Panel DCP

```
NA ──aktivasi (isi mfg date)──> AK ──submit (min N foto)──> SB ──approve QC──> AP
                                                             │                  │
                                                             └──reject QC──> RJ │
                                                                            │   │
                                                             <──UNDO─────────┘   │
                                                                                 v
                                                              jadi slot MCP status DA
```

Catatan yang perlu tampil:
- `UNDO` mengembalikan `RJ` → `SB` dan menyetel `undo_flag = 'X'`
- Panel `AP` naik menjadi slot MCP berstatus `DA`
- Saat DCP di-close, panel yang masih `NA`/`AK`/`SB` tetap pada statusnya tapi tidak bisa maju lagi
- Header DCP juga bisa di-reject seluruhnya (`O` → `R`) bila buyer batal — digambar sebagai cabang terpisah di level header

### 4.3 Section 3 — State Machine Panel MCP

Dua titik masuk:

```
DA (warisan dari panel DCP approved) ─┐
                                      ├─> DA ──submit (min N foto)──> SB ──approve──> AP
BL (slot polos) ──start (isi mfg date)┘                                │
                                                                       │
                                        <──reject (foto dihapus)───────┘
```

**Perbedaan penting dari DCP yang wajib terlihat di diagram:** reject panel MCP **tidak** dead-end. Panel kembali ke `DA`, foto yang sudah di-upload dihapus, dan panel siap di-submit ulang. Bandingkan dengan DCP yang punya status `RJ` terpisah dan butuh UNDO eksplisit.

Saat `closeMcpHeader`: semua panel yang bukan `AP` diubah menjadi `OB` (Obsolete), header menjadi `A`.

### 4.4 Section 4 — Alur Renewal MCP

```
Input SO baru
   └─> cari MCP existing per material (findRenewalCandidate)
         └─> MCP lama: status A, is_renewed = 'X', renewal_date = hari ini
              semua panel MCP lama ──> OB
         └─> MCP baru dibuat:
              dcp_id = '' (tidak lewat DCP sama sekali)
              parent_mcp_id = MCP lama
              expire_date = hari ini + masa berlaku MCP
```

Diagram harus menegaskan bahwa renewal **melewati seluruh siklus DCP** — inilah alasan cabang validasi di §4.1 mengarahkan ke sini.

---

## 5. Teknik Render

### 5.1 SVG

Satu `<svg viewBox="...">` per section, dengan `preserveAspectRatio="xMidYMid meet"` dan `max-width: 100%; height: auto`. Setiap SVG dibungkus container ber-`overflow-x: auto` supaya diagram lebar bisa di-scroll sendiri tanpa membuat body halaman scroll horizontal.

### 5.2 Warna

Node diberi `class`, bukan atribut `fill` hardcode:

```css
.fc-node-sales  { fill: var(--color-info); }
.fc-node-admin  { fill: var(--color-navy); }
.fc-node-qc     { fill: var(--color-success); }
.fc-node-end    { fill: var(--color-gray-500); }
.fc-arrow       { stroke: var(--color-gray-600); }
.fc-arrow-alt   { stroke-dasharray: 4 3; }
```

Kelima variabel di atas sudah diverifikasi ada di `style.css` (`--color-navy` baris 8, `--color-gray-500` baris 19, `--color-gray-600` baris 20, `--color-success` baris 26, `--color-info` baris 32).

### 5.3 Angka Aturan Dibaca dari CONFIG

Teks catatan di bawah diagram di-render lewat JavaScript, mengambil nilai dari `CONFIG`:

| Teks di halaman | Sumber |
|---|---|
| "minimal N foto per submit" | `CONFIG.MIN_PHOTO_PER_PANEL` |
| "minimal N panel approved untuk close DCP" | `CONFIG.MIN_APPROVE_DCP_CLOSE` |
| "minimal N panel approved untuk close MCP" | `CONFIG.MIN_APPROVE_MCP_CLOSE` |
| Label status pada legend | `DCP_PANEL_STATUS_LABEL`, `MCP_PANEL_STATUS_LABEL`, dst |

Label status pada legend diambil dari map label yang sudah ada di `config.js`, bukan diketik ulang.

**Jumlah panel TIDAK boleh dibaca dari `CONFIG.PANEL_PER_SO`.** Lihat §5.5.

### 5.5 Jumlah Panel per DCP — Jangan Tulis "15"

Diagram harus menulis **"panel sebanyak qty di SO"**, bukan angka 15.

Alasan: `biz.js` membuat panel dengan `for (let n = 1; n <= item.menge; n++)` — jumlahnya mengikuti qty item SO, bukan konstanta. `CONFIG.PANEL_PER_SO: 15` **dideklarasikan tapi tidak pernah dipakai di seluruh prototype** (diverifikasi dengan grep: satu-satunya kemunculan adalah deklarasinya sendiri di `config.js:14`).

Jadi README yang menyebut "15 pcs panel per DCP header" tidak tercermin di kode. Menulis "15" di diagram akan membuatnya berbohong untuk SO dengan qty berapa pun selain 15. Hal yang sama berlaku untuk slot MCP, yang dibangkitkan sebanyak `hdr.qty_total`.

Perbedaan README vs kode ini di luar lingkup pekerjaan flowchart dan **tidak diperbaiki di sini** — hanya dicatat agar diagram tetap jujur.

### 5.4 Legend

Satu baris legend per section: warna → role (Section 1), atau kode status → label (Section 2–4). Legend status di-generate dari map di `config.js` sesuai §5.3.

---

## 6. Penanganan Error

Halaman ini tidak melakukan operasi data, sehingga tidak ada error path bisnis. Dua kondisi yang tetap ditangani:

1. **Belum login** — ditangani `Auth.guard([])`, redirect ke `login.html`
2. **Constant tidak ditemukan** — bila suatu key `CONFIG` hilang, teks catatan menampilkan tanda tanya alih-alih `undefined`, dan diagram tetap tampil

---

## 7. Kriteria Selesai

1. Menu "Alur Sistem" muncul di sidebar untuk keempat role (SALES, ADMIN, QC, IT) dan ter-highlight aktif saat halaman dibuka
2. Halaman terbuka tanpa "Akses Ditolak" untuk keempat akun demo
3. Keempat diagram tampil dan terbaca pada lebar viewport 1280px dan 768px; body halaman tidak scroll horizontal
4. Tidak ada request ke host eksternal baru selain yang sudah dipakai prototype (Google Fonts, Font Awesome)
5. Angka pada catatan cocok dengan nilai di `CONFIG` — diverifikasi dengan mengubah satu constant sementara lalu memastikan teks ikut berubah
6. Transisi status pada diagram cocok dengan implementasi `biz.js` — diverifikasi manual per fungsi

---

## 8. Catatan Porting ke BSP

`flowchart.html` → `flowchart.htm` sebagai BSP page statis. Karena tidak ada dependency CDN dan tidak ada akses data, halaman ini adalah yang paling sederhana untuk di-port: SVG dan CSS bisa disalin apa adanya. Bagian yang membaca `CONFIG` diganti dengan konstanta ABAP atau di-hardcode saat porting, karena `config.js` tidak ikut ke BSP dalam bentuk yang sama.
