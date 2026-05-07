const express = require("express");
const { 
  getDashboardStats, 
  getAllBusinesses, 
  updateBusinessStatus 
} = require("../controllers/superadminController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.get("/stats", protect, getDashboardStats);
router.get("/businesses", protect, getAllBusinesses);
router.put("/businesses/:id/status", protect, updateBusinessStatus);

module.exports = router;
