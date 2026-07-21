const express = require("express");
const { getDashboardStats, getRecentActivities, getCustomers, addCustomer } = require("../controllers/dashboardController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.get("/stats", protect, getDashboardStats);
router.get("/recent-activities", protect, getRecentActivities);
router.get("/customers", protect, getCustomers);
router.post("/customers", protect, addCustomer);

module.exports = router;
