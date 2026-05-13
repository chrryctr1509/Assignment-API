# Acceptance Criteria
Generated: 2026-05-13
Source: docs/wave-plan.md

## Per-Feature Criteria

### Feature: Registration (POST /registration)
**Done when ALL of these are true:**
1. Email format valid (regex check)
2. Password min 8 characters
3. Password stored as bcrypt hash (not plain text)
4. Response: `{ status: 0, message: "Registrasi berhasilsilakukan login", data: null }`
5. Error if email already exists: `{ status: 102, message: "...", data: null }`

**Verification:**
- `curl -X POST /registration -d '{"email":"test@test.com","password":"12345678"}'` → 201 + token response format

### Feature: Login (POST /login)
**Done when ALL of these are true:**
1. Email and password validated (not empty)
2. bcrypt compare works
3. JWT returned on success
4. Response: `{ status: 0, message: "Login Sukses", data: { token: "..." } }`
5. Error: `{ status: 103, message: "Username atau password salah", data: null }`

**Verification:**
- `curl -X POST /login -d '{"email":"test@test.com","password":"wrong"}'` → 401 + status 103

### Feature: Get Profile (GET /profile)
**Done when ALL of these are true:**
1. JWT required (401 if missing)
2. Response: `{ status: 0, message: "Sukses", data: { email, first_name, last_name, profile_image } }`
3. No password in response

**Verification:**
- With valid token → 200 + user data
- Without token → 401 + status 108

### Feature: Update Profile (PUT /profile/update)
**Done when ALL of these are true:**
1. JWT required
2. Updates first_name and last_name only (email cannot change)
3. Response: `{ status: 0, message: "Update Profile berhasil", data: { email, first_name, last_name, profile_image } }`

**Verification:**
- `curl -X PUT /profile/update -H "Authorization: Bearer {{token}}" -d '{"first_name":"John"}'` → 200

### Feature: Update Profile Image (PUT /profile/image)
**Done when ALL of these are true:**
1. JWT required
2. Multipart/form-data with field `profile_image`
3. Only accepts jpeg/png (rejects others with status 102)
4. File saved to uploads/ directory
5. Response includes updated profile_image path

**Verification:**
- Upload jpeg → 200 + path in response
- Upload png → 200 + path in response
- Upload gif → 400 + status 102

### Feature: Get Banner (GET /banner)
**Done when ALL of these are true:**
1. JWT required
2. Returns array of banners with: banner_name, banner_image, description
3. At least 5 banners seeded
4. Response: `{ status: 0, message: "Sukses", data: [...] }`

### Feature: Get Services (GET /services)
**Done when ALL of these are true:**
1. JWT required
2. Returns array of services with: service_code, service_name, service_icon, service_tariff
3. At least 12 services seeded
4. Response: `{ status: 0, message: "Sukses", data: [...] }`

### Feature: Get Balance (GET /balance)
**Done when ALL of these are true:**
1. JWT required
2. Returns user's current balance
3. Response: `{ status: 0, message: "Get Balance Berhasil", data: { balance: ... } }`

### Feature: Top Up (POST /topup)
**Done when ALL of these are true:**
1. JWT required
2. top_up_amount must be positive number > 0
3. Balance updated atomically using single UPDATE query (`UPDATE users SET balance = balance + ?`)
4. Transaction recorded with type "TOPUP"
5. Response: `{ status: 0, message: "Top Up Balance berhasil", data: { balance: <new_balance> } }`
6. Error if amount <= 0: `{ status: 102, message: "Paramter amount hanya boleh angka dan tidak boleh lebih kecil dari 0", data: null }`

**NOT done if:**
- Balance read first, then written (read-write race condition)
- Multiple queries for single topup operation

### Feature: Transaction (POST /transaction)
**Done when ALL of these are true:**
1. JWT required
2. service_code validated against services table
3. Balance sufficient (>= tariff) — checked atomically in same query or before deduct
4. Balance deducted atomically using single UPDATE query (`UPDATE users SET balance = balance - ? WHERE id = ? AND balance >= ?`)
5. Transaction recorded with invoice_number (format: INV+timestamp-random)
6. Response: `{ status: 0, message: "Transaksi berhasil", data: { invoice_number, service_code, service_name, transaction_type, total_amount, created_on } }`
7. Error if service not found: `{ status: 102, message: "Service atau Layanan tidak ditemukan", data: null }`
8. Error if insufficient balance: `{ status: 102, message: "Saldo tidak mencukupi", data: null }`

**NOT done if:**
- Balance read first, then written separately (race condition)
- Multiple queries for single transaction operation

### Feature: Transaction History (GET /transaction/history)
**Done when ALL of these are true:**
1. JWT required
2. Pagination: offset, limit params
3. Returns user's transactions only (DESC by created_on)
4. Response: `{ status: 0, message: "Get History Berhasil", data: { offset, limit, records: [...] } }`

### Feature: Migration System
**Done when ALL of these are true:**
1. `npm run migrate` executes all DDL and seeds
2. Idempotent: safe to run multiple times
3. Creates all 4 tables with correct schema
4. Seeds 5 banners + 12 services

### Feature: Postman Collection
**Done when ALL of these are true:**
1. All 11 endpoints covered
2. `{{base_url}}` variable used
3. `{{token}}` variable auto-saved from login
4. Auth header set for protected endpoints
5. Can be imported and run immediately

## Decision Framework

### Pivot when:
- > 50% acceptance criteria fail after wave execution
- Architecture assumption proven wrong

### Stop and ask when:
- DB credentials not provided
- Blocker found not in pre-mortem

### Continue without asking:
- Fix clear root cause issues
- Config changes that don't affect business logic

### Early warning signs:
- Developer self-test fails > 3 items → architecture issue
- Boot fails → config/resource issue
- > 5 interface mismatches → contract too vague