const pool = require("../config/database");

const getBanner = async (req, res) => {
  try {
    const [rows] = await pool.execute(
      "SELECT banner_name, banner_image, description FROM banners",
    );
    res.json({ status: 0, message: "Sukses", data: rows });
  } catch (err) {
    res.status(500).json({ status: 500, message: err.message, data: null });
  }
};

const getServices = async (req, res) => {
  try {
    const [rows] = await pool.execute(
      "SELECT service_code, service_name, service_icon, service_tariff FROM services",
    );
    res.json({ status: 0, message: "Sukses", data: rows });
  } catch (err) {
    res.status(500).json({ status: 500, message: err.message, data: null });
  }
};

module.exports = { getBanner, getServices };
