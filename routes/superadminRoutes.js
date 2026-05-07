const express = require("express");
const { 
  getDashboardStats, 
  getAnalyticsSummary,
  getAllBusinesses, 
  updateBusinessStatus,
  getAllUsers,
  getAllPlans,
  getAllDomains,
  getAuditLogs
} = require("../controllers/superadminController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.get("/health", (req, res) => res.json({ status: "Super Admin API is healthy" }));

router.get("/stats", protect, getDashboardStats);
router.get("/analytics/summary", protect, getAnalyticsSummary);
router.get("/businesses", protect, getAllBusinesses);
router.put("/businesses/:id/status", protect, updateBusinessStatus);
router.get("/users", protect, getAllUsers);
router.get("/subscription-plans", protect, getAllPlans);
router.get("/custom-domains", protect, getAllDomains);
router.get("/audit-logs", protect, getAuditLogs);

module.exports = router;
