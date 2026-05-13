# Pipeline: Post-Pipeline

Wajib dijalankan setelah pipeline selesai dan PR dibuat.
Update pipeline intelligence, docs refresh, timestamp semua docs.
NON-NEGOTIABLE — jangan skip meskipun context hampir penuh.

---

## POST-PIPELINE: Update Pipeline Intelligence

Setelah semua waves selesai dan PR dibuat:

### Notify Pipeline Complete
```bash
bash .claude/telegram/notify-pipeline-finish.sh "$PR_URL" "$PIPELINE_DURATION" "$FEATURES_SUMMARY" 2>/dev/null || true
```

### Notify PR Ready
```bash
bash .claude/telegram/notify-pr-ready.sh "$PR_URL" "$BRANCH_NAME" "$PR_TITLE" 2>/dev/null || true
```

### 1. Update Pipeline Intelligence
Baca lalu update `docs/pipeline-intelligence.md` (buat dari template `docs/pipeline-intelligence.md.template` jika belum ada).
Tulis/append pipeline-intelligence.md dengan entry baru untuk pipeline run ini dengan data:
- Duration per wave
- Merge conflicts yang terjadi
- Fix attempts dari fix-ledger
- Hook violations dari hook-log.txt
- Patterns yang terdeteksi
- Recommendations untuk next run

### 2. Increment Pipeline Counter
```bash
COUNTER=$(grep "^current:" docs/pipeline-intelligence.md | awk '{print $2}')
NEW_COUNTER=$((COUNTER + 1))
sed -i "s/^current: .*/current: $NEW_COUNTER/" docs/pipeline-intelligence.md
```

### 3. Check Retro Trigger (setiap 5 pipeline)
```bash
COUNTER=$(grep "^current:" docs/pipeline-intelligence.md | awk '{print $2}')
TRIGGER=$(grep "^retro_trigger_at:" docs/pipeline-intelligence.md | awk '{print $2}')
if [ "$COUNTER" -ge "$TRIGGER" ]; then
  echo "RETRO_TRIGGER"
fi
```

Jika `RETRO_TRIGGER` → panggil retro-agent untuk retrospective analysis, lalu reset counter:
```bash
sed -i "s/^current: .*/current: 0/" docs/pipeline-intelligence.md
```

---

## Phase 5 — Post-Pipeline Docs Refresh (WAJIB sebelum session end)

Setelah PR created dan SEBELUM session berakhir, update semua context docs
agar pipeline berikutnya tidak perlu scan ulang:

1. **Update project-context.md:**
   - Spawn codebase-scout (haiku) dengan mode REFRESH
   - Input: list file yang dibuat/modified di pipeline ini (dari git diff)
   - Output: updated project-context.md yang reflect state terkini
   - JANGAN scan seluruh project — hanya update section yang berubah

2. **Update conventions.md:**
   - Jika ada convention baru yang ditemukan atau dipakai → append
   - Jika ada dependency baru (package.json, requirements.txt berubah) → update stack section

3. **Update agent-context.md:**
   - Fresh context package untuk pipeline berikutnya
   - Include: current stack, file structure summary, recent changes, active branch

4. **Update pipeline-intelligence.md:**
   - Append entry: timestamp, scope type, features built, issues found, fix rounds, duration
   - Ini jadi historical data untuk wave-planner dan retro-agent

4B. **Update project-memory.md:**
   - Baca `docs/pipeline-state.md` — ambil pipeline type, result, branch
   - Baca `docs/wave-execution-state.md` — ambil wave progress
   - Update `.claude/memory/project-memory.md` sections:

   ```bash
   cat > .claude/memory/project-memory.md << 'PMEOF'
   # Project Memory — Active Project State
   # Updated by orchestrator after each pipeline completion.

   ---

   ## Current State
   Last pipeline: $(date '+%Y-%m-%d') — [TYPE] — [RESULT]
   Branch: $(git branch --show-current)
   Wave progress: [N/M waves completed]
   Open issues: [count dari QA failures yang belum resolved]

   ---

   ## Environment Status
   Docker: [running/stopped/not-configured]
   Database: [engine dari docker-compose.yml] [status]
   Ports: [dari docker-compose.yml port mappings]
   Last health check: $(date '+%Y-%m-%d %H:%M')

   ---

   ## Pending Decisions
   [Dari docs/pipeline-state.md waiting_for field — jika ada]

   ---

   ## Pipeline History (last 5)
   | Date | Type | Features | Waves | Result |
   |------|------|----------|-------|--------|
   | [append row baru, keep max 5 rows terbaru] |
   PMEOF
   ```

   JANGAN overwrite jika sudah ada data — MERGE: append pipeline history row, update Current State dan Environment Status sections.

5. **Timestamp semua docs:**
   - Setiap doc yang di-update, tambah `last_updated: [timestamp]` di header
   - Ini dipakai oleh cache check di pipeline berikutnya

Jika context terlalu besar untuk Phase 5 → compact dulu, lalu update docs.
Phase 5 is NON-NEGOTIABLE — jangan skip meskipun context hampir penuh.
Jika perlu, Phase 5 jalan di session terpisah (/start refresh-docs).

---

## Step 6: Memory Consolidation Offer (Post-Pipeline)

Setelah PR dibuat, cek apakah pipeline ini menghasilkan lessons baru:

```bash
# Hitung lessons yang ditambahkan di session ini
# (lessons baru biasanya di paling bawah file)
TOTAL_LESSONS=$(grep -c "^### " .claude/memory/lessons.md 2>/dev/null || echo "0")
RECENT_LESSONS=$(grep -c "$(date '+%Y-%m-%d')" .claude/memory/lessons.md 2>/dev/null || echo "0")
# Juga count lessons dari agents (dari YAML outputs di session ini)
# Jika pipeline tadi punya developer agents yang tulis lessons, ini akan > 0
echo "Recent lessons dari pipeline: $RECENT_LESSONS"
LESSONS_LINES=$(wc -l < .claude/memory/lessons.md 2>/dev/null || echo "0")
```

**Offer ke developer jika SALAH SATU kondisi terpenuhi:**
1. `RECENT_LESSONS >= 2` — ada 2+ lessons baru dari pipeline ini
2. `LESSONS_LINES >= 150` — mendekati threshold (max 200)

**Cara offer (via terminal + Telegram):**

Di terminal:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 MEMORY CONSOLIDATION AVAILABLE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Pipeline ini menghasilkan [RECENT_LESSONS] lessons baru.
Total lessons: [TOTAL_LESSONS] ([LESSONS_LINES] baris)

Consolidate sekarang akan:
- Deduplicate entries serupa
- Resolve contradictions
- Prune entries lama jika > 200 baris
- Update CLAUDE.md conventions

[Y] Consolidate sekarang
[N] Skip — nightly cron akan handle
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Via Telegram (jika aktif):
```bash
bash .claude/telegram/notify-action-required.sh \
  "Pipeline selesai. $RECENT_LESSONS lessons baru. Memory: $LESSONS_LINES/200 baris." \
  "Y) Consolidate sekarang" \
  "N) Skip"
```

**Jika Y** → spawn consolidate-memory (haiku)
**Jika N** → skip, nightly cron handle
**Jika tidak ada response dalam 30 detik** → skip (non-blocking, pipeline sudah selesai)

**Jika TIDAK memenuhi kondisi offer** (0-1 lesson baru DAN < 150 baris) → skip tanpa offer, lanjut.
