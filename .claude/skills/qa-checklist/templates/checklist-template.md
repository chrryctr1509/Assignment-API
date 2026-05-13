# QA Checklist
> project : [project-name]
> config  : docs/qa-project-config.md
> generated_at : [YYYY-MM-DD HH:MM]
> generated_by : qa-checklist-generator | qa-checklist-interpreter | manual

---

<!-- FORMAT SPECIFICATION
Each TC follows this structure. The runner ONLY understands this format.
User-provided checklists in other formats must go through qa-checklist-interpreter first.

Variables: {{base_url}}, {{api_url}}, {{auth_token}}, {{cookie_header}}
           Resolved from docs/qa-project-config.md at runtime.

Comparison rules (used in Expected block):
  exact              : value must match exactly
  numeric_tolerance  : ±N (e.g., numeric_tolerance: 0.01)
  contains           : response must contain substring
  regex              : response must match pattern
  exists             : field must be present (value ignored)
  less_than          : numeric value < threshold
  greater_than       : numeric value > threshold
  json_subset        : response JSON must contain all specified keys/values
  status_code        : HTTP status code must match
  type               : value type check (string, number, boolean, array, object)
-->

## TC-001: [descriptive name]
strategy    : api | browser | cli | manual
priority    : critical | high | medium | low
tags        : [comma-separated tags, e.g., auth, crud, calculation]
depends_on  : [TC-IDs or empty]

### Input
```yaml
# For strategy: api
method: GET | POST | PUT | PATCH | DELETE
endpoint: "{{api_url}}/path"
headers:
  Authorization: "Bearer {{auth_token}}"
  Content-Type: "application/json"
body:
  field: value

# For strategy: browser
url: "{{base_url}}/path"
actions:
  - click: "#element-selector"
  - fill: { selector: "#input", value: "test data" }
  - wait: { selector: ".result", timeout: 5000 }
  - snapshot: true

# For strategy: cli
command: "docker compose exec backend python manage.py some_command"
args: ["--flag", "value"]

# For strategy: manual
instruction: "Describe what the tester should do manually"
```

### Expected
```yaml
# Per-field comparison rules
status_code: { rule: exact, value: 200 }
body:
  id: { rule: exists }
  name: { rule: exact, value: "expected name" }
  total: { rule: numeric_tolerance, value: 100.50, tolerance: 0.01 }
  description: { rule: contains, value: "partial text" }
  email: { rule: regex, value: "^[\\w]+@[\\w]+\\.[a-z]{2,}$" }
  items: { rule: json_subset, value: { status: "active" } }
  count: { rule: less_than, value: 1000 }
  score: { rule: greater_than, value: 0 }
response_time_ms: { rule: less_than, value: 2000 }

# For browser strategy — check element state after actions
elements:
  ".success-message": { rule: exists }
  ".total-display": { rule: contains, value: "100.50" }
```

### Test Data
```yaml
source: inline | file
# If inline:
data:
  username: "testuser"
  password: "testpass123"
# If file:
file_path: "tests/data/tc001-data.json"
```
