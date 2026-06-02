const express = require("express");
const { createOrder, getOrders, updateOrder, recordPayment } = require("../controllers/orderController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/create", protect, createOrder);
router.post("/payment", protect, recordPayment);
router.get("/", protect, getOrders);
router.put("/:id", protect, updateOrder);

module.exports = router;