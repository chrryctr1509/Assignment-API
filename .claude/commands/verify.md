# /verify — Smart Verification

Jalankan verification pipeline dengan **awareness** terhadap QA yang sudah dilakukan (per-wave QA dari Brief 23, qa-summary, verification state). Hindari re-run test yang sudah ter-cover.

---

## Mode Detection

Saat `/verify` dipanggil, orchestrator cek state QA yang sudah ada:

```bash
# 1. Cek per-wave QA results (Brief 23)
WAVE_QA_COUNT=$(ls docs/qa-wave-*.md 2>/dev/null | wc -l)

# 2. Cek QA summary (Phase 5.post doc-updater aggregation)
QA_SUMMARY_EXISTS="false"
QA_SUMMARY_FRESH="false"
if [ -f "docs/qa-summary.md" ]; then
  QA_SUMMARY_EXISTS="true"
  # Fresh jika dibuat < 2 jam yang lalu
  SUMMARY_AGE=$(find docs/qa-summary.md -mmin -120 2>/dev/null | wc -l)
  [ "$SUMMARY_AGE" -gt 0 ] && QA_SUMMARY_FRESH="true"
fi

# 3. Cek verification state
VERIFICATION_STATE="none"
if [ -f "docs/verification-state.md" ]; then
  VERIFICATION_STATE=$(grep "^status:" docs/verification-state.md | awk '{print $2}')
fi

# 4. Cek qa-orchestration state
QA_ORCH_STATE="none"
if [ -f "docs/qa-orchestration-state.md" ]; then
  QA_ORCH_STATE=$(grep "^status:" docs/qa-orchestration-state.md | awk '{print $2}')
fi
```

---

## Routing Logic

### `/verify` (no flags — smart mode)

```
IF qa-orchestration-state.md exists AND status = running:
  → Resume QA orchestration dari step terakhir
  → "Resuming QA dari step [N]..."

ELIF qa-summary.md exists AND fresh (<2 jam):
  → SKIP V1-V4. Hanya jalankan:
    - V5: Feature audit (re-check completeness vs brief)
    - V6: Re-loop jika fail
  → "QA summary masih fresh. Running feature audit + re-loop only."

ELIF wave QA reports exist (docs/qa-wave-*.md):
  → SKIP unit test per-feature (sudah di-cover per wave)
  → Jalankan:
    - V1-V2: Env + boot + health (always, karena env bisa berubah)
    - V4: Browser testing (visual verification)
    - V5: Feature audit
    - V6: Re-loop
  → SKIP V3 yang overlap dengan per-wave unit tests
  → "Per-wave QA detected. Skipping covered tests, running V1-V2, V4-V6."

ELSE (no prior QA):
  → Jalankan FULL V1-V6
  → "No prior QA detected. Running full verification."
```

### `/verify --full` (force full)

Ignore semua cached QA. Jalankan V1-V6 lengkap.
**Gunakan saat:** user tidak percaya cached results, atau setelah major manual changes.

### `/verify --skip-boot` (skip env/boot)

Skip V1-V2. Mulai dari V3.
**Gunakan saat:** app sudah running, user hanya mau re-verify features.

### `/verify --wave N` (wave-specific)

Re-run QA HANYA untuk Wave N:
1. Baca `docs/wave-plan.md` → extract fitur list Wave N
2. Spawn qa-tester WAVE-SCOPED (mode dari Brief 23) untuk Wave N
3. Output update `docs/qa-wave-N.md`
4. Jika cross-wave flag → juga test integration Wave N ↔ waves lain

**Gunakan saat:** user fix manual di area Wave N, mau re-verify hanya wave itu.

### `/verify --adversarial` (adversarial only)

Skip functional tests. Jalankan HANYA adversarial testing:
- Input validation attacks
- State & flow attacks
- Data shape attacks
- Concurrent attacks

**Gunakan saat:** functional sudah pass, mau stress-test robustness.

---

## Behavior

1. Detect mode berdasarkan flags dan existing QA state
2. Baca `cat .claude/skills/pipeline-verification/SKILL.md` untuk V1-V6 details
3. Jalankan phases sesuai routing logic di atas
4. Update `docs/verification-state.md` setelah selesai

---

## Usage

```
/verify                 # Smart — skip yang sudah di-cover
/verify --full          # Force full V1-V6
/verify --skip-boot     # Skip V1-V2
/verify --wave 2        # Re-verify Wave 2 saja
/verify --adversarial   # Adversarial testing only
```
