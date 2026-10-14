const express = require("express");
const { protect } = require("../middleware/authMiddleware");
const {
  getInventory,
  getLowStockProducts,
  adjustStock,
  quickInward,
} = require("../controllers/inventoryController");

const router = express.Router();

router.get("/", protect, getInventory);
router.get("/low-stock", protect, getLowStockProducts);
router.post("/adjust", protect, adjustStock);
router.post("/inward", protect, quickInward);

module.exports = router;