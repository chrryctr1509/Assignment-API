const express = require("express");
const router = express.Router();
const { verifyToken } = require("../middleware/auth");
const { upload } = require("../middleware/upload");
const membershipController = require("../controllers/membershipController");

// POST /registration — public
router.post("/registration", membershipController.register);

// POST /login — public
router.post("/login", membershipController.login);

// GET /profile — JWT required
router.get("/profile", verifyToken, membershipController.getProfile);

// PUT /profile/update — JWT required
router.put("/profile/update", verifyToken, membershipController.updateProfile);

// PUT /profile/image — JWT required, multipart/form-data
router.put(
  "/profile/image",
  verifyToken,
  upload.single("profile_image"),
  membershipController.updateProfileImage,
);

module.exports = router;
