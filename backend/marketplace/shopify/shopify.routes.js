const express = require('express');
const router = express.Router();
const authMiddleware = require('../../../middleware/authMiddleware');
const shopifyController = require('./shopify.controller');

// ==========================================
// 1. Connection & Settings (Flutter App calls these)
// ==========================================

// Check if merchant is connected to Shopify
router.get('/status', authMiddleware, shopifyController.checkStatus);

// Save Shopify Store URL & Access Token from the App UI
router.post('/connect', authMiddleware, shopifyController.connectAccount);

// Remove connection
router.post('/disconnect', authMiddleware, shopifyController.disconnectAccount);


// ==========================================
// 2. Product Push (Flutter App calls these)
// ==========================================

// Push a single Retail Verse product to Shopify
router.post('/products/push', authMiddleware, shopifyController.pushProduct);

// Bulk push selected products to Shopify
router.post('/products/bulk-push', authMiddleware, shopifyController.bulkPushProducts);

// Category Mapping APIs (For Shopify Collections)
router.post('/category-mappings', authMiddleware, shopifyController.saveCategoryMapping);
router.get('/category-mappings', authMiddleware, shopifyController.getCategoryMappings);


// ==========================================
// 3. Webhooks (Shopify Server calls these automatically)
//
// Register this URL in Shopify Partner Dashboard:
// https://YOUR_BACKEND.onrender.com/api/marketplace/shopify/webhook/orders
//
// Events to subscribe: orders/create, orders/paid
// ==========================================

// Shopify calls this when a customer places an order
// rawBody is already preserved by global express.json verify in app.js
router.post('/webhook/orders', shopifyController.handleOrderWebhook);

module.exports = router;
