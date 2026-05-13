---
name: context-resilience
description: "Panduan compact context, resume session, dan estimasi context budget per wave"
---

# Context Resilience Skill

## Kapan Compact

### WAJIB compact:
1. Setelah planning phase + APPROVE, SEBELUM Wave 1
2. Setelah setiap wave selesai, SEBELUM wave berikutnya
3. Saat response mulai lambat atau mulai kehilangan context detail

### Instruksi compact yang efektif:
```
Compact context sekarang. Pertahankan HANYA:
- docs/wave-execution-state.md (file checklist — ini yang paling penting)
- docs/wave-plan.md (remaining waves)
- docs/conventions.md (coding standards)
- docs/design-direction.md (design rules)
- docs/docker-assessment.md (Docker rules)
- .env (config values)

Buang SEMUA:
- Conversation sebelum titik ini
- Planning analysis detail
- File contents yang sudah ditulis ke disk
- Tool call results yang sudah diproses
```

### Setelah compact, PERTAMA yang harus dilakukan:
```bash
cat docs/wave-execution-state.md | head -30
cat docs/wave-plan.md | head -20
```
Ini mengembalikan context minimal yang dibutuhkan untuk lanjut execution.

## Cara Resume

### Session baru setelah context habis:
```
Baca docs/wave-execution-state.md dan docs/session-handoff.md.
Lanjutkan dari file terakhir yang belum [x].
JANGAN re-plan. JANGAN re-create files [x]. Langsung execute.
```

## Estimasi Context Budget per Wave

### Planning phase: ~30-50% context
- Brief analysis, wave planning, approval → heavy
- HARUS compact setelah ini

### Per wave execution:
- 10-20 files per wave: ~15-25% context
- 20-40 files per wave: ~25-40% context
- 40+ files per wave: PECAH wave jadi sub-waves

### Rule of thumb:
- Jika wave punya >20 files → pertimbangkan pecah jadi sub-wave yang lebih kecil
- Jika 2 waves sudah dieksekusi tanpa compact → COMPACT SEKARANG
- Jika response time terasa lambat → COMPACT SEGERA
- Jika total file terlalu banyak (>20 per wave) → split wave
