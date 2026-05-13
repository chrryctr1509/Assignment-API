---
name: pipeline-planning
description: >
  Planning quality gates — deliberation, acceptance criteria, dan critic challenge.
  Dipanggil SETELAH Phase 0 analysis selesai dan SEBELUM APPROVE gate.
  Memastikan planning cukup matang sebelum mulai build.
  3 gate sequential: deliberation → acceptance criteria → critic challenge.
---

# Pipeline Planning Gates

## KAPAN SKILL INI DIBACA
- Otomatis oleh orchestrator setelah Phase 0 (analysis) selesai
- Setelah code-architect dan wave-planner produce output
- SEBELUM APPROVE gate
- WAJIB untuk BUILD, NEW_FEATURE, GREENFIELD
- SKIP untuk SMALL_EDIT dan BUG_FIX (scope terlalu kecil)

## FLOW OVERVIEW

```
Phase 0 selesai (analysis + architecture + wave-plan ready)
    ↓
Gate 1: Deliberation + Pre-Mortem
    ↓ (flag ke user jika terlalu banyak unknowns)
Gate 2: Acceptance Criteria
    ↓ (setiap fitur punya measurable "done")
Gate 3: Critic Challenge (max 2x loop)
    ↓ GO → APPROVE gate
    ↓ GO-WITH-CONDITIONS → address → re-critic (loop)
    ↓ NO-GO → revise → re-critic (loop)
    ↓ 2x NO-GO → eskalasi ke user
    ↓
APPROVE gate (user confirm)
```

---

## GATE 1: Deliberation + Pre-Mortem

### Input yang harus sudah ada
Sebelum mulai Gate 1, VERIFY file-file ini sudah ada:
- `docs/project-context.md` — dari codebase-scout
- `docs/architecture-blueprint.md` — dari code-architect
- `docs/wave-plan.md` atau `docs/task-breakdown.md` — dari wave-planner
- `docs/technical-spec.md` — dari technical-planner (jika ada)

Jika salah satu BELUM ADA → STOP, jangan lanjut. Report ke orchestrator.

### Step 1.1 — Classify Knowledge

Baca semua docs di atas, lalu classify SEMUA elemen project ke 3 bucket:

**Controllable (kita kontrol penuh):**
- Code yang kita tulis sendiri
- Database schema
- Internal API contracts
- Docker configuration

**Influenceable (bisa kita pengaruhi, tapi tidak 100% kontrol):**
- Third-party library behavior
- AI provider response quality
- Performance characteristics
- Browser compatibility

**Uncontrollable (di luar kontrol kita):**
- Third-party API availability / contract changes
- External service uptime
- User behavior patterns
- Hardware/network conditions

### Step 1.2 — Identify Unknowns

Untuk setiap komponen di architecture-blueprint:

```markdown
## Yang Sudah Dipahami (verified)
- [komponen]: [evidence — file dibaca, API tested, docs confirmed]

## Yang BELUM Dipahami (unknown)
- [komponen]: [kenapa belum tahu — belum ada docs? belum test? dependency belum ready?]

## Asumsi yang Dibuat (unverified)
- [asumsi]: [apa yang kita anggap benar tanpa verifikasi]
- Jika asumsi ini SALAH → [konsekuensi yang terjadi]
```

### Step 1.3 — Pre-Mortem Analysis

Bayangkan project ini GAGAL. Tanyakan:

```markdown
## Pre-Mortem: Jika project ini gagal, kenapa gagal?

### Technical Failures
1. [Skenario gagal #1]: [kenapa bisa terjadi] → [probability: HIGH/MED/LOW]
   Mitigasi: [apa yang bisa dilakukan sekarang untuk mencegah]
2. [Skenario gagal #2]: ...

### Integration Failures
1. [Service A tidak bisa connect ke Service B karena ...]
   Mitigasi: [...]

### Assumption Failures
1. [Kita assume X tapi ternyata Y] → [impact]
   Mitigasi: [...]
```

### Step 1.4 — Decision Point

Hitung:
- Jumlah items di "Uncontrollable" yang CRITICAL untuk project
- Jumlah items di "Unknown" yang belum ada path to resolve
- Jumlah pre-mortem skenario dengan probability HIGH

**Jika > 3 CRITICAL uncontrollable ATAU > 3 unresolved unknowns:**

```
⚠️ Planning flag: terlalu banyak variabel yang tidak terkontrol.

Uncontrollable risks:
- [list]

Unresolved unknowns:
- [list]

Opsi:
1. Lanjut dengan mitigasi — accept risks, tambah fallback/stub strategy
2. Investigate dulu — resolve unknowns sebelum lanjut planning
3. Reduce scope — hilangkan fitur yang bergantung pada uncontrollable

Mana yang kamu pilih?
```

**Jika semua manageable → lanjut ke Gate 2.**

### Step 1.5 — Output

Tulis ke `docs/deliberation.md`:
```markdown
# Deliberation Report
Generated: [timestamp]

## Knowledge Classification
### Controllable
- [list]
### Influenceable
- [list]
### Uncontrollable
- [list]

## Unknowns
### Verified (sudah dipahami)
- [list with evidence]
### Unknown (belum dipahami)
- [list with reason]
### Assumptions (unverified)
- [list with consequence if wrong]

## Pre-Mortem
### If this project fails, it fails because:
1. [scenario + probability + mitigation]
2. ...

## Decision
- Flag raised: [YES/NO]
- User decision: [if flagged]
- Proceed to Gate 2: [YES/NO]
```

---

## GATE 2: Acceptance Criteria

### Step 2.1 — Baca wave-plan

Baca `docs/wave-plan.md` atau `docs/task-breakdown.md`. Untuk SETIAP fitur/task:

### Step 2.2 — Generate acceptance criteria per fitur

Untuk setiap fitur, definisikan:

```markdown
### Feature: [nama fitur]

**Done when ALL of these are true:**
1. [Functional]: [apa yang harus bisa dilakukan — specific, testable]
2. [API]: [endpoint exists, returns correct shape, handles errors]
3. [UI]: [component renders, shows correct data, handles empty/error state]
4. [Integration]: [connects to other services correctly]
5. [Edge case]: [handles [specific edge case]]

**NOT done if any of these are true:**
- Console errors saat page load
- API returns 500 pada happy path
- Empty state tidak di-handle (crash instead of "no data" message)
- Hardcoded values yang seharusnya configurable

**Measurable verification:**
- Endpoint: `[METHOD] [URL]` → expected response `[shape]`
- UI: navigate to `[URL]` → expect `[visible element]`
- Test: `[test command]` → expect pass
```

### Step 2.3 — Decision thresholds

Definisikan untuk keseluruhan project:

```markdown
## Decision Framework

### Kapan PIVOT (ubah approach)
- Jika > 50% acceptance criteria gagal setelah wave execution
- Jika architecture assumption terbukti salah (dari deliberation)
- Jika estimated effort berubah > 2x dari planning

### Kapan STOP dan tanya user
- Jika butuh credentials/config yang belum di-provide
- Jika menemukan blocker yang tidak ada di pre-mortem
- Jika 2x fix loop gagal untuk issue yang sama

### Kapan lanjut tanpa tanya
- Fix untuk issue yang jelas root cause-nya
- Config change yang tidak impact business logic
- Formatting/linting issues

### Leading indicators (early warning signs)
- Developer self-test gagal > 3 items → kemungkinan architecture issue
- Boot time > 2 menit → kemungkinan resource/config issue
- > 5 interface mismatches ditemukan → kemungkinan shared contract kurang detail
```

### Step 2.4 — Output

Tulis ke `docs/acceptance-criteria.md`:
```markdown
# Acceptance Criteria
Generated: [timestamp]
Source: docs/wave-plan.md

## Per-Feature Criteria

### Feature 1: [nama]
**Done when:**
1. [criteria]
2. [criteria]
**NOT done if:**
- [anti-criteria]
**Verification:**
- [measurable check]

### Feature 2: [nama]
...

## Decision Framework
### Pivot when: [conditions]
### Stop and ask when: [conditions]
### Continue without asking when: [conditions]
### Early warning signs: [indicators]
```

**PENTING:** `docs/acceptance-criteria.md` menjadi SOURCE OF TRUTH untuk:
- `feature-auditor` di verification pipeline (Phase 5)
- `qa-tester` untuk test planning
- `code-reviewer` untuk completeness check

---

## GATE 3: Critic Challenge (Max 2x Loop)

### Step 3.1 — Spawn critic agent

Critic HARUS baca:
- `docs/architecture-blueprint.md`
- `docs/wave-plan.md`
- `docs/deliberation.md` (dari Gate 1)
- `docs/acceptance-criteria.md` (dari Gate 2)

### Step 3.2 — Critic evaluasi 4 pertanyaan

```markdown
## Planning Critic Review

### 1. Weakest Assumption
Apa asumsi paling lemah di architecture ini?
- [asumsi]
- Jika salah → [impact]
- Rekomendasi: [mitigasi atau investigate]

### 2. Biggest Risk
Apa risiko terbesar yang bisa menyebabkan project gagal?
- [risk]
- Probability: [HIGH/MED/LOW]
- Rekomendasi: [prevent atau accept]

### 3. What's Missing
Apa yang TIDAK ada di plan tapi SEHARUSNYA ada?
- [missing item]
- Kenapa penting: [reason]
- Rekomendasi: [add atau acknowledge gap]

### 4. Alternative Approach
Apakah ada pendekatan lain yang lebih baik?
- [alternative]
- Pro: [advantages]
- Con: [disadvantages]
- Rekomendasi: [switch atau stick with current]
```

### Step 3.3 — Critic verdict

```markdown
## Verdict: [GO / GO-WITH-CONDITIONS / NO-GO]

### Jika GO:
Confidence: [HIGH/MEDIUM/LOW]
Catatan: [optional notes]

### Jika GO-WITH-CONDITIONS:
Conditions yang HARUS di-address sebelum build:
1. [condition — specific, actionable]
2. [condition]
Setelah conditions addressed → re-submit ke critic

### Jika NO-GO:
Alasan:
1. [reason — specific]
2. [reason]
Yang harus direvisi:
1. [architecture change needed]
2. [plan change needed]
Setelah revisi → re-submit ke critic
```

### Step 3.4 — Loop logic

```
loop_count = 0

WHILE verdict != GO AND loop_count < 2:
    IF verdict == GO-WITH-CONDITIONS:
        → Orchestrator address conditions
        → Update architecture-blueprint dan/atau wave-plan
        → Re-submit ke critic
        → loop_count++

    IF verdict == NO-GO:
        → Orchestrator revise architecture/plan
        → Update docs
        → Re-submit ke critic
        → loop_count++

IF loop_count >= 2 AND verdict masih bukan GO:
    → Eskalasi ke user
```

### Step 3.5 — Eskalasi (setelah 2x loop)

```
⚠️ Planning critic masih belum approve setelah 2x revisi.

Concerns yang belum resolved:
1. [concern dari critic]
2. [concern dari critic]

Opsi:
1. 🟢 Override — lanjut build, accept risks yang diketahui
   → Risks akan di-track di deliberation.md
   → Verification pipeline akan catch issues post-build
2. 🔄 Redesign — saya revisi approach secara fundamental
   → Kembali ke code-architect untuk alternative architecture
3. 💬 Discuss — kita diskusi dulu sebelum lanjut
   → Masuk DISCUSSION mode

Mana yang kamu pilih?
```

Jika user pilih Override:
- Catat di `docs/deliberation.md`: "USER OVERRIDE — accepted risks: [list]"
- Lanjut ke APPROVE gate
- Verification pipeline post-build harus EXTRA scrutiny pada accepted risks

### Step 3.6 — Output

Tulis ke `docs/critic-planning-verdict.md`:
```markdown
# Critic Planning Review
Generated: [timestamp]
Loop count: [N]
Final verdict: [GO/GO-WITH-CONDITIONS/NO-GO/USER-OVERRIDE]

## Review Summary
### Weakest assumption: [summary]
### Biggest risk: [summary]
### Missing items: [summary]
### Alternative considered: [summary]

## Verdict History
- Loop 1: [verdict] — [reason]
- Loop 2: [verdict] — [reason] (jika ada)

## Conditions (jika GO-WITH-CONDITIONS)
- [x] [condition 1 — addressed]
- [x] [condition 2 — addressed]

## User Override (jika applicable)
- Accepted risks: [list]
- Override reason: [user's reason]
```

---

## INTEGRATION NOTES

### Hubungan dengan acceptance-criteria.md
`docs/acceptance-criteria.md` yang di-generate di Gate 2 akan dipakai oleh:
- `feature-auditor` di verification pipeline → cross-check actual vs criteria
- `qa-tester` → test berdasarkan acceptance criteria, bukan hanya task-breakdown
- `code-reviewer` → verify completeness
- `user-simulator` → test user-facing criteria

### Hubungan dengan deliberation.md
`docs/deliberation.md` yang di-generate di Gate 1 akan dipakai oleh:
- `critic` di Gate 3 → evaluate risks
- `orchestrator` → decision making saat issue muncul di execution
- `verification pipeline` → extra scrutiny pada accepted risks dan assumptions

### Resume behavior
Jika context habis di tengah planning gates:
- Save state ke `docs/planning-gate-state.md`: gate terakhir, output yang sudah ada
- Saat resume → cek planning-gate-state → lanjut dari gate yang belum selesai
- JANGAN re-run gate yang sudah selesai (output docs sudah ada)
