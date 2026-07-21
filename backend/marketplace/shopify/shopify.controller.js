const crypto = require('crypto');
const shopifyService = require('./shopify.service');

// ─────────────────────────────────────────────
// Helper: Verify Shopify Webhook HMAC Signature
// ─────────────────────────────────────────────
const verifyShopifyWebhook = (req) => {
  const secret = process.env.SHOPIFY_WEBHOOK_SECRET;
  if (!secret) return true; // Skip verification if secret not set (dev mode)

  const hmac = req.headers['x-shopify-hmac-sha256'];
  if (!hmac) return false;

  const body = req.rawBody || JSON.stringify(req.body);
  const digest = crypto
    .createHmac('sha256', secret)
    .update(body, 'utf8')
    .digest('base64');

  return crypto.timingSafeEqual(Buffer.from(digest), Buffer.from(hmac));
};

// ─────────────────────────────────────────────
// 1. Check Shopify Connection Status
// ─────────────────────────────────────────────
exports.checkStatus = async (req, res) => {
  try {
    const isConnected = await shopifyService.checkStatus(req.user.clientId);
    res.json({ isConnected });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// ─────────────────────────────────────────────
// 2. Connect Shopify Account
// ─────────────────────────────────────────────
exports.connectAccount = async (req, res) => {
  try {
    const { storeUrl, accessToken } = req.body;
    if (!storeUrl || !accessToken) {
      return res.status(400).json({ error: 'Store URL and Access Token are required' });
    }
    const result = await shopifyService.connectAccount(req.user.clientId, storeUrl, accessToken);
    res.json({ message: `Successfully connected to Shopify store: ${result.shopName}` });
  } catch (error) {
    if (error.response?.status === 401) {
      return res.status(401).json({ error: 'Invalid Shopify Access Token. Please check and try again.' });
    }
    res.status(500).json({ error: error.message });
  }
};

// ─────────────────────────────────────────────
// 3. Disconnect Shopify Account
// ─────────────────────────────────────────────
exports.disconnectAccount = async (req, res) => {
  try {
    await shopifyService.disconnectAccount(req.user.clientId);
    res.json({ message: 'Disconnected from Shopify' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// ─────────────────────────────────────────────
// 4. Push Single Product to Shopify
// ─────────────────────────────────────────────
exports.pushProduct = async (req, res) => {
  try {
    const { productId } = req.body;
    if (!productId) return res.status(400).json({ error: 'productId is required' });
    const result = await shopifyService.pushProduct(req.user.clientId, productId);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// ─────────────────────────────────────────────
// 5. Bulk Push Products to Shopify
// ─────────────────────────────────────────────
exports.bulkPushProducts = async (req, res) => {
  try {
    const { productIds } = req.body;
    if (!productIds || !Array.isArray(productIds) || productIds.length === 0) {
      return res.status(400).json({ error: 'productIds array is required' });
    }
    const result = await shopifyService.bulkPushProducts(req.user.clientId, productIds);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// ─────────────────────────────────────────────
// 6. Save Category Mapping
// ─────────────────────────────────────────────
exports.saveCategoryMapping = async (req, res) => {
  try {
    const { localCategoryId, shopifyCollectionId, shopifyCollectionName } = req.body;
    await shopifyService.saveCategoryMapping(
      req.user.clientId,
      localCategoryId,
      shopifyCollectionId,
      shopifyCollectionName
    );
    res.json({ message: 'Category mapping saved successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// ─────────────────────────────────────────────
// 7. Get Category Mappings
// ─────────────────────────────────────────────
exports.getCategoryMappings = async (req, res) => {
  try {
    const mappings = await shopifyService.getCategoryMappings(req.user.clientId);
    res.json(mappings);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// ─────────────────────────────────────────────
// 8. Handle Shopify Order Webhook
//    Shopify calls this when someone buys from store
// ─────────────────────────────────────────────
exports.handleOrderWebhook = async (req, res) => {
  try {
    // Verify HMAC signature for security
    if (!verifyShopifyWebhook(req)) {
      return res.status(401).send('Unauthorized: Invalid HMAC signature');
    }

    const shopifyOrder = req.body;
    const storeUrl = req.headers['x-shopify-shop-domain'];

    if (!storeUrl) {
      return res.status(400).send('Missing x-shopify-shop-domain header');
    }

    // Respond immediately to Shopify (must within 5 seconds)
    res.status(200).send('Webhook received');

    // Process in background (non-blocking)
    shopifyService.handleOrderWebhook(shopifyOrder, storeUrl).catch((err) => {
      console.error('Background Shopify order processing failed:', err.message);
    });

  } catch (error) {
    console.error('Shopify Webhook Error:', error);
    res.status(500).send('Webhook processing failed');
  }
};
