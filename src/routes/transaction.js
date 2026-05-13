const express = require("express");
const router = express.Router();
const { verifyToken } = require("../middleware/auth");
const transactionController = require("../controllers/transactionController");

// GET /balance — JWT required
router.get("/balance", verifyToken, transactionController.getBalance);

// POST /topup — JWT required
router.post("/topup", verifyToken, transactionController.topUp);

// POST /transaction — JWT required
router.post("/transaction", verifyToken, transactionController.transaction);

// GET /transaction/history — JWT required
router.get(
  "/transaction/history",
  verifyToken,
  transactionController.getHistory,
);

module.exports = router;
