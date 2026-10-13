const MarketplaceConnection = require('../../models/MarketplaceConnection');
const MarketplaceProductMapping = require('../../models/MarketplaceProductMapping');
const Product = require('../../models/Product');
const flipkartMapper = require('./flipkart.mapper');
const flipkartHelper = require('./flipkart.helper');

exports.getConnectionStatus = async (businessId) => {
    const connection = await MarketplaceConnection.findOne({ clientId: businessId, platform: 'flipkart' });
    if (!connection) {
        return { connected: false };
    }
    return {
        connected: true,
        status: connection.status,
        lastUpdated: connection.updatedAt
    };
};

exports.saveConnection = async (businessId, appId, appSecret) => {
    // 1. Obtain an access token from Flipkart using the App ID and Secret
    const tokenData = await flipkartHelper.generateAccessToken(appId, appSecret);
    
    // 2. Save or update the connection in the DB
    const connection = await MarketplaceConnection.findOneAndUpdate(
        { clientId: businessId, platform: 'flipkart' },
        {
            clientId: businessId,
            platform: 'flipkart',
            status: 'active',
            credentials: {
                appId,
                appSecret,
                accessToken: tokenData.access_token,
                // In production, handle token expiration and refresh logic
            }
        },
        { upsert: true, new: true }
    );
    return connection;
};

exports.removeConnection = async (businessId) => {
    return await MarketplaceConnection.findOneAndDelete({ clientId: businessId, platform: 'flipkart' });
};

exports.handleOAuthCallback = async (authCode, businessId) => {
    if (!businessId) {
        return { success: true, message: "Authorization code received" };
    }
    const mockToken = `flipkart_oauth_${Date.now()}`;
    return await MarketplaceConnection.findOneAndUpdate(
        { clientId: businessId, platform: 'flipkart' },
        {
            clientId: businessId,
            platform: 'flipkart',
            status: 'active',
            credentials: {
                accessToken: mockToken,
                refreshToken: `refresh_${Date.now()}`
            }
        },
        { upsert: true, new: true }
    );
};

exports.pushSingleProduct = async (businessId, productId) => {
    // 1. Get the connection token
    const connection = await MarketplaceConnection.findOne({ clientId: businessId, platform: 'flipkart' });
    if (!connection || connection.status !== 'active') {
        throw new Error("Flipkart account is not connected or active.");
    }

    // 2. Fetch the Retail Verse Product
    const product = await Product.findOne({ _id: productId, businessId: businessId });
    if (!product) {
        throw new Error("Product not found in inventory.");
    }

    // 3. Map the product to Flipkart's format
    const flipkartPayload = flipkartMapper.mapProductToFlipkart(product);

    try {
        // 4. Send to Flipkart (Mock API Call)
        // const response = await axios.post('FLIPKART_LISTING_API', flipkartPayload, { headers: { Authorization: `Bearer ${connection.credentials.accessToken}` }});
        
        // Let's pretend it returned an FSN (Flipkart Serial Number)
        const mockFsn = `FSN_${Date.now()}`;
        const mockSku = product.sku || `SKU_${Date.now()}`;

        // 5. Save the mapping on SUCCESS
        const mapping = await MarketplaceProductMapping.findOneAndUpdate(
            { clientId: businessId, productId: productId, platform: 'flipkart' },
            {
                clientId: businessId,
                productId: productId,
                platform: 'flipkart',
                platformProductId: mockFsn,
                platformSku: mockSku,
                syncStatus: 'synced',
                errorLog: null, // Clear any previous errors
                lastSyncedAt: new Date()
            },
            { upsert: true, new: true }
        );

        return { mapping, flipkartPayload };
    } catch (error) {
        // Phase 11: Error Handling & Logging
        // Extract the exact error message from Flipkart's API response if it exists
        const flipkartErrorMessage = error.response && error.response.data 
            ? JSON.stringify(error.response.data) 
            : error.message;

        // Save the error in the DB so the Admin can see why it failed
        await MarketplaceProductMapping.findOneAndUpdate(
            { clientId: businessId, productId: productId, platform: 'flipkart' },
            {
                clientId: businessId,
                productId: productId,
                platform: 'flipkart',
                syncStatus: 'failed',
                errorLog: flipkartErrorMessage,
                lastSyncedAt: new Date()
            },
            { upsert: true } // Upsert even on failure to track the attempt
        );

        // Throw a clean error back to the Controller (and Flutter App)
        throw new Error(`Flipkart Sync Failed: ${flipkartErrorMessage}`);
    }
};

exports.pushBulkProducts = async (businessId, productIds) => {
    const results = [];
    for (const productId of productIds) {
        try {
            const result = await this.pushSingleProduct(businessId, productId);
            results.push({ productId, success: true, result });
        } catch (error) {
            results.push({ productId, success: false, error: error.message });
        }
    }
    return results;
};

const Order = require('../../models/Order');
const MarketplaceOrderMapping = require('../../models/MarketplaceOrderMapping');

exports.processIncomingOrder = async (webhookData) => {
    // 1. Extract Flipkart SKU and Order details from webhook payload
    const flipkartSku = webhookData.skuId;
    const flipkartOrderId = webhookData.orderId;

    // 2. Find the local Retail Verse product using the Product Mapping DB
    const mapping = await MarketplaceProductMapping.findOne({ platformSku: flipkartSku, platform: 'flipkart' });
    if (!mapping) {
        throw new Error(`Product mapping not found for Flipkart SKU: ${flipkartSku}`);
    }

    const businessId = mapping.clientId;
    const retailVerseProductId = mapping.productId;

    // 3. Map Flipkart JSON to Retail Verse Order format
    const retailOrderData = flipkartMapper.mapFlipkartOrderToRetailVerse(webhookData, businessId, retailVerseProductId);
    
    // 4. Create the new Order locally
    const newOrder = await Order.create(retailOrderData);

    // 5. Save the Order Mapping (Linking local Order ID with Flipkart Order ID)
    await MarketplaceOrderMapping.create({
        clientId: businessId,
        orderId: newOrder._id,
        platform: 'flipkart',
        platformOrderId: flipkartOrderId,
        platformStatus: 'created'
    });

    // 6. Deduct local inventory
    const product = await Product.findOne({ _id: retailVerseProductId, businessId: businessId });
    if (product) {
        // Simple stock deduction. Assuming webhookData.quantity is available, else default to 1.
        product.stockQuantity = product.stockQuantity - (webhookData.quantity || 1);
        await product.save();
    }

    console.log(`Successfully processed Flipkart order: ${flipkartOrderId} into Local Order: ${newOrder._id}`);
    return newOrder;
};

// Phase 8: Real-Time Inventory Sync
exports.syncInventoryToFlipkart = async (businessId, productId, newStockQuantity) => {
    // 1. Check if the product is mapped to Flipkart
    const mapping = await MarketplaceProductMapping.findOne({ 
        clientId: businessId, 
        productId: productId, 
        platform: 'flipkart' 
    });

    if (!mapping) {
        // Not listed on Flipkart, no sync needed.
        return { skipped: true, message: "Product not mapped to Flipkart." };
    }

    // 2. Fetch connection
    const connection = await MarketplaceConnection.findOne({ clientId: businessId, platform: 'flipkart' });
    if (!connection || connection.status !== 'active') {
        throw new Error("Flipkart connection inactive. Cannot sync inventory.");
    }

    // 3. Make Axios call to Flipkart Inventory API
    // const response = await axios.post(`FLIPKART_INVENTORY_API/${mapping.platformSku}`, 
    //      { stock_count: newStockQuantity }, 
    //      { headers: { Authorization: `Bearer ${connection.credentials.accessToken}` }}
    // );

    // 4. Update the sync status in DB
    mapping.syncStatus = 'synced';
    mapping.lastSyncedAt = new Date();
    await mapping.save();

    console.log(`Successfully synced stock (${newStockQuantity}) for SKU: ${mapping.platformSku} on Flipkart.`);
    return { success: true, platformSku: mapping.platformSku, newStock: newStockQuantity };
};
