const express = require("express");
const { 
  getDashboardStats, 
  getAnalyticsSummary,
  getAllBusinesses, 
  createBusiness,
  updateBusinessStatus,
  getAllUsers,
  createUser,
  updateUserStatus,
  updateUserRole,
  deleteUser,
  getAllPlans,
  getAllDomains,
  addCustomDomain,
  verifyCustomDomain,
  activateCustomDomain,
  deleteCustomDomain,
  getAuditLogs
} = require("../controllers/superadminController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.get("/health", (req, res) => res.json({ status: "Super Admin API is healthy" }));

// Stats & Analytics
router.get("/stats", protect, getDashboardStats);
router.get("/analytics/summary", protect, getAnalyticsSummary);

// Businesses
router.get("/businesses", protect, getAllBusinesses);
router.post("/businesses", protect, createBusiness);
router.put("/businesses/:id/status", protect, updateBusinessStatus);

// Users (Platform Level)
router.get("/users", protect, getAllUsers);
router.post("/users", protect, createUser);
router.patch("/users/:id/status", protect, updateUserStatus);
router.patch("/users/:id/role", protect, updateUserRole);
router.delete("/users/:id", protect, deleteUser);

// Subscriptions & Plans
router.get("/subscription-plans", protect, getAllPlans);

// Custom Domains
router.get("/custom-domains", protect, getAllDomains);
router.post("/custom-domains", protect, addCustomDomain);
router.post("/custom-domains/:id/verify", protect, verifyCustomDomain);
router.patch("/custom-domains/:id/active", protect, activateCustomDomain);
router.delete("/custom-domains/:id", protect, deleteCustomDomain);

// Audit Logs
router.get("/audit-logs", protect, getAuditLogs);

module.exports = router;
