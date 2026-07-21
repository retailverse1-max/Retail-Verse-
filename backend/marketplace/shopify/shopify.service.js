const axios = require('axios');
const MarketplaceConnection = require('../../models/MarketplaceConnection');
const MarketplaceProductMapping = require('../../models/MarketplaceProductMapping');
const MarketplaceOrderMapping = require('../../models/MarketplaceOrderMapping');
const Product = require('../../models/Product');
const Order = require('../../models/Order');
const User = require('../../models/User');
const { createAndSendNotification } = require('../../services/notificationService');

const SHOPIFY_API_VERSION = '2024-01';

class ShopifyService {

  // ─────────────────────────────────────────────
  // Helper: Build Shopify API base URL + headers
  // ─────────────────────────────────────────────
  _getClient(storeUrl, accessToken) {
    const base = storeUrl.startsWith('https://') ? storeUrl : `https://${storeUrl}`;
    return axios.create({
      baseURL: `${base}/admin/api/${SHOPIFY_API_VERSION}`,
      headers: {
        'X-Shopify-Access-Token': accessToken,
        'Content-Type': 'application/json',
      },
    });
  }

  // ─────────────────────────────────────────────
  // 1. Check Connection Status
  // ─────────────────────────────────────────────
  async checkStatus(clientId) {
    const conn = await MarketplaceConnection.findOne({ clientId, platform: 'shopify' });
    return !!(conn && conn.status === 'active');
  }

  // ─────────────────────────────────────────────
  // 2. Connect Shopify Account (Save to DB + Verify)
  // ─────────────────────────────────────────────
  async connectAccount(clientId, storeUrl, accessToken) {
    // Verify credentials by calling Shopify shop endpoint
    const client = this._getClient(storeUrl, accessToken);
    const shopRes = await client.get('/shop.json');
    const shopName = shopRes.data?.shop?.name || storeUrl;

    // Upsert connection in DB
    await MarketplaceConnection.findOneAndUpdate(
      { clientId, platform: 'shopify' },
      {
        clientId,
        platform: 'shopify',
        status: 'active',
        credentials: {
          appId: storeUrl,       // storeUrl saved here
          accessToken: accessToken,
        },
        settings: { autoSyncInventory: true, autoImportOrders: true },
      },
      { upsert: true, new: true }
    );

    return { shopName };
  }

  // ─────────────────────────────────────────────
  // 3. Disconnect
  // ─────────────────────────────────────────────
  async disconnectAccount(clientId) {
    await MarketplaceConnection.findOneAndUpdate(
      { clientId, platform: 'shopify' },
      { status: 'inactive' }
    );
    return true;
  }

  // ─────────────────────────────────────────────
  // Helper: Get saved Shopify credentials from DB
  // ─────────────────────────────────────────────
  async _getCreds(clientId) {
    const conn = await MarketplaceConnection.findOne({ clientId, platform: 'shopify', status: 'active' });
    if (!conn) throw new Error('Shopify account not connected. Please connect first from Settings.');
    return {
      storeUrl: conn.credentials.appId,
      accessToken: conn.credentials.accessToken,
    };
  }

  // ─────────────────────────────────────────────
  // 4. Push Single Product to Shopify
  // ─────────────────────────────────────────────
  async pushProduct(clientId, productId) {
    const { storeUrl, accessToken } = await this._getCreds(clientId);
    const client = this._getClient(storeUrl, accessToken);

    // Fetch product from DB
    const product = await Product.findById(productId);
    if (!product) throw new Error('Product not found in Retail Verse');

    // Check if already pushed
    const existing = await MarketplaceProductMapping.findOne({
      clientId, productId, platform: 'shopify',
    });

    // Build Shopify product payload
    const payload = {
      product: {
        title: product.name,
        body_html: product.description || '',
        vendor: 'Retail Verse',
        product_type: product.category || '',
        variants: [{
          price: product.price.toString(),
          sku: product.sku,
          inventory_management: 'shopify',
          inventory_quantity: product.stock,
          barcode: product.barcode || '',
        }],
        images: product.imageUrl ? [{ src: product.imageUrl }] : [],
      },
    };

    let shopifyProductId;
    let shopifyVariantId;

    if (existing?.platformProductId) {
      // UPDATE existing Shopify product
      const res = await client.put(`/products/${existing.platformProductId}.json`, payload);
      shopifyProductId = res.data.product.id.toString();
      shopifyVariantId = res.data.product.variants[0].id.toString();

      await MarketplaceProductMapping.findByIdAndUpdate(existing._id, {
        syncStatus: 'synced',
        lastSyncedAt: new Date(),
        platformSku: product.sku,
      });
    } else {
      // CREATE new Shopify product
      const res = await client.post('/products.json', payload);
      shopifyProductId = res.data.product.id.toString();
      shopifyVariantId = res.data.product.variants[0].id.toString();

      await MarketplaceProductMapping.create({
        clientId,
        productId,
        platform: 'shopify',
        platformProductId: shopifyProductId,
        platformSku: product.sku,
        marketplacePrice: product.price,
        syncStatus: 'synced',
        lastSyncedAt: new Date(),
        errorLog: '',
      });
    }

    return {
      success: true,
      message: `Product "${product.name}" pushed to Shopify successfully`,
      shopifyProductId,
      shopifyVariantId,
    };
  }

  // ─────────────────────────────────────────────
  // 5. Bulk Push Products to Shopify
  // ─────────────────────────────────────────────
  async bulkPushProducts(clientId, productIds) {
    const results = [];
    const errors = [];

    for (const productId of productIds) {
      try {
        const result = await this.pushProduct(clientId, productId);
        results.push(result);
      } catch (err) {
        errors.push({ productId, error: err.message });
        // Update mapping as failed
        await MarketplaceProductMapping.findOneAndUpdate(
          { clientId, productId, platform: 'shopify' },
          { syncStatus: 'failed', errorLog: err.message }
        );
      }
    }

    return {
      success: true,
      pushed: results.length,
      failed: errors.length,
      errors,
      message: `Bulk push complete: ${results.length} pushed, ${errors.length} failed`,
    };
  }

  // ─────────────────────────────────────────────
  // 6. Sync Inventory to Shopify (update stock)
  // ─────────────────────────────────────────────
  async syncInventory(clientId, productId, newStock) {
    try {
      const { storeUrl, accessToken } = await this._getCreds(clientId);
      const client = this._getClient(storeUrl, accessToken);

      const mapping = await MarketplaceProductMapping.findOne({
        clientId, productId, platform: 'shopify',
      });

      if (!mapping) return; // Not pushed to Shopify yet, skip

      // Get inventory item ID from Shopify
      const variantsRes = await client.get(`/products/${mapping.platformProductId}/variants.json`);
      const variant = variantsRes.data.variants[0];
      if (!variant) return;

      // Get inventory levels to find location_id
      const levelsRes = await client.get(`/inventory_levels.json?inventory_item_ids=${variant.inventory_item_id}`);
      const level = levelsRes.data.inventory_levels[0];
      if (!level) return;

      // Set inventory level
      await client.post('/inventory_levels/set.json', {
        location_id: level.location_id,
        inventory_item_id: variant.inventory_item_id,
        available: newStock,
      });

      await MarketplaceProductMapping.findByIdAndUpdate(mapping._id, {
        syncStatus: 'synced',
        lastSyncedAt: new Date(),
      });
    } catch (err) {
      console.error(`Shopify inventory sync error for product ${productId}:`, err.message);
      // Non-critical: log but don't throw
    }
  }

  // ─────────────────────────────────────────────
  // 7. Handle Incoming Order Webhook from Shopify
  //    (called when customer buys from Shopify store)
  // ─────────────────────────────────────────────
  async handleOrderWebhook(shopifyOrder, storeUrl) {
    try {
      // Find which client owns this store
      const conn = await MarketplaceConnection.findOne({
        platform: 'shopify',
        'credentials.appId': storeUrl,
        status: 'active',
      });

      if (!conn) {
        console.warn('Shopify webhook: No matching client found for store:', storeUrl);
        return;
      }

      const clientId = conn.clientId;

      // Avoid duplicate processing
      const alreadyProcessed = await MarketplaceOrderMapping.findOne({
        platform: 'shopify',
        platformOrderId: shopifyOrder.id.toString(),
      });
      if (alreadyProcessed) {
        console.log(`Shopify order ${shopifyOrder.id} already processed. Skipping.`);
        return;
      }

      // Build order items from Shopify line items
      const orderItems = [];
      const stockUpdates = []; // Track which products need stock reduction

      for (const lineItem of shopifyOrder.line_items) {
        // Find our product by SKU
        const product = await Product.findOne({ clientId, sku: lineItem.sku });

        if (product) {
          orderItems.push({
            productId: product._id,
            name: lineItem.title,
            qty: lineItem.quantity,
            price: parseFloat(lineItem.price),
            total: parseFloat(lineItem.price) * lineItem.quantity,
          });
          stockUpdates.push({ product, qty: lineItem.quantity });
        } else {
          console.warn(`Shopify webhook: No matching product found for SKU: ${lineItem.sku}`);
        }
      }

      // Guard: if no items matched, still record order but with empty items list
      if (orderItems.length === 0) {
        console.warn(`Shopify order #${shopifyOrder.order_number}: No SKUs matched. Order will be recorded without items.`);
      }

      // Find the admin User for this client (needed for createdBy field)
      const adminUser = await User.findOne({ clientId, role: 'admin' });
      if (!adminUser) {
        console.error(`Shopify webhook: No admin user found for clientId ${clientId}. Skipping order save.`);
        return;
      }

      // Create Order in our DB
      const orderId = `SHP-${shopifyOrder.order_number}`;
      const newOrder = await Order.create({
        orderId,
        channel: 'shopify',
        type: 'sale',
        items: orderItems,
        total: parseFloat(shopifyOrder.total_price),
        paymentMethod: 'card', // Shopify handles actual payment (card/UPI/etc.)
        paymentStatus: shopifyOrder.financial_status === 'paid' ? 'paid' : 'pending',
        status: 'completed',
        createdBy: adminUser._id, // ✅ Real User ID (admin of that store)
        clientId,
        customerName: `${shopifyOrder.customer?.first_name || ''} ${shopifyOrder.customer?.last_name || ''}`.trim(),
        customerPhone: shopifyOrder.customer?.phone || '',
        customerEmail: shopifyOrder.customer?.email || '',
        customerAddress: shopifyOrder.shipping_address?.address1 || '',
        notes: `Shopify Order #${shopifyOrder.order_number}`,
      });

      // Save order mapping
      await MarketplaceOrderMapping.create({
        clientId,
        orderId: newOrder._id,
        platform: 'shopify',
        platformOrderId: shopifyOrder.id.toString(),
        platformStatus: shopifyOrder.fulfillment_status || 'unfulfilled',
      });

      // ── Reduce Stock for each product ──
      for (const { product, qty } of stockUpdates) {
        const newStock = Math.max(0, product.stock - qty);
        await Product.findByIdAndUpdate(product._id, { stock: newStock });

        // Also sync updated stock back to Shopify
        await this.syncInventory(clientId, product._id, newStock);

        // Send low stock notification if needed
        if (newStock <= product.reorderLevel) {
          await createAndSendNotification({
            title: '⚠️ Low Stock Alert',
            message: `"${product.name}" ka stock ${newStock} reh gaya hai (Shopify order se). Reorder karein!`,
            type: 'low_stock',
            targetRoles: ['admin', 'inventory'],
            clientId,
            data: { productId: product._id.toString(), stock: newStock },
          });
        }
      }

      // ── Send New Order Notification ──
      const customerName = `${shopifyOrder.customer?.first_name || 'Customer'}`;
      await createAndSendNotification({
        title: '🛒 New Shopify Order!',
        message: `${customerName} ne Shopify se order kiya — ₹${shopifyOrder.total_price}. Order ID: #${shopifyOrder.order_number}`,
        type: 'new_order',
        targetRoles: ['admin'],
        clientId,
        data: {
          shopifyOrderId: shopifyOrder.id.toString(),
          orderId: newOrder._id.toString(),
          amount: shopifyOrder.total_price,
        },
      });

      console.log(`✅ Shopify order #${shopifyOrder.order_number} processed for client ${clientId}`);
      return newOrder;

    } catch (err) {
      console.error('Shopify webhook processing error:', err);
      throw err;
    }
  }

  // ─────────────────────────────────────────────
  // 8. Category Mapping (using DB)
  // ─────────────────────────────────────────────
  async saveCategoryMapping(clientId, localCategoryId, shopifyCollectionId, shopifyCollectionName) {
    const MarketplaceCategoryMapping = require('../../models/MarketplaceCategoryMapping');
    await MarketplaceCategoryMapping.findOneAndUpdate(
      { clientId, retailVerseCategoryId: localCategoryId, platform: 'shopify' },
      {
        clientId,
        retailVerseCategoryId: localCategoryId,
        platform: 'shopify',
        platformCategoryId: shopifyCollectionId,
        platformCategoryName: shopifyCollectionName,
      },
      { upsert: true, new: true }
    );
    return true;
  }

  async getCategoryMappings(clientId) {
    const MarketplaceCategoryMapping = require('../../models/MarketplaceCategoryMapping');
    return MarketplaceCategoryMapping.find({ clientId, platform: 'shopify' })
      .populate('retailVerseCategoryId', 'name');
  }
}

module.exports = new ShopifyService();
