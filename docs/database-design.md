# SIMS PPOB — Database Design Document

## Overview
- **Database Name:** sims_ppob
- **Engine:** MySQL 8.0+
- **Character Set:** utf8mb4
- **Collation:** utf8mb4_unicode_ci

## Entity Relationship Diagram

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

## Tables

### 1. users
**Description:** User account data

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

**Indexes:**
- PRIMARY KEY on `id`
- UNIQUE INDEX on `email`

**DDL:**
```sql
CREATE TABLE users (
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
```

---

### 2. banners
**Description:** Promotional banners

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INT | PRIMARY KEY, AUTO_INCREMENT | - | Banner ID |
| banner_name | VARCHAR(100) | NOT NULL | - | Banner display name |
| banner_image | VARCHAR(255) | NOT NULL | - | Banner image URL |
| description | TEXT | DEFAULT NULL | - | Banner description |
| created_on | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | - | Creation time |

**Indexes:**
- PRIMARY KEY on `id`

**DDL:**
```sql
CREATE TABLE banners (
  id INT AUTO_INCREMENT PRIMARY KEY,
  banner_name VARCHAR(100) NOT NULL,
  banner_image VARCHAR(255) NOT NULL,
  description TEXT,
  created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

### 3. services
**Description:** Available payment services

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | INT | PRIMARY KEY, AUTO_INCREMENT | - | Service ID |
| service_code | VARCHAR(50) | UNIQUE, NOT NULL | - | Service code (e.g., PULSA) |
| service_name | VARCHAR(100) | NOT NULL | - | Service display name |
| service_icon | VARCHAR(255) | DEFAULT NULL | - | Service icon URL |
| service_tariff | DECIMAL(15,2) | NOT NULL | - | Service price in IDR |
| created_on | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | - | Creation time |

**Indexes:**
- PRIMARY KEY on `id`
- UNIQUE INDEX on `service_code`

**DDL:**
```sql
CREATE TABLE services (
  id INT AUTO_INCREMENT PRIMARY KEY,
  service_code VARCHAR(50) UNIQUE NOT NULL,
  service_name VARCHAR(100) NOT NULL,
  service_icon VARCHAR(255),
  service_tariff DECIMAL(15,2) NOT NULL,
  created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

### 4. transactions
**Description:** User transaction history

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

**Indexes:**
- PRIMARY KEY on `id`
- UNIQUE INDEX on `invoice_number`
- INDEX on `user_id`
- INDEX on `created_on`

**Foreign Key:**
- `user_id` → `users.id` (ON DELETE CASCADE)

**DDL:**
```sql
CREATE TABLE transactions (
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

---

## Seed Data

### Banners (5 items)
| id | banner_name | banner_image | description |
|----|-------------|--------------|-------------|
| 1 | Promo Selamat Tahun Baru | https://cdn.example.com/banner/newyear.jpg | Diskon 20% untuk semua transaksi |
| 2 | Cashback 10% | https://cdn.example.com/banner/cashback.jpg | Cashback 10% untuk pembayaran pulsa |
| 3 | Gratis biaya admin | https://cdn.example.com/banner/freeadmin.jpg | Tidak ada biaya admin untuk bulan ini |
| 4 | Promo Weekend | https://cdn.example.com/banner/weekend.jpg | Diskon special weekend |
| 5 | Bonus Saldo | https://cdn.example.com/banner/bonus.jpg | Dapatkan bonus saldo setelah registrasi |

```sql
INSERT IGNORE INTO banners (id, banner_name, banner_image, description) VALUES
(1, 'Promo Selamat Tahun Baru', 'https://cdn.example.com/banner/newyear.jpg', 'Diskon 20% untuk semua transaksi'),
(2, 'Cashback 10%', 'https://cdn.example.com/banner/cashback.jpg', 'Cashback 10% untuk pembayaran pulsa'),
(3, 'Gratis biaya admin', 'https://cdn.example.com/banner/freeadmin.jpg', 'Tidak ada biaya admin untuk bulan ini'),
(4, 'Promo Weekend', 'https://cdn.example.com/banner/weekend.jpg', 'Diskon special weekend'),
(5, 'Bonus Saldo', 'https://cdn.example.com/banner/bonus.jpg', 'Dapatkan bonus saldo setelah registrasi');
```

### Services (12 items)
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

```sql
INSERT IGNORE INTO services (id, service_code, service_name, service_icon, service_tariff) VALUES
(1, 'PULSA', 'Pulsa Elektrik', 'https://cdn.example.com/icon/pulsa.png', 40000.00),
(2, 'PGN', 'Tagihan Gas', 'https://cdn.example.com/icon/pgn.png', 50000.00),
(3, 'LISTRIK', 'Tagihan Listrik', 'https://cdn.example.com/icon/listrik.png', 10000.00),
(4, 'PDAM', 'Tagihan PDAM', 'https://cdn.example.com/icon/pdam.png', 40000.00),
(5, 'PBB', 'Pajak Bumi dan Bangunan', 'https://cdn.example.com/icon/pbb.png', 40000.00),
(6, 'TV_LANGGANAN', 'TV Langganan', 'https://cdn.example.com/icon/tv.png', 36000.00),
(7, 'MUSIK', 'Langganan Musik', 'https://cdn.example.com/icon/musik.png', 50000.00),
(8, 'VOUCHER_GAME', 'Voucher Game', 'https://cdn.example.com/icon/game.png', 100000.00),
(9, 'VOUCHER_MAKANAN', 'Voucher Makanan', 'https://cdn.example.com/icon/food.png', 30000.00),
(10, 'KURBAN', 'Kurban', 'https://cdn.example.com/icon/kurban.png', 2500000.00),
(11, 'ZAKAT', 'Zakat', 'https://cdn.example.com/icon/zakat.png', 300000.00),
(12, 'QURBAN', 'Qurban', 'https://cdn.example.com/icon/qurban.png', 200000.00);
```

---

## Complete DDL (All Tables)

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

---

## Migration Status

| Table | DDL File | Seed Data | Status |
|-------|----------|-----------|--------|
| users | migrations/001_init.sql | - | ✅ Created |
| banners | migrations/001_init.sql | seeds/seed.sql | ✅ Created |
| services | migrations/001_init.sql | seeds/seed.sql | ✅ Created |
| transactions | migrations/001_init.sql | - | ✅ Created |

Run migration: `npm run migrate`