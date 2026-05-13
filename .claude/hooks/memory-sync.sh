#!/usr/bin/env bash
# memory-sync.sh — Stop hook safety net for memory persistence
# Ensures lessons written during session survive worktree cleanup.
#
# Logic:
# 1. Detect if we're in a worktree (git toplevel != CLAUDE_PROJECT_DIR)
# 2. If in worktree → copy new lesson entries to main repo
# 3. If in main repo → no-op
# 4. Always exit 0 (non-blocking safety net)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
LOG_FILE="$SCRIPT_DIR/hook-log.txt"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] MEMORY_SYNC: $1" >> "$LOG_FILE" 2>/dev/null || true
}

# Detect if we're in a worktree
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$GIT_ROOT" ]; then
  log "Not a git repo — skipping"
  exit 0
fi

# Normalize paths for comparison
NORMALIZED_GIT=$(cd "$GIT_ROOT" 2>/dev/null && pwd)
NORMALIZED_PROJECT=$(cd "$PROJECT_DIR" 2>/dev/null && pwd)

if [ "$NORMALIZED_GIT" = "$NORMALIZED_PROJECT" ]; then
  log "Main repo — no sync needed"
  exit 0
fi

# We're in a worktree — sync lessons to main repo
MAIN_LESSONS="$NORMALIZED_PROJECT/.claude/memory/lessons.md"
WT_LESSONS="$NORMALIZED_GIT/.claude/memory/lessons.md"

if [ ! -f "$WT_LESSONS" ]; then
  log "No worktree lessons.md — skipping"
  exit 0
fi

if [ ! -f "$MAIN_LESSONS" ]; then
  log "No main lessons.md — copying entire file"
  mkdir -p "$(dirname "$MAIN_LESSONS")" 2>/dev/null || true
  cp "$WT_LESSONS" "$MAIN_LESSONS" 2>/dev/null || true
  log "Copied worktree lessons.md to main repo"
  exit 0
fi

# Both exist — compare and sync new entries
MAIN_ENTRIES=$(grep -c "^### " "$MAIN_LESSONS" 2>/dev/null || echo "0")
WT_ENTRIES=$(grep -c "^### " "$WT_LESSONS" 2>/dev/null || echo "0")

if [ "$WT_ENTRIES" -gt "$MAIN_ENTRIES" ]; then
  NEW_COUNT=$((WT_ENTRIES - MAIN_ENTRIES))
  log "Syncing $NEW_COUNT new lessons from worktree to main repo"

  # Extract entries after MAIN_ENTRIES position and append to main
  awk -v start="$MAIN_ENTRIES" '
    /^### / { count++ }
    count > start { print }
  ' "$WT_LESSONS" >> "$MAIN_LESSONS" 2>/dev/null || true

  log "Sync complete: $NEW_COUNT entries appended"
else
  log "No new entries in worktree (main=$MAIN_ENTRIES, wt=$WT_ENTRIES)"
fi

# Also sync recent-memory.md if exists
WT_RECENT="$NORMALIZED_GIT/.claude/memory/recent-memory.md"
MAIN_RECENT="$NORMALIZED_PROJECT/.claude/memory/recent-memory.md"

if [ -f "$WT_RECENT" ] && [ -f "$MAIN_RECENT" ]; then
  diff "$MAIN_RECENT" "$WT_RECENT" 2>/dev/null | grep "^>" | sed 's/^> //' >> "$MAIN_RECENT" 2>/dev/null || true
  log "recent-memory.md synced"
fi

# Always exit 0 — this is a safety net, never block
exit 0
