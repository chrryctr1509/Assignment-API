---
name: pipeline-delivery
description: >
  Generate delivery report dan user guidance setelah semua verification + QA selesai.
  Dijalankan di Phase 6 Final Delivery, SEBELUM PR creation.
  Output: docs/delivery-report.md + chat message singkat ke user.
---

# Post-Verification Delivery Report

## KAPAN SKILL INI DIBACA
- Otomatis oleh orchestrator di Phase 6, setelah QA pass
- JANGAN skip — user harus tahu apa yang sudah di-deliver

## STEP 1: Collect Data
Baca file-file berikut:
- `docs/verification-report.md` — test results
- `docs/qa-report.md` — QA results (jika ada)
- `docs/feature-audit-report.md` — feature completeness (jika ada)
- `docs/task-breakdown.md` — original scope
- `docker-compose.yml` — service URLs dan ports
- `.env` atau `.env.example` — credentials info
- `database/seeds/*.sql` — default credentials

## STEP 2: Generate `docs/delivery-report.md`

```markdown
# Delivery Report — [PROJECT NAME]
Generated: [timestamp]
Branch: [branch name]

## Quick Start
1. [Exact command to start app — e.g. `docker compose up -d`]
2. Open [URL] in browser
3. Login with [default credentials or "credentials provided separately"]

## URLs
| Service | URL | Credentials |
|---------|-----|-------------|
| App | http://localhost:[port] | admin@... / [password] |
| API Docs | http://localhost:[port]/api/docs | same as above |
| [other services] | ... | ... |

## What Was Built
[3-5 bullet summary of what was delivered]

## What Was Tested
| Category | Tests | Pass | Fail | Skip |
|----------|-------|------|------|------|
| API Endpoints | [N] | [N] | [N] | [N] |
| Browser Smoke | [N] | [N] | [N] | [N] |
| Feature Audit | [N] | [N] | [N] | [N] |
| Adversarial | [N] | [N] | [N] | [N] |
| Spec Compliance | [N] | [N] | [N] | [N] |

## Known Limitations
- [List items that were skipped, deferred, or partially implemented]
- [Items that need manual configuration — e.g. "Stripe keys need to be added for payment flow"]

## Verification Status
- Verification loops used: [N]/3
- Final status: [PASS / PARTIAL]
- Last verified: [timestamp]

## Next Steps (if any)
- [Remaining items from backlog]
- [Manual steps user needs to do]
```

## STEP 3: Chat Message ke User

Setelah generate file, TAMPILKAN message singkat di chat:

```
Delivery complete!

Quick Start:
   docker compose up -d
   Open http://localhost:[port]
   Login: [email] / [password]

Test Results: [X]/[Y] passed ([Z]% coverage)
Known Issues: [N] items (see docs/delivery-report.md)
Full report: docs/delivery-report.md

Mau saya bantu dengan hal lain?
```

## STEP 4: Telegram Notification (jika configured)
Kirim via notify hook:
```bash
bash .claude/telegram/notify-action-required.sh \
  "Build & Verify Complete — Project: [name], Branch: [branch], Tests: [X]/[Y] passed, Status: [PASS/PARTIAL]. Open app: [URL]. Full report: docs/delivery-report.md"
```
