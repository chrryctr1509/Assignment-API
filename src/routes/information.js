const express = require("express");
const router = express.Router();
const { verifyToken } = require("../middleware/auth");
const informationController = require("../controllers/informationController");

// GET /banner — JWT required
router.get("/banner", verifyToken, informationController.getBanner);

// GET /services — JWT required
router.get("/services", verifyToken, informationController.getServices);

module.exports = router;
