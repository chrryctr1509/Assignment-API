# Consolidate Memory Skill

Consolidate and promote memory entries across the 3-tier memory system.
Schedule: nightly at 2am via cron, or invoke manually.

## When to Use
- Automatically via nightly cron schedule
- Manually after a productive session with many decisions
- When `recent-memory.md` grows beyond 50 entries

## Process

### Step 1: Read All Memory Layers

```bash
cat .claude/memory/recent-memory.md
cat .claude/memory/long-term-memory.md
cat .claude/memory/project-memory.md
cat .claude/memory/lessons.md
```

### Step 2: Prune Stale Entries from Recent Memory

Entries in `recent-memory.md` older than 48 hours → evaluate:
- If the pattern appeared 2+ times → PROMOTE to long-term-memory.md
- If it was a one-time decision → PRUNE (delete entry)
- If it references an ongoing issue → keep until resolved

```
How to determine age:
- Entry format includes date: ### [YYYY-MM-DD HH:MM]
- Current date comparison
- Mark pruned entries: Status: pruned
```

### Step 3: Promote Validated Patterns

Move confirmed patterns from recent-memory to long-term-memory:

**Promotion criteria (any of these):**
1. Same pattern observed 2+ times in recent-memory
2. User explicitly confirmed approach ("yes exactly", "perfect")
3. Fix that resolved a recurring error (check fix-ledger for matches)
4. Convention that was consistent across 3+ files in a pipeline

**Promotion format:**
```markdown
### [pattern-name]
Context: [when this applies]
Rule: [what to do]
Confirmed: [date promoted]
Source: [recent-memory entries that confirmed this]
```

### Step 4: Update Project Memory

Read `docs/pipeline-state.md` and `docs/wave-execution-state.md` if they exist.
Update `project-memory.md` with:
- Last pipeline result
- Current branch status
- Any open issues or pending decisions

### Step 5: Cross-Reference with Lessons (Auto-Resolve)

Check entries in `long-term-memory.md` against `lessons.md`:
- **Duplicate** → keep in lessons.md (source of truth for errors), remove from long-term-memory
- **Contradiction** → auto-resolve:
  1. Entry yang LEBIH BARU menang (cek timestamp/posisi di file — entry lebih bawah = lebih baru)
  2. Hapus entry yang lama/kontradiktif
  3. Log: "Contradiction resolved: [entry lama] removed, [entry baru] kept"
  4. Jika tidak bisa tentukan mana yang baru → flag for programmer review (jangan auto-resolve)

### Step 6: Update CLAUDE.md (if section markers exist)

If the project's `CLAUDE.md` has `<!-- BEGIN:conventions -->` markers:
- Read `long-term-memory.md` confirmed patterns
- Update the conventions section with newly confirmed patterns
- DO NOT overwrite content outside section markers

### Step 6B: Update CLAUDE.md fix-protocol Known Pitfalls

If the project's `CLAUDE.md` has `<!-- BEGIN:fix-protocol -->` markers:

```bash
# Check for fix failures in lessons
grep -B1 -A3 "❌" .claude/memory/lessons.md 2>/dev/null | head -40
```

Jika ada lessons dengan fix failure (`❌`):
1. Extract pattern: "Jangan [apa yang dicoba dan gagal] — lihat lesson [STACK:CONTEXT]"
2. Cari section `### Known Pitfalls` di antara fix-protocol markers
3. Append pitfall baru (skip jika sudah ada — cek duplikat berdasarkan lesson ID)
4. Format per entry: `- Jangan [action] — [kenapa gagal] (lesson [STACK:CONTEXT], [tanggal])`

Ini membuat fix-protocol BELAJAR dari kesalahan sebelumnya.
Hanya append, jangan hapus pitfalls existing.

### Step 7: Report

Output summary:
```
Memory Consolidation Report — [date]
- Entries pruned from recent: [N]
- Patterns promoted to long-term: [N]
- Project memory updated: yes/no
- CLAUDE.md conventions updated: yes/no
- CLAUDE.md fix-protocol pitfalls added: [N]
- Duplicates with lessons.md: [N]
- Contradictions flagged: [N]
```

## Memory Pruning Protocol (Inspired by autoDream)

Setiap kali consolidate-memory dijalankan, WAJIB lakukan pruning berikut SETELAH Step 7:

### Prune Step 1: Deduplicate lessons.md
Scan `lessons.md` untuk entries yang membahas ERROR YANG SAMA:
```bash
# Cari entries dengan keyword serupa
grep -n "^### " .claude/memory/lessons.md | sort -t: -k2
```
Jika ada 2+ entries tentang error yang sama (keyword match > 80%):
→ MERGE menjadi 1 entry yang paling lengkap (gabungkan solusi ✅ dan ❌)
→ Hapus entries duplikat
→ Log: "Deduplicated: merged [N] entries → 1"

### Prune Step 2: Eliminate Contradictions di lessons.md
Scan untuk entries dimana solusi `✅` di satu entry adalah solusi `❌` di entry lain:
```bash
# Extract semua solusi
grep -B2 -A1 "✅\|❌" .claude/memory/lessons.md
```
Jika ditemukan kontradiksi:
- Entry yang LEBIH BARU menang (entry lebih bawah di file = lebih baru)
- Update entry lama: hapus solusi yang kontradiktif, tambah note "Superseded by [entry baru]"
- Log: "Contradiction resolved: [entry lama] updated, [entry baru] is source of truth"

### Prune Step 3: Enforce Max Size — lessons.md
```bash
LINES=$(wc -l < .claude/memory/lessons.md)
MAX_LINES=200
```
Jika LINES > MAX_LINES:
1. Hitung entries: `ENTRY_COUNT=$(grep -c "^### " .claude/memory/lessons.md)`
2. Hapus entries TERLAMA (paling atas file) satu per satu sampai file <= MAX_LINES
3. JANGAN hapus entries yang:
   - Di-reference oleh pipeline terakhir (cek `project-memory.md` last entry)
   - Memiliki tag `pinned` atau `critical`
4. Log: "Pruned [N] old entries. lessons.md: [old_lines] → [new_lines] lines"

### Prune Step 4: Enforce Max Size — project-memory.md
```bash
LINES=$(wc -l < .claude/memory/project-memory.md)
MAX_LINES=100
```
Jika LINES > MAX_LINES:
1. Keep hanya 20 entries terbaru (paling bawah file)
2. Hapus entries lama di atas
3. Log: "Pruned project-memory.md to last 20 entries"

### Prune Step 5: Enforce Max Size — long-term-memory.md
```bash
LINES=$(wc -l < .claude/memory/long-term-memory.md 2>/dev/null)
MAX_LINES=150
```
Jika LINES > MAX_LINES:
1. Hapus patterns terlama yang TIDAK pernah di-reference di 5 pipeline terakhir
2. Log: "Pruned long-term-memory.md: [old_lines] → [new_lines] lines"

## Scheduling

### Trigger (5 cara):

**1. Nightly cron (existing — otomatis):**
```bash
/schedule create --name "consolidate-memory" --cron "0 2 * * *" --prompt "Run the consolidate-memory skill"
```

**2. Manual (existing):**
```
/consolidate-memory
```

**3. Post-pipeline offer (BARU):**
Setelah pipeline selesai dan PR dibuat, orchestrator OFFER ke developer jika:
- Ada 2+ lessons baru dari pipeline ini, ATAU
- lessons.md sudah >= 150 baris
Developer bisa accept (Y) atau skip (N). Jika skip, nightly cron handle.
Non-blocking: jika tidak ada response dalam 30 detik → skip.

**4. Pre-pipeline threshold offer (BARU):**
Saat `/start` dijalankan, orchestrator cek ukuran lessons.md:
- 150-200 baris → OFFER ke developer (Y/N)
- \> 200 baris → AUTO-TRIGGER (sudah critical, harus prune, tidak perlu offer)
- < 150 baris → skip, tidak perlu offer

**5. Threshold auto-trigger (BARU):**
Jika lessons.md > 200 baris saat `/start` → langsung trigger tanpa offer.
Ini safety net — seharusnya jarang terjadi kalau offer dan cron berjalan normal.
