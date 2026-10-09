const MarketplaceConnection = require('../../models/MarketplaceConnection');
const MarketplaceProductMapping = require('../../models/MarketplaceProductMapping');
const Product = require('../../models/Product');
const meeshoMapper = require('./meesho.mapper');

exports.getConnectionStatus = async (businessId) => {
    const connection = await MarketplaceConnection.findOne({ clientId: businessId, platform: 'meesho' });
    if (!connection) {
        return { connected: false };
    }
    return {
        connected: true,
        status: connection.status,
        lastUpdated: connection.updatedAt
    };
};

exports.saveConnection = async (businessId, apiKey, supplierId) => {
    const connection = await MarketplaceConnection.findOneAndUpdate(
        { clientId: businessId, platform: 'meesho' },
        {
            clientId: businessId,
            platform: 'meesho',
            status: 'active',
            credentials: {
                appId: supplierId || 'MEESHO_SUPPLIER',
                accessToken: apiKey,
            }
        },
        { upsert: true, new: true }
    );
    return connection;
};

exports.removeConnection = async (businessId) => {
    return await MarketplaceConnection.findOneAndDelete({ clientId: businessId, platform: 'meesho' });
};

exports.pushSingleProduct = async (businessId, productId) => {
    // 1. Fetch Product
    const product = await Product.findOne({ _id: productId, businessId: businessId });
    if (!product) {
        throw new Error("Product not found in inventory.");
    }

    // 2. Map Product to Meesho Catalog format
    const meeshoPayload = meeshoMapper.mapProductToMeesho(product);

    try {
        // 3. Create or Update Meesho Product Mapping
        const mockMeeshoId = `MEESHO_CAT_${Date.now()}`;
        const mockSku = product.sku || `SKU_${Date.now()}`;

        const mapping = await MarketplaceProductMapping.findOneAndUpdate(
            { clientId: businessId, productId: productId, platform: 'meesho' },
            {
                clientId: businessId,
                productId: productId,
                platform: 'meesho',
                platformProductId: mockMeeshoId,
                platformSku: mockSku,
                marketplacePrice: product.salePrice || product.price,
                syncStatus: 'synced',
                errorLog: null,
                lastSyncedAt: new Date()
            },
            { upsert: true, new: true }
        );

        return { mapping, meeshoPayload };
    } catch (error) {
        await MarketplaceProductMapping.findOneAndUpdate(
            { clientId: businessId, productId: productId, platform: 'meesho' },
            {
                clientId: businessId,
                productId: productId,
                platform: 'meesho',
                syncStatus: 'failed',
                errorLog: error.message,
                lastSyncedAt: new Date()
            },
            { upsert: true }
        );

        throw new Error(`Meesho Sync Failed: ${error.message}`);
    }
};

exports.bulkPushProducts = async (businessId, productIds = []) => {
    let targetProducts = productIds;

    if (!targetProducts || targetProducts.length === 0) {
        const allProducts = await Product.find({ businessId: businessId });
        targetProducts = allProducts.map(p => p._id);
    }

    const results = [];
    for (const pId of targetProducts) {
        try {
            const res = await exports.pushSingleProduct(businessId, pId);
            results.push({ productId: pId, success: true, mapping: res.mapping });
        } catch (err) {
            results.push({ productId: pId, success: false, error: err.message });
        }
    }

    return results;
};
