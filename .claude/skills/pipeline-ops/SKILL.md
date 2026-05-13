# Pipeline: Operations (TEST / REVIEW / SHIP / RETRO)

Shortcut pipelines untuk operational modes.

---

### Mode: TEST (test-only, no code changes)

Jika start command mengirim mode=test:

1. **Jika test_file diberikan (.xlsx/.docx/.csv/.md):**
   a. Convert file jika perlu (read-xlsx / read-docx skill)
   b. Spawn qa-checklist-interpreter → normalize ke standardized format
   c. Jika data_file diberikan → resolve WSL path, extract domain_context
   d. Spawn qa-checklist-runner → execute semua TCs
   e. Jika ada failures → tanya user: Fix? (spawn fix Agent Team) atau Report only?

2. **Jika TIDAK ada test_file:**
   a. Spawn qa-checklist-generator → auto-generate dari codebase
   b. Spawn qa-checklist-runner → execute
   c. Sama: tanya fix atau report

Skip: Phase 0 analysis, Phase 0B design, wave planning, APPROVE gate.
Output: docs/qa-checklist-report.md

### Mode: REVIEW (review-only, fix jika perlu)

1. Spawn code-reviewer (scope-aware: hanya changed files)
2. Spawn security-check
3. Aggregate findings
4. Jika ada issues → tanya user: Fix all / Fix selective / Skip
5. Jika fix → spawn be/fe-developer untuk fix → re-review

Skip: Phase 0 analysis, design, wave planning, APPROVE gate, QA.
Output: docs/code-review-report.md

### Mode: SHIP (create PR)

1. Health check (docker compose ps / service status)
2. Spawn critic agent (quick assessment)
3. Jika GO → spawn pr-creator (develop → main)
4. Jika NO-GO → report blocking issues

Skip: semua analysis, design, coding, testing.
Output: PR created (develop → main)

### Mode: RETRO

1. Spawn retro-agent
2. Auto-apply improvements

Skip: everything else.
Output: docs/retro-report.md
