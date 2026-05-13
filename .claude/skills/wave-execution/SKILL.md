---
name: wave-execution
description: "Template prompt untuk Team Lead saat spawn teammates, worktree naming, merge strategy"
---

# Wave Execution Skill

## PURPOSE
Template dan panduan untuk orchestrator saat menjalankan wave execution — spawn Agent Team teammates, manage worktrees, dan coordinate merges.

## TEAM LEAD PROMPT TEMPLATE

Saat orchestrator spawn Agent Team untuk sebuah wave:

```
You are a teammate in Wave [N]: [Wave Name].

## Your Assignment
- Feature: [feature_name]
- Scope: [BE|FE|fullstack] 
- Files to create/modify: [list from wave-plan.md]
- Worktree: wave-[N]-[feature-slug]

## Context
Read these docs before starting:
1. docs/agent-context.md — full project context
2. docs/wave-plan.md — your wave assignment
3. docs/architecture-blueprint.md — file structure and skeleton
4. docs/conventions.md — latest convention updates
5. docs/design-direction.md — design decisions (for FE)

## Rules
1. ONLY touch files assigned to you (isolation)
2. Commit frequently with descriptive messages
3. Run tests for your changes before completing
4. If blocked by another teammate's work → document in docs/merge-plan.md
5. When done → commit all changes and report completion

## Stack Skills
Load these skills: [list based on stack]
```

## WORKTREE NAMING CONVENTION
```
Format: wave-{wave_number}-{feature_slug}
Examples:
  wave-1-user-auth
  wave-1-dashboard-ui
  wave-2-payment-api
  wave-2-notification-system
  wave-0-foundation (greenfield)
```

## WORKTREE LIFECYCLE
```bash
# Create (git-manager Mode E)
git worktree add -b wave-1-user-auth ../worktrees/wave-1-user-auth develop

# List
git worktree list

# After completion — merge to develop (git-manager Mode D)
git checkout develop
git merge --no-ff wave-1-user-auth -m "merge: wave-1 user-auth feature"

# Cleanup
git worktree remove ../worktrees/wave-1-user-auth
git branch -d wave-1-user-auth
```

## MERGE ORDER STRATEGY

### Within a Wave (parallel teammates)
1. Merge fitur tanpa dependency duluan
2. Merge fitur dengan dependency setelah dependency-nya merged
3. Jika conflict → resolve di branch yang merge belakangan

### Between Waves (sequential)
1. Wave N harus fully merged sebelum Wave N+1 mulai
2. Run full test suite setelah wave merge
3. Jika test gagal → fix SEBELUM lanjut ke wave berikutnya

### Merge Plan Template
```markdown
# Merge Plan — Wave [N]

## Merge Order
1. [feature-a] → develop (no dependencies)
2. [feature-b] → develop (depends on feature-a)
3. [feature-c] → develop (depends on feature-a)

## Conflict Risk
- [feature-b] and [feature-c] both touch [shared-file] → resolve in feature-c merge

## Post-Merge Verification
- [ ] All tests pass
- [ ] Health check: all containers healthy
- [ ] No regression in existing features
```

## CROSS-WAVE DEPENDENCY HANDLING
1. Wave N fitur butuh output dari Wave N-1 fitur
2. Resolution: Wave N-1 harus COMPLETE dan MERGED sebelum Wave N start
3. Jika fitur di Wave N butuh partial output dari Wave N (concurrent):
   - Document shared interface di docs/merge-plan.md
   - First teammate creates interface → commits → second teammate uses it
   - NOT parallel — sequential within wave for dependent features
