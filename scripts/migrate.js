const fs = require("fs");
const path = require("path");
const mysql = require("mysql2/promise");
require("dotenv").config();

async function migrate() {
  console.log("Starting migration...");

  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    multipleStatements: true,
  });

  const migrationDir = path.join(__dirname, "..", "migrations");
  const seedsDir = path.join(__dirname, "..", "seeds");

  try {
    // Run migrations
    const migrationSQL = fs.readFileSync(
      path.join(migrationDir, "001_init.sql"),
      "utf8",
    );
    console.log("Running migrations...");
    await connection.query(migrationSQL);
    console.log("Migrations complete.");

    // Run seeds
    const seedSQL = fs.readFileSync(path.join(seedsDir, "seed.sql"), "utf8");
    console.log("Running seeds...");
    await connection.query(seedSQL);
    console.log("Seeds complete.");

    await connection.end();
    console.log("All migrations and seeds completed successfully.");
    process.exit(0);
  } catch (error) {
    await connection.end();
    console.error("Migration failed:", error.message);
    process.exit(1);
  }
}

migrate();
