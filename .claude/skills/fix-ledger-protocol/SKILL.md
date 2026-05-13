---
name: fix-ledger-protocol
description: "Rules dan format untuk baca/tulis fix-ledger.md — constraint strategi baru WAJIB beda"
---

# Fix Ledger Protocol

## PURPOSE
Protocol untuk fix-strategist agent dalam mengelola fix-ledger.md — memastikan setiap attempt menggunakan strategi yang BERBEDA.

## FORMAT ENTRY

### Per TC, Per Environment:
```markdown
## TC-XXX: [Test Case Name]

### Attempt 1 — [environment]
- Date: [YYYY-MM-DD HH:MM]
- Strategy: [deskripsi strategi]
- Developer: [be-developer | fe-developer]
- Files changed: [list]
- Result: ✅ Resolved | ❌ Failed
- Error (if failed): [error message]
- Root cause: [analysis]

### Attempt 2 — [environment]
- Date: [YYYY-MM-DD HH:MM]
- Strategy: [HARUS BEDA dari Attempt 1]
- Forbidden strategies: ["strategi attempt 1"]
- ...
```

## CONSTRAINT RULES
1. **Strategi baru WAJIB berbeda** — jika Attempt 1 pakai "fix regex validation", Attempt 2 TIDAK BOLEH pakai variasi regex yang sama
2. **Forbidden list kumulatif** — setiap attempt menambah forbidden list
3. **Escalation wajib sequential**: retry → rollback+rewrite → skip+known-issue → stop+report
4. **Ledger harus ditulis SEBELUM coding** — ini pre-condition, bukan post-condition
5. **Environment-specific** — fix yang berhasil di MySQL belum tentu berhasil di PostgreSQL

## ESCALATION MATRIX

| Attempt | Level | Action |
|---------|-------|--------|
| 1-2 | Retry | Fix langsung, strategi berbeda |
| 3 | Rollback+Rewrite | Rollback semua, tulis ulang dari perspektif berbeda |
| 4 | Skip+Known Issue | Mark as known issue, tulis workaround |
| 5+ | Stop+Report | Stop loop, need human intervention |

## SEARCH PROTOCOL
Sebelum menulis entry baru:
1. `grep "TC-XXX" docs/fix-ledger.md` — cek existing attempts
2. Baca SEMUA attempts untuk TC ini
3. Compile forbidden strategies
4. Baru tulis entry baru

## CLEANUP
- Entries yang ✅ Resolved > 30 hari → archive ke `docs/history/fix-ledger-archive.md`
- Known Issues tetap di ledger sampai resolved
