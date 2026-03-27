const express = require("express");
const { getProducts } = require("../controllers/productController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.get("/", protect, getProducts);

module.exports = router;