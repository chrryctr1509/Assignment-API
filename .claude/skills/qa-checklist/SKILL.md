---
name: qa-checklist
description: |
  Modular QA checklist pipeline — generate, interpret, and run deterministic test cases
  against any live app. Reads a .md checklist with test cases and expected values,
  executes each TC (API, browser, CLI, or manual), compares results against ground truth
  with configurable tolerances, and auto-fixes failures via be-developer/fe-developer.
  Project-agnostic: works across any stack.
allowed-tools:
  - Agent
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# QA Checklist Pipeline

## Overview

Deterministic QA pipeline that complements the exploratory `qa-tester` (pytest).
Three core agents work together:

| Agent | Role |
|-------|------|
| `qa-checklist-generator` | Analyzes codebase, generates checklist + config |
| `qa-checklist-interpreter` | Normalizes any-format checklist to standardized format |
| `qa-checklist-runner` | Executes TCs, compares results, generates report |

## Entry Point

Use the `/qa-checklist` command. Sub-modes:

```
/qa-checklist                     → interactive menu
/qa-checklist generate            → run generator only
/qa-checklist run                 → run runner (standardized checklist must exist)
/qa-checklist run --file path.md  → interpret file first, then run
/qa-checklist full                → generate + run
/qa-checklist config              → generate/update config only
```

## Standardized Checklist Format

The **contract** between all agents. See `templates/checklist-template.md` for the full spec.

Each TC declares:
- `strategy`: api | browser | browser-debug | cli | manual
- `priority`: critical | high | medium | low
- `needs` (optional, for browser-debug): network | upload | lighthouse
- `### Input`: endpoint+method+body (api), url+actions (browser), command (cli)
- `### Expected`: per-field comparison rules (exact, numeric_tolerance, contains, regex, exists, less_than, greater_than, json_subset)
- `### Test Data`: inline yaml or file path reference

Variables like `{{base_url}}`, `{{auth_token}}` are resolved from `docs/qa-project-config.md`.

## Project Config

Per-project config at `docs/qa-project-config.md`. See `templates/project-config-template.md`.

Contains: connection info, auth strategy, environment setup/teardown, test data locations, browser config.

## Integration with Existing Agents

- **qa-tester**: Complementary. qa-tester = exploratory (pytest). Runner = deterministic (checklist). Both can run.
- **user-simulator**: Runner's `browser` strategy delegates to GStack Browse.
- **Chrome DevTools MCP**: Runner's `browser-debug` strategy uses Chrome DevTools MCP for network inspection, file uploads, and Lighthouse audits.
- **be-developer / fe-developer**: Fix loop routes failures in code-review-report compatible format.
- **simulation-config-writer**: Generator reads `docs/user-simulation-config.md` for app flows and auth.

## Templates

```
templates/
  checklist-template.md        # Empty checklist with format spec
  project-config-template.md   # Empty config template
  report-template.md           # Report output template
```
