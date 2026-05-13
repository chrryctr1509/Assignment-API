---
name: design-philosophy
description: >
  Soul desain untuk semua pekerjaan frontend. Berisi 4 prinsip Apple-style
  (Clarity, Deference, Depth, Simplicity), clarification protocol, dan Golden Test.
  Wajib dibaca fe-developer sebelum implementasi. Untuk panduan eksekusi teknis
  (typography, color, motion), load juga skill frontend-craft.
---

# Design Philosophy — Apple-Style Simplicity
> Skill ini adalah soul desain untuk semua pekerjaan frontend.
> Dibaca dan diinternalisasi oleh fe-developer sebelum implementasi.
> Dijadikan checklist validasi oleh qa-tester setelah implementasi.
> Untuk panduan eksekusi teknis (typography, color, motion, spatial), load juga skill `frontend-craft`.

---

## A. PRINSIP INTI (Apple Design Principles)

### 1. Clarity — UI harus langsung dipahami
- Hierarki visual jelas: elemen terpenting paling menonjol
- Label sederhana: gunakan kata yang paling sedikit, paling jelas
- Tidak banyak elemen bersaing perhatian user
- Satu halaman = satu tugas utama
- Maksimal 1–2 CTA utama per halaman

### 2. Deference — UI tidak mendominasi konten
- Whitespace adalah fitur, bukan kekosongan
- Warna netral sebagai dasar; warna kuat hanya untuk aksi penting
- Shadow dan border minimal — elemen ringan secara visual
- Background putih atau netral sebagai default

### 3. Depth — Struktur dan hubungan antar elemen jelas
- Grouping elemen yang terkait secara visual
- Spacing konsisten menciptakan ritme visual
- Grid system yang konsisten di seluruh halaman

### 4. Simplicity — Hapus semua yang tidak perlu
Steve Jobs: "Simple can be harder than complex."
- Jika satu elemen tidak membantu user → hapus
- Jika bisa menjadi 1 klik → jangan 3 klik
- Jika bisa menjadi 3 kata → jangan 10 kata

---

## B. CLARIFICATION PROTOCOL — Pertanyaan Wajib Sebelum Implementasi

Sebelum mulai implementasi UI apapun, fe-developer WAJIB menjalankan protokol ini.

### Langkah 1 — Cek apakah keputusan sudah ada
```bash
cat docs/design-decisions.md 2>/dev/null && echo "EXISTS" || echo "NOT_FOUND"
```

**Jika EXISTS:** Baca file, tampilkan ringkasan keputusan, langsung lanjut implementasi.
Tidak perlu tanya ulang kecuali ada aspek yang tidak tercakup.

**Jika NOT_FOUND:** Lanjut ke Langkah 2.

### Langkah 2 — Tampilkan pertanyaan ke user (satu batch)

Tampilkan dalam format ini — jangan tanya satu per satu:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DESIGN CLARIFICATION — sebelum implementasi dimulai
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Jawab pertanyaan berikut untuk mendefinisikan arah desain.
Boleh jawab singkat, atau ketik "default" untuk gunakan nilai standar.

1. Mode warna
   → Light mode / Dark mode / Keduanya?
   Default: Light mode

2. Brand color
   → Ada warna utama spesifik? (hex code / nama brand)
   Default: #2563EB (biru netral)

3. Layout density
   → Compact (lebih padat, banyak data) atau Spacious (lapang, fokus)?
   Default: Spacious

4. Target device utama
   → Mobile-first / Desktop-first / Keduanya sama penting?
   Default: Desktop-first

5. Design system existing
   → Ada library CSS / component yang sudah dipakai di project ini?
   Default: Tidak ada, bangun dari nol

6. Tone visual
   → Formal & professional / Friendly & approachable / Minimal & clean?
   Default: Minimal & clean

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**STOP — Tunggu jawaban user sebelum lanjut.**

### Langkah 3 — Simpan keputusan ke file

Setelah user menjawab, simpan ke `docs/design-decisions.md`:

```markdown
# Design Decisions
> Dibuat oleh fe-developer berdasarkan konfirmasi programmer
> Tanggal: [YYYY-MM-DD]
> Digunakan oleh: fe-developer (implementasi) + qa-tester (validasi)

## Keputusan

| Aspek              | Keputusan                  |
|--------------------|----------------------------|
| Mode warna         | [jawaban]                  |
| Brand color        | [jawaban]                  |
| Layout density     | [jawaban]                  |
| Target device      | [jawaban]                  |
| Design system      | [jawaban]                  |
| Tone visual        | [jawaban]                  |

## Catatan Tambahan
[jika user memberikan context tambahan]
```

Setelah file tersimpan → lanjut implementasi.

---

## C. GOLDEN TEST — Validasi Akhir (Steve Jobs Style)

Sebelum UI dianggap selesai, jawab 3 pertanyaan ini secara jujur:

```
GOLDEN TEST
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Apakah user memahami halaman ini dalam 3 detik?
   → YA / TIDAK

2. Apakah halaman ini bisa dibuat lebih sederhana lagi?
   → TIDAK / YA (jika YA — sederhanakan dulu, baru selesai)

3. Apakah semua elemen visual memiliki tujuan yang jelas?
   → YA / TIDAK (jika TIDAK — hapus elemen yang tidak bertujuan)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Hanya jika semua jawaban lulus → UI boleh dianggap selesai.**

Jika gagal di pertanyaan 2 atau 3 → perbaiki terlebih dahulu sebelum commit.
