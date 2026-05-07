const express = require("express");
const { createRazorpayOrder, verifyRazorpayPayment } = require("../controllers/paymentController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.get("/test", (req, res) => {
  res.json({
    success: true,
    message: process.env.RAZORPAY_KEY_ID 
      ? "✅ Razorpay is ACTIVE and Keys are loaded!" 
      : "❌ Razorpay Key ID is MISSING in Render Environment Variables",
    keyIdPreview: process.env.RAZORPAY_KEY_ID ? `${process.env.RAZORPAY_KEY_ID.substring(0, 8)}...` : null
  });
});

router.post("/razorpay/create-order", protect, createRazorpayOrder);
router.post("/razorpay/verify", protect, verifyRazorpayPayment);

module.exports = router;
