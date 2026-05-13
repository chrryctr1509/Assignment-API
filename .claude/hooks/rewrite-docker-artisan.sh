#!/bin/bash
# rewrite-docker-artisan.sh (Brief 27 + 27.b)
# PreToolUse hook: environment-aware rewrite of `php artisan *` → `docker exec -it <container> php artisan *`
#
# 4-tier pre-flight detection (any "NO" → passthrough silently):
#   0. pipeline-state.md: project_mode=host → passthrough (orchestrator decision)
#   1. docker-assessment.md Host Services lists php → passthrough (user preference)
#   2. docker-compose.yml missing → passthrough (no infrastructure)
#   3. docker-compose.yml has no matching service → passthrough + warn
# All tiers say "docker" → rewrite
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

# Skip if already docker
if echo "$CMD" | grep -qE '^[[:space:]]*docker[[:space:]]+(exec|compose)'; then
  echo "$INPUT"
  exit 0
fi

# Only act on php artisan
if ! echo "$CMD" | grep -qE '(^|[;&|][[:space:]]*)[[:space:]]*php[[:space:]]+artisan\b'; then
  echo "$INPUT"
  exit 0
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# === TIER 0: pipeline-state.md project_mode ===
# Orchestrator (future Brief 31) can write `project_mode: host` to explicitly
# opt-out of Docker rewrites. This is the highest-priority signal.
PIPELINE_STATE="$PROJECT_ROOT/docs/pipeline-state.md"
if [ -f "$PIPELINE_STATE" ]; then
  if grep -qiE '^[[:space:]]*-?[[:space:]]*project_mode[[:space:]]*:[[:space:]]*host\b' "$PIPELINE_STATE" 2>/dev/null; then
    echo "[rewrite-docker-artisan] SKIP: project_mode=host in pipeline-state.md" >&2
    echo "$INPUT"
    exit 0
  fi
fi

# === TIER 1: docker-assessment.md Host Services ===
DOCKER_ASSESS="$PROJECT_ROOT/docs/docker-assessment.md"
if [ -f "$DOCKER_ASSESS" ]; then
  HOST_SECTION=$(sed -n '/^## *Host Services/,/^## /p' "$DOCKER_ASSESS" 2>/dev/null)
  if echo "$HOST_SECTION" | grep -qiE '\b(php|artisan|laravel)\b'; then
    echo "[rewrite-docker-artisan] SKIP: php in Host Services (docker-assessment.md)" >&2
    echo "$INPUT"
    exit 0
  fi
fi

# === TIER 2: docker-compose.yml presence ===
COMPOSE_FILE=""
for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  if [ -f "$PROJECT_ROOT/$f" ]; then
    COMPOSE_FILE="$PROJECT_ROOT/$f"
    break
  fi
done

if [ -z "$COMPOSE_FILE" ]; then
  echo "[rewrite-docker-artisan] SKIP: no docker-compose.yml (bare host project)" >&2
  echo "$INPUT"
  exit 0
fi

# === TIER 3: Matching service in compose ===
DETECTED=$(awk '/^services:/{f=1; next} /^[^[:space:]]/{f=0} f && /^  [a-zA-Z0-9_-]+:/{gsub(/[: ]/,""); print}' "$COMPOSE_FILE" | \
           grep -iE '^(app|laravel|backend|php|api)$' | head -1)

if [ -z "$DETECTED" ]; then
  echo "[rewrite-docker-artisan] SKIP: docker-compose.yml has no php-related service (app|laravel|backend|php|api)" >&2
  echo "$INPUT"
  exit 0
fi

CONTAINER="$DETECTED"

# === REWRITE ===
NEW_CMD=$(echo "$CMD" | sed -E "s#(^|[;&|][[:space:]]*)[[:space:]]*(php[[:space:]]+artisan)\b#\1docker exec -it $CONTAINER \2#")

echo "[rewrite-docker-artisan] $CMD → $NEW_CMD" >&2

echo "$INPUT" | jq --arg c "$NEW_CMD" '.tool_input.command = $c'
exit 0
