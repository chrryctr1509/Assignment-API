#!/bin/bash
# rewrite-docker-pip.sh (Brief 28)
# PreToolUse hook: environment-aware rewrite of `pip *` / `pip3 *` → `docker exec -it <container> pip/pip3 *`
#
# Container heuristic: app|backend|api|python|django|flask|worker
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

if ! echo "$CMD" | grep -qE '(^|[;&|][[:space:]]*)[[:space:]]*(pip|pip3)[[:space:]]+'; then
  echo "$INPUT"
  exit 0
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

PIPELINE_STATE="$PROJECT_ROOT/docs/pipeline-state.md"
if [ -f "$PIPELINE_STATE" ]; then
  if grep -qiE '^[[:space:]]*-?[[:space:]]*project_mode[[:space:]]*:[[:space:]]*host\b' "$PIPELINE_STATE" 2>/dev/null; then
    echo "[rewrite-docker-pip] SKIP: project_mode=host" >&2
    echo "$INPUT"
    exit 0
  fi
fi

DOCKER_ASSESS="$PROJECT_ROOT/docs/docker-assessment.md"
if [ -f "$DOCKER_ASSESS" ]; then
  HOST_SECTION=$(sed -n '/^## *Host Services/,/^## /p' "$DOCKER_ASSESS" 2>/dev/null)
  if echo "$HOST_SECTION" | grep -qiE '\b(python|pip|django|flask)\b'; then
    echo "[rewrite-docker-pip] SKIP: python/pip in Host Services" >&2
    echo "$INPUT"
    exit 0
  fi
fi

COMPOSE_FILE=""
for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  if [ -f "$PROJECT_ROOT/$f" ]; then
    COMPOSE_FILE="$PROJECT_ROOT/$f"
    break
  fi
done

if [ -z "$COMPOSE_FILE" ]; then
  echo "[rewrite-docker-pip] SKIP: no docker-compose.yml" >&2
  echo "$INPUT"
  exit 0
fi

# Service regex priority: Python-specific names first, 'api' as last fallback.
# Brief 28.a removed 'app|backend' — generic names that overlap with PHP ecosystem
# caused wrong-container rewrites in mixed-ecosystem compose files.
# Edge case (Python service named 'app' without any python-specific peer):
# user can override via docs/docker-assessment.md Host Services table.
DETECTED=$(awk '/^services:/{f=1; next} /^[^[:space:]]/{f=0} f && /^  [a-zA-Z0-9_-]+:/{gsub(/[: ]/,""); print}' "$COMPOSE_FILE" | \
           grep -iE '^(python|django|flask|worker|api)$' | head -1)

if [ -z "$DETECTED" ]; then
  echo "[rewrite-docker-pip] SKIP: no python-related service (python|django|flask|worker|api)" >&2
  echo "$INPUT"
  exit 0
fi

CONTAINER="$DETECTED"

NEW_CMD=$(echo "$CMD" | sed -E "s#(^|[;&|][[:space:]]*)[[:space:]]*(pip|pip3)[[:space:]]+#\1docker exec -it $CONTAINER \2 #")

echo "[rewrite-docker-pip] $CMD → $NEW_CMD" >&2

echo "$INPUT" | jq --arg c "$NEW_CMD" '.tool_input.command = $c'
exit 0
