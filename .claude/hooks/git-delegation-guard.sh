#!/bin/bash
# git-delegation-guard.sh — Block orchestrator dari menjalankan git mutating commands
# Hook type: PreToolUse (Bash)
#
# LOGIC:
#   1. Detect: apakah Bash command mengandung git mutating operation?
#   2. Jika YA → BLOCK (exit 2) + pesan instruksi spawn git-manager
#   3. Jika read-only git → ALLOW (exit 0)
#   4. Jika bukan git command → ALLOW (exit 0)
#
# SCOPE: Hook ini ter-trigger untuk semua agents yang pakai Bash tool.
#        git-manager dan pr-creator di-spawn dengan ORCHESTRATOR_GUARD_SKIP=1
#        sehingga guard di-skip untuk mereka.

# Parse input dari Claude Code
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Jika tidak bisa parse atau command kosong → allow
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Skip guard jika env var set (untuk git-manager dan pr-creator)
if [ "${ORCHESTRATOR_GUARD_SKIP:-}" = "1" ]; then
  exit 0
fi

# ════════════════════════════════════════════════════
# PATTERN 1: Git mutating commands — HARD BLOCK
# ════════════════════════════════════════════════════
# Regex: git followed by mutating subcommand
GIT_MUTATE_PATTERN='git\s+(commit|push|merge|rebase|cherry-pick|tag|stash|reset|checkout\s+-b|switch\s+-c|branch\s+-[dD]|branch\s+-m|worktree\s+add|worktree\s+remove)'

if echo "$COMMAND" | grep -qEi "$GIT_MUTATE_PATTERN"; then
  # Extract the specific git subcommand for logging
  GIT_SUBCMD=$(echo "$COMMAND" | grep -oEi 'git\s+\w+' | head -1)

  cat >&2 << BLOCK_MSG
══════════════════════════════════════════════════════════════
BLOCKED: Orchestrator tidak boleh menjalankan git mutating commands.
Command: $GIT_SUBCMD
══════════════════════════════════════════════════════════════

Kamu adalah CONDUCTOR, bukan PLAYER.
SPAWN git-manager untuk operasi git ini.

Contoh:
  Spawn git-manager: "Commit semua perubahan dengan message 'feat(scope): description'. Push ke origin develop."
  Spawn git-manager: "Create branch feature/xxx dari develop."
  Spawn git-manager: "Merge feature/xxx ke develop. Resolve conflicts jika ada."

══════════════════════════════════════════════════════════════
BLOCK_MSG

  # Log
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED orchestrator git: $COMMAND" >> .claude/hooks/hook-log.txt 2>/dev/null || true

  exit 2
fi

# ════════════════════════════════════════════════════
# PATTERN 2: git add — CONDITIONAL
# ════════════════════════════════════════════════════
# git add *.md → ALLOW (orchestrator tulis .md, perlu stage)
# git add . / git add -A / git add backend/ → BLOCK (terlalu broad, delegate)

if echo "$COMMAND" | grep -qEi 'git\s+add'; then
  # Allow: git add yang HANYA stage .md files
  if echo "$COMMAND" | grep -qE 'git\s+add\s+.*\.md$'; then
    exit 0
  fi
  # Allow: git add untuk specific docs/ files
  if echo "$COMMAND" | grep -qE 'git\s+add\s+docs/'; then
    exit 0
  fi
  # Block: git add . / git add -A / git add [non-md-path]
  cat >&2 << BLOCK_MSG
══════════════════════════════════════════════════════════════
BLOCKED: Orchestrator git add terlalu broad.
Command: $COMMAND
══════════════════════════════════════════════════════════════

Orchestrator hanya boleh 'git add' file .md yang dia tulis sendiri.
Untuk stage semua file → SPAWN git-manager.

Contoh:
  git add docs/wave-plan.md          ← OK (specific .md)
  git add docs/pipeline-state.md     ← OK (specific .md)
  git add .                          ← BLOCKED (delegate ke git-manager)
  git add backend/                   ← BLOCKED (delegate ke git-manager)

══════════════════════════════════════════════════════════════
BLOCK_MSG

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED orchestrator git add: $COMMAND" >> .claude/hooks/hook-log.txt 2>/dev/null || true
  exit 2
fi

# ════════════════════════════════════════════════════
# PATTERN 3: GitHub/GitLab API calls — BLOCK
# ════════════════════════════════════════════════════
# Orchestrator tidak boleh langsung call git API — delegate ke pr-creator atau git-manager
GIT_API_PATTERN='(api\.github\.com|gitlab\.com/api|api\.gitlab)'

if echo "$COMMAND" | grep -qEi "$GIT_API_PATTERN"; then
  cat >&2 << BLOCK_MSG
══════════════════════════════════════════════════════════════
BLOCKED: Orchestrator tidak boleh langsung call Git API.
Command: $(echo "$COMMAND" | head -c 200)
══════════════════════════════════════════════════════════════

Untuk PR creation → SPAWN pr-creator
Untuk repo operations → SPAWN git-manager

══════════════════════════════════════════════════════════════
BLOCK_MSG

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED orchestrator git API: $COMMAND" >> .claude/hooks/hook-log.txt 2>/dev/null || true
  exit 2
fi

# ════════════════════════════════════════════════════
# PATTERN 4: Git read-only commands — ALLOW
# ════════════════════════════════════════════════════
# Orchestrator BOLEH baca git state
GIT_READ_PATTERN='git\s+(log|status|diff|branch(\s+--show-current|\s+-l|\s+-a)?|remote|show|rev-parse|describe|shortlog|ls-files|ls-tree|config\s+--get|fetch)'

if echo "$COMMAND" | grep -qEi "$GIT_READ_PATTERN"; then
  exit 0
fi

# ════════════════════════════════════════════════════
# PATTERN 5: Unknown git commands — WARN (not block)
# ════════════════════════════════════════════════════
if echo "$COMMAND" | grep -qEi '^\s*git\s+'; then
  # Unknown git command — warn but allow (avoid false positive blocking)
  echo "⚠️ WARNING: Unknown git command detected. Jika ini mutating operation, seharusnya delegate ke git-manager." >&2
  exit 0
fi

# Not a git command at all → allow
exit 0
