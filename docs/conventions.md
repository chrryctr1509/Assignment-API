# SIMS PPOB — Coding Conventions

## 1. Coding Standards

### Raw Query Only
All database operations use `mysql2` with prepared statements. **No ORM allowed** (Sequelize, TypeORM, Prisma banned).

Use `?` placeholders — never `$1`, `$2` (those are PostgreSQL).

```javascript
// SELECT
const [rows] = await pool.execute(
  'SELECT * FROM users WHERE email = ?',
  [email]
);

// INSERT
await pool.execute(
  'INSERT INTO users (id, email, first_name, last_name, password) VALUES (UUID(), ?, ?, ?, ?)',
  [email, first_name, last_name, hashedPassword]
);

// UPDATE
await pool.execute(
  'UPDATE users SET first_name = ?, updated_on = NOW() WHERE id = ?',
  [first_name, userId]
);
```

### Async/Await
All DB operations must be async/await. No callbacks.

### Error Handling
Every controller function wraps logic in try-catch:

```javascript
{
  status: 0,
  message: "Sukses",
  data: { ... }
}

// Error response
{
  status: <code>,
  message: "<error message>",
  data: null
}
```

---

## 2. File Structure

```
src/
├── config/
│   └── database.js         # mysql2 connection pool
├── middleware/
│   ├── auth.js             # JWT verification
│   └── upload.js           # multer (jpeg/png, 2MB max)
├── routes/
│   ├── membership.js       # /registration, /login, /profile/*
│   ├── information.js      # /banner, /services
│   └── transaction.js      # /balance, /topup, /transaction, /transaction/history
├── controllers/
│   ├── membershipController.js
│   ├── informationController.js
│   └── transactionController.js
├── app.js                  # Express setup + middleware + routes
migrations/
├── 001_init.sql            # CREATE TABLE IF NOT EXISTS (idempotent)
seeds/
├── seed.sql                # INSERT IGNORE (idempotent seed)
scripts/
├── migrate.js              # auto-migration runner
uploads/                    # profile images
postman/
├── SIMS_PPOB.postman_collection.json
.env.example
```

---

## 3. API Response Format

**Success:**
```json
{ "status": 0, "message": "...", "data": {...} }
```

**Error:**
```json
{ "status": <code>, "message": "...", "data": null }
```

| Code | Meaning |
|------|---------|
| 0 | Success |
| 102 | Validation error / bad request |
| 103 | Authentication failed (wrong credentials) |
| 108 | Token invalid or expired |

---

## 4. JWT Middleware Rules

- Extract token from `Authorization: Bearer <token>` header.
- Verify with `jwt.verify(token, process.env.JWT_SECRET)`.
- If invalid or expired: return 401 `{ status: 108, message: "Token tidak tidak valid atau kadaluwarsa", data: null }`.
- If valid: attach decoded payload to `req.user`.

All routes except `/registration` and `/login` require JWT.

---

## 5. MySQL Conventions

| Element | Convention |
|---------|-----------|
| Connection | `mysql2.createPool()` with `.env` config |
| Placeholders | `?` only (never `$1`) |
| UUID primary key | `CHAR(36) DEFAULT (UUID())` |
| Balance column | `DECIMAL(15,2)` |
| Timestamps | `TIMESTAMP DEFAULT CURRENT_TIMESTAMP` |
| Update timestamp | `updated_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` |
| Seed data | `INSERT IGNORE` (idempotent) |
| Table creation | `CREATE TABLE IF NOT EXISTS` (idempotent) |

---

## 6. Naming Conventions

| Element | Style | Example |
|---------|-------|---------|
| Tables | snake_case | `users`, `banners`, `services`, `transactions` |
| Columns | snake_case | `first_name`, `created_on`, `updated_on` |
| Files | camelCase.js | `membershipController.js`, `auth.js` |
| Routes (URL) | kebab-case | `/profile-update`, `/transaction-history` |
| Controllers | camelCase | `membershipController` |
| Middleware | camelCase | `auth.js`, `upload.js` |

---

## 7. Package.json Scripts

```json
{
  "scripts": {
    "start": "node src/app.js",
    "dev": "nodemon src/app.js",
    "migrate": "node scripts/migrate.js"
  }
}
```

---

## 8. Dependencies

```json
{
  "dependencies": {
    "express": "^4.18.x",
    "mysql2": "^3.6.x",
    "bcryptjs": "^2.4.x",
    "jsonwebtoken": "^9.0.x",
    "multer": "^1.4.x-lts.1",
    "dotenv": "^16.x",
    "cors": "^2.8.x"
  },
  "devDependencies": {
    "nodemon": "^3.x"
  }
}
```