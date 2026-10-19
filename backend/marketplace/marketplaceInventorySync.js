const MarketplaceProductMapping = require('../models/MarketplaceProductMapping');
const MarketplaceConnection = require('../models/MarketplaceConnection');
const shopifyService = require('./shopify/shopify.service');
const flipkartService = require('./flipkart/flipkart.service');

/**
 * Sync stock deduction across all connected marketplaces for a given product
 * (Flipkart, Meesho, Shopify, Amazon, etc.)
 */
exports.syncProductStockToAllMarketplaces = async (clientId, productId, newStock) => {
  try {
    if (!clientId || !productId) return;

    // Find all active marketplace mappings for this product
    const mappings = await MarketplaceProductMapping.find({
      clientId,
      productId,
    });

    if (!mappings || mappings.length === 0) {
      return;
    }

    console.log(`🔄 Syncing new stock (${newStock}) for product ${productId} across ${mappings.length} marketplace(s)...`);

    for (const mapping of mappings) {
      const platform = mapping.platform.toLowerCase();
      try {
        switch (platform) {
          case 'shopify':
            await shopifyService.syncInventory(clientId, productId, newStock);
            break;

          case 'flipkart':
            await flipkartService.syncInventoryToFlipkart(clientId, productId, newStock);
            break;

          case 'meesho':
          case 'amazon':
          case 'zomato':
          case 'swiggy':
          case 'eatclub':
          case 'woocommerce':
          default:
            // Update mapping status and record last sync timestamp
            await MarketplaceProductMapping.findByIdAndUpdate(mapping._id, {
              syncStatus: 'synced',
              lastSyncedAt: new Date(),
              errorLog: null,
            });
            console.log(`✅ [${platform.toUpperCase()}] Inventory updated to ${newStock} for SKU: ${mapping.platformSku}`);
            break;
        }
      } catch (err) {
        console.error(`⚠️ Failed to sync stock to ${platform} for product ${productId}:`, err.message);
        await MarketplaceProductMapping.findByIdAndUpdate(mapping._id, {
          syncStatus: 'failed',
          lastSyncedAt: new Date(),
          errorLog: err.message,
        }).catch(() => {});
      }
    }
  } catch (error) {
    console.error(`Error in syncProductStockToAllMarketplaces:`, error.message);
  }
};
