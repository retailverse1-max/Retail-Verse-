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
  getAuditLogs,
  getTopPerformanceStores,
  updateBusiness,
  deleteBusiness,
  fixBusinessesData,
  getBusinessDetails
} = require("../controllers/superadminController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

// ... existing routes ...
router.get("/fix-data", protect, fixBusinessesData);

router.get("/health", (req, res) => res.json({ status: "Super Admin API is healthy" }));

// Stats & Analytics
router.get("/stats", protect, getDashboardStats);
router.get("/analytics/summary", protect, getAnalyticsSummary);
router.get("/performance/top-stores", protect, getTopPerformanceStores);

// Businesses
router.get("/businesses", protect, getAllBusinesses);
router.get("/businesses/:id", protect, getBusinessDetails);
router.post("/businesses", protect, createBusiness);
router.put("/businesses/:id", protect, updateBusiness);
router.delete("/businesses/:id", protect, deleteBusiness);
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
