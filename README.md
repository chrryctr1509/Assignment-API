# SIMS PPOB API

REST API for SIMS PPOB payment services.

**Live URL:** https://assignment-api-production-7244.up.railway.app

---

## API Usage Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    SIMS PPOB API FLOW                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌──────────┐      ┌──────────┐      ┌──────────────────┐ │
│   │ REGISTER │ ───► │  LOGIN   │ ───► │ GET TOKEN + SAVE │ │
│   └──────────┘      └──────────┘      └────────┬─────────┘ │
│                                                 │           │
│   ┌─────────────────────────────────────────────┘           │
│   │                                                      │
│   ▼                                                      │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│   │ BALANCE  │  │  BANNER  │  │ SERVICES │  │ PROFILE  │  │
│   └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  │
│        │             │             │             │         │
│        └─────────────┴─────────────┴─────────────┘         │
│                         │                                   │
│                    (READ DATA)                              │
│                         │                                   │
│   ┌─────────────────────┴─────────────────────┐            │
│   │                                              │            │
│   ▼                                              ▼            │
│   ┌──────────┐                          ┌──────────────┐       │
│   │  TOP UP  │                          │ TRANSACTION │       │
│   │ (+saldo) │                          │  (PAYMENT)  │       │
│   └────┬─────┘                          └──────┬───────┘       │
│        │                                       │              │
│        └───────────────┬───────────────────────┘              │
│                        ▼                                     │
│               ┌──────────────┐                               │
│               │   HISTORY    │                               │
│               │ (view all)   │                               │
│               └──────────────┘                               │
└─────────────────────────────────────────────────────────────┘
```

### Flow Steps:

1. **REGISTER** → Create new account
2. **LOGIN** → Get JWT token
3. **READ DATA** → Balance, Banner, Services, Profile
4. **TOP UP** → Add balance to account
5. **TRANSACTION** → Pay for services (Pulsa, Game, etc.)
6. **HISTORY** → View all transactions

---

## Database Design

### Entity Relationship Diagram

```
┌─────────────────┐     ┌─────────────────┐
│     USERS        │     │    BANNERS      │
├─────────────────┤     ├─────────────────┤
│ id (PK) CHAR(36)│     │ id (PK) INT     │
│ email VARCHAR   │     │ banner_name     │
│ first_name      │     │ banner_image    │
│ last_name       │     │ description     │
│ password        │     │ created_on      │
│ profile_image   │     └─────────────────┘
│ balance         │
│ created_on       │     ┌─────────────────┐
│ updated_on       │     │    SERVICES     │
└────────┬────────┘     ├─────────────────┤
         │              │ id (PK) INT     │
         │ 1:N           │ service_code    │
         ▼              │ service_name    │
┌─────────────────┐     │ service_icon    │
│  TRANSACTIONS   │     │ service_tariff  │
├─────────────────┤     │ created_on      │
│ id (PK) CHAR(36)│     └─────────────────┘
│ user_id (FK)    │
│ invoice_number  │
│ service_code    │
│ service_name    │
│ transaction_type│
│ total_amount    │
│ created_on       │
└─────────────────┘
```

### Complete DDL (All Tables)

```sql
-- SIMS PPOB Database Schema
-- Database Engine: MySQL 8.0+

-- Create Database
CREATE DATABASE IF NOT EXISTS sims_ppob
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE sims_ppob;

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  email VARCHAR(100) UNIQUE NOT NULL,
  first_name VARCHAR(50) NOT NULL,
  last_name VARCHAR(50) NOT NULL,
  password VARCHAR(255) NOT NULL,
  profile_image VARCHAR(255) DEFAULT NULL,
  balance DECIMAL(15,2) DEFAULT 0,
  created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Banners table
CREATE TABLE IF NOT EXISTS banners (
  id INT AUTO_INCREMENT PRIMARY KEY,
  banner_name VARCHAR(100) NOT NULL,
  banner_image VARCHAR(255) NOT NULL,
  description TEXT,
  created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Services table
CREATE TABLE IF NOT EXISTS services (
  id INT AUTO_INCREMENT PRIMARY KEY,
  service_code VARCHAR(50) UNIQUE NOT NULL,
  service_name VARCHAR(100) NOT NULL,
  service_icon VARCHAR(255),
  service_tariff DECIMAL(15,2) NOT NULL,
  created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Transactions table
CREATE TABLE IF NOT EXISTS transactions (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  user_id CHAR(36) NOT NULL,
  invoice_number VARCHAR(50) UNIQUE NOT NULL,
  service_code VARCHAR(50) DEFAULT NULL,
  service_name VARCHAR(100) DEFAULT NULL,
  transaction_type VARCHAR(20) NOT NULL,
  total_amount DECIMAL(15,2) NOT NULL,
  created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_id (user_id),
  INDEX idx_created_on (created_on)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### Seed Data

**Banners (5 items):**
| id | banner_name | banner_image | description |
|----|-------------|--------------|-------------|
| 1 | Promo Selamat Tahun Baru | https://cdn.example.com/banner/newyear.jpg | Diskon 20% untuk semua transaksi |
| 2 | Cashback 10% | https://cdn.example.com/banner/cashback.jpg | Cashback 10% untuk pembayaran pulsa |
| 3 | Gratis biaya admin | https://cdn.example.com/banner/freeadmin.jpg | Tidak ada biaya admin untuk bulan ini |
| 4 | Promo Weekend | https://cdn.example.com/banner/weekend.jpg | Diskon special weekend |
| 5 | Bonus Saldo | https://cdn.example.com/banner/bonus.jpg | Dapatkan bonus saldo setelah registrasi |

**Services (12 items):**
| id | service_code | service_name | service_icon | service_tariff |
|----|--------------|--------------|--------------|---------------|
| 1 | PULSA | Pulsa Elektrik | https://cdn.example.com/icon/pulsa.png | 40,000.00 |
| 2 | PGN | Tagihan Gas | https://cdn.example.com/icon/pgn.png | 50,000.00 |
| 3 | LISTRIK | Tagihan Listrik | https://cdn.example.com/icon/listrik.png | 10,000.00 |
| 4 | PDAM | Tagihan PDAM | https://cdn.example.com/icon/pdam.png | 40,000.00 |
| 5 | PBB | Pajak Bumi dan Bangunan | https://cdn.example.com/icon/pbb.png | 40,000.00 |
| 6 | TV_LANGGANAN | TV Langganan | https://cdn.example.com/icon/tv.png | 36,000.00 |
| 7 | MUSIK | Langganan Musik | https://cdn.example.com/icon/musik.png | 50,000.00 |
| 8 | VOUCHER_GAME | Voucher Game | https://cdn.example.com/icon/game.png | 100,000.00 |
| 9 | VOUCHER_MAKANAN | Voucher Makanan | https://cdn.example.com/icon/food.png | 30,000.00 |
| 10 | KURBAN | Kurban | https://cdn.example.com/icon/kurban.png | 2,500,000.00 |
| 11 | ZAKAT | Zakat | https://cdn.example.com/icon/zakat.png | 300,000.00 |
| 12 | QURBAN | Qurban | https://cdn.example.com/icon/qurban.png | 200,000.00 |

---

## Tech Stack
- Node.js + ExpressJS
- MySQL (mysql2/promise)
- JWT Authentication
- bcrypt password hashing

## Prerequisites
- Node.js 18+
- MySQL 8.0+
- npm

## Installation

```bash
# Clone repository
git clone https://github.com/chrryctr1509/Assignment-API.git
cd Assignment-API

# Install dependencies
npm install

# Setup environment
cp .env.example .env
# Edit .env with your MySQL credentials

# Run migrations
npm run migrate

# Start server
npm start
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| PORT | Server port | 3000 |
| NODE_ENV | Environment | development |
| MYSQL_URL | Railway MySQL connection string | - |
| DB_HOST | MySQL host (local) | localhost |
| DB_PORT | MySQL port | 3306 |
| DB_NAME | Database name | sims_ppob |
| DB_USER | Database user | postgres |
| DB_PASSWORD | Database password | - |
| JWT_SECRET | JWT signing secret | - |
| JWT_EXPIRES_IN | Token expiry | 12h |
| UPLOAD_DIR | Upload directory | uploads |

---

## API Endpoints

### 1. POST /registration
**Auth:** No | **Method:** POST

```bash
POST https://assignment-api-production-7244.up.railway.app/registration
Content-Type: application/json

Body:
{
  "email": "user@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "password": "password123"
}

Response (201):
{
  "status": 0,
  "message": "Registrasi berhasil silakan login",
  "data": null
}
```

### 2. POST /login
**Auth:** No | **Method:** POST

```bash
POST https://assignment-api-production-7244.up.railway.app/login
Content-Type: application/json

Body:
{
  "email": "user@example.com",
  "password": "password123"
}

Response (200):
{
  "status": 0,
  "message": "Login Sukses",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### 3. GET /health
**Auth:** No | **Method:** GET

```bash
GET https://assignment-api-production-7244.up.railway.app/health

Response (200):
{
  "status": "ok",
  "timestamp": "2026-05-14T06:00:00.000Z"
}
```

### 4. GET /profile
**Auth:** JWT Required | **Method:** GET

```bash
GET https://assignment-api-production-7244.up.railway.app/profile
Authorization: Bearer {{token}}

Response (200):
{
  "status": 0,
  "message": "Sukses",
  "data": {
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "profile_image": null
  }
}
```

### 5. PUT /profile/update
**Auth:** JWT Required | **Method:** PUT

```bash
PUT https://assignment-api-production-7244.up.railway.app/profile/update
Authorization: Bearer {{token}}
Content-Type: application/json

Body:
{
  "first_name": "Jane",
  "last_name": "Doe"
}

Response (200):
{
  "status": 0,
  "message": "Update Profile berhasil",
  "data": {
    "email": "user@example.com",
    "first_name": "Jane",
    "last_name": "Doe",
    "profile_image": null
  }
}
```

### 6. PUT /profile/image
**Auth:** JWT Required | **Method:** PUT | **Content-Type:** multipart/form-data

```bash
PUT https://assignment-api-production-7244.up.railway.app/profile/image
Authorization: Bearer {{token}}
Content-Type: multipart/form-data

Form Data:
- key: profile_image (file, jpeg/png only, max 2MB)

Response (200):
{
  "status": 0,
  "message": "Update Profile Image berhasil",
  "data": {
    "email": "user@example.com",
    "first_name": "Jane",
    "last_name": "Doe",
    "profile_image": "1747152341234-1234.jpeg"
  }
}
```

### 7. GET /banner
**Auth:** JWT Required | **Method:** GET

```bash
GET https://assignment-api-production-7244.up.railway.app/banner
Authorization: Bearer {{token}}

Response (200):
{
  "status": 0,
  "message": "Sukses",
  "data": [
    {
      "banner_name": "Promo Selamat Tahun Baru",
      "banner_image": "https://cdn.example.com/banner/newyear.jpg",
      "description": "Diskon 20% untuk semua transaksi"
    },
    ...
  ]
}
```

### 8. GET /services
**Auth:** JWT Required | **Method:** GET

```bash
GET https://assignment-api-production-7244.up.railway.app/services
Authorization: Bearer {{token}}

Response (200):
{
  "status": 0,
  "message": "Sukses",
  "data": [
    {
      "service_code": "PULSA",
      "service_name": "Pulsa Elektrik",
      "service_icon": "https://cdn.example.com/icon/pulsa.png",
      "service_tariff": "40000.00"
    },
    ...
  ]
}
```

### 9. GET /balance
**Auth:** JWT Required | **Method:** GET

```bash
GET https://assignment-api-production-7244.up.railway.app/balance
Authorization: Bearer {{token}}

Response (200):
{
  "status": 0,
  "message": "Get Balance Berhasil",
  "data": {
    "balance": "0.00"
  }
}
```

### 10. POST /topup
**Auth:** JWT Required | **Method:** POST

```bash
POST https://assignment-api-production-7244.up.railway.app/topup
Authorization: Bearer {{token}}
Content-Type: application/json

Body:
{
  "top_up_amount": 50000
}

Response (200):
{
  "status": 0,
  "message": "Top Up Balance berhasil",
  "data": {
    "balance": "50000.00"
  }
}
```

### 11. POST /transaction
**Auth:** JWT Required | **Method:** POST

```bash
POST https://assignment-api-production-7244.up.railway.app/transaction
Authorization: Bearer {{token}}
Content-Type: application/json

Body:
{
  "service_code": "PULSA"
}

Response (200):
{
  "status": 0,
  "message": "Transaksi berhasil",
  "data": {
    "invoice_number": "INV1778689601622821",
    "service_code": "PULSA",
    "service_name": "Pulsa Elektrik",
    "transaction_type": "PAYMENT",
    "total_amount": "40000.00",
    "created_on": "2026-05-13T16:26:41.622Z"
  }
}
```

### 12. GET /transaction/history
**Auth:** JWT Required | **Method:** GET

```bash
GET https://assignment-api-production-7244.up.railway.app/transaction/history?offset=0&limit=5
Authorization: Bearer {{token}}

Response (200):
{
  "status": 0,
  "message": "Get History Berhasil",
  "data": {
    "offset": 0,
    "limit": 5,
    "records": [
      {
        "invoice_number": "INV1778689601622821",
        "transaction_type": "PAYMENT",
        "description": "Pulsa Elektrik",
        "total_amount": "40000.00",
        "created_on": "2026-05-13T16:26:41.000Z"
      }
    ]
  }
}
```

---

## Complete Usage Example

### Terminal with curl:

```bash
# 1. Register
curl -X POST https://assignment-api-production-7244.up.railway.app/registration \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","first_name":"Test","last_name":"User","password":"password123"}'

# 2. Login (copy token from response)
curl -X POST https://assignment-api-production-7244.up.railway.app/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# 3. Get Profile (use token)
curl https://assignment-api-production-7244.up.railway.app/profile \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

# 4. Get Balance
curl https://assignment-api-production-7244.up.railway.app/balance \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

# 5. Top Up
curl -X POST https://assignment-api-production-7244.up.railway.app/topup \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"top_up_amount": 100000}'

# 6. Transaction (bayar PULSA)
curl -X POST https://assignment-api-production-7244.up.railway.app/transaction \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"service_code": "PULSA"}'

# 7. Check History
curl "https://assignment-api-production-7244.up.railway.app/transaction/history?offset=0&limit=5" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

## Response Format

**Success:**
```json
{
  "status": 0,
  "message": "Sukses",
  "data": {...}
}
```

**Error:**
```json
{
  "status": <code>,
  "message": "...",
  "data": null
}
```

| Code | Meaning | HTTP Status |
|------|---------|-------------|
| 0 | Success | 200/201 |
| 102 | Validation error / bad request | 400 |
| 103 | Authentication failed | 401 |
| 108 | Token invalid or expired | 401 |
| 500 | Internal server error | 500 |

---

## Error Handling Guide

| Error | Cause | Solution |
|-------|-------|----------|
| `status: 102, "Format email tidak valid"` | Email format invalid | Check email format (e.g., user@domain.com) |
| `status: 102, "Email sudah terdaftar"` | Email already registered | Use different email |
| `status: 102, "Password minimal 8 karakter"` | Password too short | Use password with 8+ characters |
| `status: 103, "Username atau password salah"` | Wrong email or password | Check credentials |
| `status: 108, "Token tidak tidak valid atau kadaluwarsa"` | Token expired or invalid | Re-login to get new token |
| `status: 102, "Saldo tidak mencukupi"` | Insufficient balance | Top up first |
| `status: 102, "Service atau Layanan tidak ditemukan"` | Service code not found | Check valid service codes via GET /services |
| `status: 102, "Format Image tidak sesuai"` | Wrong file format | Use only jpeg or png |

---

## Testing with Postman

1. Import `postman/SIMS_PPOB.postman_collection.json` into Postman
2. The collection is pre-configured with Railway URL: `https://assignment-api-production-7244.up.railway.app`
3. Run **Registration** request first
4. Run **Login** request — token auto-saved to `{{token}}`
5. All subsequent requests will auto-use the token
6. Test endpoints in order: Register → Login → Profile → Balance → Top Up → Transaction → History

---

## Deployment

### Railway.app
1. Connect GitHub repository to Railway
2. Add MySQL plugin (Railway provides MySQL)
3. Set environment variable `MYSQL_URL` with Railway provided connection string
4. Deploy automatically on push to main branch

### API Live Status
- **URL:** https://assignment-api-production-7244.up.railway.app
- **Health Check:** https://assignment-api-production-7244.up.railway.app/health

---

## Database Schema Reference

### users
| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | CHAR(36) | PRIMARY KEY | UUID() | Unique user identifier |
| email | VARCHAR(100) | UNIQUE, NOT NULL | - | User email (login) |
| first_name | VARCHAR(50) | NOT NULL | - | User first name |
| last_name | VARCHAR(50) | NOT NULL | - | User last name |
| password | VARCHAR(255) | NOT NULL | - | bcrypt hashed password |
| profile_image | VARCHAR(255) | DEFAULT NULL | - | Path to profile image |
| balance | DECIMAL(15,2) | DEFAULT 0 | 0.00 | User balance (in IDR) |
| created_on | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | - | Account creation time |
| updated_on | TIMESTAMP | ON UPDATE CURRENT_TIMESTAMP | - | Last update time |

### banners
| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INT | PRIMARY KEY, AUTO_INCREMENT | - | Banner ID |
| banner_name | VARCHAR(100) | NOT NULL | - | Banner display name |
| banner_image | VARCHAR(255) | NOT NULL | - | Banner image URL |
| description | TEXT | DEFAULT NULL | - | Banner description |
| created_on | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | - | Creation time |

### services
| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INT | PRIMARY KEY, AUTO_INCREMENT | - | Service ID |
| service_code | VARCHAR(50) | UNIQUE, NOT NULL | - | Service code (e.g., PULSA) |
| service_name | VARCHAR(100) | NOT NULL | - | Service display name |
| service_icon | VARCHAR(255) | DEFAULT NULL | - | Service icon URL |
| service_tariff | DECIMAL(15,2) | NOT NULL | - | Service price in IDR |
| created_on | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | - | Creation time |

### transactions
| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | CHAR(36) | PRIMARY KEY | UUID() | Transaction ID |
| user_id | CHAR(36) | NOT NULL, FK → users.id | - | User reference |
| invoice_number | VARCHAR(50) | UNIQUE, NOT NULL | - | Unique invoice number |
| service_code | VARCHAR(50) | DEFAULT NULL | - | Service code (NULL for TOPUP) |
| service_name | VARCHAR(100) | DEFAULT NULL | - | Service name (NULL for TOPUP) |
| transaction_type | VARCHAR(20) | NOT NULL | - | TOPUP or PAYMENT |
| total_amount | DECIMAL(15,2) | NOT NULL | - | Transaction amount |
| created_on | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | - | Transaction time |