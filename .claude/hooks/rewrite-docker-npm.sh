#!/bin/bash
# rewrite-docker-npm.sh (Brief 28)
# PreToolUse hook: environment-aware rewrite of `npm *` / `npx *` → `docker exec -it <container> npm/npx *`
#
# 4-tier pre-flight detection (mirror dari rewrite-docker-artisan):
#   0. pipeline-state.md: project_mode=host → passthrough
#   1. docker-assessment.md Host Services lists node/npm → passthrough
#   2. docker-compose.yml missing → passthrough
#   3. docker-compose.yml has no frontend-related service → passthrough
#
# Container heuristic: frontend|web|node|ui|client (node.js stack conventions)
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

# Only act on npm/npx
if ! echo "$CMD" | grep -qE '(^|[;&|][[:space:]]*)[[:space:]]*(npm|npx)[[:space:]]+'; then
  echo "$INPUT"
  exit 0
fi

# Skip MCP-related npx calls (security-gate has MCP whitelist — these run on host by design)
if echo "$CMD" | grep -qE 'npx[[:space:]]+.*?(chrome-devtools-mcp|@playwright/mcp|@anthropic-ai)'; then
  echo "$INPUT"
  exit 0
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# === TIER 0: pipeline-state.md project_mode ===
PIPELINE_STATE="$PROJECT_ROOT/docs/pipeline-state.md"
if [ -f "$PIPELINE_STATE" ]; then
  if grep -qiE '^[[:space:]]*-?[[:space:]]*project_mode[[:space:]]*:[[:space:]]*host\b' "$PIPELINE_STATE" 2>/dev/null; then
    echo "[rewrite-docker-npm] SKIP: project_mode=host in pipeline-state.md" >&2
    echo "$INPUT"
    exit 0
  fi
fi

# === TIER 1: docker-assessment.md Host Services ===
DOCKER_ASSESS="$PROJECT_ROOT/docs/docker-assessment.md"
if [ -f "$DOCKER_ASSESS" ]; then
  HOST_SECTION=$(sed -n '/^## *Host Services/,/^## /p' "$DOCKER_ASSESS" 2>/dev/null)
  if echo "$HOST_SECTION" | grep -qiE '\b(node|npm|npx|frontend|yarn)\b'; then
    echo "[rewrite-docker-npm] SKIP: node/npm in Host Services (docker-assessment.md)" >&2
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
  echo "[rewrite-docker-npm] SKIP: no docker-compose.yml (bare host project)" >&2
  echo "$INPUT"
  exit 0
fi

# === TIER 3: Matching frontend service ===
DETECTED=$(awk '/^services:/{f=1; next} /^[^[:space:]]/{f=0} f && /^  [a-zA-Z0-9_-]+:/{gsub(/[: ]/,""); print}' "$COMPOSE_FILE" | \
           grep -iE '^(frontend|web|node|ui|client)$' | head -1)

if [ -z "$DETECTED" ]; then
  echo "[rewrite-docker-npm] SKIP: docker-compose.yml has no frontend-related service (frontend|web|node|ui|client)" >&2
  echo "$INPUT"
  exit 0
fi

CONTAINER="$DETECTED"

# === REWRITE ===
NEW_CMD=$(echo "$CMD" | sed -E "s#(^|[;&|][[:space:]]*)[[:space:]]*(npm|npx)[[:space:]]+#\1docker exec -it $CONTAINER \2 #")

echo "[rewrite-docker-npm] $CMD → $NEW_CMD" >&2

echo "$INPUT" | jq --arg c "$NEW_CMD" '.tool_input.command = $c'
exit 0
