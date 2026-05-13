# QA Checklist Report
> project    : [project-name]
> branch     : [branch-name]
> run_at     : [YYYY-MM-DD HH:MM]
> config     : docs/qa-project-config.md
> checklist  : docs/qa-checklist.md

---

## Summary

| Metric | Count |
|--------|-------|
| Total TCs | [N] |
| PASS | [N] |
| FAIL | [N] |
| SKIP (manual) | [N] |
| SKIP (depends_on failed) | [N] |
| Error (execution error) | [N] |

**Pass Rate**: [X]% ([pass] / [total - skipped])

---

## Results by Priority

| Priority | Pass | Fail | Skip |
|----------|------|------|------|
| critical | [N] | [N] | [N] |
| high | [N] | [N] | [N] |
| medium | [N] | [N] | [N] |
| low | [N] | [N] | [N] |

---

## Per-TC Results

### TC-001: [name] — PASS | FAIL | SKIP | ERROR
strategy : [api/browser/cli/manual]
priority : [critical/high/medium/low]
duration : [Nms]

**Input sent:**
```
[actual request/command sent]
```

**Response received:**
```
[actual response — truncated if >50 lines]
```

**Comparison:**
| Field | Expected | Actual | Rule | Result |
|-------|----------|--------|------|--------|
| status_code | 200 | 200 | exact | PASS |
| body.name | "test" | "test" | exact | PASS |
| body.total | 100.50 ±0.01 | 100.49 | numeric_tolerance | PASS |

<!-- Repeat for each TC -->

---

## Code Bugs (dispatch to developer)

<!-- This section is formatted to be compatible with code-review-report.md
     so be-developer/fe-developer can consume it directly.
     ONLY CODE_BUG classified failures appear here. -->

### FAIL-001: TC-[NNN] — [name]
severity       : critical | high | medium
assign         : BE | FE
classification : CODE_BUG
file_hint      : [likely file path based on endpoint/component]

**What failed:**
[description of the mismatch]

**Expected:**
```
[expected value/behavior]
```

**Actual:**
```
[actual value/behavior]
```

**Suggested fix:**
[brief suggestion based on the mismatch pattern]

---

## LLM Behavior Deviations (informational)

<!-- These failures are caused by AI decision-making differences,
     NOT code bugs. Do NOT dispatch to developers.
     Recommendation: revise checklist expectations or mark as probabilistic. -->

| TC | Name | Field | Expected | Actual | Reasoning |
|----|------|-------|----------|--------|-----------|
| TC-[NNN] | [name] | [field] | [expected] | [actual] | [why AI chose differently] |

---

## Environment Issues

<!-- Infrastructure / connectivity problems. Retry or investigate infra. -->

| TC | Name | Issue | Detail |
|----|------|-------|--------|
| TC-[NNN] | [name] | timeout / connection refused / etc | [detail] |

---

## Manual TCs (require human verification)

| TC | Name | Instruction |
|----|------|-------------|
| TC-[NNN] | [name] | [what to verify manually] |

---

## Fix Loop Status

| Cycle | TCs Retested (CODE_BUG only) | Passed | Still Failing |
|-------|------------------------------|--------|---------------|
| 1 | [N] | [N] | [N] |
| 2 | [N] | [N] | [N] |
| 3 (max) | [N] | [N] | [N] |

---

## Classification Summary

| Classification | Count | Action |
|----------------|-------|--------|
| CODE_BUG | [N] | Dispatched to be/fe-developer |
| LLM_BEHAVIOR | [N] | Checklist revision recommended |
| ENVIRONMENT | [N] | Infra investigation needed |
