const express = require("express");
const { protect } = require("../middleware/authMiddleware");
const {
  getVendors,
  createVendor,
  deleteVendor,
  getAllocation,
  saveAllocation,
  manualNotifyVendors,
  getAllocationHistory,
  getVendorPortalData,
  updateVendorAllocationStatus,
} = require("../controllers/vendorController");

const router = express.Router();

router.get("/", protect, getVendors);
router.post("/", protect, createVendor);
router.delete("/:id", protect, deleteVendor);

router.get("/allocation", protect, getAllocation);
router.post("/allocation", protect, saveAllocation);
router.post("/allocation/notify", protect, manualNotifyVendors);
router.get("/allocation/history", protect, getAllocationHistory);

// Vendor Portal Routes
router.get("/portal/data", protect, getVendorPortalData);
router.patch("/portal/allocation-status", protect, updateVendorAllocationStatus);

module.exports = router;

