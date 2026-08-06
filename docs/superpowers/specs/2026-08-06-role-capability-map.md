# Peta Kewenangan per Role &mdash; Color Panel

**Tanggal:** 6 Agustus 2026
**Status:** Draf untuk direview Yogi &amp; Arya
**Sumber:** guard tiap halaman `prototype/`, fungsi `biz.js` yang dipanggilnya, `NAV_MENU` di `config.js`, dan tabel role di spec 28 Juli bagian 4.2

Dokumen ini **memotret keadaan sekarang**, bukan mengusulkan keadaan yang ideal. Yang ditemukan tidak konsisten dicatat apa adanya di bagian 5, supaya keputusannya diambil sadar.

---

## 1. Ringkasan Empat Role

| Role | Inti pekerjaannya | Landing page |
|---|---|---|
| **SALES** | Mengajukan permintaan pembuatan Color Panel untuk buyer yang dipegangnya | Request List |
| **ADMIN** | Menyetujui permintaan, lalu menjalankan seluruh siklus fisik panel DCP dan MCP | Dashboard |
| **QC** | Memeriksa dan memutuskan hasil panel yang di-submit | MCP List |
| **IT** | Menjaga sistem: pemetaan user, master data, dan jejak audit | Dashboard |

Satu kalimat yang membedakan ADMIN dan QC: **ADMIN mengerjakan panel, QC menilai panel.** Batas itu yang seharusnya tercermin di kewenangan, dan bagian 5 mencatat di mana batas itu belum terjaga.

---

## 2. Akses Halaman

Diambil dari `Auth.guard([...])` tiap halaman dan `roles` di `NAV_MENU`.

Legenda: **B** = boleh buka &amp; menu tampil &middot; **b** = boleh buka tapi menu tidak tampil &middot; &mdash; = ditolak

| Halaman | SALES | ADMIN | QC | IT |
|---|:---:|:---:|:---:|:---:|
| Alur Sistem (flowchart) | B | B | B | B |
| Dashboard | &mdash; | B | B | B |
| Request List | B | B | &mdash; | B |
| Request Form | B | B | &mdash; | B |
| Request Detail | B | B | &mdash; | B |
| DCP List | &mdash; | B | B | B |
| DCP Detail | &mdash; | b | b | b |
| MCP List | &mdash; | B | B | B |
| MCP Detail | &mdash; | b | b | b |
| Renewal MCP | &mdash; | B | &mdash; | B |
| Master User | &mdash; | B | &mdash; | B |
| Master Buyer | &mdash; | B | &mdash; | B |
| Master Color Code | &mdash; | B | B | B |
| Audit Log | &mdash; | &mdash; | &mdash; | B |

---

## 3. Kewenangan Aksi

Ini bagian yang penting. Bisa membuka halaman tidak sama dengan bisa berbuat sesuatu di dalamnya.

Legenda: **Y** = bisa &middot; &mdash; = tidak bisa &middot; **?** = perlu keputusan, lihat bagian 5

### 3.1 Request-DCP

| Aksi | Fungsi | SALES | ADMIN | QC | IT |
|---|---|:---:|:---:|:---:|:---:|
| Buat request dari nomor SO | `createRequest` | Y | Y | &mdash; | Y |
| Approve request | `approveRequest` | &mdash; | Y | &mdash; | &mdash; |
| Reject request | `rejectRequest` | &mdash; | Y | &mdash; | &mdash; |

SALES hanya bisa membuat request untuk SO milik buyer-nya sendiri. Ini **satu-satunya** aturan role yang ditegakkan di dalam `biz.js` (baris 976); sisanya hanya dijaga tampilan.

### 3.2 Siklus Panel DCP

| Aksi | Fungsi | SALES | ADMIN | QC | IT |
|---|---|:---:|:---:|:---:|:---:|
| Aktivasi panel (isi tgl manufaktur) | `activateDcpPanel` | &mdash; | Y | &mdash; | &mdash; |
| Submit panel + foto | `submitDcpPanel` | &mdash; | Y | &mdash; | &mdash; |
| **Approve panel** | `approveDcpPanel` | &mdash; | Y | **?** | &mdash; |
| **Reject panel** | `rejectDcpPanel` | &mdash; | Y | **?** | &mdash; |
| Undo panel rejected | `undoDcpPanel` | &mdash; | Y | **?** | &mdash; |
| Close DCP header | `closeDcpHeader` | &mdash; | Y | &mdash; | &mdash; |
| Reject DCP header | `rejectDcpHeader` | &mdash; | Y | &mdash; | &mdash; |

### 3.3 Siklus Panel MCP

| Aksi | Fungsi | SALES | ADMIN | QC | IT |
|---|---|:---:|:---:|:---:|:---:|
| Start slot BL (isi tgl manufaktur) | `startBlankMcpSlot` | &mdash; | Y | &mdash; | &mdash; |
| Submit panel + foto | `submitMcpPanel` | &mdash; | Y | &mdash; | &mdash; |
| **Approve panel** | `approveMcpPanel` | &mdash; | Y | **?** | &mdash; |
| **Reject panel** | `rejectMcpPanel` | &mdash; | Y | **?** | &mdash; |
| Close MCP header | `closeMcpHeader` | &mdash; | Y | &mdash; | &mdash; |

### 3.4 Renewal dan Master Data

| Aksi | SALES | ADMIN | QC | IT |
|---|:---:|:---:|:---:|:---:|
| Cari kandidat renewal &amp; jalankan | &mdash; | Y | &mdash; | Y |
| Tambah/ubah user &amp; pemetaan buyer | &mdash; | **?** | &mdash; | Y |
| Tambah/ubah master buyer | &mdash; | Y | &mdash; | Y |
| Tambah/ubah master Color Code | &mdash; | Y | **?** | Y |
| Lihat Audit Log | &mdash; | &mdash; | &mdash; | Y |

---

## 4. Data yang Terlihat

Selain "boleh berbuat apa", ada "boleh melihat data siapa".

| Role | Batas data |
|---|---|
| **SALES** | Hanya request milik buyer yang dipetakan ke dirinya. Ditegakkan lewat `BUYER_ID` di `ZCP_USER` |
| **ADMIN** | Seluruh buyer, seluruh request, seluruh DCP dan MCP |
| **QC** | Seluruh DCP dan MCP. Tidak melihat Request sama sekali |
| **IT** | Seluruh data, ditambah Audit Log |

Sales tanpa `BUYER_ID` ditolak masuk sejak versi BSP &mdash; tanpa itu penyaringannya tidak punya pegangan dan Sales akan melihat request milik semua buyer.

---

## 5. Titik yang Perlu Keputusan Anda

Enam hal yang ditemukan tidak konsisten. Nomor 1 yang paling berdampak.

### 5.1 QC tidak bisa meng-approve panel &mdash; padahal itu pekerjaannya

Di `dcp_detail.html:122` dan `mcp_detail.html:97`:

```js
const canEdit = Auth.hasRole(ROLES.ADMIN);
```

Seluruh tombol aksi panel &mdash; termasuk **Approve** dan **Reject** &mdash; bergantung pada `canEdit`. Akibatnya QC bisa membuka kedua halaman tapi **tidak bisa menekan apa pun**. QC praktis jadi role baca-saja.

Ini bertentangan dengan aturan bisnis yang sudah dikunci, dengan diagram Alur Sistem yang menulis "approve QC" di transisi `SB` &rarr; `AP`, dan dengan `biz.js` yang tidak membatasi siapa pun.

Kemungkinan besar ini kelalaian saat membangun prototype, bukan keputusan. Tapi bisa juga memang disengaja &mdash; misalnya kalau di lapangan yang menekan tombol tetap Admin sambil didampingi QC. **Perlu Anda pastikan.**

Tiga pilihan:

| Pilihan | Konsekuensi |
|---|---|
| **A.** QC bisa approve/reject/undo panel; ADMIN tidak | Batas "ADMIN mengerjakan, QC menilai" jadi tegas. Tapi kalau QC berhalangan, tidak ada yang bisa meloloskan panel |
| **B.** QC dan ADMIN sama-sama bisa | Luwes, tidak ada yang macet. Tapi batas perannya kabur dan audit log jadi satu-satunya cara tahu siapa yang menilai |
| **C.** Tetap seperti sekarang, ADMIN saja | QC turun jadi peran pemantau. Kalau ini yang dipilih, sebaiknya QC tidak diberi menu DCP/MCP sama sekali supaya tidak menyesatkan |

### 5.2 QC bisa mengubah master Color Code

`master_color.html` mengizinkan QC lewat guard, dan **tidak ada pemeriksaan role lagi di dalamnya**. Jadi QC bisa menambah dan mengubah Color Code, termasuk warna hex dan namanya.

Dugaan saya maksudnya QC boleh *melihat* Color Code sebagai referensi saat memeriksa panel, bukan mengubahnya. Perlu dipisahkan antara boleh-buka dan boleh-ubah.

### 5.3 Master User: ADMIN ikut atau tidak

Tiga sumber, tiga jawaban berbeda:

| Sumber | Siapa yang boleh |
|---|---|
| `prototype/pages/master_user.html` | ADMIN dan IT |
| Spec 28 Juli bagian 4.2 | IT saja |
| `admin_user.htm` yang sudah jadi di BSP | IT saja |

Yang sudah terpasang di SAP mengikuti spec. Kalau ADMIN memang perlu memetakan Sales ke buyer tanpa menunggu IT, ini harus diubah.

### 5.4 Sales tidak bisa memantau hasil requestnya

Sales membuat request lalu kehilangan jejak. Halaman DCP dan MCP tertutup untuk Sales, dan di `request_detail.html:242` tombol menuju DCP sengaja disembunyikan supaya Sales tidak menabrak "Akses Ditolak".

Padahal pertanyaan paling wajar dari Sales adalah "panel untuk buyer saya sudah sampai mana". Perlu diputuskan apakah Sales dapat halaman pemantauan baca-saja, atau memang cukup bertanya ke Admin.

### 5.5 Reject DCP header hanya ADMIN

`rejectDcpHeader` dipakai saat buyer batal beli &mdash; seluruh panel yang belum approved langsung jadi `OB`. Ini tindakan yang tidak bisa dibatalkan dan berdampak ke seluruh header.

Sekarang ADMIN bisa melakukannya sendirian tanpa persetujuan siapa pun. Perlu dipastikan apakah itu memang wewenang ADMIN, atau butuh keterlibatan pihak lain.

### 5.6 Satu user dengan dua role

`ZCP_USER` mencatat "satu user satu role", tapi PFCG tidak mencegah seseorang ditugaskan ke beberapa role sekaligus. Sistem menyelesaikannya dengan prioritas **ADMIN &gt; IT &gt; QC &gt; SALES**.

Akibat yang perlu disadari: user dengan `ZCP_ADMIN` **dan** `ZCP_QC` akan **selalu** diperlakukan sebagai ADMIN. Dia tidak akan pernah bisa bertindak sebagai QC, sekalipun role QC-nya melekat. Kalau di lapangan ada orang yang memang merangkap, prioritas ini justru menghalanginya.

---

## 6. Catatan Penting untuk Porting ke BSP

**`biz.js` hampir tidak menegakkan role sama sekali.** Dari tujuh belas fungsi, hanya `createRequest` yang memeriksa role. Selebihnya bergantung sepenuhnya pada tombol yang disembunyikan di tampilan.

Di prototype itu bisa diterima &mdash; ia alat demo. Di BSP tidak. Menyembunyikan tombol hanya menyembunyikan tombol; siapa pun yang tahu nama halaman dan nama field form bisa mengirim permintaan langsung.

Karena itu, apa pun keputusan di bagian 5, penegakannya harus berada di **ABAP class**, bukan di layout. Layout tetap menyembunyikan tombol supaya tampilannya bersih, tapi itu kenyamanan, bukan pengamanan.

Pola yang sudah dipakai `admin_user.htm` bisa jadi contoh: penjagaan role ada di `OnInitialization` **dan** diulang di `OnInputProcessing`, karena `OnInputProcessing` berjalan lebih dulu &mdash; tanpa pengulangan itu, data sudah tersimpan sebelum pelakunya sempat ditolak.

---

## 7. Yang Saya Butuhkan dari Review Anda

Empat pertanyaan, urut dari yang paling menghambat:

1. **QC boleh approve panel atau tidak?** (bagian 5.1) &mdash; ini menentukan bentuk `dcp_detail.htm` dan `mcp_detail.htm`, dua halaman terbesar yang belum dibangun
2. **Master User: ADMIN ikut atau IT saja?** (5.3) &mdash; halaman ini sudah jadi, mengubahnya sekarang murah
3. **Sales perlu halaman pemantauan?** (5.4) &mdash; kalau ya, jadi halaman baru di luar delapan yang direncanakan
4. **Color Code: QC lihat saja atau boleh ubah?** (5.2)

Nomor 5.5 dan 5.6 bisa diputuskan belakangan; keduanya tidak menghambat pembangunan halaman berikutnya.

---

## 8. KEPUTUSAN SEMENTARA &mdash; IT Memegang Akses Penuh

**Ditetapkan 6 Agustus 2026. Berlaku selama masa pembangunan. WAJIB DICABUT sebelum go-live.**

### Isi keputusan

Pemegang role `ZCP_IT` boleh menjalankan **seluruh alur bisnis dari awal sampai akhir**: membuat request sebagai Sales, menyetujuinya sebagai Admin, mengerjakan panel sebagai Admin, dan menilainya sebagai QC.

### Alasan

Pengujian end-to-end tersendat karena akun untuk role lain belum tersedia. Menunggu Basis menyiapkan empat akun dengan empat role hanya untuk mencoba satu alur akan menghentikan pekerjaan berhari-hari. Bagian 5 dokumen ini &mdash; termasuk pertanyaan besar apakah QC boleh approve panel &mdash; baru bisa dijawab setelah alurnya benar-benar pernah dijalankan sampai tuntas.

Ini keputusan sadar untuk menukar ketegasan role dengan kecepatan umpan balik, bukan kelalaian.

### Cara kerjanya

Kewenangan dipisahkan dari identitas. `gv_role` menjawab "dia siapa" untuk keperluan tampilan; empat flag menjawab "dia boleh apa":

| Flag | Artinya |
|---|---|
| `gv_as_sales` | Boleh membuat request |
| `gv_as_admin` | Boleh menjalankan siklus panel DCP dan MCP |
| `gv_as_qc` | Boleh approve/reject panel |
| `gv_as_it` | Boleh master user dan audit log |

Seluruh layout dan penjagaan memeriksa **flag**, bukan `gv_role`. Flag diturunkan dari role PFCG yang benar-benar dipegang, bukan dari `gv_role` hasil prioritas &mdash; kalau memakai `gv_role`, user ber-`ZCP_ADMIN` sekaligus `ZCP_IT` justru kehilangan kewenangan IT karena prioritas menjadikannya ADMIN.

### Cara mencabutnya nanti

Satu blok, satu file: hapus blok bertanda `SEMENTARA: IT memegang akses penuh` di `_shared/role_detect.abap`, lalu sebarkan ke `OnRequest`/`OnInitialization` tiap halaman.

```abap
IF lv_has_it = 'X'.
  gv_as_sales = 'X'.
  gv_as_admin = 'X'.
  gv_as_qc    = 'X'.
ENDIF.
```

Tidak ada tempat lain yang perlu disentuh. Itulah gunanya memisahkan flag dari `gv_role` sejak awal &mdash; pencabutan nanti tidak akan menyentuh satu pun layout.

### Yang harus diingat selama keputusan ini berlaku

1. **Menguji sebagai IT tidak membuktikan role lain bekerja.** IT lolos di semua tempat. Pengujian batas role baru sahih setelah blok ini dicabut.
2. **Jangan dijadikan alasan menunda bagian 5.** Empat pertanyaan di bagian 7 tetap harus dijawab; keputusan ini hanya memberi waktu, bukan menghapus pertanyaannya.
3. **Semua halaman baru wajib memakai flag**, jangan `gv_role`. Satu halaman yang memeriksa `gv_role = 'ADMIN'` akan luput saat pencabutan dan menjadi lubang yang tidak terlihat.
