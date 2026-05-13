---
name: pipeline-verification
description: >
  Post-build verification pipeline. Dijalankan OTOMATIS setelah wave execution
  selesai dan SEBELUM PR creation. Memastikan aplikasi benar-benar jalan,
  semua fitur terimplementasi, dan semua test pass. Termasuk re-loop logic
  (max 3x) untuk auto-fix issues yang ditemukan.
---

# Post-Build Verification Pipeline

## SCOPE UPDATE (2026-04-09)

Skill ini sekarang hanya digunakan untuk:
1. **Phase V1 (Environment Collection)** — dipanggil oleh Phase 4 Pre-QA Setup di pipeline-build
2. **Phase V2 (Boot + Health Check)** — dipanggil oleh Phase 4 Pre-QA Setup di pipeline-build
3. **`/verify` standalone command** — manual re-verification

Phase V3-V6 (automated tests, browser tests, feature audit, re-loop) SUDAH DIGANTIKAN oleh:
- `qa-orchestration/SKILL.md` — QA 4-step pipeline dengan smart re-loop
- Jangan jalankan V3-V6 dari skill ini jika dipanggil dari pipeline-build.
- V3-V6 HANYA jalan jika dipanggil via `/verify` standalone.

## KAPAN SKILL INI DIBACA
- Phase 4 Pre-QA Setup di pipeline-build → HANYA V1 + V2
- Saat user ketik `/verify` → V1-V6 (full standalone check)
- JANGAN skip

## OVERVIEW
Pipeline ini memastikan aplikasi BENAR-BENAR JALAN dari perspektif end user,
bukan hanya "code sudah ditulis". Ada 6 phase yang dijalankan sequential,
dengan re-loop logic untuk auto-fix.

---

## PHASE V1: Environment Collection (GRADUAL)

**Prinsip utama: JANGAN minta semua data sekaligus. Minta hanya yang dibutuhkan phase saat ini.**

### V1.1 — Scan kebutuhan
Baca file-file berikut untuk identifikasi apa yang dibutuhkan:
- `.env.example` → list semua env vars yang WAJIB diisi user
- `docker-compose.yml` → service dependencies, ports, volumes
- `docs/architecture-blueprint.md` → third-party integrations

Kategorikan kebutuhan:
- **BISA DI-GENERATE**: DB password (random), APP_KEY (generate), internal ports → GENERATE OTOMATIS
- **BUTUH DARI USER**: API keys third-party, OAuth credentials, domain-specific config
- **BISA NANTI**: Config yang hanya dibutuhkan di phase tertentu (e.g. Stripe key hanya di payment flow test)

### V1.2 — Minta ke user (HANYA yang wajib untuk boot)
Format permintaan:

```
Aplikasi sudah selesai dibangun. Sebelum saya test, saya butuh beberapa config:

**Untuk boot aplikasi (dibutuhkan sekarang):**
1. DATABASE_URL — atau saya pakai default SQLite/PostgreSQL local?
2. APP_SECRET_KEY — atau saya generate random?

**Belum dibutuhkan sekarang (akan saya tanya nanti jika perlu):**
- STRIPE_API_KEY (untuk test payment flow)
- OAUTH_CLIENT_ID (untuk test login flow)

Boleh saya generate yang bisa di-generate otomatis?
```

### V1.3 — Kirim juga via Telegram
Gunakan notify hook untuk kirim reminder ke Telegram:
```bash
bash .claude/telegram/notify-action-required.sh \
  "Verification Phase dimulai. Saya butuh beberapa config dari kamu." \
  "Cek Claude Code chat untuk detailnya."
```

### V1.4 — Tunggu response, lalu lanjut
- Jika user provide → simpan ke `.env` (JANGAN commit `.env` ke git)
- Jika user bilang "generate aja" → generate semua yang bisa di-generate
- Jika user tidak response dalam 5 menit → Telegram reminder kedua
- JANGAN lanjut ke Phase V2 tanpa minimal boot-critical env vars

---

## PHASE V2: Boot + Health Check

### V2.1 — Boot aplikasi
```bash
docker compose up -d --build
```

### V2.2 — Health check (timeout 120 detik)
```bash
# Cek semua services running
docker compose ps

# Cek endpoint health
curl -f http://localhost:PORT/health || curl -f http://localhost:PORT/api/health

# Cek database connection
docker compose exec app [framework-specific-db-check]

# Cek frontend accessible
curl -f http://localhost:FRONTEND_PORT/ -o /dev/null
```

### V2.3 — Jika gagal boot
- Baca error logs: `docker compose logs --tail=50`
- Masukkan ke fix queue (Phase V5)
- JANGAN minta user fix — coba fix sendiri dulu

---

## PHASE V3: Automated Tests (Layer 1)

### V3.1 — Jalankan existing tests
```bash
# Detect test framework dari codebase
# PHP/Laravel: php artisan test
# Python: pytest
# Node: npm test / yarn test
# Go: go test ./...
docker compose exec app [test-command]
```

### V3.2 — Jalankan API endpoint tests
Spawn `qa-tester` agent untuk:
- Hit setiap endpoint yang ada di routes
- Verify response status codes (2xx untuk happy path)
- Verify response structure match API spec (jika ada)

### V3.3 — Catat hasil
Output ke `docs/verification-report.md`:
```markdown
## Automated Test Results — Loop [N]
- Unit tests: X passed, Y failed
- API tests: X passed, Y failed
- Failed tests:
  - [test name]: [error message]
  - [test name]: [error message]
```

### V3.4 — Jika butuh data tambahan
Saat test gagal karena MISSING CONFIG (bukan bug):
```
Test payment flow gagal karena STRIPE_API_KEY belum di-set.

**Opsi:**
1. Skip payment tests untuk sekarang (test sisanya dulu)
2. Provide Stripe test key: `sk_test_...`

Mau yang mana?
```

JANGAN minta semua keys sekaligus. Tanya per-kebutuhan saat flow itu gagal.

---

## PHASE V4: Browser Tests (Layer 2)

### Prerequisites
- Playwright MCP harus tersedia (cek: lihat apakah `browser_navigate` ada di tool list)
- Jika Playwright MCP TIDAK tersedia → SKIP V4, catat "V4 SKIPPED: Playwright MCP not available"
- Jika tersedia → lanjut

### V4.1 — Authenticate
Sebelum test halaman authenticated, login dulu:

```
1. browser_navigate ke http://localhost/login (atau URL app)
2. browser_snapshot — verify login page render
3. browser_click pada email field → browser_type email credentials
4. browser_click pada password field → browser_type password
5. browser_click tombol Login
6. browser_snapshot — verify redirect ke dashboard/home
```

Credentials dari:
- `docs/user-simulation-config.md` jika ada
- `database/seeds/*.sql` — cari default admin credentials
- `.env` — cari default credentials
- Jika tidak ketemu → tanya user SATU KALI: "Butuh credentials untuk browser test. Email & password admin?"

### V4.2 — Smoke Test Semua Pages
Untuk SETIAP route yang terdaftar di frontend router:

```
1. browser_navigate ke [page URL]
2. Tunggu 3 detik (page load + API calls)
3. browser_console_messages — filter errors only
4. browser_snapshot — screenshot untuk evidence

EVALUATE:
- Console errors = 0 → PASS
- Console errors > 0 → FAIL, catat error messages
- Page redirect ke /login → kemungkinan auth expired, re-login
- Page redirect ke error page → FAIL
```

### V4.3 — Auto-discover routes dari codebase
```bash
# Next.js App Router — find all page.tsx files
find frontend/src/app -name "page.tsx" | sed 's|frontend/src/app||;s|/page.tsx||;s|\[([^]]*)\]|test-id|g'

# Output contoh:
# /dashboard
# /targets
# /targets/test-id
# /attack-lab
# /personas
# /admin/users
```

Untuk setiap route:
- Ganti `test-id` dengan actual ID dari database (query via API)
- Navigate dan smoke test

### V4.4 — Empty State vs Populated State
Test KEDUA state untuk setiap page:

**Populated state:**
- Pakai existing data dari database
- Navigate ke page → verify data render tanpa crash

**Empty state:**
- Create fresh entity (misal: target baru tanpa runs)
- Navigate ke detail page → verify empty state UI render tanpa crash
- JANGAN expect data — expect "No data yet" atau similar message

### V4.5 — Cross-Role Chain Tests (jika applicable)
Jika `docs/user-simulation-config.md` punya `cross_role_flows`:

```
Untuk setiap chain:
1. Login sebagai role A (browser_navigate /login, fill credentials)
2. Execute action (navigate, click, fill form, submit)
3. Verify expect (browser_snapshot + browser_console_messages)
4. Logout (navigate /logout atau clear cookies)
5. Login sebagai role B
6. Execute action
7. Verify expect
```

### V4.6 — File Upload Tests (jika applicable)
Jika ada upload forms:

```
1. Generate dummy file (echo "test content" > /tmp/test-upload.pdf)
2. Navigate ke upload page
3. browser_file_upload ke file input element
4. Verify upload success (no console errors, success message)
```

### V4.7 — Catat hasil
Append ke `docs/verification-report.md`:

```markdown
## Browser Test Results — Loop [N]

### Pages Tested: [X] total
### Console Errors Found: [Y]

| Page | URL | Console Errors | Screenshot | Status |
|------|-----|---------------|------------|--------|
| Dashboard | /dashboard | 0 | screenshot_001.png | PASS |
| Attack Lab | /attack-lab | TypeError: d.map... | screenshot_002.png | FAIL |
| Targets | /targets | 0 | screenshot_003.png | PASS |

### Failed Pages Detail:
- /attack-lab: TypeError: Cannot read properties of undefined (reading 'length')
  → Component receives paginated response {items:[]} but calls .length on undefined field
```

---

## PHASE V5: Feature Cross-Check (Audit)

### V5.1 — Spawn feature-auditor agent
feature-auditor membaca:
- `docs/task-breakdown.md` — sumber kebenaran: apa yang SEHARUSNYA dibangun
- Actual codebase — apa yang BENAR-BENAR dibangun

### V5.2 — Cross-check setiap task item
Untuk setiap item di task-breakdown.md:
- [ ] File yang dimaksud ADA?
- [ ] Endpoint/route TERDAFTAR?
- [ ] UI component RENDER (dari browser test)?
- [ ] Fungsionalitas BEKERJA (dari automated + browser test)?

### V5.3 — Generate gap report
```markdown
## Feature Audit — Loop [N]
### Implemented & Working
- [task-1]: User registration — endpoint exists, UI works, test passes
- [task-2]: Login flow — endpoint exists, UI works, test passes

### Implemented but Broken
- [task-5]: File upload — endpoint exists, UI exists, but upload fails (413 error)

### NOT Implemented
- [task-8]: Email notification — no mailer config, no email template, endpoint missing

### Summary
- Total tasks: 12
- Working: 8 (67%)
- Broken: 2 (17%)
- Missing: 2 (17%)
```

---

## PHASE V6: Re-Loop Logic

### V6.1 — Evaluasi hasil
Gabungkan semua findings dari Phase V3 + V4 + V5:
- Automated test failures
- Browser test failures
- Missing/broken features dari audit

### V6.2 — Jika SEMUA PASS
```
✅ Verification complete!

Semua automated tests pass.
Semua browser flows bekerja.
Semua fitur dari task-breakdown terimplementasi.

Lanjut ke PR creation.
```
→ Lanjut ke pipeline-postpipeline (PR creation)

### V6.3 — Jika ADA FAILURES dan loop_count < 3
```
⚠️ Verification loop [N]/3 — ditemukan [X] issues.

Fixing otomatis...
```

Dispatch fix agents:
- Backend issues → spawn `be-developer` dengan daftar fix items
- Frontend issues → spawn `fe-developer` dengan daftar fix items
- Infra issues → spawn `env-configurator` / `docker-manager`

Setelah fix selesai:
- Increment loop_count
- KEMBALI ke Phase V2 (boot ulang) → V3 → V4 → V5 → V6
- JANGAN skip phase manapun di re-loop

### V6.4 — Jika loop_count >= 3 dan MASIH ADA FAILURES
```
⚠️ Verification gagal setelah 3x loop.

**Yang sudah berhasil di-fix:**
- [list items yang fix dari loop 1-3]

**Yang masih gagal (butuh bantuan kamu):**
- [item]: [error detail] — sudah dicoba [approach 1, 2, 3], semua gagal
- [item]: [error detail] — kemungkinan butuh config/akses yang saya tidak punya

**Rekomendasi:**
1. Fix manual items di atas
2. Jalankan `/verify` untuk re-run verification pipeline

Mau saya lanjut ke PR dengan status partial, atau mau fix dulu?
```

### V6.5 — State tracking
Simpan state di `docs/verification-state.md`:
```markdown
# Verification State
- Loop count: [N]
- Phase terakhir: [V1-V6]
- Status: [running/passed/failed-escalated]
- Issues fixed per loop:
  - Loop 1: [X] fixed, [Y] remaining
  - Loop 2: [X] fixed, [Y] remaining
  - Loop 3: [X] fixed, [Y] remaining
- Escalated items: [list]
```

---

## RESUMABLE
Jika context habis di tengah verification:
1. Save state ke `docs/verification-state.md`
2. Saat `/start resume` → baca verification-state → lanjut dari phase terakhir
3. JANGAN ulang phase yang sudah pass di loop yang sama
