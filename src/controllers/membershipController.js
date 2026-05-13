const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const pool = require("../config/database");

const register = async (req, res) => {
  try {
    const { email, first_name, last_name, password } = req.body;

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!email || !emailRegex.test(email)) {
      return res.status(400).json({
        status: 102,
        message: "Format email tidak valid",
        data: null,
      });
    }

    // Validate password min 8 chars
    if (!password || password.length < 8) {
      return res.status(400).json({
        status: 102,
        message: "Password minimal 8 karakter",
        data: null,
      });
    }

    // Check if email already exists
    const [existing] = await pool.execute(
      "SELECT id FROM users WHERE email = ?",
      [email],
    );

    if (existing.length > 0) {
      return res.status(400).json({
        status: 102,
        message: "Email sudah terdaftar",
        data: null,
      });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Insert new user
    await pool.execute(
      "INSERT INTO users (email, first_name, last_name, password) VALUES (?, ?, ?, ?)",
      [email, first_name, last_name, hashedPassword],
    );

    return res.status(201).json({
      status: 0,
      message: "Registrasi berhasil silakan login",
      data: null,
    });
  } catch (error) {
    return res.status(500).json({
      status: 500,
      message: error.message,
      data: null,
    });
  }
};

const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate not empty
    if (!email || !password) {
      return res.status(400).json({
        status: 102,
        message: "Email dan password harus diisi",
        data: null,
      });
    }

    // Find user by email
    const [users] = await pool.execute(
      "SELECT id, email, password FROM users WHERE email = ?",
      [email],
    );

    if (users.length === 0) {
      return res.status(401).json({
        status: 103,
        message: "Username atau password salah",
        data: null,
      });
    }

    const user = users[0];

    // Compare password
    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      return res.status(401).json({
        status: 103,
        message: "Username atau password salah",
        data: null,
      });
    }

    // Generate JWT token
    const token = jwt.sign(
      { id: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || "12h" },
    );

    return res.status(200).json({
      status: 0,
      message: "Login Sukses",
      data: { token },
    });
  } catch (error) {
    return res.status(500).json({
      status: 500,
      message: error.message,
      data: null,
    });
  }
};

const getProfile = async (req, res) => {
  try {
    const userId = req.user.id;

    const [users] = await pool.execute(
      "SELECT email, first_name, last_name, profile_image FROM users WHERE id = ?",
      [userId],
    );

    if (users.length === 0) {
      return res.status(404).json({
        status: 102,
        message: "User tidak ditemukan",
        data: null,
      });
    }

    const user = users[0];

    return res.status(200).json({
      status: 0,
      message: "Sukses",
      data: {
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        profile_image: user.profile_image,
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

const updateProfile = async (req, res) => {
  try {
    const userId = req.user.id;
    const { first_name, last_name } = req.body;

    // Validate
    if (!first_name || !last_name) {
      return res.status(400).json({
        status: 102,
        message: "First name dan last name harus diisi",
        data: null,
      });
    }

    // Update profile
    await pool.execute(
      "UPDATE users SET first_name = ?, last_name = ? WHERE id = ?",
      [first_name, last_name, userId],
    );

    // Get updated data
    const [users] = await pool.execute(
      "SELECT email, first_name, last_name, profile_image FROM users WHERE id = ?",
      [userId],
    );

    const user = users[0];

    return res.status(200).json({
      status: 0,
      message: "Update Profile berhasil",
      data: {
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        profile_image: user.profile_image,
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

const updateProfileImage = async (req, res) => {
  try {
    const userId = req.user.id;

    if (!req.file) {
      return res.status(400).json({
        status: 102,
        message: "File profile_image diperlukan",
        data: null,
      });
    }

    const profileImagePath = req.file.filename;

    // Update profile image
    await pool.execute("UPDATE users SET profile_image = ? WHERE id = ?", [
      profileImagePath,
      userId,
    ]);

    // Get updated data
    const [users] = await pool.execute(
      "SELECT email, first_name, last_name, profile_image FROM users WHERE id = ?",
      [userId],
    );

    const user = users[0];

    return res.status(200).json({
      status: 0,
      message: "Update Profile Image berhasil",
      data: {
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        profile_image: user.profile_image,
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
  register,
  login,
  getProfile,
  updateProfile,
  updateProfileImage,
};
