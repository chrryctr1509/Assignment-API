Jalankan prosedur clean session — pastikan semua state tersimpan sebelum context di-clear.

---

## LANGKAH 1 — Verifikasi State Tersimpan

```bash
echo "=== Pipeline State ===" && cat docs/pipeline-state.md 2>/dev/null || echo "❌ TIDAK ADA"
echo "" && echo "=== Session Handoff ===" && cat docs/session-handoff.md 2>/dev/null || echo "❌ TIDAK ADA"
```

---

## LANGKAH 1.5 — Cek Git & MR Status

```bash
# Current branch
BRANCH=$(git branch --show-current)
echo "Branch: $BRANCH"

# Check if branch has been merged
git fetch origin 2>/dev/null
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | grep "HEAD branch" | awk '{print $NF}' || echo "main")
MERGED=$(git branch --merged "$DEFAULT_BRANCH" 2>/dev/null | grep -w "$BRANCH" && echo "YES" || echo "NO")

# Check for open MR/PR (GitLab or GitHub)
if [ -n "$GITLAB_TOKEN" ] && [ -n "$GITLAB_REPO_URL" ]; then
    PROJECT_PATH=$(echo "$GITLAB_REPO_URL" | sed 's|.*gitlab.com/||;s|\.git$||' | python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))")
    MR_STATUS=$(curl -s --max-time 5 --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "https://gitlab.com/api/v4/projects/$PROJECT_PATH/merge_requests?source_branch=$BRANCH&state=opened" \
        | python3 -c "import sys,json; mrs=json.load(sys.stdin); print(f'{len(mrs)} open')" 2>/dev/null || echo "unknown")
elif [ -n "$GITHUB_TOKEN" ]; then
    REPO=$(git remote get-url origin | sed 's|.*github.com/||;s|\.git$||')
    MR_STATUS=$(curl -s --max-time 5 -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO/pulls?head=$(echo $REPO | cut -d/ -f1):$BRANCH&state=open" \
        | python3 -c "import sys,json; prs=json.load(sys.stdin); print(f'{len(prs)} open')" 2>/dev/null || echo "unknown")
else
    MR_STATUS="unknown (no git token)"
fi

echo "Merged to $DEFAULT_BRANCH: $MERGED"
echo "Open MR/PR: $MR_STATUS"
```

Simpan status ini ke `docs/session-handoff.md` (akan di-append di LANGKAH 2):

```markdown
## Git Status (saat /clean)
- Branch: [BRANCH]
- Merged to [DEFAULT_BRANCH]: [YES/NO]
- Open MR/PR: [N open / 0 open / unknown]
- Last commit: [git log --oneline -1]
- Uncommitted changes: [git status --porcelain | wc -l] files
```

---

## LANGKAH 2 — Update session-handoff.md (Pastikan Terkini)

Tulis ulang `docs/session-handoff.md` dengan state TERKINI:

```markdown
# Session Handoff
> Dibuat oleh /clean — [YYYY-MM-DD HH:MM]
> Baca file ini setelah /clear untuk resume pipeline.

## Identitas Pipeline
Branch   : [dari pipeline-state.md]
Tipe     : [dari pipeline-state.md]
Brief    : [dari pipeline-state.md]
Dibuat   : [created_at dari pipeline-state.md]

## Status Stage Terakhir
[salin tabel Stage Progress dari pipeline-state.md]

## Stage Berikutnya
→ [stage pertama yang masih ⏳ pending]

## Keputusan yang Sudah Disetujui Programmer
[pertahankan semua keputusan dari session-handoff.md yang sudah ada]

## Cara Resume
Setelah /clear, ketik: /start resume
```

---

## LANGKAH 2.5 — Update Knowledge Graph

```bash
# Update graph dengan perubahan terbaru sebelum clean
command -v graphify &>/dev/null && graphify update . 2>/dev/null && echo "Graph updated" || true
```

Ini memastikan graph selalu fresh saat session berikutnya resume.

---

## LANGKAH 3 — Tampilkan Konfirmasi

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ PROGRESS TERSIMPAN — SIAP CLEAN CONTEXT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Semua progress sudah aman di file:

  📄 docs/pipeline-state.md   — status tiap stage
  📄 docs/session-handoff.md  — ringkasan untuk resume

Branch aktif : [nama branch]
Stage selesai: [daftar stage ✅]
Selanjutnya  : [stage berikutnya yang ⏳ pending]

Langkah selanjutnya:

  1. Ketik /clear  → membersihkan context window
  2. Ketik /start resume  → melanjutkan pipeline dari
     [stage berikutnya] dengan context yang segar

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Catatan: `.claude/memory/lessons.md` tetap tersimpan (tidak di-clear).
Orchestrator akan inject lessons ke ACP saat `/start resume`.

Setelah menampilkan ini — STOP. Tunggu user ketik `/clear`.
