# Pipeline: BUG_FIX

Skill ini berisi shortcut pipeline untuk mode BUG_FIX.
Skip brief-reader, pm-agent, convention-scout, code-architect, design-director, wave-planner.
Alasan: bug fix tidak perlu planning atau convention analysis — langsung diagnosa dan fix.

Urutan: Phase 0 (minimal) → Tracer → Fix Strategy → Developer → Post-Fix Verification → Review → Critic → PR

---

## Pre-Pipeline: Verify Scope dengan User

Sebelum mulai pipeline, TAMPILKAN ke user:
```
Saya akan jalankan BUG_FIX pipeline untuk: [ringkasan bug]
- Estimated effort: [S/M]
- Pipeline: Codebase Scout → Tracer → Fix Strategy → Developer → Review → PR
Confirm? [Proceed / Discuss first]
```

**Jika user bilang "Discuss first"** → route ke pipeline-discussion/SKILL.md
**Jika user confirm** → lanjut ke pipeline
**JANGAN mulai pipeline tanpa explicit confirmation**

---

### ⚠️ DELEGATION CHECKPOINT — BUG_FIX
Bug fix tetap WAJIB delegate ke developer agent.
Orchestrator diagnosa via tracer → strategy via fix-strategist → developer yang fix.
JANGAN langsung edit code meskipun fix-nya "obvious" atau "satu baris".

Jika scope_type = BUG FIX dari /start classification:

Skip: brief-reader, brief-interpreter, pm-agent, convention-scout, code-architect, design-director, wave-planner.
Alasan: bug fix tidak perlu planning atau convention analysis — langsung diagnosa dan fix.

1. **Phase 0 (minimal context):**
   - Spawn codebase-scout (haiku) → identifikasi area kode yang relevan
   - JANGAN spawn brief-reader, pm-agent, convention-scout

2. **Phase 0-BUG (diagnosis):**
   - Spawn tracer (sonnet) → ranked hypotheses + verification steps
   - Jika tracer confidence > 70% → langsung ke fix
   - Jika tracer confidence ≤ 70% → eskalasi ke programmer

3. **Phase 3 (fix):**
   - Spawn be-developer ATAU fe-developer (sonnet) → targeted fix di file yang teridentifikasi
   - JANGAN buat wave-plan — fix langsung di branch aktif
   - Commit: `fix(scope): deskripsi`

4. **Post-Fix Verification (MANDATORY):**
   - Lihat section "Post-Fix Verification" di bawah

5. **Phase 4 (review):**
   - Spawn code-reviewer (opus, scope-aware) → review hanya file yang diubah
   - Spawn critic (opus, quick) → GO/NO-GO
   - Jika NO-GO → 1 fix cycle, lalu re-review

6. **PR:**
   - Spawn pr-creator (haiku)

Skip: Phase 0B, Phase 1, Phase 2, APPROVE gate, wave planning.
Total agents: ~6 (vs ~19 untuk full pipeline) → **~60% token savings**

---

## Post-Fix Verification (MANDATORY)

Setelah developer fix selesai, JANGAN langsung commit/PR. Verification dulu.

### Step 1: Developer Rebuild + Self-Test (WAJIB — selalu jalan)

Developer agent HARUS (ini sudah ada di agent file mereka):
1. Rebuild service yang relevan (`docker compose restart/up --build`)
2. Verify service healthy
3. Jalankan self-test checklist
4. Output YAML dengan `self_test: passed/skipped`, `service_rebuilt: true/false`

**Orchestrator check:** Sebelum lanjut, verify developer output:
- `self_test: passed` → lanjut
- `self_test: skipped` → catat alasan, lanjut dengan warning
- `self_test: failed` → route balik ke developer, fix dulu

### Step 2: Scope Check

Determine apakah fix ini kecil atau besar:

```bash
# Hitung files yang berubah
CHANGED_FILES=$(git diff --name-only HEAD~1 | wc -l)

# Hitung services yang terdampak
SERVICES_AFFECTED=0
git diff --name-only HEAD~1 | grep -q "backend/" && SERVICES_AFFECTED=$((SERVICES_AFFECTED+1))
git diff --name-only HEAD~1 | grep -q "frontend/" && SERVICES_AFFECTED=$((SERVICES_AFFECTED+1))
git diff --name-only HEAD~1 | grep -qE "docker-compose|nginx|infra/" && SERVICES_AFFECTED=$((SERVICES_AFFECTED+1))
git diff --name-only HEAD~1 | grep -qE "database/|migrations/" && SERVICES_AFFECTED=$((SERVICES_AFFECTED+1))

echo "Changed files: $CHANGED_FILES"
echo "Services affected: $SERVICES_AFFECTED"
```

**KECIL:** `CHANGED_FILES <= 3` DAN `SERVICES_AFFECTED <= 1`
→ Skip ke Step 4 (User Guidance)

**BESAR:** `CHANGED_FILES > 3` ATAU `SERVICES_AFFECTED > 1`
→ Lanjut ke Step 3 (Automated Tests)

### Step 3: Automated Tests (HANYA untuk fix besar)

Spawn `qa-tester` dengan mode SCOPE-AWARE (bukan FULL):
```
Jalankan tests yang TERKAIT dengan files yang berubah.
Mode: SCOPE-AWARE (bukan full test suite)
Report ke docs/test-report.md
```

**Pass:** `tests_pass: true` → lanjut ke Step 4
**Fail:** route ke developer → fix → rebuild → re-test

**Max 2x loop** (bukan 3x seperti BUILD mode — fix harus cepat)

Setelah 2x masih fail:
```
Automated tests masih gagal setelah 2x fix attempt.
Lanjut ke user guidance dengan warning.
```

### Step 3B: Frontend Console Check (HANYA jika fix menyentuh frontend)

```bash
# Cek apakah ada frontend changes
git diff --name-only HEAD~1 | grep -q "frontend/" && FRONTEND_CHANGED=true || FRONTEND_CHANGED=false
```

Jika `FRONTEND_CHANGED=true`:
- Jika ada browser access (GStack Browse / Playwright MCP):
  - Buka halaman yang terdampak
  - Cek console → TIDAK BOLEH ada error merah
  - Screenshot sebagai evidence
- Jika TIDAK ada browser access:
  - `docker compose exec frontend npm run build` — minimal build check
  - Catat: `browser_check: skipped — no browser access`

### Step 4: User Guidance (WAJIB — selalu jalan)

Setelah fix verified (atau scope kecil), WAJIB kasih tahu user:

```
Fix applied and verified.

**Root cause:** [1 kalimat kenapa bug terjadi]
**What changed:** [files yang berubah, perubahan apa]

**Untuk melihat perubahan:**
1. [rebuild/restart command — ATAU "sudah di-rebuild otomatis"]
2. Buka [URL spesifik yang terdampak]
3. Test: [langkah spesifik untuk verify fix]

**Side effects:** [apakah ada hal lain yang bisa terdampak — atau "tidak ada"]
```

**Cara determine rebuild command:**

| File berubah | Command |
|-------------|---------|
| backend/** (volume mount) | Sudah auto-reload, cukup refresh |
| backend/** (no volume) | `docker compose up --build backend` |
| frontend/** (dev server) | Sudah auto-reload via hot reload |
| frontend/** (no dev server) | `docker compose up --build frontend` |
| docker-compose.yml | `docker compose up -d --build` |
| database/migrations/** | `docker compose exec backend alembic upgrade head` |
| nginx/** | `docker compose restart nginx` |

**Detect volume mount:**
```bash
docker compose config | grep -A10 "[service]:" | grep -q "volumes:" && echo "HOT_RELOAD" || echo "NEEDS_REBUILD"
```

### Commit + Push (setelah user guidance)

Setelah user guidance dikirim:
1. Commit semua changes (jika belum di-commit oleh developer)
2. Push ke remote
3. Create/update MR jika ada

**JANGAN commit + push SEBELUM user guidance.** User harus tahu dulu apa yang berubah.
