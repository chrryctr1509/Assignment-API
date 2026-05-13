#!/usr/bin/env bash
# security-gate.sh — PreToolUse hook for Bash commands
# Blocks dangerous operations. Exit 2 + stderr = Claude reads and adjusts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

LOG_FILE="$SCRIPT_DIR/hook-log.txt"

log_block() {
  local reason="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED: $reason | cmd: $COMMAND" >> "$LOG_FILE"
  if [ -x ".claude/hooks/notify.sh" ]; then
    echo '{"message":"SECURITY BLOCK: '"$reason"'"}' | .claude/hooks/notify.sh 2>/dev/null || true
  fi
}

# Block: git push to protected branches (main, master, develop, staging)
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*\b(main|master|develop|staging)\b'; then
  log_block "git push to protected branch detected"
  echo "BLOCKED: git push to protected branch detected. Use feature branches and PR instead." >&2
  bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate" 2>/dev/null &
  exit 2
fi

# Block: git push --force and --force-with-lease
# Patched by SIM-11: L18/SIM-03 — explicit matching instead of substring grep
# Patched by SIM-11: SIM-10 — --force-with-lease also blocked (still overwrites remote)
# Order matters: check --force-with-lease BEFORE --force to avoid substring match
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force-with-lease'; then
  log_block "git push --force-with-lease is forbidden"
  echo "BLOCKED: git push --force-with-lease is forbidden. Use non-destructive push or request approval." >&2
  bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate" 2>/dev/null &
  exit 2
fi
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force'; then
  log_block "git push --force is forbidden"
  echo "BLOCKED: git push --force is forbidden. Use non-destructive push." >&2
  bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate" 2>/dev/null &
  exit 2
fi
if echo "$COMMAND" | grep -qE 'git\s+push\s+-f\b'; then
  log_block "git push -f (force) is forbidden"
  echo "BLOCKED: git push -f (force) is forbidden." >&2
  bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate" 2>/dev/null &
  exit 2
fi

# Block: destructive git operations (reset --hard, checkout --, clean -f)
# Added by agent-review: data-loss operations not caught by existing rules
if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
  log_block "git reset --hard is forbidden (data loss risk)"
  echo "BLOCKED: git reset --hard is forbidden. Use git stash or git revert instead." >&2
  bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate" 2>/dev/null &
  exit 2
fi
if echo "$COMMAND" | grep -qE 'git\s+checkout\s+--\s+\.'; then
  log_block "git checkout -- . is forbidden (discards all unstaged changes)"
  echo "BLOCKED: git checkout -- . is forbidden. Use git stash to save changes." >&2
  bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate" 2>/dev/null &
  exit 2
fi
if echo "$COMMAND" | grep -qE 'git\s+clean\s+-[a-zA-Z]*f'; then
  log_block "git clean -f is forbidden (permanently deletes untracked files)"
  echo "BLOCKED: git clean -f is forbidden. Review untracked files manually." >&2
  bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate" 2>/dev/null &
  exit 2
fi

# Block: DROP DATABASE, TRUNCATE, DELETE FROM WHERE 1
if echo "$COMMAND" | grep -qiE 'DROP\s+(DATABASE|TABLE)'; then
  log_block "DROP DATABASE/TABLE detected"
  echo "BLOCKED: DROP DATABASE/TABLE is forbidden." >&2
  bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate" 2>/dev/null &
  exit 2
fi
if echo "$COMMAND" | grep -qiE 'TRUNCATE\s+'; then
  log_block "TRUNCATE detected"
  echo "BLOCKED: TRUNCATE is forbidden." >&2
  bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate" 2>/dev/null &
  exit 2
fi
if echo "$COMMAND" | grep -qiE "DELETE\s+FROM\s+.*WHERE\s+1"; then
  log_block "DELETE FROM WHERE 1 (mass delete) detected"
  echo "BLOCKED: Mass DELETE detected." >&2
  bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate" 2>/dev/null &
  exit 2
fi

# Patched by SIM-11: L36/SIM-10 — artisan tinker --execute can bypass SQL guards
# Inspect the PHP code inside tinker --execute for dangerous SQL patterns
if echo "$COMMAND" | grep -qiE 'artisan\s+tinker\s+--execute'; then
  TINKER_CODE=$(echo "$COMMAND" | sed 's/.*--execute[= ]*//; s/^"//; s/"$//')
  if echo "$TINKER_CODE" | grep -qiE 'DROP\s+(DATABASE|TABLE)|TRUNCATE|DELETE\s+FROM.*WHERE\s+1|DB::statement.*DROP|DB::unprepared'; then
    log_block "Dangerous SQL in artisan tinker --execute"
    echo "BLOCKED: artisan tinker --execute contains dangerous SQL pattern. Use migrations instead." >&2
    bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate" 2>/dev/null &
    exit 2
  fi
fi

# === SAFE CLEANUP WHITELIST (BEFORE rm -rf block) ===
# Allow rm -rf on known safe directories that agents legitimately need to clean
if echo "$COMMAND" | grep -qE 'rm\s+-r[f]*\s' ; then
  # Worktree cleanup (agent worktrees after pipeline)
  if echo "$COMMAND" | grep -qE '\.claude/worktrees/'; then
    echo "[$(date '+%H:%M:%S')] CLEANUP-ALLOW: worktree cleanup" >> "$LOG_FILE"
    exit 0
  fi
  # Build artifact cleanup (stale build, Fix Protocol Step 2)
  if echo "$COMMAND" | grep -qE '(node_modules/\.cache|__pycache__|\.pytest_cache|\.next/|\.nuxt/|dist/|build/|out/|\.vite/)'; then
    echo "[$(date '+%H:%M:%S')] CLEANUP-ALLOW: build artifact cleanup" >> "$LOG_FILE"
    exit 0
  fi
  # Video frame cleanup (post-pipeline)
  if echo "$COMMAND" | grep -qE 'docs/video-frames/'; then
    echo "[$(date '+%H:%M:%S')] CLEANUP-ALLOW: video frames cleanup" >> "$LOG_FILE"
    exit 0
  fi
  # Git worktree prune (safe git maintenance)
  if echo "$COMMAND" | grep -qE 'git\s+worktree\s+prune'; then
    echo "[$(date '+%H:%M:%S')] CLEANUP-ALLOW: git worktree prune" >> "$LOG_FILE"
    exit 0
  fi
fi

# Block: rm -rf at SYSTEM root or truly critical directories
# Fixed: match only paths that START with system dirs, not paths containing them
if echo "$COMMAND" | grep -qE 'rm\s+-r[f]*\s+\s*(\/\s|\/home\s|\/home\/\s|\/var\s|\/etc\s|\/usr\s|\.\.\s|\.\.\/)'; then
  log_block "rm -rf on critical system directory detected"
  echo "BLOCKED: rm -rf on critical system directory." >&2
  bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate" 2>/dev/null &
  exit 2
fi
# Also block rm -rf / (root filesystem)
if echo "$COMMAND" | grep -qE 'rm\s+-r[f]*\s+/$'; then
  log_block "rm -rf / detected"
  echo "BLOCKED: rm -rf / is forbidden." >&2
  bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate" 2>/dev/null &
  exit 2
fi

# Block: curl/wget to non-allowed URLs
if echo "$COMMAND" | grep -qE '(curl|wget)\s' ; then
  if ! echo "$COMMAND" | grep -qE '(localhost|127\.0\.0\.1|github\.com|raw\.githubusercontent\.com|api\.github\.com|gist\.githubusercontent\.com|gitlab\.com|api\.gitlab\.com|api\.telegram\.org|registry\.npmjs\.org|pypi\.org|packagist\.org|rubygems\.org|proxy\.golang\.org|repo1\.maven\.org|dl\.google\.com|stackoverflow\.com|docs\.python\.org|docs\.djangoproject\.com|laravel\.com|vuejs\.org|reactjs\.org|nodejs\.org|developer\.mozilla\.org)'; then
    log_block "curl/wget to external URL not in allowlist"
    echo "BLOCKED: curl/wget to external URL not in allowlist. Gunakan WebFetch tool untuk akses URL eksternal — WebFetch tidak di-block oleh security-gate." >&2
    bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate" 2>/dev/null &
    exit 2
  fi
fi

# === DOCKER ENFORCEMENT ===
# Block bare host commands if Docker assessment shows service should be dockerized
DOCKER_ASSESS="$PROJECT_ROOT/docs/docker-assessment.md"
BARE_COMMANDS="^(npm |npx |pip |pip3 |composer |php |python |python3 |pytest |phpunit |jest |node )"

# === REWRITABLE COMMANDS EXCEPTION (Brief 27.a) ===
# Commands below have corresponding rewrite hooks (PreToolUse) that auto-prepend `docker exec`.
# Since PreToolUse hooks run in parallel and block > rewrite in Claude Code semantics,
# security-gate MUST allow these patterns to let the rewrite hook do its job.
#
# WHEN TO EDIT: when adding new rewrite-docker-* hook, add pattern here.
# WHEN TO REFACTOR: if this list exceeds 5 patterns (NOTE: Brief 28 extended to 5 — at threshold;
# next addition should trigger registry refactor), consider migrating to
# .claude/hooks/rewritable-commands.txt registry (see Brief 29 decision point).
REWRITABLE_PATTERNS="^[[:space:]]*(php[[:space:]]+artisan|npm|npx|composer|pip|pip3)\b"

if [ -n "$COMMAND" ] && echo "$COMMAND" | grep -qE "$REWRITABLE_PATTERNS"; then
  echo "[$(date '+%H:%M:%S')] REWRITABLE-ALLOW: pattern matches rewrite hook (will be rewritten)" >> "$LOG_FILE"
  exit 0
fi
# === END REWRITABLE COMMANDS EXCEPTION ===

if [ -n "$COMMAND" ] && echo "$COMMAND" | grep -qE "$BARE_COMMANDS"; then
  # Check: is this a docker exec command? If yes, ALLOW
  if ! echo "$COMMAND" | grep -q "docker exec"; then
    # === MCP SERVER WHITELIST ===
    # MCP server commands via npx run on host, not in Docker containers
    MCP_WHITELIST="chrome-devtools-mcp|@playwright/mcp|@anthropic-ai"
    if echo "$COMMAND" | grep -qE "npx.*(${MCP_WHITELIST})"; then
      echo "[$(date '"'"'+%H:%M:%S'"'"')] MCP-ALLOW: npx MCP server command" >> "$LOG_FILE"
      exit 0
    fi
    # Also allow if command matches a server arg from project .mcp.json
    if [ -f "$PROJECT_ROOT/.mcp.json" ]; then
      MCP_HIT=$(python3 -c "
import json,sys
try:
  with open('"'"'$PROJECT_ROOT/.mcp.json'"'"') as f: d=json.load(f)
  cmd='"'"'$COMMAND'"'"'
  for n,c in d.get('"'"'mcpServers'"'"',{}).items():
    for a in c.get('"'"'args'"'"',[]):
      if a in cmd and not a.startswith('"'"'-'"'"'): print('"'"'y'"'"');sys.exit(0)
except: pass
" 2>/dev/null) || true
      if [ "$MCP_HIT" = "y" ]; then
        echo "[$(date '"'"'+%H:%M:%S'"'"')] MCP-ALLOW: matches .mcp.json server" >> "$LOG_FILE"
        exit 0
      fi
    fi
    # Check: is this service in host_services?
    if [ -f "$DOCKER_ASSESS" ]; then
      CMD_NAME=$(echo "$COMMAND" | awk '{print $1}')
      HOST_SECTION=$(sed -n '/Host Services/,/Execution Rules/p' "$DOCKER_ASSESS" 2>/dev/null)
      if echo "$HOST_SECTION" | grep -qi "$CMD_NAME"; then
        echo "[$(date '+%H:%M:%S')] HOST-ALLOW: $CMD_NAME (in host_services)" >> "$LOG_FILE"
        exit 0
      fi
    fi
    # Service NOT in host_services — BLOCK with AUTO-HINT
    CMD_NAME=$(echo "$COMMAND" | awk '{print $1}')

    # AUTO-HINT: Try to detect the correct container from docker-assessment.md
    CONTAINER=""
    if [ -f "$DOCKER_ASSESS" ]; then
      case "$CMD_NAME" in
        php|composer|phpunit) CONTAINER=$(sed -n '/php\|laravel\|app/s/.*container:\s*\(\S\+\).*/\1/Ip' "$DOCKER_ASSESS" 2>/dev/null | head -1 || true) ;;
        npm|npx|node|jest)   CONTAINER=$(sed -n '/node\|frontend\|fe/s/.*container:\s*\(\S\+\).*/\1/Ip' "$DOCKER_ASSESS" 2>/dev/null | head -1 || true) ;;
        python|python3|pip|pip3|pytest) CONTAINER=$(sed -n '/python\|backend\|api/s/.*container:\s*\(\S\+\).*/\1/Ip' "$DOCKER_ASSESS" 2>/dev/null | head -1 || true) ;;
      esac
    fi

    if [ -n "$CONTAINER" ]; then
      echo "BLOCKED: '$CMD_NAME' must run in Docker container." >&2
      echo "AUTO-HINT: Use instead: docker exec -it $CONTAINER $COMMAND" >&2
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED+HINT: bare $CMD_NAME -> docker exec -it $CONTAINER (auto-hint)" >> "$LOG_FILE"
    else
      echo "BLOCKED: '$CMD_NAME' must run in Docker container. Use: docker exec -it [container] $COMMAND" >&2
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED: bare $CMD_NAME (must use docker exec)" >> "$LOG_FILE"
    fi
    bash "$PROJECT_ROOT/.claude/telegram/notify-blocked.sh" "$COMMAND" "security-gate:docker-enforce" 2>/dev/null &
    exit 2
  fi
fi

exit 0