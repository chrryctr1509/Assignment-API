const pool = require("../config/database");

const getBalance = async (req, res) => {
  try {
    const userId = req.user.id;

    const [users] = await pool.execute(
      "SELECT balance FROM users WHERE id = ?",
      [userId],
    );

    if (users.length === 0) {
      return res.status(404).json({
        status: 102,
        message: "User tidak ditemukan",
        data: null,
      });
    }

    return res.status(200).json({
      status: 0,
      message: "Get Balance Berhasil",
      data: { balance: users[0].balance },
    });
  } catch (error) {
    return res.status(500).json({
      status: 500,
      message: error.message,
      data: null,
    });
  }
};

const topUp = async (req, res) => {
  try {
    const userId = req.user.id;
    const { top_up_amount } = req.body;

    if (
      !top_up_amount ||
      typeof top_up_amount !== "number" ||
      top_up_amount <= 0
    ) {
      return res.status(400).json({
        status: 102,
        message: "Format Amount tidak valid",
        data: null,
      });
    }

    // Atomic top-up
    await pool.execute("UPDATE users SET balance = balance + ? WHERE id = ?", [
      top_up_amount,
      userId,
    ]);

    // Get new balance
    const [users] = await pool.execute(
      "SELECT balance FROM users WHERE id = ?",
      [userId],
    );

    const newBalance = users[0].balance;

    // Generate invoice number: INV + timestamp + random 3 digits
    const invoiceNumber =
      "INV" +
      Date.now() +
      String(Math.floor(Math.random() * 1000)).padStart(3, "0");

    // Insert transaction record
    await pool.execute(
      "INSERT INTO transactions (user_id, invoice_number, transaction_type, total_amount) VALUES (?, ?, ?, ?)",
      [userId, invoiceNumber, "TOPUP", top_up_amount],
    );

    return res.status(200).json({
      status: 0,
      message: "Top Up Balance berhasil",
      data: { balance: newBalance },
    });
  } catch (error) {
    return res.status(500).json({
      status: 500,
      message: error.message,
      data: null,
    });
  }
};

const transaction = async (req, res) => {
  try {
    const userId = req.user.id;
    const { service_code } = req.body;

    if (!service_code) {
      return res.status(400).json({
        status: 102,
        message: "Service code harus diisi",
        data: null,
      });
    }

    // Look up service
    const [services] = await pool.execute(
      "SELECT service_code, service_name, service_tariff FROM services WHERE service_code = ?",
      [service_code],
    );

    if (services.length === 0) {
      return res.status(400).json({
        status: 102,
        message: "Service atau Layanan tidak ditemukan",
        data: null,
      });
    }

    const service = services[0];

    // Atomic check & deduct: single UPDATE with balance check in WHERE clause
    const [result] = await pool.execute(
      "UPDATE users SET balance = balance - ? WHERE id = ? AND balance >= ?",
      [service.service_tariff, userId, service.service_tariff],
    );

    if (result.affectedRows === 0) {
      return res.status(400).json({
        status: 102,
        message: "Saldo tidak mencukupi",
        data: null,
      });
    }

    // Generate invoice number
    const invoiceNumber =
      "INV" +
      Date.now() +
      String(Math.floor(Math.random() * 1000)).padStart(3, "0");

    // Get current timestamp for response
    const createdOn = new Date().toISOString();

    // Insert transaction record
    await pool.execute(
      "INSERT INTO transactions (user_id, invoice_number, service_code, service_name, transaction_type, total_amount) VALUES (?, ?, ?, ?, ?, ?)",
      [
        userId,
        invoiceNumber,
        service.service_code,
        service.service_name,
        "PAYMENT",
        service.service_tariff,
      ],
    );

    return res.status(200).json({
      status: 0,
      message: "Transaksi berhasil",
      data: {
        invoice_number: invoiceNumber,
        service_code: service.service_code,
        service_name: service.service_name,
        transaction_type: "PAYMENT",
        total_amount: service.service_tariff,
        created_on: createdOn,
      },
    });
  } catch (error) {
    return res.status(500).json({
      status: 500,
      message: error.message,
      data: null,
    });
  }
};

const getHistory = async (req, res) => {
  try {
    const userId = req.user.id;
    const offset = parseInt(req.query.offset || "0");
    const limit = parseInt(req.query.limit || "5");

    const [transactions] = await pool.query(
      `SELECT
        invoice_number,
        transaction_type,
        CASE WHEN transaction_type = 'TOPUP' THEN 'Top Up' ELSE service_name END as description,
        total_amount,
        created_on
      FROM transactions
      WHERE user_id = ?
      ORDER BY created_on DESC
      LIMIT ${limit} OFFSET ${offset}`,
      [userId],
    );

    return res.status(200).json({
      status: 0,
      message: "Get History Berhasil",
      data: {
        offset,
        limit,
        records: transactions,
      },
    });
  } catch (error) {
    return res.status(500).json({
      status: 500,
      message: error.message,
      data: null,
    });
  }
};

module.exports = {
  getBalance,
  topUp,
  transaction,
  getHistory,
};
