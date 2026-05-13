# Wave Plan
Generated: 2026-05-13
Scope: GREENFIELD
Total Waves: 6
Total Features: 11 endpoints + 1 migration system + 1 postman collection + 1 README
Strategy: adaptive

## Dependency Graph
migrations/001_init.sql, seeds/seed.sql, scripts/migrate.js
    ↓ (must exist before any code uses DB)
src/config/database.js
    ↓ (foundation for all endpoints)
membership (registration, login, profile) ←→ auth middleware (shared)
    ↓ (all modules depend on auth middleware)
information (banner, services)
    ↓ (independent of membership, also depends on auth)
transaction (balance, topup, payment, history)
    ↓ (final integration)
deliverables (postman, README, cleanup)

## Wave 0: Foundation
- Strategy: single
- Agent: project-initializer
- Tasks:
  - package.json with all deps (express, mysql2, bcryptjs, jsonwebtoken, multer, dotenv, cors)
  - .env.example (PORT, DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, JWT_SECRET, JWT_EXPIRES_IN, UPLOAD_DIR)
  - src/app.js skeleton (express setup, cors, json, urlencoded, static uploads/)
  - src/config/database.js (mysql2 pool config)
  - routes and controllers stub files
  - README.md skeleton
  - postman/ directory
- Depends on: none (first wave)
- Estimated files: 15

## Wave 1: Database
- Strategy: single
- Agent: db-designer
- Features:
  - migrations/001_init.sql: CREATE TABLE IF NOT EXISTS for users, banners, services, transactions
  - seeds/seed.sql: 5 banners + 12 services as listed in brief
  - scripts/migrate.js: read and execute SQL files, idempotent
  - npm script: "migrate": "node scripts/migrate.js"
- Depends on: Wave 0
- Estimated files: 3
- Notes: Raw SQL with prepared statements via mysql2. Idempotent DDL with IF NOT EXISTS.

## Wave 2: Auth & Membership
- Strategy: single
- Agent: be-developer
- Features:
  - src/middleware/auth.js (JWT verify middleware)
  - src/middleware/upload.js (multer jpeg/png, 2MB limit)
  - src/controllers/membershipController.js (register, login, getProfile, updateProfile, updateProfileImage)
  - src/routes/membership.js
- Endpoints implemented:
  - POST /registration: bcrypt hash password, INSERT INTO users
  - POST /login: bcrypt compare, jwt.sign
  - GET /profile: JWT required, return user data (no password)
  - PUT /profile/update: JWT required, update first_name/last_name
  - PUT /profile/image: JWT required, multer upload to uploads/, save path
- Depends on: Wave 1 (DB schema must exist)
- Estimated files: 6
- Response shapes: TBD — BE will document in docs/api-contracts.md during execution

## Wave 3: Information
- Strategy: single
- Agent: be-developer
- Features:
  - src/controllers/informationController.js (banner, services)
  - src/routes/information.js
- Endpoints implemented:
  - GET /banner: SELECT * FROM banners (JWT required)
  - GET /services: SELECT * FROM services (JWT required)
- Depends on: Wave 2 (auth middleware required)
- Estimated files: 4
- Response shapes: TBD — BE will document in docs/api-contracts.md during execution

## Wave 4: Transaction
- Strategy: single
- Agent: be-developer
- Features:
  - src/controllers/transactionController.js (balance, topup, transaction, history)
  - src/routes/transaction.js
- Endpoints implemented:
  - GET /balance: SELECT balance FROM users WHERE id = ? (JWT required)
  - POST /topup: UPDATE users SET balance = balance + ? WHERE id = ?, INSERT transaction
  - POST /transaction: validate service_code, check balance >= tariff, UPDATE balance, INSERT transaction (invoice_number: INV + timestamp + random)
  - GET /transaction/history: SELECT * FROM transactions WHERE user_id = ? ORDER BY created_on DESC LIMIT ? OFFSET ?
- Depends on: Wave 2 (auth middleware required)
- Estimated files: 4
- Response shapes: TBD — BE will document in docs/api-contracts.md during execution

## Wave 5: Deliverables
- Strategy: single
- Agent: be-developer
- Features:
  - postman/SIMS_PPOB.postman_collection.json: all 11 endpoints with {{base_url}} and {{token}}
  - README.md: description, tech stack, prerequisites, installation, env vars, endpoints table, db schema, deployment
  - .env.example: all required env vars
  - Final cleanup and verification
- Depends on: Wave 4 (all endpoints must exist)
- Estimated files: 3

## Wave Merge Analysis
- All waves have 1 agent each — sequential single-agent execution minimizes context switching
- Wave sizes are balanced (3-6 files per wave)
- No merge needed — each wave has distinct deliverable with clear handoff

## Risk Flags
- JWT token management (expiry handling) — mitigated: auth middleware in Wave 2
- Balance transaction atomicity (topup/payment) — mitigated: raw SQL transactions, single query UPDATE
- File upload security (format validation) — mitigated: multer filter in Wave 2
- Raw query prepared statement safety — mitigated: all queries use mysql2 execute with ?