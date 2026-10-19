const express = require("express");
const router = express.Router();
const {
  validateCoupon,
  getActiveCoupons,
  getAllCoupons,
  createCoupon,
  updateCoupon,
  deleteCoupon,
} = require("../controllers/couponController");
const { protect } = require("../middleware/authMiddleware");

// Public/POS user routes
router.post("/validate", protect, validateCoupon);
router.get("/active", protect, getActiveCoupons);

// Admin / Management routes
router.get("/", protect, getAllCoupons);
router.post("/", protect, createCoupon);
router.put("/:id", protect, updateCoupon);
router.delete("/:id", protect, deleteCoupon);

module.exports = router;
