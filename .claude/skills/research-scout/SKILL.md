# Research Scout Skill

Proactively discover new techniques, tools, and workflow improvements.
Schedule: 3x nightly (1am, 3am, 5am) via cron, with weekly promotion review.

## When to Use
- Automatically via scheduled cron (3x nightly)
- Manually when exploring new approaches for a specific stack
- When convention-scout finds outdated information

## Process

### Step 1: Determine Search Scope

Read project context to determine what's relevant:

```bash
# Detect current stack
cat docs/project-signal.md 2>/dev/null | grep -i "stack\|framework\|language"
cat .claude/memory/project-memory.md 2>/dev/null | head -20

# Read existing knowledge
cat .claude/memory/long-term-memory.md 2>/dev/null | grep -i "## New Learnings" -A 100
```

Default search topics (always relevant):
1. Claude Code new features/patterns/best practices
2. Agent orchestration techniques
3. Hook/skill patterns from community

Stack-specific topics (based on detected stack):
- Laravel: new versions, packages, security advisories
- Node.js: runtime updates, popular packages, security
- React/Next.js: new features, patterns, performance
- Python: FastAPI/Django updates, typing improvements
- Flutter/SwiftUI/Kotlin: latest SDK features, design patterns

### Step 2: Execute Web Searches

For each topic, search these sources:
```
1. Reddit (r/ClaudeAI, r/programming, r/webdev, stack-specific subreddits)
2. Hacker News (hn.algolia.com)
3. GitHub trending (relevant language/topic)
4. Official docs (framework changelogs, release notes)
5. Dev.to / Medium (trending articles for stack)
```

Search queries pattern:
```
"[topic] [year] new features"
"[framework] best practices [year]"
"[tool] breaking changes"
"claude code tips tricks workflow"
```

### Step 3: Cross-Reference Against Existing Knowledge

For each finding:
1. Check if it contradicts anything in `long-term-memory.md`
2. Check if it's already in `lessons.md`
3. Check if it's already in convention skills (`.claude/skills/*-conventions/`)
4. Check if it's already in `docs/conventions.md`

**Discard if:**
- Already documented in any of the above
- Outdated (older than 6 months with no recent validation)
- Not applicable to detected project stacks

**Keep if:**
- Genuinely new technique or pattern
- Updates/corrections to existing knowledge
- Security advisory affecting current stack
- Breaking change in a dependency

### Step 4: Store New Learnings

Write validated findings to `long-term-memory.md` under `## New Learnings`:

```markdown
### [YYYY-MM-DD] — [source]: [one-line summary]
URL: [source url]
Delta: [what this changes or adds vs existing knowledge]
Status: staging
```

**Max entries per run:** 5 (quality over quantity)
**Status flow:** staging → promoted (weekly) → integrated into skills

### Step 5: Weekly Promotion Review

Once a week (separate cron), review all `staging` entries:

**Promote if:**
- Validated by a second source
- Successfully applied in a pipeline
- Programmer confirmed usefulness

**Promotion action:**
1. Move from `## New Learnings` to `## Confirmed Patterns` in long-term-memory
2. If it's a convention update → also update the relevant convention skill
3. Update status: `Status: promoted`

**Discard if:**
- Contradicted by newer information
- Not applicable after further evaluation
- Programmer rejected

### Step 6: Report

Output summary per run:
```
Research Scout Report — [date] [run: 1/2/3]
- Topics searched: [N]
- New findings: [N]
- Already known: [N]
- Stored to staging: [N]
- Security advisories: [N]
```

Weekly summary:
```
Weekly Research Review — [date]
- Staging entries reviewed: [N]
- Promoted to confirmed: [N]
- Integrated into skills: [N]
- Discarded: [N]
```

## Scheduling

```bash
# 3x nightly research runs
/schedule create --name "research-scout-1" --cron "0 1 * * *" --prompt "Run research-scout skill — run 1/3"
/schedule create --name "research-scout-2" --cron "0 3 * * *" --prompt "Run research-scout skill — run 2/3"
/schedule create --name "research-scout-3" --cron "0 5 * * *" --prompt "Run research-scout skill — run 3/3"

# Weekly promotion review
/schedule create --name "research-promote" --cron "0 10 * * 0" --prompt "Run research-scout weekly promotion review"
```

## Manual Trigger

```
# Search for specific topic
/research-scout topic:flutter

# Full scan
/research-scout

# Weekly review only
/research-scout promote
```
