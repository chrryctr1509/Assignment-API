# QA Project Config
> project : [project-name]
> updated_at : [YYYY-MM-DD HH:MM]

---

## Connection
```yaml
base_url: "http://localhost:3000"
api_url: "http://localhost:8000/api"
health_check: "{{api_url}}/health"
```

## Auth
```yaml
strategy: bearer | cookie | none

# For bearer strategy:
auth_flow:
  method: POST
  endpoint: "{{api_url}}/auth/login"
  body:
    email: "[login-email]"
    password: "[login-password]"
  extract_token:
    from: body
    path: "data.token"
    # OR: from: header, name: "Authorization"
  store_as: auth_token

# For cookie strategy:
auth_flow:
  method: POST
  endpoint: "{{api_url}}/auth/login"
  body:
    email: "[login-email]"
    password: "[login-password]"
  extract_cookie:
    name: "session_id"
  store_as: cookie_header

# For none: no auth needed
```

## Environment
```yaml
setup:
  - "docker compose up -d"
  - "docker compose exec backend python manage.py migrate"
  - "docker compose exec backend python manage.py seed --test"

teardown:
  - "docker compose exec backend python manage.py flush --no-input"

# OR for non-Docker:
setup:
  - "npm run dev &"
  - "sleep 3"
teardown: []
```

## Test Data
```yaml
default_directory: "tests/data/"
fixtures:
  - "tests/data/users.json"
  - "tests/data/products.json"
```

## Browser Config
```yaml
viewport: { width: 1280, height: 720 }
default_wait_ms: 3000
screenshot_on_fail: true
```
