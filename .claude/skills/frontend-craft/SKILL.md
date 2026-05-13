---
name: frontend-craft
description: >
  Panduan eksekusi kreatif frontend. Dibaca bersamaan dengan design-philosophy.
  Berisi: typography, color system, motion, spatial composition, backgrounds,
  dan anti-AI-slop guidance. design-philosophy adalah soul-nya; skill ini adalah
  cara mengekspresikannya menjadi UI yang distinctive dan production-grade.
---

# Frontend Craft — Creative Execution Guide

> Dibaca bersamaan dengan `design-philosophy`.
> design-philosophy = WHY (values, process, Golden Test)
> frontend-craft = HOW (typography, color, motion, spatial composition)

---

## A. DESIGN THINKING — Sebelum Menulis Kode

Commit ke arah estetik yang **BOLD** dan eksekusi dengan presisi. Jangan default ke pilihan yang aman. Hasil luar biasa datang dari keputusan yang spesifik dan intentional — bukan generic best practices.

Sebelum implementasi, jawab empat pertanyaan ini:

1. **Purpose** — Apa tujuan utama halaman ini? Satu kalimat saja.
2. **Tone** — Pilih arah yang BOLD: brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian — atau definisikan sendiri. Ini titik awal, bukan batasan.
3. **Constraints** — Ada batasan teknis, brand, atau waktu yang mempengaruhi desain?
4. **Differentiation** — Apa SATU hal yang akan diingat orang dari interface ini?

Commit ke satu arah estetik yang jelas **sebelum** menulis satu baris kode.
Jangan mulai implementasi jika arah estetik masih kabur.

### Complexity-Vision Matching
Sesuaikan kompleksitas implementasi dengan visi estetik:
- **Maximalist** → kode elaboratif, animasi ekstensif, efek berlapis, tekstur kaya
- **Minimalist** → restraint, presisi, spacing yang cermat, detail yang subtle
- **Elegance** = mengeksekusi visi dengan baik, bukan selalu menambah lebih banyak

---

## B. TYPOGRAPHY

### Prinsip
- Pilih font yang **distinctive, unexpected, characterful** — bukan yang aman
- Pairing ideal: display font yang kuat + body font yang refined dan readable
- Typeface adalah personality — pilih yang sesuai tone yang sudah ditentukan di Section A

### Yang Harus Dihindari
- Inter, Roboto, Arial, system fonts — terlalu generik
- Font yang tidak punya karakter visual yang jelas
- Mixing lebih dari 2 family tanpa justifikasi visual yang kuat

### Baseline (guidance, bukan aturan kaku)
| Elemen | Ukuran titik awal |
|--------|-------------------|
| Heading utama | 32px |
| Heading sekunder | 24px |
| Subheading | 18px |
| Body | 16px |
| Caption / label kecil | 14px |

Boleh deviasi dari baseline jika ada justifikasi komposisi yang jelas.
Maksimal 2 font family — kecuali ada keputusan visual yang kuat.

---

## C. COLOR SYSTEM

### Prinsip
- Commit ke **satu palette yang cohesive** — jangan campur arah estetik
- **Dominant color + sharp accent** selalu outperform palette yang even-distributed
- Warna harus mendukung tone yang dipilih di Section A, bukan dipilih karena "terlihat bagus"

### Yang Harus Dihindari
- Purple gradient di white background — sudah terlalu umum
- Color scheme yang bisa dipakai di project manapun tanpa terasa salah
- Warna yang dipilih karena "standar" bukan karena mendukung tone

### Baseline (guidance)
| Kategori | Fungsi |
|----------|--------|
| Primary | Aksi utama, CTA, elemen paling penting |
| Neutral | Teks, background, elemen struktural |
| Semantic | Success, error, warning (hanya jika dibutuhkan) |

Warna dekoratif **diizinkan** jika mendukung arah estetik yang sudah dipilih.
Tidak ada aturan "maksimal N warna" — yang penting cohesive dan intentional.

---

## D. MOTION & MICRO-INTERACTIONS

### Prinsip
- Motion harus memperkuat hierarki dan fokus, bukan sekadar dekorasi
- **High-impact**: page load dengan staggered reveals > scattered micro-interactions di semua elemen
- Setiap animasi harus punya tujuan yang bisa dijelaskan dalam satu kalimat

### Panduan Implementasi
- **HTML/CSS**: Prioritaskan CSS-only transitions dan animations
- **React**: Gunakan Motion library (Framer Motion) untuk orchestration yang kompleks
- Gunakan `animation-delay` untuk menciptakan ritme visual yang terasa alami
- Scroll-triggering dan hover states yang **memorable** — sesuatu yang user ingat

### Yang Harus Dihindari
- Animasi pada setiap elemen tanpa hierarki — hasilnya noise, bukan polish
- Duration terlalu cepat (< 150ms) atau terlalu lambat (> 600ms) untuk transisi UI
- Animasi yang tidak bisa di-disable untuk aksesibilitas (respek `prefers-reduced-motion`)

---

## E. SPATIAL COMPOSITION

### Prinsip
- **Asymmetry, overlap, diagonal flow, grid-breaking** adalah teknik yang sah — bukan pelanggaran
- Pilih satu pendekatan dan commit: **generous negative space** OR **controlled density**
- Keduanya valid — yang tidak valid adalah tidak punya posisi

### Yang Harus Dihindari
- Predictable layouts: header, 3 cards, footer — tanpa variasi
- Component patterns yang sama persis dengan ribuan project lain
- Margin dan padding yang "asal seimbang" tanpa pertimbangan komposisi

### Teknik yang Bisa Digunakan
- Elemen yang overlap menciptakan kedalaman tanpa shadow berlebihan
- Grid-breaking untuk hero atau elemen featured — menarik perhatian secara alami
- Diagonal atau kurva sebagai elemen komposisi jika sesuai tone

---

## F. BACKGROUNDS & VISUAL DEPTH

### Prinsip
- Background menciptakan **atmosphere** — jangan defaultkan ke solid color jika ada pilihan yang lebih kaya
- Depth bisa dibangun lewat: gradient meshes, noise textures, geometric patterns, layered elements

### Teknik yang Tersedia
- **Gradient meshes** — multi-point gradients yang terasa organik
- **Noise/grain overlay** — menambah texture dan menghindari kesan flat digital
- **Layered transparencies** — elemen di atas background dengan opacity berbeda
- **Dramatic shadows** — bukan drop-shadow generik, tapi shadow yang bermakna komposisi

### Yang Harus Dihindari
- Solid white atau solid gray sebagai default tanpa pertimbangan — terlalu mudah dan terlalu umum
- Gradient yang sudah terlalu familiar (purple-to-blue, pink-to-orange)

---

## G. ANTI-AI-SLOP CHECKLIST

Sebelum selesai, verifikasi hal berikut:

- [ ] Tidak ada dua halaman yang terlihat identik dalam project ini
- [ ] Font yang dipilih bukan Inter, Roboto, atau system font
- [ ] Color palette tidak bisa dipakai di project lain tanpa terasa aneh
- [ ] Layout tidak menggunakan pola "3 equal cards in a row" tanpa variasi
- [ ] Background bukan solid white atau solid gray tanpa justifikasi
- [ ] Ada setidaknya satu elemen motion atau depth yang terasa intentional
- [ ] Desain ini TIDAK konvergen ke pilihan yang sama dengan generasi sebelumnya
- [ ] Pilihan font, tema, dan layout berbeda dari komponen terakhir yang dibangun

**Satu pertanyaan terakhir sebelum commit:**
> "Apakah ini terasa *genuinely designed* untuk konteks spesifik ini,
> atau bisa di-copy-paste ke project manapun?"

Jika jawabannya yang kedua → kembali ke Section A dan tentukan arah yang lebih spesifik.

### Variation Mandate
Setiap generasi harus berbeda. Variasikan antara tema light/dark, pairing font yang berbeda, arah estetik yang berbeda. JANGAN konvergen ke pilihan umum yang sama (misal: Space Grotesk, gradient blue-purple) di setiap build.

---

## H. REFERENSI KE DESIGN-PHILOSOPHY

Skill ini adalah **HOW** — cara eksekusi.
`design-philosophy` adalah **WHY** — alasan di balik setiap keputusan.

Sebelum memulai implementasi:
- Pastikan `design-philosophy` sudah di-load dan diinternalisasi
- Clarification Protocol (Section C di design-philosophy) sudah dijalankan
- `docs/design-decisions.md` sudah ada atau sudah dibuat

**Golden Test dari `design-philosophy` tetap berlaku sebagai validasi akhir.**
Craft yang kuat tapi gagal Golden Test = belum selesai.
