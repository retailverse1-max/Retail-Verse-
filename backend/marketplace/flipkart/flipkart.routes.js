const express = require('express');
const router = express.Router();
const { protect: authMiddleware } = require('../../middleware/authMiddleware');
const flipkartController = require('./flipkart.controller');

// ==========================================
// 1. Connection & Settings (App calls these)
// ==========================================

// Check if merchant is connected to Flipkart
router.get('/status', authMiddleware, flipkartController.checkStatus);

// Save Flipkart App ID & Secret from the App UI
router.post('/connect', authMiddleware, flipkartController.connectAccount);

// Remove connection
router.post('/disconnect', authMiddleware, flipkartController.disconnectAccount);


// ==========================================
// 2. Product Push (App calls these)
// ==========================================

// Push a single Retail Verse product to Flipkart
router.post('/products/push', authMiddleware, flipkartController.pushProduct);

// Bulk push all mapped products (Optional for Settings page)
router.post('/products/bulk-push', authMiddleware, flipkartController.bulkPushProducts);

// Phase 13: Category Mapping APIs
router.post('/category-mappings', authMiddleware, flipkartController.saveCategoryMapping);
router.get('/category-mappings', authMiddleware, flipkartController.getCategoryMappings);


// ==========================================
// 3. Webhooks (Flipkart Server calls these)
// ==========================================

// Flipkart will hit this URL when a new order arrives
// Note: No authMiddleware here because Flipkart's server is hitting it, not our App.
// We will verify Flipkart's signature inside the controller.
router.post('/webhook/orders', flipkartController.handleOrderWebhook);

module.exports = router;
