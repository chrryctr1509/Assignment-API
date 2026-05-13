#!/usr/bin/env bash
set -euo pipefail

# orchestrator-guard.sh — Orchestrator write WHITELIST
# Rule: orchestrator can only WRITE to *.md files and allowed paths.
# Everything else → BLOCK with delegation hint.
# Scope: PreToolUse Write|Edit only (NOT Bash — to avoid blocking git-manager)

# Baca input dari Claude Code via stdin (JSON format)
INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)

# Jika tidak ada file path, allow (bukan file operation)
[ -z "$FILE_PATH" ] && exit 0

# ── Write/Edit Tool Guard (WHITELIST) ──────────────────────

# WHITELIST: allowed paths for orchestrator Write/Edit
# 1. Any *.md file (docs, reports, CLAUDE.md, etc.)
if [[ "$FILE_PATH" == *.md ]]; then
    exit 0
fi

# 2. docs/ directory (any file type — orchestrator manages pipeline docs)
if echo "$FILE_PATH" | grep -qE '^docs/'; then
    exit 0
fi

# 3. .claude/memory/ (lessons, recent-memory, project-memory)
if echo "$FILE_PATH" | grep -qE '^\.claude/memory/'; then
    exit 0
fi

# 4. Hook log (append-only logging)
if echo "$FILE_PATH" | grep -qE '^\.claude/hooks/hook-log'; then
    exit 0
fi

# 5. Template files
if [[ "$FILE_PATH" == *.template ]]; then
    exit 0
fi

# BLOCK everything else
echo "══════════════════════════════════════════════════════════════" >&2
echo "BLOCKED: Orchestrator hanya boleh Write/Edit file *.md dan docs/" >&2
echo "File: $FILE_PATH" >&2
echo "" >&2
echo "Kamu adalah CONDUCTOR, bukan PLAYER." >&2
echo "" >&2
echo "Delegate ke agent yang tepat:" >&2
echo "  Application code (.py/.ts/.js) → be-developer / fe-developer" >&2
echo "  Git operations → git-manager" >&2
echo "  Docker/infra → env-configurator / docker-manager" >&2
echo "  Database → db-designer" >&2
echo "══════════════════════════════════════════════════════════════" >&2
echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED orchestrator Write: $FILE_PATH" >> .claude/hooks/hook-log.txt 2>/dev/null || true
exit 2
