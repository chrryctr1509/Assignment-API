# AGENT BRIEF — REST API SIMS PPOB (NodeJS / ExpressJS)

> Paste prompt ini ke Claude Code setelah `claude` dibuka di root project kamu.
> Gunakan command: `/start GREENFIELD`

---

## CONTEXT & OBJECTIVE

Kamu akan membangun **REST API SIMS PPOB** dari nol (GREENFIELD) menggunakan **Node.js + ExpressJS**. Ini adalah test praktek untuk posisi API Programmer di Nutech Integrasi.

**Stack yang WAJIB digunakan:**
- Runtime: Node.js (LTS)
- Framework: ExpressJS
- Database: MySQL
- ORM/Query: **RAW QUERY dengan prepared statement** (bukan Sequelize/TypeORM/Prisma ORM)
- Auth: JWT (JSON Web Token)
- Password hashing: bcrypt

**Swagger Reference:** https://api-doc-tht.nutech-integrasi.com

---

## SCOPE / FITUR YANG HARUS DIBANGUN

### Modul 1: Membership

#### 1.1 Registrasi
- **POST** `/registration`
- Request body: `{ email, first_name, last_name, password }`
- Validasi: email format valid, password minimal 8 karakter
- Password di-hash dengan bcrypt sebelum disimpan
- Response success (201): `{ status: 0, message: "Registrasi berhasil silahkan login", data: null }`
- Response error (400): `{ status: 102, message: "...", data: null }` — jika email sudah terdaftar atau validasi gagal

#### 1.2 Login
- **POST** `/login`
- Request body: `{ email, password }`
- Validasi: email & password tidak boleh kosong
- Return JWT token jika berhasil
- Response success (200): `{ status: 0, message: "Login Sukses", data: { token: "jwt_token_here" } }`
- Response error (401): `{ status: 103, message: "Username atau password salah", data: null }`

#### 1.3 Get Profile
- **GET** `/profile`
- Header: `Authorization: Bearer <token>` (WAJIB)
- Response success (200): `{ status: 0, message: "Sukses", data: { email, first_name, last_name, profile_image } }`
- Response error (401): jika token tidak valid / tidak ada

#### 1.4 Update Profile
- **PUT** `/profile/update`
- Header: `Authorization: Bearer <token>` (WAJIB)
- Request body: `{ first_name, last_name }`
- Tidak boleh update email
- Response success (200): `{ status: 0, message: "Update Profile berhasil", data: { email, first_name, last_name, profile_image } }`

#### 1.5 Update Profile Image
- **PUT** `/profile/image`
- Header: `Authorization: Bearer <token>` (WAJIB)
- Request: multipart/form-data, field `profile_image`
- Hanya menerima format: jpeg, png
- Simpan file ke folder `uploads/` atau cloud storage
- Response success (200): `{ status: 0, message: "Update Profile Image berhasil", data: { email, first_name, last_name, profile_image } }`
- Response error (400): jika format bukan jpeg/png — `{ status: 102, message: "Format Image tidak sesuai", data: null }`

---

### Modul 2: Informasi

#### 2.1 Banner
- **GET** `/banner`
- Header: `Authorization: Bearer <token>` (WAJIB)
- Response success: `{ status: 0, message: "Sukses", data: [ { banner_name, banner_image, description } ] }`
- Data banner di-seed saat migration (minimal 5 banner)

#### 2.2 Services (Daftar Layanan)
- **GET** `/services`
- Header: `Authorization: Bearer <token>` (WAJIB)
- Response success: `{ status: 0, message: "Sukses", data: [ { service_code, service_name, service_icon, service_tariff } ] }`
- Data services di-seed saat migration, contoh services:
  - PULSA: Rp 40.000
  - PGN: Rp 50.000 (Tagihan Gas)
  - LISTRIK: Rp 10.000 (Tagihan Listrik)
  - PDAM: Rp 40.000 (Tagihan PDAM)
  - PBB: Rp 40.000 (Pajak Bumi dan Bangunan)
  - TV_LANGGANAN: Rp 36.000
  - MUSIK: Rp 50.000
  - VOUCHER_GAME: Rp 100.000
  - VOUCHER_MAKANAN: Rp 30.000
  - KURBAN: Rp 2.500.000
  - ZAKAT: Rp 300.000
  - QURBAN: Rp 200.000

---

### Modul 3: Transaksi

#### 3.1 Get Balance / Cek Saldo
- **GET** `/balance`
- Header: `Authorization: Bearer <token>` (WAJIB)
- Response success: `{ status: 0, message: "Get Balance Berhasil", data: { balance: 0 } }`

#### 3.2 Top Up
- **POST** `/topup`
- Header: `Authorization: Bearer <token>` (WAJIB)
- Request body: `{ top_up_amount: number }`
- Validasi: `top_up_amount` harus angka positif > 0
- Tambahkan saldo user sebesar `top_up_amount`
- Catat ke tabel transaksi dengan `transaction_type: "TOPUP"`
- Response success: `{ status: 0, message: "Top Up Balance berhasil", data: { balance: <new_balance> } }`
- Response error (400): `{ status: 102, message: "Paramter amount hanya boleh angka dan tidak boleh lebih kecil dari 0", data: null }`

#### 3.3 Transaksi (Pembayaran Layanan)
- **POST** `/transaction`
- Header: `Authorization: Bearer <token>` (WAJIB)
- Request body: `{ service_code: string }`
- Validasi:
  - `service_code` harus valid (ada di tabel services)
  - Saldo user harus >= tariff layanan
- Logic:
  - Cari layanan berdasarkan `service_code`
  - Kurangi saldo user sebesar `service_tariff`
  - Catat ke tabel transaksi dengan `transaction_type: "PAYMENT"`, simpan `service_code`, `service_name`, `total_amount`
  - Generate `invoice_number` unik format: `INV17082023-001` (bisa pakai timestamp + random)
- Response success:
```json
{
  "status": 0,
  "message": "Transaksi berhasil",
  "data": {
    "invoice_number": "INV17082023-001",
    "service_code": "PULSA",
    "service_name": "Pulsa",
    "transaction_type": "PAYMENT",
    "total_amount": 40000,
    "created_on": "2023-08-17T10:10:10.000Z"
  }
}
```
- Response error saldo tidak cukup (400): `{ status: 102, message: "Saldo tidak mencukupi", data: null }`
- Response error service tidak ada (400): `{ status: 102, message: "Service atau Layanan tidak ditemukan", data: null }`

#### 3.4 Riwayat Transaksi
- **GET** `/transaction/history`
- Header: `Authorization: Bearer <token>` (WAJIB)
- Query params: `?offset=0&limit=5` (pagination)
- Return transaksi milik user yang sedang login, urut DESC by `created_on`
- Response success:
```json
{
  "status": 0,
  "message": "Get History Berhasil",
  "data": {
    "offset": 0,
    "limit": 5,
    "records": [
      {
        "invoice_number": "INV17082023-001",
        "transaction_type": "PAYMENT",
        "description": "Pulsa",
        "total_amount": 40000,
        "created_on": "2023-08-17T10:10:10.000Z"
      }
    ]
  }
}
```

---

## STRUKTUR DIREKTORI YANG DIHARAPKAN

```
/
├── src/
│   ├── config/
│   │   └── database.js          # konfigurasi koneksi DB
│   ├── middleware/
│   │   ├── auth.js              # JWT middleware
│   │   └── upload.js            # multer config untuk image upload
│   ├── routes/
│   │   ├── membership.js
│   │   ├── information.js
│   │   └── transaction.js
│   ├── controllers/
│   │   ├── membershipController.js
│   │   ├── informationController.js
│   │   └── transactionController.js
│   └── app.js                   # express setup
├── migrations/
│   └── 001_init.sql             # DDL semua tabel
├── seeds/
│   └── seed.sql                 # data awal banner & services
├── scripts/
│   └── migrate.js               # script auto-migration
├── uploads/                     # folder untuk profile images
├── postman/
│   └── SIMS_PPOB.postman_collection.json
├── .env.example
├── .env
├── package.json
├── README.md
└── Dockerfile (optional, jika deploy via Docker)
```

---

## DATABASE DESIGN — TABEL YANG DIBUTUHKAN

### Tabel: `users`
```sql
CREATE TABLE IF NOT EXISTS users (
  id            CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  email         VARCHAR(100) UNIQUE NOT NULL,
  first_name    VARCHAR(50) NOT NULL,
  last_name     VARCHAR(50) NOT NULL,
  password      VARCHAR(255) NOT NULL,
  profile_image VARCHAR(255) DEFAULT NULL,
  balance       DECIMAL(15,2) DEFAULT 0,
  created_on    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_on    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### Tabel: `banners`
```sql
CREATE TABLE IF NOT EXISTS banners (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  banner_name   VARCHAR(100) NOT NULL,
  banner_image  VARCHAR(255) NOT NULL,
  description   TEXT,
  created_on    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Tabel: `services`
```sql
CREATE TABLE IF NOT EXISTS services (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  service_code   VARCHAR(50) UNIQUE NOT NULL,
  service_name   VARCHAR(100) NOT NULL,
  service_icon   VARCHAR(255),
  service_tariff DECIMAL(15,2) NOT NULL,
  created_on     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Tabel: `transactions`
```sql
CREATE TABLE IF NOT EXISTS transactions (
  id               CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  user_id          CHAR(36) NOT NULL,
  invoice_number   VARCHAR(50) UNIQUE NOT NULL,
  service_code     VARCHAR(50) DEFAULT NULL,
  service_name     VARCHAR(100) DEFAULT NULL,
  transaction_type VARCHAR(20) NOT NULL,
  total_amount     DECIMAL(15,2) NOT NULL,
  created_on       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

---

## KETENTUAN TEKNIS WAJIB

### 1. Raw Query + Prepared Statement
**WAJIB** menggunakan raw query. DILARANG menggunakan ORM seperti Sequelize, TypeORM, Prisma untuk query data.

Contoh yang BENAR:
```javascript
// Menggunakan mysql2
const [rows] = await pool.execute(
  'SELECT * FROM users WHERE email = ?',
  [email]
);

// Insert dengan prepared statement
await pool.execute(
  'INSERT INTO users (id, email, first_name, last_name, password) VALUES (UUID(), ?, ?, ?, ?)',
  [email, first_name, last_name, hashedPassword]
);
```

### 2. JWT Authentication Middleware
- Semua endpoint kecuali `/registration` dan `/login` WAJIB dilindungi JWT
- Token dikirim via header: `Authorization: Bearer <token>`
- Jika token tidak valid / expired: return 401 `{ status: 108, message: "Token tidak tidak valid atau kadaluwarsa", data: null }`

### 3. Auto Migration Script
Buat script `scripts/migrate.js` yang:
- Membaca file `migrations/001_init.sql` dan `seeds/seed.sql`
- Menjalankan semua DDL & seed data secara otomatis
- Bisa dijalankan dengan: `npm run migrate`
- Idempotent (bisa dijalankan berkali-kali tanpa error — gunakan `CREATE TABLE IF NOT EXISTS`)

### 4. Error Response Format
Semua error harus mengikuti format konsisten:
```json
{
  "status": <kode_error>,
  "message": "<pesan_error>",
  "data": null
}
```

Kode status yang digunakan:
- `0` = sukses
- `102` = bad request / validasi gagal
- `103` = username/password salah
- `108` = token invalid/expired

### 5. Validasi Input
- Gunakan validasi di layer controller atau middleware dedicated
- Email: harus format email valid
- Password: minimal 8 karakter
- Amount: harus angka, tidak boleh negatif atau 0
- Service code: harus ada di database

---

## DELIVERABLE YANG WAJIB DIBUAT

### ✅ 1. Auto Migration
File: `migrations/001_init.sql` (DDL semua tabel)
File: `seeds/seed.sql` (data banner & services)
File: `scripts/migrate.js` (runner)
Script npm: `"migrate": "node scripts/migrate.js"`

Migration harus:
- Membuat semua tabel (users, banners, services, transactions)
- Seed data banner minimal 5 item
- Seed data services minimal 12 item (sesuai daftar di atas)
- Bisa dijalankan dengan `npm run migrate`
- Idempotent (tidak error jika dijalankan ulang)

### ✅ 2. Postman Collection
File: `postman/SIMS_PPOB.postman_collection.json`

Harus mencakup **semua endpoint**:
1. Registration
2. Login (dengan auto-save token ke collection variable `{{token}}`)
3. Get Profile
4. Update Profile
5. Update Profile Image
6. Get Banner
7. Get Services
8. Get Balance
9. Top Up
10. Transaction (Pembayaran)
11. Transaction History

Setiap request harus memiliki:
- URL menggunakan variable `{{base_url}}`
- Header Authorization menggunakan `{{token}}` (kecuali register & login)
- Contoh request body (pre-filled)
- Deskripsi singkat di field description

### ✅ 3. README.md
Harus mencakup:
1. **Deskripsi singkat** — apa yang dibangun
2. **Tech Stack** — Node.js, ExpressJS, MySQL, JWT, bcrypt
3. **Prerequisites** — Node.js, PostgreSQL, npm
4. **Instalasi & Setup**:
   ```bash
   git clone <repo_url>
   cd <project_name>
   npm install
   cp .env.example .env
   # Edit .env sesuai konfigurasi DB
   npm run migrate
   npm start
   ```
5. **Environment Variables** — tabel semua variabel yang dibutuhkan di `.env`
6. **API Endpoints** — tabel semua endpoint (method, path, auth, deskripsi)
7. **Database Schema** — deskripsi singkat tiap tabel
8. **Deployment** — cara deploy ke Railway.app (atau platform lain)
9. **Testing** — cara import Postman collection dan test API

---

## ENVIRONMENT VARIABLES (.env.example)

```env
# Server
PORT=3000
NODE_ENV=development

# Database
DB_HOST=localhost
DB_PORT=3306
DB_NAME=sims_ppob
DB_USER=root
DB_PASSWORD=your_password

# JWT
JWT_SECRET=your_jwt_secret_key_minimum_32_chars
JWT_EXPIRES_IN=12h

# Upload
UPLOAD_DIR=uploads
```

---

## PACKAGE.JSON SCRIPTS YANG DIBUTUHKAN

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

## DEPENDENCIES YANG DIREKOMENDASIKAN

```json
{
  "dependencies": {
    "express": "^4.18.x",
    "mysql2": "^3.6.x",
    "bcryptjs": "^2.4.x",
    "jsonwebtoken": "^9.0.x",
    "multer": "^1.4.x",
    "dotenv": "^16.x",
    "cors": "^2.8.x"
  },
  "devDependencies": {
    "nodemon": "^3.x"
  }
}
```

---

## DEPLOYMENT NOTES (untuk Railway.app)

Pastikan:
1. Ada file `Procfile` atau `railway.toml` atau pastikan `npm start` bisa jalan
2. Environment variables diset di Railway dashboard
3. Database MySQL bisa pakai Railway MySQL plugin (gratis)
4. Jalankan `npm run migrate` sebagai build command atau via Railway's start command
5. URL deployment sertakan di README

---

## KRITERIA PENILAIAN (ingat saat coding)

1. ✅ Semua endpoint sesuai Swagger spec
2. ✅ Design database normalized dan efisien
3. ✅ **RAW QUERY + PREPARED STATEMENT** — ini wajib, bukan opsional
4. ✅ Saldo benar: TOPUP menambah, PAYMENT mengurangi, tidak bisa negatif
5. ✅ Error handling lengkap: validasi input, token expired, saldo kurang, dll
6. ✅ Kode bersih, terstruktur, mudah dipahami

---

## INSTRUKSI UNTUK AGENT

Ikuti pipeline GREENFIELD:
1. **Phase 0**: Analisis brief ini, buat wave plan
2. **Wave 1 - Foundation**: Setup project, database config, migration script, seeds
3. **Wave 2 - Auth & Membership**: Register, Login, Profile endpoints + JWT middleware
4. **Wave 3 - Information**: Banner & Services endpoints
5. **Wave 4 - Transaction**: Balance, TopUp, Transaction, History endpoints
6. **Wave 5 - Deliverables**: Postman collection, README, .env.example
7. **QA**: Test semua endpoint, pastikan response sesuai format spec

**PENTING:**
- SEMUA query ke database HARUS raw query dengan prepared statement (`$1, $2, ...` untuk pg)
- JANGAN gunakan ORM
- Migration HARUS idempotent (`IF NOT EXISTS`)
- Postman collection HARUS bisa langsung di-import dan dijalankan
- README HARUS lengkap sampai cara deploy

Mulai dengan: baca brief ini → buat wave plan → minta approval → eksekusi wave per wave.