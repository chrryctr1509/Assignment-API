# Project Signal

generated_at: 2026-05-14

## Codebase Analysis

**Stack:** Node.js + Express REST API
**Database:** MySQL (mysql2/promise pool)
**Dependencies:** express, mysql2, bcryptjs, jsonwebtoken, multer, cors, dotenv, uuid, nodemon

**Entry Point:** `src/app.js` (PORT 3000)
**Database Config:** `src/config/database.js` (uses DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME)

**No deployment configs found.** Missing: railway.json, Procfile, Dockerfile, docker-compose.yml

**Environment Variables:** PORT, NODE_ENV, DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, JWT_SECRET, JWT_EXPIRES_IN, UPLOAD_DIR

## Requirements

1. **railway.json** — Railway deployment configuration
2. **Environment adjustment** — Production-ready env vars for Railway
3. **Health check endpoint** — `/health` endpoint for Railway health checks
4. **Persistent storage** — Strategy for `uploads/` folder (Railway ephemeral filesystem)
5. **Database connection** — External MySQL or Railway MySQL plugin

## Scope & Estimate

type: NEW FEATURE (adding deployment config to existing Node.js app)
effort: M (Medium)
risk_flags: database external dependency, ephemeral storage for uploads

## Notes

- Docker not available in environment — DOCKER_MODE=host-only
- Railway MySQL plugin required OR external MySQL URL
- uploads/ folder needs persistent storage solution (Cloudinary recommended for zero-config)
