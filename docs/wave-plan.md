# Wave Plan — Railway Deployment Setup

generated_at: 2026-05-14
scope_type: NEW FEATURE
effort: M

## Wave 1 — Railway Configuration

### Files to CREATE:
- `railway.json` — Railway deployment config
- `src/config/env.js` — Railway environment adapter (optional, handles PORT from Railway)

### Files to MODIFY:
- `src/app.js` — Add `/health` endpoint for Railway health checks
- `.env.example` — Update with Railway production variables

### Test Plan:
- Health endpoint returns 200 OK
- App starts on Railway-provided PORT
- Database connects via Railway MySQL plugin env vars

---

## Files Summary

| File | Action | Description |
|------|--------|-------------|
| railway.json | CREATE | Railway config (build command, start command, port) |
| src/app.js | MODIFY | Add /health endpoint |
| .env.example | MODIFY | Add Railway production vars |

