const express = require("express");
const cors = require("cors");
require("dotenv").config();

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Static files
app.use("/uploads", express.static(process.env.UPLOAD_DIR || "uploads"));

// Import routes
const membershipRoutes = require("./routes/membership");
const informationRoutes = require("./routes/information");
const transactionRoutes = require("./routes/transaction");

// Routes
app.use("/", membershipRoutes);
app.use("/", informationRoutes);
app.use("/", transactionRoutes);

// Root
app.get("/", (req, res) => {
  res.json({ status: 0, message: "SIMS PPOB API Running", data: null });
});

// Health check endpoint for Railway
app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// Error handler
app.use((err, req, res, next) => {
  if (err.message === "Format Image tidak sesuai") {
    return res
      .status(400)
      .json({ status: 102, message: err.message, data: null });
  }
  res.status(500).json({ status: 500, message: err.message, data: null });
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
