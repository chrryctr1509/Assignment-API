# Pipeline: SMALL_EDIT

Skill ini berisi shortcut pipeline untuk mode SMALL_EDIT.
Untuk perubahan < 20 baris di 1-2 file.

Urutan: Developer (haiku) → Reviewer (sonnet) → Commit

---

## Pre-Pipeline: Verify Scope dengan User

Sebelum mulai pipeline, TAMPILKAN ke user:
```
Saya akan jalankan SMALL_EDIT pipeline untuk: [ringkasan perubahan]
- Estimated effort: S (< 20 baris)
- Pipeline: Developer (haiku) → Reviewer (sonnet) → Commit
Confirm? [Proceed / Discuss first]
```

**Jika user bilang "Discuss first"** → route ke pipeline-discussion/SKILL.md
**Jika user confirm** → lanjut ke pipeline
**JANGAN mulai pipeline tanpa explicit confirmation**

---

### ⚠️ DELEGATION CHECKPOINT — SMALL_EDIT
Sebelum melakukan APAPUN, konfirmasi: "Apakah saya hendak Write/Edit application code?"
- Jika YA → STOP. Spawn be-developer atau fe-developer.
- Jika TIDAK (hanya docs/state files) → lanjut.
Hook orchestrator-guard.sh akan BLOCK jika kamu coba edit .ts/.tsx/.js/.jsx/.css/.py/.php.

Jika scope_type = SMALL EDIT (kurang dari 20 baris perubahan):

1. Orchestrator JANGAN edit code sendiri — spawn be-developer ATAU fe-developer (haiku):
   - Berikan context minimal: file path + exact change needed
   - Developer apply edit + run runability check
2. Spawn code-reviewer (sonnet, scope-aware) → quick review
3. Jika LGTM → commit
4. Jika issues → developer fix, re-review sekali
5. Jika re-review masih fail → ESCALATE ke BUG_FIX mode (spawn tracer + full developer)

Skip: Phase 0B, Phase 1, Phase 2, APPROVE gate, wave planning, critic, QA.
Total agents: ~2-3 (developer + reviewer, optional escalation)

**ATURAN: Orchestrator TIDAK PERNAH menulis application code, bahkan untuk 1 baris.**
Orchestrator hanya menulis docs/ dan pipeline state files.

---

## Post-Edit Verification

SMALL_EDIT selalu scope kecil. Tidak perlu automated tests.
Tapi WAJIB:
1. Developer self-test (dari agent file mereka — rebuild + checklist)
2. User guidance: apa yang berubah, bagaimana verify

**User Guidance (WAJIB):**
```
Edit applied.

**What changed:** [file dan perubahan spesifik]

**Untuk melihat perubahan:**
1. [rebuild command atau "auto-reload"]
2. [langkah spesifik untuk verify]

**Side effects:** [atau "tidak ada"]
```

Format sama dengan pipeline-bugfix Step 4 (User Guidance).
