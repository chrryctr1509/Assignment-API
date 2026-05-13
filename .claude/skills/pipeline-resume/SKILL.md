# Pipeline: RESUME

Protocol untuk melanjutkan pipeline yang terinterrupt.
Skip planning — langsung execute dari file terakhir yang belum selesai.

---

## LANGKAH 0 — Cek Actual Git State (SEBELUM baca saved state)

Saved state bisa stale. Git adalah sumber kebenaran.

```bash
BRANCH=$(git branch --show-current)
git fetch origin 2>/dev/null
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | grep "HEAD branch" | awk '{print $NF}' || echo "main")

echo "=== Actual Git State ==="
echo "Branch: $BRANCH"
echo "Last commit: $(git log --oneline -1)"
echo "Uncommitted: $(git status --porcelain | wc -l) files"

# Cek apakah branch sudah merged
if git branch --merged "$DEFAULT_BRANCH" 2>/dev/null | grep -qw "$BRANCH"; then
    echo "STATUS: Branch $BRANCH sudah MERGED ke $DEFAULT_BRANCH"
    echo "Tidak ada yang perlu di-resume — branch sudah selesai."
    echo ""
    echo "Opsi:"
    echo "1. Start fresh task di branch baru"
    echo "2. Checkout $DEFAULT_BRANCH dan mulai dari sana"
    # JANGAN tawarkan merge/MR — sudah merged
else
    echo "STATUS: Branch $BRANCH belum merged ke $DEFAULT_BRANCH"

    # Cek open MR/PR
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
        MR_STATUS="unknown"
    fi
    echo "Open MR/PR: $MR_STATUS"
fi
```

### Logic berdasarkan actual state:

| Git State | Saved State | Action |
|-----------|-------------|--------|
| Branch merged | Ada session-handoff | IGNORE session-handoff. Bilang "branch sudah merged, mau start fresh?" |
| Branch merged | Tidak ada | Bilang "branch sudah merged, mau start fresh?" |
| Branch NOT merged, ada uncommitted | Ada session-handoff | Resume dari session-handoff + report uncommitted changes |
| Branch NOT merged, clean | Ada session-handoff | Resume dari session-handoff |
| Branch NOT merged, ada open MR | Ada session-handoff | Bilang "ada open MR. Mau review, atau lanjut development?" |
| Branch NOT merged, no MR | Ada session-handoff | Resume normal — masih in-progress |
| Any | Tidak ada session-handoff | Assess dari git log + codebase, tawarkan opsi |

### JANGAN tawarkan merge kalau sudah merged
Ini penyebab masalah utama. Cek git dulu, baru decide apa yang ditampilkan ke user.

---

## Resume Protocol

Jika programmer ketik `/start resume` dan branch BELUM merged:

```bash
cat docs/session-handoff.md
cat docs/pipeline-state.md
```

Identifikasi wave terakhir yang selesai, lanjut dari wave berikutnya.
Tidak perlu re-run wave yang sudah selesai.

### ENHANCED RESUME — File-Level Granularity

```bash
# 1. Baca wave execution state
cat docs/wave-execution-state.md

# 2. Cari file terakhir yang belum selesai (NEXT_FILE)
NEXT_FILE=$(grep '^\- \[ \]' docs/wave-execution-state.md | head -1 | sed 's/- \[ \] //')
CURRENT_WAVE=$(grep -B 20 "^\- \[ \] $NEXT_FILE" docs/wave-execution-state.md | grep "^### Wave" | tail -1)

echo "Resuming from: $CURRENT_WAVE — file: $NEXT_FILE"
```

**RESUME RULES:**
- JANGAN re-create files yang sudah `[x]` — mereka sudah ada di disk
- JANGAN re-run planning atau analysis — langsung execute, bukan planning lagi
- JANGAN tanya user untuk re-approve — sudah di-approve sebelumnya
- Verify files yang `[x]` benar-benar ada:
  ```bash
  grep '\[x\]' docs/wave-execution-state.md | sed 's/.*\[x\] //' | while read f; do
    [ -f "$f" ] && echo "✅ $f" || echo "❌ MISSING: $f"
  done
  ```
- Jika ada file `[x]` tapi MISSING → re-create file itu
- Mulai dari file `[ ]` pertama yang belum dibuat
- Skip planning — JANGAN re-plan, langsung execute sisa file
