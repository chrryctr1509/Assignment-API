# Project Signal
generated_at: 2026-05-13

## Codebase Analysis
scope_type: GREENFIELD
repo_status: Empty — no src/, no package.json, no infrastructure
stack_detected:
  - Runtime: Node.js (LTS)
  - Framework: ExpressJS
  - Database: MySQL (raw query with mysql2, prepared statements)
  - ORM: NONE (raw mysql2 only)
  - Auth: JWT (jsonwebtoken)
  - Password: bcryptjs
  - File upload: multer
  - Config: dotenv

## Requirements
from_brief: AGENT_BRIEF_API_PROGRAMMER.md

### Modul 1: Membership
- POST /registration — email, first_name, last_name, password (bcrypt)
- POST /login — email, password → JWT
- GET /profile — JWT required
- PUT /profile/update — JWT, update first_name/last_name
- PUT /profile/image — JWT, multipart upload (jpeg/png only)

### Modul 2: Information
- GET /banner — JWT, seed 5 banners
- GET /services — JWT, seed 12 services (pulsa, pgn, listrik, pdam, pbb, tv, musik, voucher_game, voucher_makanan, kurban, zakat, qurban)

### Modul 3: Transaction
- GET /balance — JWT
- POST /topup — JWT, amount > 0
- POST /transaction — JWT, service_code validation, balance check
- GET /transaction/history — JWT, pagination offset/limit

### Deliverables
- migrations/001_init.sql — idempotent DDL
- seeds/seed.sql — banner (5) + services (12)
- scripts/migrate.js — auto-migration runner
- postman/SIMS_PPOB.postman_collection.json — all 11 endpoints
- README.md — full documentation
- .env.example

## Scope & Estimate
type: GREENFIELD
effort: L (12 endpoints, auth, transactions, file upload, postman, migration)
risk_flags:
  - JWT token management (expiry handling)
  - Balance transaction atomicity (topup/payment)
  - File upload security (format validation)
  - Raw query prepared statement safety