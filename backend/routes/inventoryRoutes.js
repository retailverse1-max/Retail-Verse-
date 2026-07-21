const express = require("express");
const { protect } = require("../middleware/authMiddleware");
const {
  getInventory,
  getLowStockProducts,
  adjustStock,
} = require("../controllers/inventoryController");

const router = express.Router();

router.get("/", protect, getInventory);
router.get("/low-stock", protect, getLowStockProducts);
router.post("/adjust", protect, adjustStock);

module.exports = router;