const express = require("express");
const router = express.Router();
const { protect: authMiddleware } = require("../middleware/authMiddleware");
const marketplaceController = require("./marketplace.controller");

// Get all statuses
router.get("/statuses", authMiddleware, marketplaceController.getAllStatuses);

// Quick 1-click connect (no credential hassle)
router.post("/quick-connect", authMiddleware, marketplaceController.quickConnect);

// Disconnect
router.post("/disconnect", authMiddleware, marketplaceController.disconnectPlatform);

// Universal sync product
router.post("/sync-product", authMiddleware, marketplaceController.syncProduct);

// Sync all products
router.post("/sync-all", authMiddleware, marketplaceController.syncAllProducts);

module.exports = router;
