---
name: qa-orchestration
description: >
  Post-development QA orchestration. Dijalankan OTOMATIS setelah semua developer
  agents output status:done. Mengoordinasikan 4 QA steps secara sequential
  dengan smart re-loop logic. Max 3x loop sebelum eskalasi ke user.
---

# QA Orchestration Pipeline

## KAPAN SKILL INI DIBACA
- Oleh orchestrator setelah SEMUA developer agents di wave terakhir output `status: done`
- SEBELUM PR creation
- JANGAN skip

## PRE-CONDITION CHECK

Sebelum mulai QA, verify:
1. Semua developer agents output `status: done`
2. Semua developer agents output `service_rebuilt: true` dan `service_healthy: true`
3. Jika ada developer yang `service_healthy: false` → STOP, route balik ke developer untuk fix boot issue

```bash
# Verify app health sebelum QA
curl -sf http://localhost:${APP_PORT:-8000}/health && echo "Backend OK" || echo "Backend DOWN"
curl -sf http://localhost:${FE_PORT:-3000} && echo "Frontend OK" || echo "Frontend DOWN"
```

Jika app tidak healthy → JANGAN mulai QA. Route ke developer/env-configurator untuk fix.

---

## QA STEPS (sequential)

### Step 1: Automated Tests — `qa-tester`

**Purpose:** Catch code breaks, regressions. Cepat (seconds-minutes).

Spawn `qa-tester` dengan mode FULL (post-build, bukan scope-aware):
```
Jalankan FULL test suite di semua environments.
Post-build verification — bukan scope-aware.
Report ke docs/test-report.md
```

**Pass criteria:** `tests_pass: true` di YAML output
**Fail criteria:** `tests_pass: false` → catat failed tests → route ke fix loop

### Step 2: Deterministic TC Execution — `qa-checklist-runner`

**Purpose:** Verify specific endpoints dan flows match expected values. Medium speed.

**Pre-step:** Cek apakah `docs/qa-checklist.md` ada.
- ADA → langsung run
- TIDAK ADA → spawn `qa-checklist-generator` dulu → baru run

Spawn `qa-checklist-runner`:
```
Jalankan semua TCs dari docs/qa-checklist.md.
Report ke docs/qa-checklist-report.md
```

**Pass criteria:** `tests_pass: true`, `failed_tcs: 0`
**Fail criteria:** `failed_tcs > 0` → catat failures → route ke fix loop

### Step 3: Browser Testing — `user-simulator`

**Purpose:** Test sebagai real user. Catch UI crashes, console errors, UX issues. Slowest.

Spawn `user-simulator` dengan mode FULL:
```
Test SEMUA user flows dari docs/user-simulation-config.md.
Include: single-role flows, cross-role chain flows, file upload flows.
Test KEDUA state: empty data DAN populated data.
Cek browser console di setiap halaman.
Report ke docs/user-simulation-report.md
```

**Pass criteria:** Semua flows pass, `console_errors: 0`
**Fail criteria:** Any flow fail ATAU console errors > 0 → route ke fix loop

### Step 4: Feature Audit — `feature-auditor`

**Purpose:** Binary check — semua fitur dari task-breakdown.md terimplementasi? Cepat.

Spawn `feature-auditor`:
```
Cross-check docs/task-breakdown.md vs actual codebase.
Report ke docs/feature-audit-report.md
```

**Pass criteria:** `completion_rate: 100%` (atau semua critical/high features implemented)
**Fail criteria:** Missing features → route ke fix loop

---

## SMART RE-LOOP LOGIC

### Prinsip: Re-run dari step yang gagal, bukan dari awal

```
Loop counter = 0 (shared across all steps)

Run Step 1 (qa-tester)
  → PASS → Run Step 2
  → FAIL → fix loop (see below)

Run Step 2 (qa-checklist-runner)
  → PASS → Run Step 3
  → FAIL → fix loop

Run Step 3 (user-simulator)
  → PASS → Run Step 4
  → FAIL → fix loop

Run Step 4 (feature-auditor)
  → PASS → QA APPROVED
  → FAIL → fix loop
```

### Fix Loop Flow

```
Step N FAIL → collect failure details
  ↓
Loop counter += 1
  ↓
Cek: loop_counter > 3?
  → YES → ESKALASI KE USER (see below)
  → NO → continue
  ↓
Classify failures:
  - Backend issue → spawn be-developer dengan fix items
  - Frontend issue → spawn fe-developer dengan fix items
  - Infra issue → spawn env-configurator / docker-manager
  - Missing feature → spawn be-developer + fe-developer
  ↓
Developer fix + rebuild + self-test
  ↓
Re-run dari Step N (BUKAN dari Step 1)
  → KECUALI developer mengubah file yang impact step sebelumnya
  → Jika developer ubah backend model/schema → re-run dari Step 1
  → Jika developer hanya ubah frontend component → re-run dari Step 3
```

### Smart Re-run Detection

Setelah developer fix, cek files yang berubah:

```bash
# Files yang berubah oleh developer fix
CHANGED=$(git diff --name-only HEAD~1)

# Determine re-run starting point
if echo "$CHANGED" | grep -qE "models/|schemas/|migrations/|database/"; then
  RESTART_FROM=1  # Schema change → re-run semua
elif echo "$CHANGED" | grep -qE "services/|routers/|tasks/"; then
  RESTART_FROM=1  # Backend logic change → re-run dari automated tests
elif echo "$CHANGED" | grep -qE "components/|hooks/|stores/|pages/|app/"; then
  RESTART_FROM=3  # Frontend-only change → re-run dari browser test
elif echo "$CHANGED" | grep -qE "\.env|docker-compose|Dockerfile|nginx"; then
  RESTART_FROM=1  # Infra change → re-run semua
else
  RESTART_FROM=$FAILED_STEP  # Default: re-run dari step yang gagal
fi
```

### Eskalasi ke User (loop > 3)

```
⚠️ QA gagal setelah 3x fix loop.

**Yang sudah berhasil:**
- Step 1 (automated tests): [PASS/FAIL]
- Step 2 (checklist): [PASS/FAIL]
- Step 3 (browser test): [PASS/FAIL]
- Step 4 (feature audit): [PASS/FAIL]

**Yang masih gagal:**
- Step [N] ([agent]): [failure summary]
  - Loop 1: [approach] → [result]
  - Loop 2: [approach] → [result]
  - Loop 3: [approach] → [result]

**Yang saya butuhkan dari kamu:**
- [specific information or action needed]

**Opsi:**
1. Saya coba fix lagi dengan informasi tambahan dari kamu
2. Lanjut ke PR dengan status partial (known issues)
3. Kamu fix manual, lalu jalankan `/verify` untuk re-test
```

---

## STATE TRACKING

Simpan state di `docs/qa-orchestration-state.md`:

```markdown
# QA Orchestration State
updated: [timestamp]

## Status
- loop_count: [N]
- current_step: [1-4]
- overall_status: [running/passed/failed-escalated]

## Step Results
- Step 1 (qa-tester): [PASS/FAIL/PENDING]
- Step 2 (qa-checklist-runner): [PASS/FAIL/PENDING]
- Step 3 (user-simulator): [PASS/FAIL/PENDING]
- Step 4 (feature-auditor): [PASS/FAIL/PENDING]

## Loop History
- Loop 1: Step [N] failed — [issue summary] — fixed by [agent]
- Loop 2: Step [N] failed — [issue summary] — fixed by [agent]
- Loop 3: Step [N] failed — [issue summary] — fixed by [agent]

## Fix Items per Loop
### Loop [N]
- [file]: [issue] → assigned to [agent] → [fixed/still failing]
```

---

## RESUMABLE

Jika context habis di tengah QA:
1. Save state ke `docs/qa-orchestration-state.md`
2. Saat `/start resume` → baca state → lanjut dari step terakhir
3. Steps yang sudah PASS di loop ini → JANGAN ulang (kecuali smart re-run detection bilang harus)
