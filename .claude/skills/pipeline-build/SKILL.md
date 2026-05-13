# Pipeline: BUILD / NEW_FEATURE / GREENFIELD

Skill ini berisi full pipeline untuk mode BUILD (termasuk NEW_FEATURE dan GREENFIELD).
Orchestrator membaca skill ini saat mode = BUILD dari /start classification.

Urutan: Phase 0 → 0B → 1 → **1.5 (Planning Gates)** → APPROVE → 2.5 → 2 (GREENFIELD) → 3 (Wave Execution) → 4 (Pre-QA Setup) → 5 (QA) → 6 (Final Delivery + PR)

---

## Pre-Phase 0: Verify Scope dengan User

Sebelum mulai Phase 0, TAMPILKAN ke user:
```
Saya akan jalankan [SCOPE TYPE] pipeline untuk: [ringkasan task]
- Estimated effort: [S/M/L/XL]
- Pipeline: Phase 0 → 0B → 1 → 1.5 (Planning Gates) → APPROVE → Wave Execution → Review → PR
Confirm? [Proceed / Discuss first]
```

**Jika user bilang "Discuss first"** → route ke pipeline-discussion/SKILL.md
**Jika user confirm** → lanjut ke Phase 0
**JANGAN mulai Phase 0 tanpa explicit confirmation**

---

## PHASE 0 — Context Analysis (3 subagents parallel)

### ⚠️ DELEGATION CHECKPOINT — BUILD MODE
Task BUILD/NEW_FEATURE WAJIB melewati full pipeline.
JANGAN PERNAH shortcut dengan edit code langsung.
Jika task terasa "sederhana" atau "cuma edit beberapa file":
- Tetap WAJIB spawn codebase-scout → planning → developer agent
- Orchestrator-guard hook akan BLOCK setiap attempt Write/Edit ke code files
- TIDAK ADA PENGECUALIAN — bahkan untuk 1 baris code

### Phase 0A — Docker Assessment + Port Scan (WAJIB SEBELUM APAPUN)

```bash
# 1. Cek Docker tersedia
docker info >/dev/null 2>&1 && echo "DOCKER_OK" || echo "DOCKER_MISSING"
```

**Jika DOCKER_MISSING:**
```
⚠️ Docker tidak terdeteksi. Pipeline tetap berjalan tapi semua service
akan jalan di host. Install Docker untuk experience terbaik:
  curl -fsSL https://get.docker.com | sh
```
→ Set `DOCKER_MODE=host-only` di pipeline-state.md. Lanjut pipeline.

**Jika DOCKER_OK:**
```bash
# 2. Run docker assessment
bash .claude/scripts/docker-assess.sh . > /tmp/docker-assessment.json

# 3. Dynamic port scan — scan semua ports yang dibutuhkan
cat /tmp/docker-assessment.json | jq '{services: (.services + .host_services) | map(select(.preferred_port > 0))}' | bash .claude/scripts/port-scan-all.sh > /tmp/port-assignments.json

# 4. Tampilkan ke user
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 DOCKER ASSESSMENT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat /tmp/docker-assessment.json | jq -r '.services[] | "  ✅ \(.name): Docker (port \(.preferred_port))"'
cat /tmp/docker-assessment.json | jq -r '.host_services[] | "  ⚠️ \(.name): Host (\(.type))"'
echo ""
echo "Port assignments:"
cat /tmp/port-assignments.json | jq -r '.assignments[] | "  \(.name): \(.preferred) → \(.assigned)"'
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

Set `DOCKER_MODE` di pipeline-state.md:
- Semua Docker → `DOCKER_MODE=full`
- Ada host_services → `DOCKER_MODE=hybrid`
- Docker missing → `DOCKER_MODE=host-only`

Teruskan ke env-configurator untuk generate .env dan docker-compose.yml.

Setelah inisialisasi selesai, spawn subagents untuk mengumpulkan context.

### Smart Cache — Skip jika Context Docs Fresh

SEBELUM spawn codebase-scout, cek cache:
```bash
# Cek apakah project-context.md ada dan fresh
if [ -f docs/project-context.md ]; then
  LAST_UPDATED=$(grep "last_updated:" docs/project-context.md | head -1)
  # Jika last_updated < 7 hari → SKIP full scan
fi
```

**Decision tree:**

1. **project-context.md TIDAK ADA:**
   → Spawn codebase-scout mode FULL (normal behavior)

2. **project-context.md ADA tapi STALE (> 7 hari atau last_pipeline sangat berbeda dari current scope):**
   → Spawn codebase-scout mode FULL (re-scan)

3. **project-context.md ADA dan FRESH (< 7 hari):**
   → SKIP codebase-scout
   → Baca langsung dari project-context.md
   → Log: "Using cached project context (updated [timestamp])"
   → Hemat ~15K tokens + 30 detik

4. **project-context.md ADA, FRESH, tapi scope type BERBEDA dari last_pipeline:**
   Contoh: last_pipeline = BUG_FIX, current = NEW_FEATURE
   → Spawn codebase-scout mode REFRESH (delta scan, bukan full)
   → Hanya scan area yang relevan dengan scope baru

**Sama untuk docs lain:**
- conventions.md: skip convention-scout jika fresh (sudah ada cache check di Phase 0B)
- agent-context.md: re-use jika fresh
- design-direction.md: re-use jika fresh (kecuali mode UPGRADE)

### Smart Phase 0 — Skip Unnecessary Agents

**Cek input type sebelum spawn:**
```bash
# Detect apakah input referensikan file brief (.docx/.pdf/.xlsx)
INPUT_HAS_FILE=$(echo "$INPUT" | grep -qE '\.(docx|pdf|xlsx)' && echo "YES" || echo "NO")
```

**Jika scope = BUG FIX atau SMALL EDIT:**
- SKIP brief-reader, brief-interpreter (tidak perlu — input adalah plain text bug description)
- SKIP pm-agent (scope sudah jelas dari input)
- Hanya spawn codebase-scout untuk identifikasi area kode
- Log: "Phase 0 optimized: BUG_FIX/SMALL_EDIT — skipping brief-reader, pm-agent"

**Jika scope = NEW FEATURE atau GREENFIELD:**
- **Jika INPUT_HAS_FILE = YES** → spawn semua 3 subagent (full analysis)
- **Jika INPUT_HAS_FILE = NO** → SKIP brief-reader dan brief-interpreter (input plain text)
  Tetap spawn: codebase-scout + pm-agent
  Log: "Phase 0 optimized: plain text input — skipping brief-reader"

**Full Phase 0 (default):**
```
PARALLEL:
  1. codebase-probe    → via codebase-scout
     Input  : project root
     Output : codebase structure, stack detection, existing patterns

  2. input-parser      → via brief-reader + brief-interpreter
     Input  : briefs/ folder atau teks langsung
     Output : parsed requirements, acceptance criteria
     SKIP IF: input is plain text (no .docx/.pdf/.xlsx) ATAU scope = BUG FIX/SMALL EDIT

  3. scope-estimator   → via pm-agent
     Input  : brief + codebase context
     Output : scope classification
     SKIP IF: scope = BUG FIX/SMALL EDIT (scope already known from input)
```

Tunggu subagent yang di-spawn selesai.

### Start Telegram Bot Daemon (jika belum jalan)
```bash
if [ -f ".claude/telegram/manage.sh" ]; then
  bash .claude/telegram/manage.sh status | grep -q "running" || bash .claude/telegram/manage.sh start
fi
```

### Notify Pipeline Start
```bash
bash .claude/telegram/notify-pipeline-start.sh "$PIPELINE_TYPE" "$FEATURES_SUMMARY" "$WAVE_COUNT" 2>/dev/null || true
```

### Output Phase 0 → `docs/project-signal.md`

Gabungkan hasil ketiga subagent ke satu file:

```bash
cat > docs/project-signal.md << 'EOF'
# Project Signal
generated_at : [timestamp]

## Codebase Analysis
[dari codebase-probe]

## Requirements
[dari input-parser]

## Scope & Estimate
type         : [GREENFIELD / NEW FEATURE / BUG FIX / SMALL EDIT]
effort       : [S / M / L / XL]
risk_flags   : [list atau "none"]
EOF
```

---

### Phase 0C — Scope Completion Validation

Setelah semua Phase 0 agents selesai, SEBELUM Phase 1 (planning):

1. **Parse input** — extract semua requirements/tasks/bugs yang disebut user:
```
Input: "Fix login bug, update dashboard, and add export feature"
Extracted: [login bug, dashboard update, export feature] → 3 items
```
2. **Cross-check dengan analysis results**:
```
codebase-scout found:  login controller, dashboard component
brief-interpreter found: export feature spec

Matched:   login bug ✅, dashboard ✅, export ✅
Unmatched: (none)
```
3. Jika ada unmatched items:
```
JANGAN lanjut ke planning.
Spawn codebase-scout lagi dengan fokus ke unmatched items.
Atau tanyakan ke programmer: "Saya tidak menemukan [X] di codebase. Bisa jelaskan lebih detail?"
```
4. Jika semua matched → update docs/analysis-checkpoint.md:
```markdown
## Analysis Checkpoint
Input items: 3
Matched: 3/3
Unmatched: 0
Ready for planning: YES
```

**ATURAN:** Jika matched < total items → STOP. Jangan lanjut ke Phase 1.

---

### Phase 0-BUG: Tracer (hanya untuk BUG FIX)

Jika `scope_type = BUG FIX` dari project-signal.md:

```
→ tracer agent (model: sonnet)
  Input  : docs/project-signal.md (bug description + codebase context)
  Output : docs/trace-report.md (ranked hypotheses + verification steps)
```

Tracer output digunakan oleh fix-strategist sebagai basis diagnosis.
Jika tracer confidence > 70% → langsung ke targeted fix.
Jika tracer confidence ≤ 70% → eskalasi ke programmer via AskUserQuestion.

---

## PHASE 0B — Convention Scout + Design Direction (parallel)

### Design Mode Decision (hanya untuk EXISTING projects)

Jika scope_type != GREENFIELD DAN existing design terdeteksi di codebase-scout report:

Tanyakan ke programmer via AskUserQuestion:
```
"Existing design system detected:
  Colors: [dari codebase-scout report]
  Fonts: [dari codebase-scout report]
  Framework: [Tailwind/MUI/custom/etc]

Options:
  A) INHERIT — keep existing design, extend for new feature (recommended)
  B) UPGRADE — generate new design direction (will change existing look)
  C) SKIP — do not run design-director"
```

Pass jawaban ke design-director sebagai mode parameter.
Jika scope_type = GREENFIELD → skip pertanyaan, langsung FRESH mode.
Jika scope_type = BUG FIX atau SMALL EDIT → skip design-director entirely.

### Smart Phase 0B — Cache Check Sebelum Spawn

**Convention-scout cache check:**
```bash
CONV_FILE="docs/conventions.md"
SKIP_CONVENTION=false
if [ -f "$CONV_FILE" ]; then
  # Cek umur file (dalam hari)
  FILE_AGE=$(( ($(date +%s) - $(stat -c %Y "$CONV_FILE" 2>/dev/null || stat -f %m "$CONV_FILE" 2>/dev/null || echo 0)) / 86400 ))
  if [ "$FILE_AGE" -lt 7 ]; then
    SKIP_CONVENTION=true
    echo "convention-scout skipped — conventions.md still fresh (${FILE_AGE} days old)"
  fi
fi
```

Spawn subagents secara **parallel** (skip yang tidak perlu):

```
PARALLEL:
  1. convention-scout (SKIP jika conventions.md ada DAN < 7 hari)
     Input  : codebase analysis dari Phase 0
     Output : docs/conventions.md
              (coding standards, naming patterns, file structure conventions)

  2. design-direction
     Input  : brief interpretation + existing design-decisions.md
     Output : docs/design-direction.md
              (UI/UX direction, color, typography, component strategy)
```

### Output Phase 0B
- `docs/conventions.md` — enforced by all developer agents
- `docs/design-direction.md` — consumed by fe-developer and qa-tester

---

## PHASE 1 — Wave Planning

### Baca Pipeline Intelligence (jika ada)
```bash
cat docs/pipeline-intelligence.md 2>/dev/null | tail -30
```
Jika ada recommendations dari pipeline sebelumnya → teruskan ke wave-planner sebagai input tambahan untuk historical pattern analysis.

Panggil **wave-planner** dengan semua output dari Phase 0 dan 0B:

```
→ wave-planner
  Input  : docs/project-signal.md + docs/conventions.md + docs/design-direction.md
  Output : docs/wave-plan.md
```

Wave-planner mengklasifikasi request dan menghasilkan `docs/wave-plan.md` yang berisi:
- Daftar waves (Wave 1, Wave 2, ... Wave N)
- Setiap wave berisi list fitur/task yang bisa dikerjakan parallel
- Dependency antar waves (Wave 2 depends on Wave 1, dll)
- Per-fitur: scope, files, test plan, assigned role (BE/FE/both)

**wave-plan.md adalah kontrak eksekusi utama** — semua execution agent
membaca dari wave-plan.md untuk tahu apa yang harus dikerjakan.

### Buat draft pipeline-state.md

```bash
mkdir -p docs
cat > docs/pipeline-state.md << 'EOF'
# Pipeline State
branch        : TBD
base_branch   : TBD
type          : [dari project-signal.md]
repo_platform : [dari MANDATORY CHECK 1]
use_docker    : [YES / NO]
created_at    : [timestamp]
approved_at   : --

## Wave Progress
[generated from wave-plan.md]
EOF
```

---

## Phase 1.5: Planning Quality Gates (WAJIB untuk BUILD/NEW_FEATURE/GREENFIELD)

Setelah wave-plan.md ter-generate DAN SEBELUM present ke user untuk APPROVE:

1. Baca skill: `cat .claude/skills/pipeline-planning/SKILL.md`
2. Ikuti 3 gates sequential:
   - Gate 1: Deliberation + Pre-Mortem → output: docs/deliberation.md
   - Gate 2: Acceptance Criteria → output: docs/acceptance-criteria.md
   - Gate 3: Critic Challenge (max 2x loop) → output: docs/critic-planning-verdict.md
3. Jika Gate 3 verdict = GO atau GO-WITH-CONDITIONS (addressed) → lanjut ke APPROVE
4. Jika Gate 3 verdict = NO-GO setelah 2x loop → eskalasi ke user (opsi di skill file)
5. Jika user override → catat di deliberation.md, lanjut ke APPROVE

**SKIP Phase 1.5 untuk:**
- SMALL_EDIT — scope terlalu kecil
- BUG_FIX — tidak perlu architecture review
- DISCUSSION — belum ada plan untuk di-review

**JANGAN lanjut ke APPROVE tanpa Phase 1.5 selesai (untuk scope yang applicable).**

---

## APPROVE GATE — Single Approval

### Check Telegram for Remote Approve (opsional)
Sebelum tampilkan APPROVE gate ke terminal, cek apakah ada approve dari Telegram:
```bash
if [ -f ".claude/telegram/incoming-command.txt" ]; then
  TELEGRAM_CMD=$(cat .claude/telegram/incoming-command.txt 2>/dev/null)
  if [ "$TELEGRAM_CMD" = "APPROVE" ]; then
    rm -f .claude/telegram/incoming-command.txt
    echo "✅ Approved via Telegram"
    # Skip terminal approve, langsung lanjut
  fi
fi
```
Jika tidak ada approve dari Telegram → tetap tampilkan approve gate normal di terminal.

### Relay ALL Action Choices to Telegram

Setiap kali pipeline membutuhkan keputusan dari user (pilihan A/B/C, approve/reject, dll):
1. Tampilkan opsi di terminal (seperti biasa)
2. JUGA kirim ke Telegram:
```bash
bash .claude/telegram/notify-action-required.sh \
  "Pertanyaan atau situasi" \
  "A) Opsi pertama" \
  "B) Opsi kedua" \
  "C) Opsi ketiga"
```
3. Cek incoming-command.txt untuk response dari Telegram
4. Response pertama (terminal ATAU Telegram) yang masuk → dipakai

Ini berlaku untuk SEMUA decision points di pipeline:
- APPROVE gate (sudah ada)
- Post-review action choices (fix all / fix selective / skip)
- QA failure handling (retry / skip / known-issue)
- Merge conflict resolution choices
- Any other user decision point

Setelah wave-plan.md ter-generate, tampilkan summary dan tunggu satu APPROVE:

```
================================================================
ADAPTIVE WAVE ORCHESTRATOR — READY FOR APPROVAL
================================================================

Request   : [ringkasan 1-2 kalimat]
Type      : [dari project-signal.md]
Branch    : [nama branch yang akan dibuat]

WAVE PLAN (dari docs/wave-plan.md):
------------------------------------------------------------
Wave 1 — Foundation:
  [list fitur/task + assigned agent]

Wave 2 — Core Features:
  [list fitur/task + assigned agent]

Wave N — Polish & Integration:
  [list fitur/task + assigned agent]
------------------------------------------------------------

Files:
  MODIFY : [list]
  CREATE : [list]
  DELETE : [list jika ada]

Conventions : docs/conventions.md
Design      : docs/design-direction.md

Setelah APPROVE:
→ Pipeline eksekusi autonomous sampai PR selesai
→ Agent Teams dengan worktree isolation per wave
→ Tidak ada interrupt kecuali automated barrier

================================================================
Ketik APPROVE untuk mulai eksekusi.
Ketik REVISE: [bagian yang perlu diubah] untuk revisi.
================================================================
```

**STOP — Tunggu APPROVE atau REVISE dari programmer.**

Jika REVISE → re-run hanya agent yang relevan → update wave-plan.md → tampilkan ulang.
Jika APPROVE → lanjut ke Phase 2.

### POST-APPROVE: Compact + Initialize Wave State

**WAJIB sebelum mulai Wave 1:**

1. Buat wave-execution-state.md dari template:
```bash
cp docs/wave-execution-state.md.template docs/wave-execution-state.md 2>/dev/null || true
```

2. Populate file list dari wave-plan.md dan architecture-blueprint.md:
```bash
# Extract semua files yang akan dibuat per wave
# Update wave-execution-state.md dengan checklist per wave
```

3. **COMPACT CONTEXT** — ini kritis:
```
Saya akan compact context sekarang. Pertahankan HANYA:
- docs/wave-plan.md (wave execution plan)
- docs/wave-execution-state.md (progress tracker)
- docs/architecture-blueprint.md (file map)
- docs/technical-spec.md (feature specs)
- docs/conventions.md (coding standards)
- docs/design-direction.md (design rules)
- .env (port assignments)
- docs/docker-assessment.md (Docker vs host)

Buang:
- Seluruh conversation planning sebelum APPROVE
- Brief analysis detail
- Context analysis output (sudah tersimpan di docs/)
```

4. Notify:
```bash
bash .claude/telegram/notify-compact.sh "post-planning" "Wave 0"
```

---

## Phase 2.5 — Pre-Implementation Analysis Gate

Setelah APPROVE dan SEBELUM mulai coding:

1. **Review deliberation.md** — pastikan semua "Belum Dipahami" sudah resolved
2. **Review wave-plan.md** — untuk setiap wave:
   - Apakah developer punya SEMUA context yang dibutuhkan?
   - Apakah ada file yang harus dibaca tapi tidak ada di file-scope-contract?
   - Apakah ada dependency yang belum di-resolve?

3. **Write docs/pre-implementation-checklist.md:**
```markdown
## Pre-Implementation Checklist

### Per Feature
- Feature A: [nama]
  - [ ] All dependencies identified
  - [ ] All affected files listed in scope contract
  - [ ] Test strategy defined
  - [ ] No unresolved questions

- Feature B: [nama]
  - [ ] ...

### Global Checks
- [ ] Deliberation complete (no unresolved items)
- [ ] Scope 100% matched
- [ ] Wave dependencies correct
- [ ] No circular dependencies between features
```

4. **Jika ada unchecked items → resolve dulu, JANGAN mulai Phase 3**

---

## PHASE 2 — Foundation (GREENFIELD only)

Hanya dijalankan jika type = GREENFIELD. Skip untuk tipe lain.

```
Sequential:
  1. project-initializer → init framework + folder structure
  2. env-configurator    → setup docker-compose, .env, config files
  3. db-designer         → create schema + migrations
  4. Health Check        → verify all containers UP and accessible
```

Jika health check gagal → STOP, laporkan ke programmer.

---

## PHASE 3 — Wave Execution

Loop melalui setiap wave di `docs/wave-plan.md` secara sequential.
Dalam setiap wave, **spawn Agent Team** dengan worktree per teammate.

### Agent Coordination Rules di Wave Execution

**Sebelum spawn agents untuk wave, TENTUKAN coordination level:**

1. **Jika wave punya 2+ agents yang work on INTERCONNECTED files** (misal: BE buat models + FE buat templates yang import models, atau BE buat API + Docker buat config yang reference API):
   → Gunakan **Agent Teams** (direct communication enabled)
   → Buat **shared contract** sebelum spawn:
     ```markdown
     ## Shared Contract — Wave [N]
     
     ### File Interfaces
     - `src/models/product.py` → class Product with fields: id, name, price, sales_count
     - `src/config.py` → DATABASE_URL, FASTMOSS_API_KEY from env
     
     ### Dependencies
     - Docker agent WAJIB tunggu pyproject.toml selesai sebelum build
     - FE agent WAJIB tunggu models selesai sebelum import
     ```
   → Simpan contract di `docs/wave-N-contract.md`
   → Semua agents dalam wave BACA contract sebelum mulai

2. **Jika wave punya agents yang work on INDEPENDENT files** (misal: 2 BE agents yang masing-masing buat module terpisah tanpa shared dependency):
   → Gunakan **subagent** (lebih murah, tidak perlu coordinate)

3. **JANGAN PERNAH spawn 3+ agents parallel tanpa shared contract** — ini menghasilkan race condition

### Pre-generate QA Checklist (parallel with implementation waves)

Jika pipeline type = GREENFIELD atau NEW FEATURE, dan wave count >= 2:
- Spawn qa-checklist-generator di Wave 2 (bersamaan dengan developer agents)
- qa-checklist-generator membaca code-architect blueprint + wave-plan
- Output: docs/qa-checklist.md (ready sebelum Phase 4 review)
- Ini menghemat ~15-20K tokens + 30 detik di Phase 4 (tidak perlu generate dari scratch)

```bash
# Spawn parallel dengan Wave 2 developers
# qa-checklist-generator baca blueprint, generate TC stubs
# Saat Phase 4 dimulai, qa-checklist-runner langsung execute — tidak perlu generate
```

### Execution Loop

```
FOR each wave in wave-plan.md:

  1. Baca wave definition dari docs/wave-plan.md
  2. Spawn Agent Team untuk wave ini:
     - Setiap teammate mendapat worktree terisolasi
     - git-manager MODE E: create worktrees untuk setiap teammate
     - BE teammates → be-developer (worktree per fitur)
     - FE teammates → fe-developer (worktree per fitur)

  3. Tunggu semua teammates dalam wave selesai

  3b. **Parse Agent Output** (structured output):
      Setelah setiap agent selesai, parse YAML header dari output:
      ```bash
      STATUS=$(echo "$AGENT_OUTPUT" | sed -n '/^---$/,/^---$/p' | grep "^status:" | awk '{print $2}')
      ISSUES=$(echo "$AGENT_OUTPUT" | sed -n '/^---$/,/^---$/p' | grep "^issues_found:" | awk '{print $2}')
      TESTS=$(echo "$AGENT_OUTPUT" | sed -n '/^---$/,/^---$/p' | grep "^tests_pass:" | awk '{print $2}')
      ```

      **Jika status = "failed":**
      - Log failure ke wave-execution-state.md
      - Jika issues_found > 0 → route ke fix-strategist
      - Jika tests_pass = false → re-run tests, then route to fix

      **Jika status = "blocked":**
      - Eskalasi ke programmer via AskUserQuestion
      - Include agent name dan blocking reason

      **Jika status = "done":**
      - Continue to verification step

  3c. **Wave Output Verification** (sebelum merge):
      ```bash
      MISSING=0
      grep '^\- \[ \]' docs/wave-execution-state.md | sed 's/- \[ \] //' | while read FILE; do
        if [ ! -f "$FILE" ]; then
          echo "MISSING: $FILE"
          MISSING=$((MISSING + 1))
        fi
      done
      ```
      Jika MISSING > 0 → re-spawn hanya agent yang file-nya gagal.

  4. Auto-merge feature branches → develop
     - git-manager MODE D: sequential merge semua feature branches
     - Conflict detection: jika conflict → STOP, laporkan
     - Update docs/merge-plan.md dengan status per branch

  5. Health check setelah merge
     - Verify app masih berjalan setelah merge
     - Jika gagal → rollback merge terakhir, laporkan

  5b. Phase 3.N.QA: WAVE QA GATE (MANDATORY — wajib lulus sebelum wave berikutnya)
      - Orchestrator spawn qa-tester dengan mode WAVE-SCOPED:
        * wave=N
        * list fitur Wave N
        * cross-wave=true jika N > 1
      - qa-tester jalankan:
        * Unit tests untuk fitur Wave N
        * Integration tests Wave N endpoints/UI
        * Cross-wave integration (jika N > 1): auth/data/state flow Wave 1..N-1 ↔ Wave N
      - Output: docs/qa-wave-N.md
      - Verdict FAIL:
        * Spawn fix-strategist (read qa-wave-N.md findings)
        * Spawn developer untuk fix (ikuti fix-ledger)
        * Re-run Wave QA Gate (max 2 re-attempts)
        * Jika masih fail setelah 2x → HALT pipeline, report ke user, JANGAN proceed
      - Verdict PASS:
        * Log "Wave N QA Gate: PASS" ke pipeline-state.md
        * Proceed ke wave berikutnya

  6. Update wave progress di pipeline-state.md (include Wave QA Gate verdict)

NEXT wave
```

### Agent Team Configuration per Wave

Setiap wave di wave-plan.md mendefinisikan:
- Jumlah teammates yang dibutuhkan
- Assignment per teammate (fitur mana, files mana)
- Dependencies intra-wave (jika ada)

**Spawn Agent Team** dengan instruksi:
- "Baca docs/agent-context.md untuk stack, scope, dan convention flags."
- "Baca docs/wave-plan.md untuk assignment kamu di wave [N]."
- "Kamu bekerja di worktree terisolasi. Jangan sentuh file di luar assignment."

### Auto-merge feature → develop

Setelah semua teammates dalam satu wave selesai:
1. git-manager MODE D melakukan sequential merge ke develop
2. Setiap feature branch di-merge satu per satu
3. Jika conflict terdeteksi → pause, resolve, lanjut
4. Update merge-plan.md dengan hasil merge

### WAVE TRANSITION PROTOCOL (jalankan antara setiap wave)

Setelah Wave [N] selesai:

1. **Update wave-execution-state.md**: tandai wave = completed
2. **Run context monitor**:
```bash
bash .claude/scripts/context-monitor.sh .
```

3. **Notify wave completion**:
```bash
CREATED=$(grep -c '\[x\]' docs/wave-execution-state.md)
TOTAL=$(grep -c '\[ \]\|\[x\]' docs/wave-execution-state.md)
bash .claude/telegram/notify-wave-complete.sh [N] [total_waves] "[wave_name]" "$CREATED" "$TOTAL"
```

4. **Cek context pressure**:
Jika context monitor recommendation = "compact-now" ATAU kamu merasa context berat:
```bash
bash .claude/telegram/notify-context-pressure.sh [N] "$CREATED" "$TOTAL"
```

5. **COMPACT CONTEXT antar wave**:
```
Compact sebelum Wave [N+1]. Pertahankan:
- docs/wave-execution-state.md (progress — file checklist)
- docs/wave-plan.md (remaining waves)
- docs/conventions.md + docs/design-direction.md
- .env
Buang: semua detail Wave [N] implementation. File sudah ditulis ke disk.
```

6. **Start next wave** dari wave-execution-state.md — hanya files yang masih [ ].

### Phase 3.post: Update Knowledge Graph
Jika graphify tersedia:
```bash
command -v graphify &>/dev/null && graphify update . 2>/dev/null || true
```
Code baru dari wave execution di-capture ke graph sebelum QA.

---

## Phase 4: Pre-QA Setup

Setelah wave execution selesai, SEBELUM QA dimulai.
Baca dari pipeline-verification/SKILL.md Phase V1 dan V2 SAJA.

### 4.1 Environment Collection (dari Verification V1)
- Scan .env.example, docker-compose.yml untuk kebutuhan config
- Kategorikan: bisa di-generate vs butuh dari user
- Minta ke user HANYA yang wajib untuk boot (gradual — jangan semua sekaligus)
- Kirim reminder via Telegram jika user tidak respond

### 4.2 Boot + Health Check (dari Verification V2)
- `docker compose up -d --build`
- Health check semua services (timeout 120 detik)
- Jika gagal boot → cek logs → coba fix sendiri → jika masih gagal, minta bantuan user

**Setelah Phase 4 selesai:** App running, healthy, siap di-test.

---

## Phase 5: Final QA (Integration Focus — Lighter)

> Karena **per-wave QA sudah cover unit + integration + cross-wave per scope** (Phase 3.N.QA), Phase 5 berubah fokus. **Tidak perlu re-run per-feature unit tests.**

Baca skill: `cat .claude/skills/qa-orchestration/SKILL.md`

**Apa yang di-SKIP di Phase 5** (sudah di-cover per wave):
- Re-running per-feature unit tests
- Re-running per-feature integration tests
- Per-wave cross-wave integration (sudah lewat Wave QA Gate)

**Apa yang FOCUS di Phase 5:**
| Step | Agent | Purpose | Speed |
|------|-------|---------|-------|
| 1 | qa-tester | Full E2E user flows yang span SEMUA waves | Medium |
| 2 | qa-checklist-runner | Deterministic TC execution (spec compliance) | Medium |
| 3 | user-simulator | Cross-role testing (admin vs user vs guest) | Slow |
| 4 | feature-auditor | Feature completeness audit vs original brief | Fast |

**Re-loop:** Gagal → developer fix → re-run dari step yang gagal. Max 3x total.

### Phase 5.3: Adversarial + Spec Compliance (MANDATORY)

Setelah E2E functional QA pass:
1. Spawn `qa-tester` dengan flag `--adversarial`
2. qa-tester jalankan Adversarial Testing (A1-A4) across **entire app** (input attacks, state attacks, data shape, auth/rbac)
3. Spec Compliance (SC1-SC5) against original brief
4. Output ke `docs/qa-report.md`
5. Jika ada FAIL → masuk ke fix queue (same as functional failures)
6. JANGAN lanjut ke Phase 6 kalau ada Critical adversarial failures (XSS, SQL injection pass through)

### Phase 5.post: QA Report Aggregation

Setelah semua per-wave + final QA selesai:
1. Spawn `doc-updater` dengan instruksi: **"aggregate QA reports"**
2. doc-updater scan `docs/qa-wave-*.md` + `docs/qa-report.md`
3. Generate `docs/qa-summary.md` dengan per-wave results + final QA + total test coverage
4. qa-summary.md di-inject ke delivery report (Phase 6)

### Phase 5.post: Final Graph Update
Jika graphify tersedia:
```bash
command -v graphify &>/dev/null && graphify update . 2>/dev/null || true
```
Final state setelah semua fixes — graph yang akan di-commit dengan PR.

---

## Phase 6: Final Delivery

Setelah semua waves selesai, spawn **Agent Team** dengan 4 reviewer parallel:

```
PARALLEL (Agent Team — 4 reviewers):
  1. code-quality reviewer  → code-reviewer agent (logic + architecture)
  2. security reviewer      → security-check agent (config + rules)
  3. user-sim reviewer      → user-simulator (end-to-end flows)
  4. qa-checklist reviewer  → qa-checklist-runner (systematic test execution)
```

Tunggu semua 4 reviewer selesai.

### Aggregate Review Results

Kumpulkan semua findings ke satu report. Jika ada critical issues:

#### POST-REVIEW FIX — via Fix Strategist (WAJIB)

Setelah code-reviewer atau qa-tester menemukan issues:

**SELALU delegate fix — orchestrator TIDAK PERNAH menulis application code.**

### Fix Cycle — via Fix Strategist (WAJIB)

1. **Spawn fix-strategist** (sonnet) dengan review findings
   - fix-strategist menganalisis SETIAP finding: root cause hypothesis, fix strategy, target files
   - fix-strategist writes strategy ke docs/fix-ledger.md
   - fix-strategist determines escalation level per finding

2. **Spawn be/fe-developer** DENGAN strategy dari fix-ledger.md
   - Developer menerima SPESIFIK instruksi: file mana, apa yang harus diubah, pendekatan apa
   - Developer WAJIB ikuti strategy — JANGAN improvisasi
   - Developer WAJIB ikuti "Fix Protocol — Root Cause First" di agent-protocol-base
   - Untuk fix kecil (≤ 10 lines): spawn developer dengan model haiku (hemat token)
   - Untuk fix besar (> 10 lines): spawn developer dengan model sonnet (normal)

3. **Post-Fix Regression Check** (WAJIB setelah setiap fix cycle)
   - Re-run SEMUA test (bukan hanya test terkait fix)
   - Jika test yang SEBELUMNYA PASS sekarang FAIL → fix menyebabkan regression
   - Jika regression → REVERT fix, kembali ke fix-strategist dengan info baru
   - Developer HARUS laporkan di structured output: `regression_check: pass|fail`

4. **Max fix cycles: 3** — jika setelah 3 cycle masih ada issues, STOP dan eskalasi ke user

ALASAN perubahan ini: tanpa fix-strategist di loop, developer langsung "tebak dan coba"
yang menyebabkan back-and-forth dan regression. Fix-strategist memastikan setiap fix
punya strategy yang jelas SEBELUM developer mulai coding.

**ATURAN KERAS: Orchestrator TIDAK PERNAH menggunakan Edit atau Write tool pada file application code.**
Yang BOLEH di-edit langsung oleh orchestrator:
- docs/*.md (pipeline state, deliberation, analysis)
- .claude/memory/*.md (lessons, memory)
- NOTHING ELSE.

### CRP Rule 6: Compact Between Fix Iterations

Jika fix cycle ke-2 atau lebih diperlukan (artinya fix pertama tidak fully resolved):

1. **Sebelum re-review, trigger compact:**
   ```
   Compact sebelum fix iteration [N]. Pertahankan:
   - docs/code-review-report.md (findings yang belum resolved)
   - docs/wave-execution-state.md (progress tracker)
   - docs/fix-trace.md (jika ada — tracking fix attempts)
   Buang: conversation history dari fix iteration sebelumnya.
   ```

2. **Log:** "CRP Rule 6: compact after fix iteration [N-1], before re-review"

3. **Alasan:** Fix cycles accumulate context rapidly (~50K per iteration).
   Tanpa compact, fix cycle ke-3 bisa mendekati context limit.
   SIM-08 menunjukkan context death di ~720K tanpa compact — ini mencegahnya.

### Health Gate Final

```bash
# Docker mode
docker compose ps | grep -E "Up|running" | wc -l

# Non-Docker mode
curl -s -o /dev/null -w "%{http_code}" http://localhost:$FE_PORT
curl -s -o /dev/null -w "%{http_code}" http://localhost:$BE_PORT
```

Semua service harus UP sebelum PR creation.

---

### Critic Quality Gate — WAJIB sebelum PR

Setelah aggregate review results DAN fix cycles selesai, spawn **critic agent**:

```
→ critic agent (model: opus)
  Input  : docs/code-review-report.md, docs/security-report.md,
           docs/user-simulation-report.md, docs/qa-checklist-report.md
  Output : docs/critic-report.md dengan GO/NO-GO verdict
```

### Parse Critic Verdict (structured output)
```bash
VERDICT=$(grep "^verdict:" docs/critic-report.md | awk '{print $2}')
SCORE=$(grep "^score:" docs/critic-report.md | awk '{print $2}')
CRITICAL=$(grep "^critical_unresolved:" docs/critic-report.md | awk '{print $2}')
```

**Jika VERDICT = "GO":** → Lanjut ke PR Creation
**Jika VERDICT = "NO-GO":** → Kembali ke fix cycle (count terhadap max 3)
**Jika SCORE >= 60 DAN CRITICAL = 0:** → GO with caveats, include di PR description

---

### Doc-updater Gate — Skip jika perubahan kecil

Sebelum spawn doc-updater (biasanya setelah wave terakhir):

```bash
# Hitung total lines changed
DIFF_LINES=$(git diff --stat develop 2>/dev/null | tail -1 | grep -oE '[0-9]+' | head -1)
DIFF_LINES=${DIFF_LINES:-0}

# Cek apakah ada file baru
NEW_FILES=$(git diff --name-status develop 2>/dev/null | grep -c "^A" || echo "0")

echo "Doc-updater gate: $DIFF_LINES lines changed, $NEW_FILES new files"
```

**JIKA DIFF_LINES < 20 DAN NEW_FILES = 0:**
- SKIP doc-updater — perubahan terlalu kecil untuk justify doc update
- Log: "doc-updater skipped — diff too small ($DIFF_LINES lines, 0 new files)"

**JIKA DIFF_LINES >= 20 ATAU NEW_FILES > 0:**
- Spawn doc-updater seperti biasa

---

### Parallel Post-Review Actions

Setelah critic verdict = GO, spawn secara **parallel** (bukan sequential):

```
PARALLEL (jika doc-updater tidak di-skip oleh gate):
  1. doc-updater   → sync docs dengan code changes
  2. pr-creator    → create PR dari develop → main

Alasan: doc-updater menulis ke docs/, pr-creator membaca git log.
Mereka tidak conflict — bisa jalan bersamaan. Saves ~30 detik.
```

**Retro-agent ASYNC** (non-blocking, background):
Jika pipeline counter mencapai retro_trigger_at:
- Spawn retro-agent di background SETELAH PR creation selesai
- Retro-agent tidak blocking — PR sudah dibuat, pipeline sudah selesai
- Log: "retro-agent spawned async (non-blocking)"

### 6.1 Generate Delivery Report (WAJIB sebelum PR)

Baca skill: `cat .claude/skills/pipeline-delivery/SKILL.md`
Ikuti steps 1-4 untuk generate report + chat message + Telegram notification.
Output: `docs/delivery-report.md`

### 6.2 User Guidance Message (WAJIB sebelum PR)

Setelah critic verdict = GO, SEBELUM PR creation, kirim message ke user:

```
Semua selesai dan sudah di-test.

**Aplikasi sudah running dan ready:**
- Frontend: http://localhost:[FE_PORT]
- Backend API: http://localhost:[APP_PORT]
- API Docs: http://localhost:[APP_PORT]/api/docs (jika ada)

**Tidak perlu setup apapun** — environment sudah di-configure, services sudah running.

**Login credentials:**
- [role]: [email] / [password atau "lihat .env"]

**Yang sudah di-verify:**
- Automated tests: [X]/[Y] pass
- Checklist TCs: [X]/[Y] pass
- Browser flows: [X]/[Y] pass
- Feature completeness: [X]%
- Fix loops: [N]/3 used

**Jika ingin re-verify setelah perubahan manual:**
`/verify`

Mau saya lanjut ke PR creation?
```

### 6.3 Revision Guard

Jika user minta fitur baru SEBELUM confirm PR:
→ Warn: "Test dulu yang ada sebelum tambah fitur baru"
→ Opsi: test dulu (recommended) atau langsung tambah fitur
→ Lihat Revision Guard di CLAUDE.md Orchestrator Rules untuk detail

### 6.4 PR Creation — develop → main

```
→ pr-creator (bisa parallel dengan doc-updater)
  Source : develop
  Target : main
  Body   : auto-generated changelog dari wave-plan.md + git log
```

**ATURAN MUTLAK: PR hanya DIBUAT, NEVER merge to main.**
Programmer review dan merge sendiri di GitHub/GitLab.

PR description wajib include:
- Wave execution summary (dari wave-plan.md)
- Changelog auto-generated dari commit history
- Link ke test reports dan review findings
- Link ke docs/delivery-report.md

---

### Post-Pipeline: Update Project Memory

Setelah pipeline selesai (PR created atau stopped):

```bash
DATE=$(date '+%Y-%m-%d %H:%M')
PIPELINE_TYPE=$(grep "^type" docs/project-signal.md | cut -d: -f2 | xargs)
WAVE_COUNT=$(grep -c "^## Wave" docs/wave-plan.md 2>/dev/null || echo "0")

cat >> .claude/memory/project-memory.md << MEMEOF

### $DATE — Pipeline: $PIPELINE_TYPE
- Waves: $WAVE_COUNT
- Branch: $(git branch --show-current)
- Result: [success/partial/failed]
MEMEOF
```
