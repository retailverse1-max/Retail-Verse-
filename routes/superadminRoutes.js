const express = require("express");
const { protect, superAdminOnly } = require("../middleware/authMiddleware");
const {
  getBusinesses,
  createBusiness,
  getCustomDomains,
  addCustomDomain,
  verifyCustomDomain,
  activateCustomDomain,
  deleteCustomDomain,
  listUsers,
  createUser,
  updateUserStatus,
  updateUserRole,
  deleteUser,
} = require("../controllers/superadminController");

const router = express.Router();

router.use(protect);
router.use(superAdminOnly);

router.get("/businesses", getBusinesses);
router.post("/businesses", createBusiness);

router.get("/custom-domains", getCustomDomains);
router.post("/custom-domains", addCustomDomain);
router.post("/custom-domains/:id/verify", verifyCustomDomain);
router.patch("/custom-domains/:id/active", activateCustomDomain);
router.delete("/custom-domains/:id", deleteCustomDomain);

router.get("/users", listUsers);
router.post("/users", createUser);
router.patch("/users/:id/status", updateUserStatus);
router.patch("/users/:id/role", updateUserRole);
router.delete("/users/:id", deleteUser);

module.exports = router;
