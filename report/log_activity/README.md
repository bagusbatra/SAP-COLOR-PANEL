# Log Activity — Indeks Harian

Satu file per tanggal, format nama `YYYY-MM-DD.md` supaya urut sendiri di file explorer maupun di git.

| Tanggal | Hari | Fokus | Task tersentuh |
|---|---|---|---|
| [2026-08-08](2026-08-08.md) | Sabtu | `ZCP_BUYER` dipensiunkan, buyer dibaca dari KNA1, interval SNRO `ZCP_REQ` | Jalur B B10, B11, B17 |
| [2026-08-06](2026-08-06.md) | Kamis | Prototype dirapikan, aplikasi BSP lahir, autentikasi pindah ke SAP standar, 5 halaman | Jalur B B1&ndash;B11 |
| [2026-07-29](2026-07-29.md) | Rabu | 10 tabel, 6 index, lock object, 5 objek number range | Task 3 Step 5 (sebagian) |
| [2026-07-28](2026-07-28.md) | Selasa | Inisialisasi repo, file DDIC, domain dan data element | Task 1, Task 2, Task 3 Step 1&ndash;4 |

Checkpoint per task dan per step ada di `../report.md`.

## Format entri harian

Tiap file mengikuti kerangka yang sama supaya gampang dibandingkan antar hari:

```
# Log Activity — <tanggal> (<hari>)

**Fokus hari ini:**
**Task tersentuh:**

## Yang dikerjakan
## Masalah yang muncul dan cara mengatasinya
## Catatan teknis yang perlu diingat
## Commit
## Status akhir hari
```

Bagian *Masalah* dan *Catatan teknis* boleh dilewat kalau hari itu memang tidak ada. Bagian *Status akhir hari* jangan dilewat &mdash; itu yang dibaca pertama kali saat mulai kerja keesokan harinya.
