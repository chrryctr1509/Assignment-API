const mysql = require("mysql2/promise");
require("dotenv").config();

let pool;

// Railway menyediakan MYSQL_URL (private internal) atau MYSQL_PUBLIC_URL
const mysqlUrl =
  process.env.MYSQL_URL ||
  process.env.MYSQL_PUBLIC_URL;

if (mysqlUrl) {
  // Railway MySQL: gunakan connection URL langsung
  pool = mysql.createPool({
    uri: mysqlUrl,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    ssl: false, // Railway internal tidak butuh SSL
  });
  console.log("Database: connected via MYSQL_URL (Railway)");
} else {
  // Local development: gunakan individual env vars
  pool = mysql.createPool({
    host: process.env.DB_HOST || "localhost",
    port: parseInt(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER || "root",
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_NAME || "sims_ppob",
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
  });
  console.log(`Database: connected via host (${process.env.DB_HOST})`);
}

// Test koneksi saat startup
pool
  .getConnection()
  .then((conn) => {
    console.log("Database connection OK");
    conn.release();
  })
  .catch((err) => {
    console.error("Database connection FAILED:", err.message);
  });

module.exports = pool;
