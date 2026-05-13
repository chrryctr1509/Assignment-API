# Agent Protocol Base — Shared Execution Protocol

Semua execution agent WAJIB mengikuti protokol ini sebelum memulai pekerjaan.

---

## LANGKAH 0 — Sync Pipeline State (WAJIB, tidak bisa di-skip)

Baca `docs/pipeline-state.md` sebelum melakukan apapun:

```bash
cat docs/pipeline-state.md
```

**Jika file tidak ada → STOP.**
Laporkan ke orchestrator: "pipeline-state.md tidak ditemukan."

Verifikasi stage sebelumnya sudah selesai. Ambil dari file, lalu tampilkan:
```
Agent   : [nama agent kamu]
Branch  : [dari pipeline-state]
Feature : [fitur yang di-assign dari wave-plan.md]
Stage   : running
```

**Jika branch di pipeline-state != branch aktif git → STOP.**

Update baris agent kamu di `docs/pipeline-state.md` → `running [timestamp]`

---

## LANGKAH 0B — Cek Lessons dari ACP (WAJIB)

Lessons yang relevan SUDAH ada di `docs/agent-context.md` section `## Relevant Lessons`.

Jika ACP tidak ada (dipanggil di luar pipeline, misal fix mode):
```bash
grep -A 5 "^### BE:\|^### FE:\|^### INFRA:\|^### QA:" .claude/memory/lessons.md 2>/dev/null | head -60
```

**Aturan wajib:**
- Jika error yang kamu hadapi SUDAH ADA di lessons → langsung gunakan solusi yang tercatat.
  JANGAN coba solusi yang sudah terbukti gagal.
- Jika belum ada di lessons → ikuti Error Handling Protocol di bawah.

### Baca retro recommendations (jika ada)
```bash
grep -A 3 "Auto-Applied Updates" docs/retro-report.md 2>/dev/null | head -10
```

---

## Docker Assessment Rules (WAJIB)

```bash
cat docs/docker-assessment.md 2>/dev/null || echo "NO_DOCKER_ASSESSMENT"
```

**RULES berdasarkan assessment:**

1. Jika service kamu ada di "Dockerized Services" → SEMUA command via docker exec:
   ```bash
   # BENAR
   docker exec -it app php artisan migrate
   docker exec -it node npm install express
   docker exec -it python pip install fastapi

   # SALAH — JANGAN PERNAH
   php artisan migrate
   npm install express
   ```

2. Jika service kamu ada di "Host Services" → boleh jalan di host.

3. Jika docker-assessment.md TIDAK ADA → asumsikan Docker mode. Pakai docker exec.

4. **Port references**: SELALU baca dari .env, JANGAN hardcode.
   ```bash
   source .env && curl http://localhost:${APP_PORT}/api/health
   ```

---

## Internet Access Rules

1. **Prefer WebFetch/WebSearch** untuk akses URL eksternal — tool ini TIDAK di-block oleh security-gate.
2. **curl/wget hanya untuk localhost dan API internal** (localhost, 127.0.0.1, api.telegram.org, registry.npmjs.org, dll yang ada di allowlist).
3. **Jika user kasih link referensi** → gunakan WebFetch untuk membaca konten.
4. **Jika curl di-block** → jangan retry, langsung switch ke WebFetch:
   ```
   # SALAH — akan di-block
   curl https://example.com/docs/api

   # BENAR — gunakan WebFetch tool
   WebFetch("https://example.com/docs/api")
   ```

---

## Error Handling Protocol

### Loop Detection — WAJIB diikuti setiap kali ada error

Buat session tracking:
```
Error     : [deskripsi error]
Percobaan 1: [deskripsi fix] → [hasil]
Percobaan 2: [deskripsi fix] → [hasil]
```

**Jika hendak mencoba fix yang PERSIS SAMA dengan yang sudah gagal → STOP.**

Ini adalah loop:

1. **Tulis lesson baru** (search-before-write):
   ```bash
   grep -i "[keyword dari error]" .claude/memory/lessons.md
   ```
   - Match + status solved → SKIP
   - Match + status pending → UPDATE
   - Tidak ada match → Tulis entry baru

2. **STOP** — jangan coba fix apapun lagi.

3. **Laporkan ke orchestrator:**
   ```
   LOOP TERDETEKSI — [agent-name]
   Error    : [deskripsi]
   Dicoba   : [fix 1], [fix 2] — semua gagal
   Lesson   : sudah ditulis ke .claude/memory/lessons.md
   Butuh    : input dari programmer untuk lanjut
   ```

### Setelah Fix Berhasil — Tulis Lesson

Jika error butuh lebih dari 1 percobaan:
```bash
grep -i "[keyword dari error]" .claude/memory/lessons.md
```
Tulis lesson baru atau update existing entry.

---

## Fix Protocol — Root Cause First (WAJIB sebelum menulis fix code)

Protocol ini WAJIB diikuti setiap kali agent menerima bug report, review finding, atau error yang harus di-fix.
JANGAN PERNAH langsung menulis fix code. SELALU investigasi dulu.

### Step 1: Understand Current State
1. Baca error message / review finding secara LENGKAP — jangan skim
2. Jalankan app dan REPRODUKSI masalah (jika memungkinkan)
3. Baca file yang terlibat — PAHAMI logic yang ada SEBELUM mengubah apapun
4. Cek: `git diff HEAD -- [file]` — apa yang baru saja berubah di file ini?

### Step 2: Eliminate Non-Code Causes
Sebelum mengubah source code, ELIMINASI dulu penyebab non-code:
1. **Stale build artifacts:**
   - Node/React: `rm -rf node_modules/.cache dist/ .next/ build/`
   - Python: `find . -name '__pycache__' -exec rm -rf {} +`
   - Docker: `docker compose build --no-cache [service]`
   - Electron: `rm -rf dist/ out/` lalu rebuild
   - Compiled output: hapus dan compile ulang
   Jika error HILANG setelah clean build → masalahnya BUKAN di source code. JANGAN modify source.
2. **Config issue:** cek .env, environment variables, port conflicts
3. **Service not restarted:** apakah perubahan code sudah di-pick up oleh running service?

### Step 3: Trace Root Cause
1. Error berasal dari MANA? Trace dari error message → file → function → line
2. KENAPA error ini terjadi? Apa yang berubah sehingga ini sekarang error?
3. Cek: `git log --oneline -5 -- [file]` — ada perubahan recent?
4. Jika error di file yang TIDAK kamu ubah → kemungkinan besar bukan code bug

### Step 4: Verify Baseline (WAJIB sebelum fix)
Catat apa yang SUDAH BEKERJA sekarang:
- Test mana yang pass? → Jalankan: `[test command] 2>&1 | tail -20`
- Endpoint mana yang jalan?
- Komponen mana yang render benar?
- Behavior mana yang correct?
→ Simpan sebagai checklist WAJIB: semua ini HARUS tetap bekerja setelah fix

### Step 5: Minimal Fix
- Ubah SESEDIKIT MUNGKIN baris kode
- JANGAN refactor code lain yang tidak terkait bug
- JANGAN "improve" atau "clean up" code sekitar
- Fix HANYA yang broken — sisanya JANGAN disentuh
- Jika ragu apa root cause-nya → TANYA user via AskUserQuestion, jangan tebak

### Step 6: Post-Fix Verification (WAJIB)
1. Bug yang di-report → sudah fixed?
2. SEMUA yang dicatat di Step 4 → masih bekerja? (run test, check endpoints)
3. Test yang tadi pass → masih pass?
4. Jika ada yang BARU rusak setelah fix → ini REGRESSION → WAJIB revert

### Revert Protocol
Jika fix gagal atau menyebabkan regression:
1. **JANGAN stack fix di atas fix yang gagal** — ini menyebabkan compound failure
2. REVERT perubahan: `git checkout -- [files yang kamu ubah]`
3. Kembali ke Step 1 — investigasi ulang dengan pendekatan BERBEDA
4. Tulis lesson ke `.claude/memory/lessons.md`: apa yang dicoba dan kenapa gagal
5. Jika sudah 2x gagal dengan pendekatan berbeda → ESKALASI ke user, jangan coba lagi

### LARANGAN di Fix Mode
- DILARANG mengubah file yang TIDAK disebutkan di review finding / bug report
- DILARANG disable fitur yang sebelumnya bekerja sebagai "fix"
- DILARANG mengubah konfigurasi (transparent, GPU, framework settings) tanpa bukti bahwa itu root cause
- DILARANG assume bahwa sesuatu "tidak bekerja di environment ini" tanpa BUKTI (log, error, test)

---

## Post-Implementation Runability Check (WAJIB setelah setiap implementasi)

Setelah selesai implement/edit code, SEBELUM commit, tanya:

### "Apakah code ini bisa jalan dari fresh clone + install?"

Cek SETIAP hal berikut yang relevan:

**1. Dependencies**
- Apakah saya import/require/use library yang BELUM ada di dependency file?
  - JS/TS: cek package.json (dependencies atau devDependencies)
  - Python: cek requirements.txt atau pyproject.toml
  - PHP: cek composer.json
  - Go: cek go.mod
  - Kotlin: cek build.gradle
- Jika ada yang belum terdaftar → TAMBAHKAN SEKARANG sebelum commit
- Command: `docker exec -it [container] [package-manager] install [package]`

**2. Registrasi**
- File baru (controller, route, middleware, component) → sudah di-register?
  - Laravel: routes/api.php atau routes/web.php
  - Express: router file
  - Vue/React: router atau index file
  - Django: urls.py
- Config baru → sudah di-register di config loader?
- Middleware baru → sudah di-apply di route atau kernel?

**3. Environment**
- Variable baru (API key, URL, port) → sudah ada di .env.example?
- Jangan tambah ke .env langsung (di-block oleh file-protect hook)
- Tambah ke .env.example sebagai template

**4. Database**
- Table/column baru → migration sudah di-buat dan di-run?
- Seeder data yang dibutuhkan → sudah di-buat?

**5. Assets & External Resources**
- Font baru → sudah di-install atau di-link (Google Fonts, npm package)?
- Icon library baru → sudah di-install?
- CSS framework baru → sudah di-import?
- Image/media → path sudah benar?

**6. Build & Config**
- TypeScript types → package punya @types/ yang perlu di-install?
- Tailwind config → class baru yang butuh extend di tailwind.config?
- Webpack/Vite config → alias baru yang perlu di-tambah?

### Cara Cek

Sebelum commit, jalankan:
```bash
# JS/TS — cek import yang tidak ada di package.json
grep -rh "from ['\"]" [src-files] | grep -v node_modules | sort -u
cat package.json | jq '.dependencies + .devDependencies | keys[]'
# Bandingkan — ada import yang tidak ada di dependencies?

# Python — cek import yang tidak ada di requirements.txt
grep -rh "^import \|^from " [src-files] | sort -u
cat requirements.txt
# Bandingkan

# PHP — cek use yang tidak ada di composer.json
grep -rh "^use " [src-files] | sort -u
```

### Jika menemukan gap:
1. Install dependency: `docker exec -it [container] [install command]`
2. Verify dependency file ter-update (package.json, requirements.txt, etc.)
3. Commit dependency file BERSAMA code change — bukan commit terpisah

---

## Uncertainty Protocol

Jika setelah investigasi kamu TIDAK YAKIN apa root cause-nya:
1. JANGAN tebak dan coba — ini menyebabkan regression
2. TANYA user via AskUserQuestion:
   "Saya menemukan [apa yang ditemukan] tapi belum yakin apakah ini root cause.
   [pertanyaan spesifik tentang context yang hanya user tahu]"
3. Tunggu jawaban sebelum menulis fix code
4. Jika user juga tidak yakin → sarankan diagnostic steps yang bisa user lakukan manual

JANGAN PERNAH berasumsi bahwa sesuatu "tidak bekerja di environment ini" tanpa bukti.
Jika sesuatu SEBELUMNYA bekerja dan sekarang tidak → ada perubahan spesifik yang menyebabkannya.
Tugas kamu adalah MENEMUKAN perubahan itu, bukan menebak.

---

## Fix Scope Guard

Saat fix mode, kamu HANYA boleh modify file yang:
- Disebutkan di review finding (docs/code-review-report.md) — specific files + line numbers
- Disebutkan di fix strategy (docs/fix-ledger.md) — target files

Jika investigasi menunjukkan fix memerlukan perubahan di file LAIN yang tidak ada di list:
- JANGAN langsung modify
- Laporkan ke orchestrator: "Fix memerlukan perubahan di [file X] yang di luar scope review"
- Tunggu orchestrator approve scope expansion

ALASAN: Tanpa scope guard, developer cenderung mengubah file-file terkait secara spekulatif,
menyebabkan regression di tempat yang tidak terduga.

---

## Test-Driven Development Protocol (Universal — WAJIB untuk semua execution agents)

Semua **execution agents** (developer, fixer, qa-tester jika menulis code) **WAJIB**:

1. **Cek existing test baseline** SEBELUM mulai koding — catat total/pass/fail (pre-existing)
2. **Tulis test** yang define expected behavior SEBELUM koding fitur/fix
3. **Verify SEMUA test (baru + lama)** PASS SETELAH koding
4. **DILARANG** mengubah ekspektasi test lama supaya pass (anti-cheat)
5. **Report** test results di output:
   ```
   test_baseline: {total: N, pass: N, fail: N (pre-existing)}
   test_after: {total: N, pass: N, fail: N}
   new_tests_written: N
   regressions: none | [list]
   ```

### Anti-Cheat Guard (universal)
Yang DILARANG KERAS untuk semua agents:
- Mengubah assertion di test lama
- Menghapus test lama yang fail
- Menambah `.skip` / `@skip` / `@pytest.mark.skip` ke test lama
- Mengubah expected value di test lama

Jika test lama fail karena perubahanmu → **YANG SALAH ADALAH CODE BARU KAMU**, bukan test lamanya.

### Pre-Commit Gate
`git-manager` WAJIB jalankan test suite sebelum setiap `git commit` (lihat `git-manager.md` → Pre-Commit Regression Gate). Jika test fail dan bukan pre-existing → commit di-BLOCK, developer fix dulu.

---

## MCP Browser Error Handling (Self-Healing Protocol)

Jika MCP browser tool return error, JANGAN langsung minta bantuan developer.
Ikuti self-healing steps berikut:

### Error: "Target closed" / "Target.setDiscoverTargets" / "Protocol error"

Artinya: Chrome browser tidak jalan atau connection terputus.

**Self-heal steps (coba SEMUA sebelum eskalasi):**

Step 1 — Restart MCP connection:
```
Coba tool lain dulu — misalnya list_console_messages atau take_screenshot.
Kadang reconnect otomatis setelah retry.
```

Step 2 — Check apakah aplikasi jalan:
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "APP_DOWN"
```
- Jika APP_DOWN → aplikasi belum start. Jalankan:
  ```bash
  docker compose up -d
  # atau
  npm run dev
  ```
  Tunggu 10 detik, coba MCP lagi.

Step 3 — Check apakah port benar:
```bash
source .env
echo "APP_PORT=$APP_PORT"
curl -s -o /dev/null -w "%{http_code}" http://localhost:${APP_PORT} 2>/dev/null
```
- Jika port salah → ganti URL di MCP call ke port yang benar.

Step 4 — Kill stale Chrome dan coba lagi:
```bash
pkill -f "chrome.*remote-debugging" 2>/dev/null || true
pkill -f "chromium.*remote-debugging" 2>/dev/null || true
sleep 3
```
Lalu coba MCP tool lagi — Chrome DevTools MCP akan spawn Chrome baru.

Step 5 — Coba Playwright MCP sebagai fallback:
```
Jika Chrome DevTools gagal setelah Step 1-4, switch ke Playwright MCP:
  browser_navigate instead of navigate_page
  browser_snapshot instead of take_screenshot
```

### Error: "Cannot find browser" / "Browser not found" / "Executable doesn't exist"

Step 1 — Check Chrome/Chromium installed:
```bash
which google-chrome || which chromium-browser || which chromium 2>/dev/null
```
- Jika tidak ada → log: "Chrome not installed. Visual testing skipped."
- Fallback ke curl/API testing.
- JANGAN minta developer install Chrome — itu infrastructure decision.

### Error: "Navigation timeout" / "Timeout exceeded"

Step 1 — Aplikasi mungkin lambat start. Tunggu dan retry:
```bash
sleep 10
```
Coba navigate lagi. Max 3 retries.

Step 2 — Check apakah URL benar (typo, wrong path):
```bash
# List available routes
docker exec -it app php artisan route:list 2>/dev/null  # Laravel
# atau
grep -r "path:" src/router/ 2>/dev/null  # Vue/React router
```

### Error: "net::ERR_CONNECTION_REFUSED"

Aplikasi tidak listen di port tersebut.
```bash
# Check apa yang listen
ss -tlnp | grep -E "3000|8000|5173" 2>/dev/null
# atau
netstat -tlnp 2>/dev/null | grep -E "3000|8000|5173"
```
Ganti URL ke port yang benar.

### Kapan BARU eskalasi ke developer

HANYA eskalasi jika SEMUA self-heal steps sudah dicoba dan GAGAL:

```markdown
⚠️ MCP BROWSER ERROR — Self-healing gagal

Error: [exact error message]
Self-heal attempts:
1. Retry MCP → [result]
2. Check app running → [result]
3. Check port → [result]
4. Kill stale Chrome → [result]
5. Playwright fallback → [result]

Yang perlu developer lakukan:
- [SATU instruksi spesifik, contoh: "Jalankan `docker compose up -d` lalu confirm"]
```

JANGAN eskalasi dengan pesan generic seperti "MCP error, please help."
HARUS kasih exact command yang developer perlu jalankan.

### Logging

Setiap MCP error dan self-heal attempt, log ke structured output:
```yaml
mcp_issues:
  - error: "Target closed"
    self_heal: "Step 4 — killed stale Chrome, retry succeeded"
    resolved: true
  - error: "Browser not found"
    self_heal: "All steps failed"
    resolved: false
    fallback: "curl API testing"
```

---

## Self-Verification Rule (Semua Execution Agents)

Sebelum output `status: done`, VERIFY hasil kerjamu sendiri.
`status: done` artinya "siap di-review", BUKAN "selesai untuk user".

| Tipe output | Verification minimum |
|-------------|---------------------|
| File baru | `test -f [path]` — pastikan file ADA |
| Code changes | Baca ulang diff — cek obvious errors |
| Config changes | Validate syntax (JSON/YAML/TOML) |
| Endpoint baru | Hit endpoint, verify response code + shape |
| UI component | Build check minimal, browser check jika bisa |

### YAML Output Fields
Semua execution agents WAJIB include di YAML header:
- `self_test: passed / skipped / failed`
- `self_test_note: ""` — alasan jika skipped, detail jika failed

### Honesty Rule
Lebih baik jujur `self_test: skipped — app not running` daripada bohong `self_test: passed`.
Orchestrator dan QA agent akan membaca field ini.

---

## QA Handoff Protocol

Setelah execution agent output `status: done`, orchestrator akan OTOMATIS route ke QA pipeline. Agent TIDAK perlu explicitly call QA — orchestrator yang handle routing.

### Apa yang QA butuhkan dari output kamu:
- `self_test: passed/skipped` — QA tahu apakah developer sudah verify sendiri
- `service_rebuilt: true/false` — QA tahu apakah app sudah running code terbaru
- `service_healthy: true/false` — QA tahu apakah app accessible
- `service_url: "..."` — QA tahu di mana test
- `response_shapes: [...]` (be-developer) — QA tahu expected API response structure
- `files_created/modified: [...]` — QA tahu scope perubahan

### Saat menerima fix request dari QA loop:
- Baca fix items SPESIFIK dari QA report (bukan general "fix bugs")
- Fix HANYA item yang diminta — jangan refactor, jangan expand scope
- Rebuild service setelah fix
- Self-test ulang
- Output `status: done` dengan updated YAML

---

## Structured Output Header (WAJIB di akhir pekerjaan)

Sebelum menyelesaikan pekerjaan, output YAML frontmatter block ini di AWAL output/report:

```yaml
---
agent: [nama-agent]
status: done|failed|blocked
files_created: [list paths]
files_modified: [list paths]
issues_found: [jumlah]
tests_pass: true|false
commit: "[conventional commit message]"
next_agent: [suggested next agent atau "none"]
---
```

Ini memungkinkan orchestrator mem-parse hasil secara programmatik.

---

## Codebase Navigation — Graph First

Sebelum grep/find untuk cari files:
1. Cek `graphify-out/GRAPH_REPORT.md` — mungkin jawaban sudah ada di god nodes atau communities
2. Cek `graphify-out/wiki/index.md` jika ada — navigate structured docs
3. Gunakan `graphify query "pertanyaan"` untuk targeted graph search
4. Baru fallback ke grep/find jika graph tidak cover

Ini saves tokens — graph query ~1.7k tokens vs grep ~10-50k tokens.

---

## Setelah Semua Task Selesai

Update baris agent kamu di `docs/pipeline-state.md` → `done [timestamp]`
Laporkan ke orchestrator bahwa pekerjaan selesai di worktree ini.

---

## Read-Before-Fix Protocol (Semua Execution Agents)

SEBELUM coba fix error apapun, WAJIB search lessons dulu.
Lessons berisi solusi yang sudah terbukti (✅) dan pendekatan yang sudah gagal (❌).
Mengabaikan lessons = buang token untuk ulangi kesalahan yang sama.

### Kapan WAJIB Search

1. **Error/exception muncul** — apapun: runtime error, build error, test failure
2. **Behavior unexpected** — output tidak sesuai harapan, UI rusak, data salah
3. **Sebelum pilih strategi fix** — cek apakah strategi itu pernah gagal

### Cara Search

```bash
# Search by keyword dari error message
grep -i -A 6 "[keyword error]" .claude/memory/lessons.md 2>/dev/null

# Contoh: error "Objects are not valid as React child"
grep -i -A 6 "react child\|Error #31\|not valid" .claude/memory/lessons.md 2>/dev/null

# Contoh: migration gagal
grep -i -A 6 "migration\|alembic\|migrate" .claude/memory/lessons.md 2>/dev/null
```

### Cara Pakai Hasil Search

**Jika ada match dengan ✅ (solusi yang berhasil):**
→ GUNAKAN solusi itu langsung. JANGAN coba cara lain dulu.
→ Jika solusi ✅ ternyata tidak work di konteks kamu → update lesson (tambah note) + coba cara lain

**Jika ada match dengan ❌ (pendekatan yang gagal):**
→ JANGAN ulangi pendekatan itu. Sudah terbukti gagal.
→ Cari alternatif lain.

**Jika tidak ada match:**
→ Coba fix sendiri seperti biasa
→ Setelah berhasil → TULIS lesson baru (ikuti Write-Back Protocol di bawah)

### JANGAN

- Jangan `cat` seluruh lessons.md (bisa besar) — selalu `grep`
- Jangan skip search karena "pasti belum ada" — search itu 1 detik, fix trial-error itu 5 menit
- Jangan abaikan entry ❌ — jika kamu coba pendekatan yang sama dan gagal lagi, itu token yang terbuang

---

## Lesson Write-Back Protocol (Semua Execution Agents)

Setiap agent yang encounter dan resolve error/issue WAJIB menulis ke memory.
Ini yang memberi makan ke seluruh memory system (consolidation, pruning, CLAUDE.md auto-update).

### Kapan WAJIB Tulis Lesson

1. **Error yang kamu fix** — setelah berhasil fix error apapun
2. **Workaround yang kamu temukan** — solusi non-obvious yang agent lain perlu tahu
3. **Pattern yang baru kamu temukan** — convention, gotcha, atau quirk di project ini
4. **Fix yang GAGAL** — sama pentingnya, supaya agent lain tidak ulangi

### Kapan JANGAN Tulis

- Typo fix (salah ketik variable name)
- Import yang kurang (trivial)
- Error yang sudah ada di lessons.md (cek dulu!)

### Cara Tulis (WAJIB ikuti urutan ini)

**Step 1: Search dulu — JANGAN duplikat**
```bash
grep -i "[keyword dari error]" .claude/memory/lessons.md 2>/dev/null
```
- Jika match + status ✅ → SKIP, jangan tulis duplikat
- Jika match + status ⏳ → UPDATE entry yang ada, jangan buat baru
- Jika tidak ada match → lanjut Step 2

**Step 2: Tentukan prefix stack**
```
BE:Node / BE:Laravel / BE:Python / BE:Go
FE:React / FE:Next / FE:Vanilla / FE:Vue
DB:Postgres / DB:MySQL / DB:SQLite
QA:Smoke / QA:E2E
INFRA:Docker / INFRA:Git / INFRA:Deploy
```

**Step 3: Append entry baru ke lessons.md**
```bash
cat >> .claude/memory/lessons.md << 'LESSON_EOF'

### [STACK:CONTEXT] — [deskripsi error singkat]
Konteks  : [file/fungsi/kondisi spesifik]
Dicoba   : ❌ [fix yang gagal] — [kenapa gagal]
Solusi   : ✅ [fix yang berhasil]
Tanggal  : $(date '+%Y-%m-%d')
LESSON_EOF
```

**Step 4: Cek ukuran file**
```bash
ENTRY_COUNT=$(grep -c "^### " .claude/memory/lessons.md 2>/dev/null || echo "0")
if [ "$ENTRY_COUNT" -ge 50 ]; then
  echo "<!-- COMPACTION_NEEDED -->" >> .claude/memory/lessons.md
fi
```

### Contoh Entry yang Benar

```markdown
### FE:React — Objects are not valid as React child (Error #31)
Konteks  : ScenarioCard.tsx — render `{run.scenario}` langsung di JSX
Dicoba   : ❌ JSON.stringify(scenario) — output string bukan UI yang diinginkan
Solusi   : ✅ Destructure: `{run.scenario.scenario_id}` — render field spesifik
Tanggal  : 2026-04-12
```

```markdown
### BE:Python — Alembic migration gagal di Docker
Konteks  : docker compose exec backend alembic upgrade head — connection refused
Dicoba   : ❌ Langsung run alembic — DB belum ready
Solusi   : ✅ Wait for DB: `until pg_isready; do sleep 1; done && alembic upgrade head`
Tanggal  : 2026-04-12
```

### YAML Output — Tambahan Field

Semua execution agents yang encounter error/issue, tambahkan di YAML output:
```yaml
lessons_written: 1          # jumlah lesson baru yang ditulis di session ini
lessons_updated: 0          # jumlah lesson existing yang di-update
```

Jika tidak encounter error → `lessons_written: 0`, `lessons_updated: 0` (tetap tulis field-nya).
