# Pipeline: DISCUSSION

Skill ini berisi consultant mode — orchestrator menjadi advisor, bukan builder.
ZERO implementation. Hanya analysis, comparison, dan recommendation.

Urutan: D1 (Context) → D2 (Analysis) → D3 (Iterative Discussion) → D4 (Transition to Pipeline)

---

### Mode: DISCUSSION (consultant mode, bukan builder)

Jika scope = DISCUSSION:

**Orchestrator TIDAK mulai pipeline.** Orchestrator menjadi consultant.

#### Pre-D1: Acknowledge DISCUSSION Mode ke User

Sebelum mulai D1, inform user:
```
Input Anda terlihat eksplorasi. Saya masuk DISCUSSION mode.
Saya akan analisis context dulu, lalu kita diskusikan approach terbaik.
```

Lalu lanjut ke D1 — JANGAN tunggu response untuk ini, langsung proceed ke D1.

#### Phase D1: Understand Context

1. Spawn codebase-scout (haiku) → baca project state
   - Atau baca project-context.md jika fresh (< 7 hari)
2. Baca docs/pipeline-intelligence.md → history pipeline sebelumnya
3. Baca .claude/memory/lessons.md → known issues dan patterns
4. Baca .claude/memory/project-memory.md → project state

#### Phase D2: Present Analysis

Berdasarkan context, presentasikan ke user:
```markdown
## Project Analysis

### Current State
- Stack: [detected]
- Files: [count]
- Last pipeline: [date, scope, features]

### Areas for Improvement
1. [area] — [why, evidence dari codebase]
2. [area] — [why, evidence]
3. [area] — [why, evidence]

### Known Issues (dari lessons + pipeline history)
- [issue from lessons.md]
- [issue from pipeline-intelligence.md]

### Questions for You
- Which area is most important to your users?
- What's your timeline?
- Any constraints (budget, tech stack, team size)?
```

#### Phase D3: Iterative Discussion

Setelah present analysis, TUNGGU user response. Jangan proceed ke pipeline.

Untuk setiap user message selama DISCUSSION mode:

1. **Jika user tanya lebih detail** ("tell me more about X"):
   - Baca file yang relevan (controller, model, component terkait X)
   - Presentasikan options dengan pro/con
   - Estimasi effort per option (S/M/L/XL)
   - JANGAN mulai coding

2. **Jika user compare options** ("WebSocket vs SSE?"):
   - Presentasikan comparison table
   - Recommend berdasarkan project context
   - JANGAN mulai coding

3. **Jika user minta scope** ("how much work is this?"):
   - Estimasi: file count, wave count, pipeline type
   - Token/cost estimate berdasarkan pipeline type
   - JANGAN mulai coding

4. **Jika user tanya "what if"** ("what if we add caching?"):
   - Analyze impact pada codebase
   - List files yang perlu diubah
   - Identify risks
   - JANGAN mulai coding

5. **Jika user tanya teknologi/approach terbaru** ("is Redis better than Memcached now?"):
   - Gunakan WebSearch untuk cari benchmark/comparison data terbaru
   - Gunakan WebFetch untuk baca artikel/dokumentasi yang relevan
   - Presentasikan findings dengan source links
   - SELALU cite source (URL + tanggal)
   - JANGAN mulai coding

6. **Jika user kasih link referensi** ("check this: https://..."):
   - Gunakan WebFetch untuk baca konten link
   - Summarize dan relate ke project context
   - JANGAN gunakan curl — di-block oleh security-gate

7. **Jika diskusi butuh benchmark/comparison data**:
   - WebSearch cari data terbaru (benchmark results, library comparisons, adoption stats)
   - Presentasikan dalam tabel dengan source citation
   - Prioritaskan data dari 12 bulan terakhir

**ATURAN WEB RESEARCH:**
- SELALU cite source (URL) untuk setiap claim dari web
- JANGAN pakai curl atau Bash untuk HTTP requests — gunakan WebFetch/WebSearch
- Jika WebFetch gagal → inform user, jangan fabricate data
- Web research hanya di DISCUSSION mode — JANGAN di pipeline execution

#### Phase D4: Transition to Pipeline (CRITICAL — JANGAN SHORTCUT)

User signals readiness dengan:
- "OK, let's do it" / "go ahead" / "proceed" / "build it" / "start" / "implement"
- "OK" (standalone confirmation setelah scope jelas)
- "approved" / "yes, proceed"
- "build first" / "just build it"

⚠️ **ATURAN TRANSISI — WAJIB DIIKUTI:**

Saat user confirm build, orchestrator DILARANG:
- Langsung spawn developer agents
- Langsung mulai coding
- Skip classification dan pipeline routing
- Assume scope tanpa validasi

Orchestrator WAJIB:

**Step D4-1: Summarize scope dari diskusi**
```
Scope confirmed dari diskusi:
- [feature/fix 1]
- [feature/fix 2]
- Approach: [yang sudah di-agree]
- Estimated: [effort S/M/L/XL]
```

**Step D4-2: Re-classify scope**
Berdasarkan diskusi, tentukan scope type:
- Empty repo / no existing code → **GREENFIELD**
- Existing repo + new features → **NEW_FEATURE**
- Existing repo + fix → **BUG_FIX**
- Existing repo + small change → **SMALL_EDIT**

```bash
# Verify repo state
ls src/ app/ frontend/ backend/ 2>/dev/null && echo "EXISTING" || echo "EMPTY_REPO"
```

Jika EMPTY_REPO → scope = **GREENFIELD**, effort minimal = L

**Step D4-3: Confirm ke user**
```
Saya akan mulai [SCOPE TYPE] pipeline untuk scope di atas.
Estimated effort: [S/M/L/XL]
Pipeline: [agents yang akan di-spawn sesuai mode]

Confirm? [Proceed / Revise scope]
```

**Step D4-4: Route ke pipeline skill**
Setelah user confirm:
1. Baca PIPELINE ROUTING table di orchestrator core
2. Load skill yang sesuai: `pipeline-build/SKILL.md` untuk GREENFIELD/NEW_FEATURE
3. Ikuti skill STEP BY STEP — mulai dari Phase 0
4. JANGAN skip phase apapun

**ATURAN KERAS:**
- Transisi dari DISCUSSION ke BUILD **SELALU** melewati full pipeline
- TIDAK ADA shortcut — bahkan jika scope "terasa sederhana"
- Orchestrator-guard hook akan BLOCK jika kamu coba Write code langsung
- Jika scope = GREENFIELD → WAJIB Phase 0 + code-architect + wave-planner + APPROVE

### ATURAN DISCUSSION MODE:

* JANGAN spawn developer agents
* JANGAN write application code
* JANGAN create wave-plan
* JANGAN mulai Phase 0B, 1, 2, atau 3
* BOLEH spawn codebase-scout (haiku) untuk read-only analysis
* BOLEH read files untuk jawab pertanyaan user
* BOLEH write docs/deliberation.md sebagai notes diskusi
* Mode ini ZERO implementation — hanya analysis dan consultation
