# Claude Team Agents — Usage Guide

How to install, configure, and run the autonomous agent team in any project.

> For project architecture, agent roster, and hooks reference, see **README.md**.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Setup](#2-setup)
3. [Configure Credentials](#3-configure-credentials)
4. [Setup Telegram Bot](#4-setup-telegram-bot)
5. [Running Modes](#5-running-modes)
6. [Telegram Commands](#6-telegram-commands)
7. [Pipeline Commands](#7-pipeline-commands)
8. [Usage Scenarios](#8-usage-scenarios)
9. [Cross-Platform Setup](#9-cross-platform-setup)
10. [MCP Server Setup](#10-mcp-server-setup)
11. [Flow Optimization & Cost Tips](#11-flow-optimization--cost-tips)
12. [Docker-First Architecture](#12-docker-first-architecture)
13. [Context Resilience Protocol](#13-context-resilience-protocol)
14. [Environment-Specific Setup](#14-environment-specific-setup)
15. [Troubleshooting](#15-troubleshooting)
16. [Quick Reference Card](#16-quick-reference-card)

---

## 1. Prerequisites

### System Requirements

- **Claude Code CLI** v2.1.80+ installed and authenticated
- **Bun** runtime installed (required by hook dispatcher + native channel plugins)
- **Bash** shell (Linux, macOS, or WSL on Windows)
- **tmux** installed (required for Telegram bidirectional mode)
- **jq** installed (JSON processing in hooks and daemon) — v1.6+
- **curl** installed (Telegram API calls)
- **Git** 2.35+ initialized in your project (required for worktree support)
- **ffmpeg** installed (required for video input processing — frame extraction)
- **Docker** 24+ and **Docker Compose** v2+ (recommended for most stacks)
- **Node** 18+ (for hooks that use npx)
- **MCP Servers** (optional but recommended for browser testing):
  - Chrome DevTools MCP: auto-installed via npx
  - Playwright MCP: auto-installed via npx
  - Configured in `.mcp.json` at project root (portable, no hardcoded paths)

### Install Missing Tools

```bash
# Ubuntu/Debian/WSL
sudo apt install tmux jq curl git ffmpeg
curl -fsSL https://bun.sh/install | bash

# macOS
brew install tmux jq curl git bun gnu-sed ffmpeg

# Docker (if not installed)
curl -fsSL https://get.docker.com | sh
```

### Windows (PowerShell) Prerequisites

setup.ps1 auto-installs missing tools via **winget** or **Chocolatey**:
- git, jq, node, docker, ffmpeg → via `winget install` (preferred) or `choco install`
- bun → via official PowerShell installer (`irm bun.sh/install.ps1 | iex`)
- claude → manual install only (`npm install -g @anthropic-ai/claude-code`)
- tmux → **not available on native Windows** (Telegram bidirectional requires WSL)
- WSL → checked automatically; warns if missing with install instructions

> **Note:** setup.ps1 checks for WSL availability. If WSL is not installed,
> it warns that Telegram bidirectional mode will not work, but continues setup.
> All other agent features work on native Windows.

### Verify Claude Code

```bash
claude --version
# Should be v2.1.80 or higher
```

### Claude Code Plan

Agent Teams require a **Claude Max plan** or **API key with Opus 4.6 access**.

---

## 2. Setup

### Quick Setup (Recommended)

**Linux / macOS / WSL:**

```bash
cd /path/to/claude-team-agents
chmod +x setup.sh
./setup.sh /path/to/your-project
```

**Windows (PowerShell):**

```powershell
cd C:\path\to\claude-team-agents
.\setup.ps1 C:\path\to\your-project
```

### What setup.sh / setup.ps1 do

Both scripts follow the same steps with platform-specific implementation:

| Step | What | setup.sh | setup.ps1 |
|------|------|----------|-----------|
| 0 | System Prerequisites | Detects OS (WSL/macOS/Debian/RedHat/Arch), auto-install via apt/brew/dnf/pacman | Detects Windows version, auto-install via winget/choco, checks WSL |
| 1 | Copy agent system | Smart merge with config preservation | Same (Copy-Item with backup) |
| 2 | Clean runtime state | Remove PIDs/logs/queues + **reset memory files** | Same + **reset memory files** |
| 3 | Make scripts executable | `chmod +x .claude/hooks/*.sh` | N/A (Windows doesn't need chmod) |
| 4 | Orchestrator patch | Native sed/head/tail | Via Git Bash fallback |
| 1.5 | Generate CLAUDE.md | Minimal CLAUDE.md with section markers + fix-protocol | Same |
| 1.5.1 | **settings.local.json** | Generate template if missing (smart merge) or fresh; validate JSON + warn if no tokens | Same |
| 5 | Update .gitignore | Append missing entries | Same |
| 5.5 | **MCP Server Setup** | Copy .mcp.json, check npx, merge global settings via jq, auto-detect Chrome/Chromium binary and set CHROME_PATH | Copy .mcp.json, check npx, merge global settings via ConvertFrom-Json, auto-detect Chrome paths |
| 6 | Verify setup | Check dirs, files, executability, count | Check dirs, files, count |

> Both produce identical results. Choose based on your OS.

> **Telegram bidirectional mode** requires tmux (Linux/macOS/WSL only).
> setup.ps1 checks for WSL automatically — if available, Telegram works via WSL bridge.
> If WSL is not installed: `wsl --install -d Ubuntu`

### Manual Setup (if you prefer)

<details>
<summary>Click to expand manual steps</summary>

```bash
# 1. Copy
cp -r .claude /path/to/<YOUR_PROJECT>/.claude
cp -r docs /path/to/<YOUR_PROJECT>/docs 2>/dev/null

# 2. Clean state
cd /path/to/<YOUR_PROJECT>
rm -f .claude/telegram/daemon.pid .claude/telegram/injector.pid
rm -f .claude/telegram/daemon.log .claude/telegram/injector.log
rm -f .claude/hooks/hook-log.txt

# 3. Make executable
chmod +x .claude/telegram/*.sh .claude/hooks/*.sh .claude/scripts/*.sh

# 4. Verify
ls .claude/
# Expected: agents/ commands/ hooks/ memory/ scripts/ skills/ telegram/
```

</details>

---

## 3. Configure Credentials

### Option A: Via settings.local.json (Recommended)

```json
{
  "env": {
    "TELEGRAM_BOT_TOKEN": "your-bot-token-here",
    "TELEGRAM_CHAT_ID": "your-chat-id-here",
    "GITLAB_TOKEN": "your-gitlab-token-here",
    "GITLAB_REPO_URL": "https://gitlab.com/your/repo"
  },
  "permissions": {
    "allow": [
      "Bash(chmod +x .claude/telegram/*.sh)",
      "Bash(bash .claude/telegram/manage.sh stop)",
      "Bash(bash .claude/telegram/manage.sh start)",
      "Bash(bash .claude/telegram/manage.sh start-channels)",
      "Bash(bash .claude/telegram/manage.sh status)"
    ]
  }
}
```

`settings.local.json` is per-machine — do NOT commit to git.

> **New:** `setup.sh` auto-generates this template. See `.claude/SETTINGS-LOCAL-README.md` for field-by-field guide.
> Template includes GitHub fields and expanded permissions (docker compose, git read-only commands).

### Option B: Via .env file

```bash
# GIT PLATFORM (choose one)
GITLAB_TOKEN=glpat-xxxxxxxxxxxxxxxxxxxx
GITLAB_REPO_URL=https://gitlab.com/username/repo-name
# OR
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx

# DATABASE
DB_ENGINE=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=myapp
DB_USERNAME=root
DB_PASSWORD=secret

# TELEGRAM
TELEGRAM_BOT_TOKEN=your-bot-token-here
TELEGRAM_CHAT_ID=your-chat-id-here
```

**Token permissions:**

| Platform | Where to create | Required scopes |
|----------|----------------|-----------------|
| GitLab | User Settings → Access Tokens | `api`, `read_repository`, `write_repository` |
| GitHub | Settings → Developer Settings → PAT | `repo` (full control) |

### Option C: Use both (most robust)

Put credentials in both files. Claude Code reads `settings.local.json`; standalone daemon reads `.env`.

---

## 4. Setup Telegram Bot

### Step 1: Create a bot

1. Open Telegram → search `@BotFather` → send `/newbot`
2. Name your bot and set a username
3. Copy the **bot token** (e.g. `1234567890:ABCdefGHIjklMNOpqrsTUVwxyz`)

### Step 2: Get your Chat ID

1. Search `@userinfobot` in Telegram → send `/start`
2. Copy your **Chat ID** (a number like `5211366883`)

### Step 3: Run the setup wizard

```bash
bash .claude/telegram/setup-telegram.sh
```

This validates credentials, registers bot commands, and sends a test message.

### Notifications Sent by the Bot

| Event | When |
|-------|------|
| Pipeline start | After context analysis |
| Security block | When hook blocks an operation |
| PR ready | After PR is created |
| Pipeline complete | After all work is done |

### File Uploads via Telegram

Send a `.docx` file directly to the bot → auto-starts a pipeline with the brief.

Send a video file (`.mp4`, `.mov`, `.webm`, `.avi`, `.mkv`) → auto-extracts frames via ffmpeg and starts pipeline with video context.

Videos can be sent as a Telegram video or as a document attachment — both are handled. **Note:** Telegram Bot API limits file downloads to 20MB. For larger videos, upload manually to `briefs/` folder.

---

## 5. Running Modes

### Mode 1: Terminal Only (no Telegram)

```bash
cd /path/to/your-project
claude
# Then type: /start <your task>
```

### Mode 2: Terminal + Custom Telegram (file-queue mode)

```bash
# Auto-wrapper (recommended) — creates tmux, starts daemon, launches Claude
bash .claude/telegram/claude-agent.sh
```

### Mode 3: Terminal + Native Channels (best experience)

```bash
bash .claude/telegram/claude-agent.sh --channels plugin:telegram@claude-plugins-official
```

**First-time channel setup** (one-time only):
```bash
claude
/plugin install telegram@claude-plugins-official
/reload-plugins
/telegram:configure <your-bot-token>
# Exit, restart with --channels flag
# Send message to bot → get pairing code
/telegram:access pair <code>
/telegram:access policy allowlist
```

### Mode 4: Full Remote (Telegram only)

```bash
bash .claude/telegram/manage.sh start
# Then from Telegram: /run <your task>
```

### Windows (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File .claude\telegram\claude-agent.ps1
```

Uses SendKeys API instead of tmux. Terminal must be in foreground for Telegram responses.

---

## 6. Telegram Commands

| Command | Description |
|---------|-------------|
| `/status` | Show pipeline status and pending questions |
| `/approve` | Approve a waiting pipeline |
| `/reject` | Reject and stop pipeline |
| `/run <task>` | Start a new pipeline remotely |
| `/cancel` | Kill the running pipeline session |
| `/queue` | Show queued tasks |
| `/log` | Show last 10 hook log entries |
| `/retro` | Trigger retrospective analysis |

Send a `.docx` file directly to the bot → auto-starts a pipeline with the brief.
Send a video file (`.mp4`/`.mov`/`.webm`/`.avi`/`.mkv`) → auto-extracts frames and starts pipeline with video context.
Video > 20MB → upload manually to `briefs/` (Telegram Bot API limit).

---

## 7. Pipeline Commands

### Available Commands

| Command | What it does |
|---------|-------------|
| `/start <task>` | Full pipeline: analyze → plan → approve → build → review → PR |
| `/start <question>` | Discussion mode: analyze codebase, present options, consult before building |
| `/start resume` | Resume interrupted pipeline from last checkpoint |
| `/review-and-fix` | Review changed files + fix issues |
| `/qa-checklist full` | Generate QA checklist → run → report |
| `/qa-checklist run --file test.xlsx` | Run existing checklist from file |
| `/retro` | Retrospective analysis |
| `/clean` | Save state and exit cleanly |
| `/verify` | Re-run post-build verification pipeline standalone |

### /verify — Smart Verification

Run verification standalone with awareness of QA already done. Detects existing per-wave QA reports and qa-summary freshness before routing.

```
/verify                 — smart mode (skips phases already covered by per-wave QA or fresh qa-summary)
/verify --full          — force full V1-V6, ignore caches
/verify --skip-boot     — skip V1-V2 if app already running (start at V3)
/verify --wave N        — re-run qa-tester WAVE-SCOPED only for Wave N (updates docs/qa-wave-N.md)
/verify --adversarial   — adversarial testing only (input/state/data/concurrent attacks)
```

**When to use which:**
- After manual fixes scoped to one wave → `/verify --wave N` (fastest)
- After env/credential changes → `/verify --skip-boot` (app already up)
- To stress-test robustness → `/verify --adversarial`
- When you don't trust cached QA → `/verify --full`
- Everything else → `/verify` (respects cached results)

### Scope Verification (all inputs)

Before any pipeline starts, the orchestrator verifies scope with the user:

- **Clear task** (e.g. "add JWT auth"): shows scope type, effort estimate, agent list. User confirms with "Proceed" or "Discuss first".
- **Clear discussion** (e.g. "what should we build next?"): enters DISCUSSION mode directly.
- **Ambiguous** (e.g. "improve login performance"): presents A/B choice — discuss first or build immediately.

No pipeline ever starts without explicit user confirmation.

### Video as Input

Video files can be attached to any pipeline mode. Frames are auto-extracted via ffmpeg before the pipeline starts:

```
/start briefs/design-ref.mp4                          — analyze video flow
/start Bug: form error briefs/bug.mp4                  — bug fix with video evidence
/start Revisi desain checkout briefs/competitor.webm   — build with video reference
```

### Pipeline Flow by Scope

```
DISCUSSION (pre-pipeline consultation — no code written):
  D1: codebase-scout → read project state
  D2: present project analysis (stack, improvements, known issues)
  D3: iterative Q&A (options, comparisons, effort estimates, web research)
  D4: user says "go ahead" → transition to pipeline below
  ⤷ WebSearch + WebFetch for tech comparisons, benchmarks, latest docs

GREENFIELD / NEW_FEATURE (full pipeline):
  Phase 0   → codebase-scout + brief-reader + pm-agent (parallel)
  Phase 0B  → convention-scout + design-director (parallel)
  Phase 0C  → scope completion validation (all input items matched?)
  Phase 1   → wave-planner + code-architect
  Phase 1B  → deliberation protocol (understood/unknown/assumptions/risks)
  APPROVE   → terminal or Telegram
  Phase 2.5 → pre-implementation analysis gate
  Phase 2   → foundation (greenfield only)
  Phase 3   → be-developer + fe-developer per wave (parallel Agent Teams)
              + TDD Protocol (test-first) + runability check + browser verification (fe)
              + git-manager pre-commit regression gate (blocks commit on test fail)
              + Phase 3.N.QA Wave QA Gate (qa-tester WAVE-SCOPED per wave, max 2 re-fix)
  Phase 4   → Pre-QA Setup (env collection + boot + health check)
  Phase 5   → Final QA — Integration Focus (E2E + adversarial A1-A4 + spec SC1-SC6 + audit)
              + doc-updater aggregates qa-wave-*.md → docs/qa-summary.md
  Phase 6   → code-reviewer + security-check (parallel review)
  Fix       → fix-strategist → developer → re-review (max 3 cycles, compact between)
  Critic    → GO / NO-GO
  Delivery  → docs/delivery-report.md + user guidance + revision guard
  PR        → develop → main
  Post      → post-pipeline docs refresh

BUG_FIX (optimized — 49% fewer tokens):
  codebase-scout → tracer → developer → code-reviewer → critic → pr-creator
  ⤷ SKIPS: brief-reader, pm-agent, convention-scout, code-architect, wave-planner

SMALL_EDIT (minimal — ~90% fewer tokens):
  be/fe-developer (haiku) → code-reviewer → commit
  ⤷ Escalates to BUG_FIX if re-review fails
  ⤷ SKIPS: all planning, all QA, critic
```

---

## 8. Usage Scenarios

### Scenario A: Greenfield (Project from scratch)

```bash
mkdir -p ~/project/apps/my-project && cd ~/project/apps/my-project
git init && git checkout -b develop
./setup.sh .    # or copy .claude/ manually
# Create .env + remote repo
claude
/start briefs/brief.docx
# OR: /start Build an e-commerce app with Laravel + React + MySQL
```

**Cost estimate:** ~720K tokens, ~$12

**Checklist:**
- [ ] Empty project folder with `git init` + `develop` branch
- [ ] `.claude/` copied and scripts executable
- [ ] `.env` with credentials (Git token + DB + Telegram)
- [ ] Remote repo created + `git remote add origin`
- [ ] Docker running

---

### Scenario B: New Feature

```bash
cd ~/project/apps/existing-project
git checkout develop && git pull
docker compose up -d
claude
/start briefs/brief-export-pdf.docx
# OR: /start Add PDF export for reports page with company logo
```

**Cost estimate:** ~500K tokens, ~$8

---

### Scenario C: Bug Fix

```bash
cd ~/project/apps/existing-project
git checkout develop && git pull
docker compose up -d
claude
/start Bug: checkout button errors on mobile. Blank screen at viewport < 768px.
```

**Cost estimate:** ~90K tokens, ~$4 (optimized — skips 5 planning agents)

---

### Scenario D: Small Edit

```bash
claude
/start Change primary button color from blue to green (#2D6A4F)
/start Update copyright year from 2025 to 2026 in footer
```

Spawns a developer agent (haiku) for the edit + code-reviewer. If review fails, escalates to BUG_FIX mode automatically.

**Cost estimate:** ~25K tokens, ~$1

---

### Scenario D2: Discussion (Explore Before Building)

```bash
claude
/start I want to improve the trading platform
/start what should we build next?
/start help me decide between WebSocket and SSE
/start the dashboard feels slow, what can we do?
/start explore notification options
```

Orchestrator enters DISCUSSION mode:
1. Reads codebase, project history, known issues
2. Presents analysis with improvement areas and questions
3. You discuss options, compare approaches, estimate effort
4. Web research (WebSearch/WebFetch) for benchmarks and latest docs
5. When ready, say "go ahead" to transition to pipeline

**Cost estimate:** ~5-15K tokens per discussion round (no pipeline cost until you confirm)

---

### Scenario D3: Video Input (Design Reference or Bug Recording)

```bash
claude
# Referensi desain dari screen recording
/start briefs/reference-flow.mp4

# Bug report dengan screen recording
/start Bug: form submit error, lihat briefs/bug-recording.mov

# Video sebagai attachment ke task lain
/start revisi desain checkout seperti di video briefs/competitor.webm

# Analisis flow dari video
/start lihat video ini dan analisis flow-nya briefs/app-demo.mp4
```

Orchestrator extracts video frames via ffmpeg (smart sampling berdasarkan durasi), then distributes frames ke agent yang relevan (design-director, fe-developer, tracer) sebagai visual context.

**Requirements:** ffmpeg terinstall (auto-checked oleh setup.sh/setup.ps1)
**Supported formats:** .mp4, .mov, .webm, .avi, .mkv
**Cost estimate:** same as underlying pipeline type + ~2-5K tokens for frame analysis

**Frame limits per scope** (auto-adjusted):

| Scope | Max Frames |
|-------|-----------|
| BUG_FIX / DISCUSSION | 25 |
| BUILD (existing) | 20 |
| NEW_FEATURE | 15 |
| GREENFIELD / SMALL_EDIT | 10 |

**Resume support:** Video frames are preserved when a pipeline is interrupted. `/start resume` re-uses existing frames without re-extraction.

**Telegram:** You can also send video files directly to the Telegram bot — frames are auto-extracted and a pipeline starts automatically.

---

### Scenario E: Continue After Phase 1

```bash
git checkout develop && git pull
docker compose up -d
claude
/start briefs/brief-phase2.docx
```

Design inherits from phase 1. Convention scout checks for stack updates.

---

### Scenario F: Resume Interrupted Pipeline

```bash
claude
/start resume
```

Reads `docs/wave-execution-state.md`, finds last incomplete file, resumes immediately. No re-planning.

---

### Scenario G: QA Only

```bash
claude
/qa-checklist full                              # generate + run
/qa-checklist run --file briefs/test-cases.xlsx  # run existing
/qa-checklist run --file t.xlsx --data d.xlsx    # with data file
```

Supports `.md`, `.xlsx`, `.docx`, `.csv`. Windows paths auto-resolved to WSL.

---

### Scenario H: Review Only

```bash
claude
/review-and-fix        # scope-aware (changed files only)
/review-and-fix --full # entire codebase
```

---

### Scenario I: Retrospective

```bash
claude
/retro              # full retrospective
/retro focus waves  # wave performance only
/retro focus hooks  # hook violations only
```

---

### Post-Build Verification Flow

After each wave's QA Gate passes and wave execution completes:
1. Phase 4: Pre-QA Setup — collects .env values, boots app, health check
2. Phase 5: Final QA (Integration Focus) — E2E flows spanning all waves + adversarial (A1-A4) + spec compliance (SC1-SC6) + cross-role testing. Skips per-feature re-runs (already covered by Wave QA Gates)
3. Phase 5.post: doc-updater aggregates all `docs/qa-wave-*.md` into `docs/qa-summary.md`
4. Phase 6: Final Delivery — delivery report + user guidance + PR

If issues found → auto-fix loop (max 3x with compact between) → re-test → escalate to user with 3 options (revert feature / skip test / stop pipeline) if still failing. See **README.md → Expanded Escalation Path** for detail.

User receives:
- Chat message: URLs, credentials, test summary
- File: docs/delivery-report.md (detailed report)
- Telegram: notification with status

### API Contracts

BE developers auto-write response shapes to `docs/api-contracts.md`.
FE developers read this file before coding components that consume API.

If you see frontend crashes like `TypeError: .map is not a function`:
1. Check `docs/api-contracts.md` — is the endpoint documented?
2. Compare documented shape vs actual API response
3. Fix frontend to handle the actual shape (wrapper objects, nested fields)

---

## 9. Cross-Platform Setup

### Supported Platforms

| Platform | Full Support | Notes |
|----------|-------------|-------|
| **WSL2 (Ubuntu)** | ✅ Complete | Recommended for Windows users |
| **Linux (Debian/Ubuntu)** | ✅ Complete | Native support |
| **Linux (RedHat/Arch)** | ✅ Complete | setup.sh auto-detects package manager |
| **macOS** | ✅ Complete | One `sed -i` difference (auto-handled) |
| **Windows (PowerShell)** | ⚠️ Partial | Hooks via .ps1. Telegram daemon requires WSL. |

### Per-OS Instructions

**WSL2:** Everything works out of the box.
```bash
./setup.sh /path/to/project
```

**PowerShell:** Hooks work natively via `.ps1`. Telegram needs WSL.
```powershell
.\setup.ps1 C:\path\to\project
# Telegram: wsl -- bash .claude/telegram/setup-telegram.sh
```

**macOS:** Full support. Install GNU sed for consistency.
```bash
brew install tmux jq bun gnu-sed
./setup.sh /path/to/project
```

### Hook Parity

All `.sh` hooks have matching `.ps1` with identical rules. The Bun-based `dispatcher.ts` auto-detects OS and routes correctly. You never call hooks directly.

### orchestrator-guard.sh (PreToolUse — Write|Edit)
- **Fungsi:** Mencegah orchestrator menulis application code langsung
- **Block:** File dengan extension .ts, .tsx, .js, .jsx, .vue, .py, .php, .go, .css, .scss, .html, .svelte
- **Allow:** docs/, .claude/memory/, config files (.md, .json, .yml, .env, .template)
- **Behavior saat block:** Exit 2 + pesan ke stderr yang menginstruksikan orchestrator spawn developer agent
- **Log:** Setiap block dicatat di .claude/hooks/hook-log.txt

### What Does NOT Work on Native Windows (without WSL)

- Telegram bot daemon (bash + tmux)
- Utility scripts (docker-assess.sh, port-scan-all.sh)

**Recommendation:** Install WSL2 (`wsl --install -d Ubuntu`).

---

## 10. MCP Server Setup

### What's Configured

| Server | Purpose | Used By |
|--------|---------|---------|
| chrome-devtools | Network inspection, Lighthouse, screenshots | qa-checklist-runner, user-simulator |
| playwright | Browser automation | user-simulator (fallback) |

### Browser Tool Hierarchy

| Priority | Tool | Used For |
|----------|------|----------|
| 1st | Chrome DevTools MCP | Network inspection, screenshots, console, Lighthouse |
| 2nd | Playwright MCP | Browser automation, click/type/navigate |
| ❌ | Raw Playwright/Puppeteer | **PROHIBITED** — use MCP wrappers only |
| ❌ | curl for external URLs | **PROHIBITED** — use WebFetch tool instead |

fe-developer runs mandatory visual verification via Chrome DevTools MCP before every commit (layout, responsive, interactions, console errors). Screenshots saved to `docs/screenshots/`.

### MCP is Optional

Core pipeline works without MCP. If not available:
- fe-developer skips browser verification (falls back to code-only checks)
- qa-checklist-runner skips `browser-debug` strategy
- No browser-based Lighthouse audits

### Verify MCP

```bash
cat .mcp.json
npx chrome-devtools-mcp --version 2>/dev/null || echo "Not installed"
npx @anthropic-ai/claude-code-mcp-playwright --version 2>/dev/null || echo "Not installed"
```

---

## 11. Flow Optimization & Cost Tips

### Smart Pipeline Routing

The orchestrator automatically optimizes based on input type:

| Input Type | Agents Skipped | Token Savings |
|-----------|---------------|---------------|
| DISCUSSION | All pipeline agents — consultation only | ~95% |
| BUG_FIX | brief-reader, pm-agent, convention-scout, code-architect, wave-planner | 49% |
| SMALL_EDIT | All planning + QA + critic (uses haiku developer) | ~90% |
| NEW_FEATURE | None — full pipeline | 0% |
| GREENFIELD | None — full pipeline + foundation | 0% |

### Cost Estimates

See **README.md → Cost Estimates** for tokens/cost per pipeline type. Typical durations: SMALL_EDIT 2-3 min, BUG_FIX 5-10 min, NEW_FEATURE 15-30 min, GREENFIELD 30-60 min.

### Tips for Cost Efficiency

- **Use BUG_FIX scope** for targeted fixes (say "bug:" or "fix:" — don't describe bugs as features)
- **Use SMALL_EDIT** for config changes, text updates, color changes
- Convention-scout is auto-skipped if `conventions.md` is < 7 days old
- Doc-updater is auto-skipped if diff < 20 lines with no new files
- Wave merging combines lightweight waves to reduce compact cycles
- Every agent has explicit `model:` in frontmatter — no accidental opus usage

### Model Routing

See **README.md → By Model Tier** for the agent-to-model mapping.

If an agent has no `model:` line, it inherits opus from orchestrator (expensive) — check with:
```bash
grep "^model:" .claude/agents/[name].md
```

### Video Input Token Cost

Video frames add ~50-100K tokens depending on frame count and visual complexity. Frame limits are auto-optimized per scope (BUG_FIX: 25, GREENFIELD: 10).

Tips to minimize video token usage:
- **Trim video** to the relevant section before sending (< 2 minutes ideal)
- **Short videos** (< 15 seconds) get the best frame coverage (1 frame/second)
- Use **BUG_FIX** scope when reporting bugs via video — gets highest frame limit (25) with optimized pipeline

---

## 12. Docker-First Architecture

All services run in Docker containers by default.

### Automatic Assessment

Phase 0A runs `docker-assess.sh` to classify each service:
- **Dockerizable**: PHP, Node, Python, MySQL, PostgreSQL, Redis → container
- **Host-only**: Office Add-in, Electron, React Native → host fallback

`port-scan-all.sh` assigns ports without conflicts. All written to `.env`.

### Enforcement

`security-gate.sh` blocks bare `npm`, `pip`, `composer` on host when Docker is available:

```bash
# CORRECT
docker exec -it app php artisan migrate
docker exec -it node npm install express

# WRONG — blocked by hook
php artisan migrate
npm install express
```

Ports from `.env`, never hardcoded:
```bash
source .env
curl http://localhost:${APP_PORT}/api/health
```

### Native (Non-Docker) Projects

Framework is Docker-first but supports native host execution:
- **Existing project without `docker-compose.yml`** → hooks auto-detect, passthrough rewrites
- **User choice** via `docs/docker-assessment.md` Host Services table overrides auto-detection
- **Orchestrator override** via `project_mode: host` in `docs/pipeline-state.md` (future: set by Brief 31 GREENFIELD dialog)

Rewrite hooks (`rewrite-docker-*.sh`) check these signals before transforming commands. If any signal says "host", rewrite is skipped and the command runs on the host as-is.

---

## 13. Context Resilience Protocol

Large pipelines (50+ files) can exceed the context window. CRP handles this automatically.

### How It Works

1. **Compact between waves** — discard conversation history, keep state files
2. **File-level tracking** — `wave-execution-state.md` tracks `[x]`/`[ ]` per file
3. **Graceful exit** — if context pressure detected, save state and stop cleanly
4. **Resume** — `/start resume` picks up from last `[ ]` file, no re-planning

### CRP Rule 6: Compact Between Fix Iterations

If fix cycle 2+ is needed, compact before re-review. Fix cycles accumulate ~50K tokens per iteration — without compact, cycle 3 can hit context limit.

### Context Budget

| Phase | Usage |
|-------|-------|
| Planning | ~30-50% |
| 10-20 files/wave | ~15-25% |
| 20-40 files/wave | ~25-40% |
| 40+ files/wave | Auto-split into sub-waves |

### Video Frame Preservation

Video frames extracted during a pipeline are preserved when the pipeline is interrupted:
- `/start resume` re-uses existing frames in `docs/video-frames/` — no re-extraction
- Frames are only cleaned up when `/clean` is run or the pipeline completes successfully
- Frames are NOT deleted while `docs/wave-execution-state.md` contains incomplete tasks

---

## 14. Environment-Specific Setup

### Multi-Database Testing

Add to `.env`:
```env
DB_ENGINE_PRIMARY=mysql
DB_ENGINE_SECONDARY=postgresql
MYSQL_HOST=mysql
PGSQL_HOST=pgsql
```

Create `docs/test-environment-config.md` with environment definitions (Docker MySQL, Docker PostgreSQL, staging, mobile viewport, MS Add-ins).

### Staging Server

```env
STAGING_URL=https://staging.myapp.com
STAGING_API_TOKEN=Bearer eyJxxxxxxxxxxxx
```

### Microsoft Add-ins

```env
ADDIN_MANIFEST_URL=https://localhost:3000/manifest.xml
OFFICE_VERSION=365
```

---

## 15. Troubleshooting

### Bot daemon won't start

```bash
bash .claude/telegram/manage.sh status
cat .claude/telegram/daemon.log
echo $TELEGRAM_BOT_TOKEN  # should not be empty
```

### Telegram messages not arriving

1. Verify token: `curl https://api.telegram.org/bot<TOKEN>/getMe`
2. Verify chat ID: `curl https://api.telegram.org/bot<TOKEN>/getUpdates`
3. Check daemon: `bash .claude/telegram/manage.sh status`

### Hook blocked my command

Read the BLOCKED message in stderr. Common blocks:
- Push to protected branch → use feature branch
- Writing to .env → use settings.local.json
- Bare `npm`/`pip`/`composer` → use `docker exec`

```bash
grep "BLOCKED" .claude/hooks/hook-log.txt
```

### git-manager blocked by git-delegation-guard

If git-manager cannot run `git commit` / `git push`, verify registration scope:

- `git-delegation-guard` MUST NOT be in `.claude/settings.json` (global scope would block all agents)
- `git-delegation-guard` MUST be in `.claude/agents/orchestrator.md` frontmatter (scoped = orchestrator only)

```bash
# Should be 0 (not in global settings)
grep -c "git-delegation-guard" .claude/settings.json

# Should be >= 1 (in orchestrator frontmatter)
grep -c "git-delegation-guard" .claude/agents/orchestrator.md
```

If wrongly in settings.json, move it to orchestrator.md frontmatter (see Brief 31).

### Pipeline won't resume

```bash
cat docs/wave-execution-state.md   # file-level progress
cat docs/session-handoff.md        # session-level state
claude
/start resume
```

### Chrome DevTools MCP: "Target closed" / "Protocol error"

Chrome/Chromium not found or not configured. Fix:

```bash
# Check what browser is available
which google-chrome || which chromium-browser || which chromium

# If found but MCP doesn't use it — set CHROME_PATH:
# (replace path with your actual browser path)
cat ~/.claude/settings.json | jq '.mcpServers."chrome-devtools".env.CHROME_PATH = "/path/to/your/chrome"' > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json

# If no browser found:
# Ubuntu/WSL:
sudo apt install chromium-browser
# macOS:
brew install chromium

# Re-run setup to auto-detect:
./setup.sh .
```

Note: setup.sh auto-detects Chrome/Chromium and configures CHROME_PATH in Step 5.5.

### MCP server not available

```bash
cat .mcp.json
npx chrome-devtools-mcp --version 2>/dev/null || echo "Not installed"
```

MCP is optional — core pipeline works without it.

### npx MCP command blocked by security-gate

security-gate has an MCP whitelist. If still blocked, check that `security-gate.sh` has the `MCP_WHITELIST` section.

### macOS: sed errors in session-summary

```bash
brew install gnu-sed
# Hooks auto-detect macOS and use sed -i '' syntax
```

### PowerShell hooks out of sync

```bash
diff .claude/hooks/security-gate.sh .claude/hooks/security-gate.ps1
# Both should have: MCP whitelist, destructive git blocks, curl allowlist
```

### CLAUDE.md — Primary Enforcement Layer

CLAUDE.md adalah file yang PALING PENTING dalam agent system. Dibaca otomatis oleh SEMUA agents (orchestrator + sub-agents) di awal setiap session.

Isi CLAUDE.md:
1. **Orchestrator Rules** — delegation enforcement, pipeline routing, coordination rules
2. **Verification Pipeline Routing** — Phase 4 → 5 → 6 gate routing
3. **QA Standards** — adversarial testing mandatory after functional tests
4. **Delivery Report** — docs/delivery-report.md generation before PR
5. **Communication Style** — caveman style (short, no fluff, save tokens)
6. **Project context** — auto-generated oleh codebase-scout setelah first pipeline run
7. **Architecture** — auto-generated oleh code-architect
8. **Conventions** — auto-generated oleh convention-scout, updated oleh consolidate-memory
9. **Security rules** — auto-generated oleh security-learner
10. **Fix protocol** — auto-generated oleh codebase-scout, Known Pitfalls updated oleh consolidate-memory
11. **Custom Instructions** — area untuk user tulis instruksi custom, tidak di-overwrite

Sections are auto-populated with 3-5 line summaries + pointers to detail files (target ~150 lines total).

Setup.sh generate CLAUDE.md dari template. Pipeline pertama populate section markers. Pipeline berikutnya update sections yang berubah.

JANGAN hapus Orchestrator Rules section — ini enforcement utama untuk delegation dan pipeline behavior.

CLAUDE.md is auto-generated by:
- **setup.sh/setup.ps1** — creates CLAUDE.md with Orchestrator Rules + empty section markers + generic fix-protocol
- **codebase-scout** — populates project, architecture, fix-protocol sections with project-specific data
- **doc-updater** — staleness check after each pipeline (updates stale sections, preserves Orchestrator Rules)
- **consolidate-memory** — appends Known Pitfalls from lessons.md fix failures

```bash
# Verify CLAUDE.md has all required sections:
grep -c "Orchestrator Rules\|BEGIN:project\|BEGIN:architecture\|BEGIN:conventions\|BEGIN:security\|BEGIN:fix-protocol\|Custom Instructions" CLAUDE.md
# Expected: 7+
```

The `## Custom Instructions` section at the bottom of CLAUDE.md is NEVER overwritten by agents — safe for manual additions.

### Model running on wrong tier

```bash
grep "^model:" .claude/agents/[name].md
```

Every agent MUST have explicit `model:` line. If missing, it inherits opus from orchestrator (expensive).

### Docker containers not running

```bash
docker compose up -d
docker compose ps     # all must be UP
docker compose logs   # check for errors
```

### Hybrid Model Routing

Agent system menggunakan dua mekanisme multi-agent secara strategic:
- **Agent Teams** untuk parallel implementation (Phase 3, 4) dimana coordination penting
- **Subagent** dengan model routing (haiku/sonnet/opus) untuk semua task lain, menghemat ~40-70% cost

Orchestrator otomatis memilih mekanisme berdasarkan task type. User tidak perlu configure.

### Agent Teams not active

Check settings.json: must have `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"` and model must be Opus 4.6.

### ffmpeg not found

```bash
ffmpeg -version
# Ubuntu/WSL: sudo apt install ffmpeg
# macOS: brew install ffmpeg
# Windows: winget install Gyan.FFmpeg
# Or re-run setup.sh / setup.ps1 (auto-installs ffmpeg)
```

### Video format not supported

Supported: `.mp4`, `.mov`, `.webm`, `.avi`, `.mkv`. Convert other formats:
```bash
ffmpeg -i input.xyz -c copy output.mp4
```

### Video too large for Telegram

Telegram Bot API limits bot downloads to 20MB. Options:
- Upload manually to `briefs/` folder
- Compress: `ffmpeg -i input.mp4 -vf scale=1280:-2 -crf 28 output.mp4`

### Frames not extracted

```bash
ffmpeg -i briefs/video.mp4 -vf "fps=1/2" -frames:v 5 /tmp/test_%04d.jpg
# If error → video is corrupt or codec not supported
```

### Resume not using existing frames

```bash
ls docs/video-frames/                              # frames must exist
grep "\[ \]" docs/wave-execution-state.md          # state must have incomplete tasks
# Both must be true for frame re-use on resume
```

---

## 16. Quick Reference Card

```
+----------------------------------------------------------+
|  QUICK START:                                            |
|                                                          |
|  Linux/macOS/WSL:                                        |
|    ./setup.sh /path/to/your-project                      |
|    cd /path/to/your-project                              |
|    claude  ->  /start <your task>                        |
|                                                          |
|  Windows (PowerShell):                                   |
|    .\setup.ps1 C:\path\to\your-project                   |
|    cd C:\path\to\your-project                            |
|    claude  ->  /start <your task>                        |
+----------------------------------------------------------+
|  PREREQUISITES:                                          |
|  [ ] Claude Code v2.1.80+                                |
|  [ ] Docker + Docker Compose v2+                         |
|  [ ] Git 2.35+                                           |
|  [ ] jq 1.6+                                             |
|  [ ] tmux (Linux/macOS/WSL)                              |
|  [ ] Bun                                                 |
|  [ ] ffmpeg (video input processing)                     |
|  [ ] .mcp.json at project root                           |
|                                                          |
|  WINDOWS:                                                |
|  [ ] WSL2 (wsl --install -d Ubuntu)                      |
|  [ ] Docker Desktop WSL2 backend                         |
|  [ ] .\setup.ps1 C:\path\to\project                     |
|                                                          |
|  macOS:                                                  |
|  [ ] brew install tmux jq bun gnu-sed ffmpeg             |
|  [ ] ./setup.sh /path/to/project                         |
+----------------------------------------------------------+
|  PIPELINE COMMANDS:                                      |
|  /start <task>          — full pipeline                  |
|  /start <question>      — discussion mode (consult)      |
|  /start resume          — resume interrupted             |
|  /start <video.mp4>     — analyze video (extract frames) |
|  /review-and-fix        — review + fix changed files     |
|  /qa-checklist full     — generate + run QA              |
|  /retro                 — retrospective analysis         |
|  /clean                 — save state and exit            |
|  /verify                — smart verify (skip covered QA) |
|  /verify --wave N       — re-verify one wave only        |
|  /verify --adversarial  — adversarial tests only         |
|  /verify --full         — force full V1-V6               |
+----------------------------------------------------------+
|  For cost estimates per pipeline type, see README.md.   |
+----------------------------------------------------------+
|  TELEGRAM COMMANDS:                                      |
|  /status  — view pipeline progress                       |
|  /approve — approve pipeline from Telegram               |
|  /reject  — reject & stop pipeline                       |
|  /run     — start new pipeline remotely                  |
|  /log     — view last 10 hook events                     |
|  /retro   — trigger retrospective                        |
+----------------------------------------------------------+
```

---

## Quick Start Checklist

```
LINUX / macOS / WSL:
[ ] 1. Run: ./setup.sh /path/to/your-project
[ ] 2. Add credentials to .claude/settings.local.json (or .env)
[ ] 3. Verify: cat .mcp.json (should exist at project root)
[ ] 4. Run: bash .claude/telegram/setup-telegram.sh
[ ] 5. Start: bash .claude/telegram/claude-agent.sh
[ ] 6. Type /start <your task> in terminal
[ ] 7. Or send /run <task> from Telegram

WINDOWS (PowerShell):
[ ] 1. Run: .\setup.ps1 C:\path\to\your-project
[ ] 2. Add credentials to .claude\settings.local.json (or .env)
[ ] 3. Verify: cat .mcp.json (should exist at project root)
[ ] 4. Run: wsl -- bash .claude/telegram/setup-telegram.sh
[ ] 5. Start: powershell -File .claude\telegram\claude-agent.ps1
[ ] 6. Type /start <your task> in terminal
[ ] 7. Or send /run <task> from Telegram
```
