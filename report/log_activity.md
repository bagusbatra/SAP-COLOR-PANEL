# Log Activity — Color Panel Sub-Proyek 1

Catatan harian apa saja yang dikerjakan, termasuk masalah yang muncul dan cara mengatasinya. Entri terbaru di atas.

- **Checkpoint per task/step:** `report/report.md`
- **Plan sumber:** `docs/superpowers/plans/2026-07-28-color-panel-foundation-dcp.md`

---

## 29 Juli 2026 — Rabu

**Fokus hari ini:** Task 3 Step 5 — membuat sepuluh tabel transparan beserta secondary index-nya di SE11.

### Yang dikerjakan

**1. Verifikasi silang data element sebelum mulai**

Sebelum menyentuh SE11, dicek dulu apakah 18 data element hasil kerja kemarin sudah cukup untuk seluruh tabel. Hasilnya: 18 data element di `data_elements.txt` semuanya terpakai di 10 file definisi tabel, dan tidak ada tabel yang mereferensi `ZCP_DE_*` di luar daftar. Aman untuk lanjut.

**2. Membuat sepuluh tabel transparan di SE11**

Dikerjakan satu per satu, tidak diborong sekaligus, supaya kalau ada error langsung ketahuan tabel mana penyebabnya.

| Urutan | Tabel | Data Class | Size | Catatan |
|:---:|---|:---:|:---:|---|
| 1 | `ZCP_USER` | APPL1 | 1 | Tabel pertama, sekalian belajar alur SE11 |
| 2 | `ZCP_BUYER` | APPL1 | 1 | Tanpa kejutan |
| 3 | `ZCP_COLOR_CODE` | APPL1 | 1 | Index `MAT` sempat terlewat, dibuat menyusul |
| 4 | `ZCP_REQUEST` | APPL0 | 1 | Mulai masuk wilayah data transaksi |
| 5 | `ZCP_REQUEST_ITM` | APPL0 | 1 | Butuh reference field untuk `MENGE` |
| 6 | `ZCP_SO_IMPORT` | APPL0 | 1 | Butuh reference field untuk `MENGE` |
| 7 | `ZCP_DCP_HDR` | APPL0 | 1 | 23 kolom, terpanjang |
| 8 | `ZCP_DCP_ITEM` | APPL0 | 1 | Primary key 3 kolom, `PANEL_ID` bukan key |
| 9 | `ZCP_PHOTO` | APPL0 | **3** | Dua kali gagal aktivasi, lihat masalah di bawah |
| 10 | `ZCP_AUDIT_LOG` | APPL0 | **3** | Lancar |

Semua tabel: Delivery Class `A`, Table View Maintenance *Display/Maintenance Allowed*, Buffering *not allowed*, package `$TMP`.

**3. Membuat enam secondary index**

| Tabel | Index | Sifat | Field |
|---|:---:|:---:|---|
| `ZCP_COLOR_CODE` | `MAT` | Unique | MANDT, MATNR |
| `ZCP_REQUEST` | `SO` | Non-unique | MANDT, SO_NUMBER |
| `ZCP_DCP_HDR` | `REQ` | Non-unique | MANDT, REQUEST_ID |
| `ZCP_DCP_ITEM` | `PID` | Unique | MANDT, PANEL_ID |
| `ZCP_PHOTO` | `REF` | Non-unique | MANDT, REF_TYPE, REF_ID, PANEL_NUMBER |
| `ZCP_AUDIT_LOG` | `REF` | Non-unique | MANDT, REF_TYPE, REF_ID |

**4. Memperbarui dokumentasi repo**

Plan file diberi blok *Checkpoint Terakhir*, checkbox Task 1 dan Task 2 ditandai selesai, Task 3 Step 5 ditandai sebagian dengan sub-checklist. Empat catatan jebakan aktivasi ditambahkan ke file definisi tabel yang bersangkutan.

### Masalah yang muncul dan cara mengatasinya

**a. Warning `Enhancement category for table missing` di setiap tabel**

Muncul tiap kali aktivasi. Bukan error — tabel tetap Active. Diselesaikan lewat menu `Extras -> Enhancement Category` lalu pilih `Can Be Enhanced (Character-Type or Numeric)`.

Sempat dibiarkan dulu di `ZCP_USER` sambil memastikan apakah berpengaruh ke sistem. Kesimpulannya tidak berpengaruh ke runtime, tapi tetap dibereskan supaya log aktivasi bersih dan warning asli tidak tenggelam di antara warning palsu.

**b. `ZCP_PHOTO` gagal aktivasi — dua sebab sekaligus**

Pesan lengkapnya:

```
TABL ZCP_PHOTO was not activated
Enhancement category for table missing
Enhancement category for include or subtype missing
ZCP_PHOTO-PHOTO_DATA: Too long for activation of 'not null' flag (>255)
Table ZCP_PHOTO must be created in the database
Check on table ZCP_PHOTO resulted in errors
```

Sebab pertama: `PHOTO_DATA` dicentang *Initial Values*. Flag itu berarti `NOT NULL` di database, dan field `RAWSTRING` tidak bisa diberi jaminan itu. Solusinya hilangkan centang *Initial Values* khusus di baris `PHOTO_DATA`; field lain tetap dicentang.

Sebab kedua: Enhancement Category belum diisi, dan untuk tabel ini harus `Can Be Enhanced (Deep)` — bukan `Character-Type or Numeric` seperti sembilan tabel lain. Penyebabnya `RAWSTRING` termasuk tipe deep, datanya tidak duduk langsung di baris tabel.

Setelah dua perbaikan itu, aktivasi berhasil.

**c. Index `MAT` di `ZCP_COLOR_CODE` terlewat**

Ketahuan waktu mau membuat index `PID` di `ZCP_DCP_ITEM` — disebut "ini yang kedua kalinya pakai UNIQUE", padahal yang pertama belum pernah dibuat. Penyebabnya waktu tabel ketiga langkah index diberikan ringkas, penjelasan detailnya baru muncul di tabel keempat.

Dicek lewat `SE11 -> ZCP_COLOR_CODE -> Indexes...`, ternyata memang kosong. Langsung dibuat dengan sifat Unique dan field `MANDT`, `MATNR`.

Pelajarannya: setiap selesai satu tabel yang punya index, cek langsung lewat tombol *Indexes...*, jangan diasumsikan sudah jadi.

### Catatan teknis yang perlu diingat

1. **`MANDT` harus diketik manual di index.** SE11 tidak menambahkannya otomatis seperti pada primary key, dan harus jadi field pertama.
2. **Index UNIQUE menganggap dua nilai kosong sebagai duplikat.** Berlaku di `MAT` (`MATNR`) dan `PID` (`PANEL_ID`). Kalau nanti muncul dump `DUPLICATE KEY`, tersangka pertama adalah kolom yang lupa diisi, bukan data kembar beneran.
3. **Field `QUAN` wajib punya reference field.** `MENGE` (`MENGE_D`) di `ZCP_REQUEST_ITM` dan `ZCP_SO_IMPORT` harus menunjuk ke `MEINS` di tabel yang sama, lewat tab *Currency/Quantity Fields*.
4. **`QTY_TOTAL` di `ZCP_DCP_HDR` bertipe `INT4`, bukan `MENGE_D`,** karena isinya cacah panel fisik — bilangan bulat tanpa satuan. Jadi tabel itu tidak butuh tab Currency/Quantity Fields.

### Commit hari ini

| Commit | Waktu | Isi |
|---|---|---|
| `73132d7` | 15:26 | `docs(ddic): checkpoint Task 3 - 10 tabel dan 6 index aktif di SE11` |

### Status akhir hari

Task 3 Step 5 selesai sebagian: **tabel dan index tuntas**, sisa empat objek belum dikerjakan — lock object `EZCP_SO`, lima number range di SNRO, message class `ZCP` di SE91, dan Table Maintenance Generator untuk `ZCP_BUYER`.

---

## 28 Juli 2026 — Selasa

**Fokus hari ini:** Menyiapkan repo, menulis seluruh file definisi DDIC, dan membuat domain beserta data element di SE11.

### Yang dikerjakan

**1. Task 1 — Inisialisasi repo (selesai)**

Repo git dibuat di `D:\DEV\SAP COLOR PANEL` beserta struktur folder `src/01_ddic/tables`, `src/02_classes`, `src/03_reports`, `src/04_bsp/zbsp_color_panel`. Dibuat juga `.gitignore` dan `README.md`.

`README.md` memuat empat aturan teknis yang tidak boleh dilanggar sepanjang proyek: nol karakter non-ASCII di sumber BSP, OpenSQL gaya lama tanpa `@`, semua halaman BSP stateful, dan identitas pelaku selalu `USER_ID` dari session — tidak pernah `SY-UNAME`.

**2. Task 2 — Domain dan data element (selesai)**

File `src/01_ddic/domains.txt` dan `src/01_ddic/data_elements.txt` ditulis, lalu objeknya dibuat di SE11 dan diaktifkan.

Enam domain fixed-value:

| Domain | Tipe | Nilai |
|---|:---:|---|
| `ZCP_DOM_ROLE` | CHAR 10 | SALES, ADMIN, IT |
| `ZCP_DOM_REQ_ST` | CHAR 1 | P, C |
| `ZCP_DOM_ITM_ST` | CHAR 1 | P, A, R |
| `ZCP_DOM_DCP_ST` | CHAR 1 | O, C, R |
| `ZCP_DOM_PANEL_ST` | CHAR 2 | NA, AK, SB, AP, RJ, OB |
| `ZCP_DOM_CC_ST` | CHAR 1 | A, I, O |

Delapan belas data element `ZCP_DE_*`. Field yang sudah punya data element standar SAP sengaja memakai yang standar dan tidak dibuatkan versi `ZCP_DE_` sendiri: `MATNR`, `MAKTX`, `VBELN`, `POSNR`, `MENGE_D`, `MEINS`, `LAND1`, `DATUM`, `TIMESTAMP`.

**3. Task 3 Step 1–4 — Menulis file definisi (selesai)**

Sepuluh file definisi tabel di `src/01_ddic/tables/`, plus `lock_objects.txt`, `snro.txt`, dan `messages_zcp.txt` berisi 20 pesan error.

### Commit hari ini

| Commit | Waktu | Isi |
|---|---|---|
| `9ce9d97` | 11:39 | `first commit` |
| `d7af600` | 14:16 | File awal proyek: `.gitignore`, README, data element, domain, lock object, message, SNRO, dan seluruh definisi tabel |

### Status akhir hari

Task 1 dan Task 2 tuntas. Seluruh file DDIC sudah tertulis di repo, tinggal dieksekusi ke sistem SAP.

### Keputusan desain yang diambil hari ini

**Status memakai domain berdaftar nilai tetap**, bukan CHAR biasa. Konsekuensinya SM30 menampilkan teks status, dan nilai yang salah tertangkap saat aktivasi tabel — bukan saat produksi.

**`ZCP_REQUEST` index `SO` sengaja non-unique.** Material yang ditolak harus bisa diajukan ulang dalam request baru dengan nomor SO yang sama. Yang mencegah duplikasi sesungguhnya adalah `ZCP_SO_IMPORT`, yang hanya menampung item approved.

**Kolom penghitung di `ZCP_DCP_HDR` dihapus dari rancangan.** `QTY_ACTIVE`, `QTY_APPROVED`, `QTY_REJECTED` dari deklarasi 21 Juli tidak dipakai. Angka-angka itu dihitung dari `ZCP_DCP_ITEM` saat dibutuhkan, supaya tidak pernah ada keadaan di mana penghitung dan kenyataan berbeda.
