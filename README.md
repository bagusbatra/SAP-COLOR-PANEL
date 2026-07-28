# Color Panel Management System &mdash; SAP S/4HANA 1809

Sumber ABAP dan BSP untuk aplikasi `ZBSP_COLOR_PANEL` di PT. Kayu Mebel Indonesia.

## Cara pakai repo ini

Repo ini adalah sumber kebenaran. SE80 tidak punya versioning yang layak,
jadi setiap perubahan ditulis di sini lebih dulu, baru di-paste ke SAP.

- `src/01_ddic/` &mdash; definisi domain, data element, tabel, number range, lock object
- `src/02_classes/` &mdash; ABAP Class, dibuat lewat SE24
- `src/03_reports/` &mdash; report uji, dibuat lewat SE38
- `src/04_bsp/` &mdash; halaman BSP, dibuat lewat SE80

## Dokumen

- Spec: `docs/superpowers/specs/2026-07-28-color-panel-foundation-dcp-design.md`
- Plan: `docs/superpowers/plans/2026-07-28-color-panel-foundation-dcp.md`

## Aturan teknis yang tidak boleh dilanggar

1. Nol karakter non-ASCII di sumber BSP &mdash; pakai HTML entity
2. OpenSQL gaya lama tanpa `@`, tanpa inline declaration
3. Semua halaman BSP stateful
4. Identitas pelaku selalu USER_ID dari session, tidak pernah SY-UNAME
