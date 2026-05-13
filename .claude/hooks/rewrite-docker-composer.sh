#!/bin/bash
# rewrite-docker-composer.sh (Brief 28)
# PreToolUse hook: environment-aware rewrite of `composer *` → `docker exec -it <container> composer *`
#
# Container heuristic: app|laravel|backend|php|api (same as artisan — PHP ecosystem)
#
# Requires: Claude Code v2.0.10+, jq
# Invoked by: .claude/hooks/dispatcher.ts

set -e

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$CMD" ]; then
  echo "$INPUT"
  exit 0
fi

if echo "$CMD" | grep -qE '^[[:space:]]*docker[[:space:]]+(exec|compose)'; then
  echo "$INPUT"
  exit 0
fi

if ! echo "$CMD" | grep -qE '(^|[;&|][[:space:]]*)[[:space:]]*composer[[:space:]]+'; then
  echo "$INPUT"
  exit 0
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# === TIER 0 ===
PIPELINE_STATE="$PROJECT_ROOT/docs/pipeline-state.md"
if [ -f "$PIPELINE_STATE" ]; then
  if grep -qiE '^[[:space:]]*-?[[:space:]]*project_mode[[:space:]]*:[[:space:]]*host\b' "$PIPELINE_STATE" 2>/dev/null; then
    echo "[rewrite-docker-composer] SKIP: project_mode=host in pipeline-state.md" >&2
    echo "$INPUT"
    exit 0
  fi
fi

# === TIER 1 ===
DOCKER_ASSESS="$PROJECT_ROOT/docs/docker-assessment.md"
if [ -f "$DOCKER_ASSESS" ]; then
  HOST_SECTION=$(sed -n '/^## *Host Services/,/^## /p' "$DOCKER_ASSESS" 2>/dev/null)
  if echo "$HOST_SECTION" | grep -qiE '\b(php|composer|laravel)\b'; then
    echo "[rewrite-docker-composer] SKIP: php/composer in Host Services (docker-assessment.md)" >&2
    echo "$INPUT"
    exit 0
  fi
fi

# === TIER 2 ===
COMPOSE_FILE=""
for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  if [ -f "$PROJECT_ROOT/$f" ]; then
    COMPOSE_FILE="$PROJECT_ROOT/$f"
    break
  fi
done

if [ -z "$COMPOSE_FILE" ]; then
  echo "[rewrite-docker-composer] SKIP: no docker-compose.yml (bare host project)" >&2
  echo "$INPUT"
  exit 0
fi

# === TIER 3 ===
# Service regex priority: PHP-specific names first, generic 'app|backend' as fallback.
# Brief 28.a removed 'api' — 'api' is typically a Python service name and was
# overlapping with pip/Python ecosystem. Reordered so 'laravel|php' (PHP-specific)
# match before 'app|backend' (generic).
DETECTED=$(awk '/^services:/{f=1; next} /^[^[:space:]]/{f=0} f && /^  [a-zA-Z0-9_-]+:/{gsub(/[: ]/,""); print}' "$COMPOSE_FILE" | \
           grep -iE '^(laravel|php|app|backend)$' | head -1)

if [ -z "$DETECTED" ]; then
  echo "[rewrite-docker-composer] SKIP: no php-related service (laravel|php|app|backend)" >&2
  echo "$INPUT"
  exit 0
fi

CONTAINER="$DETECTED"

# === REWRITE ===
NEW_CMD=$(echo "$CMD" | sed -E "s#(^|[;&|][[:space:]]*)[[:space:]]*composer[[:space:]]+#\1docker exec -it $CONTAINER composer #")

echo "[rewrite-docker-composer] $CMD → $NEW_CMD" >&2

echo "$INPUT" | jq --arg c "$NEW_CMD" '.tool_input.command = $c'
exit 0
