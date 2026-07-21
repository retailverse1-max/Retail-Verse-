const flipkartService = require('./flipkart.service');

// 1. Connection Controllers
exports.checkStatus = async (req, res) => {
    try {
        // Assume req.user.businessId is set by authMiddleware
        const businessId = req.user.businessId; 
        const status = await flipkartService.getConnectionStatus(businessId);
        res.status(200).json({ success: true, data: status });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

exports.connectAccount = async (req, res) => {
    try {
        const businessId = req.user.businessId;
        const { appId, appSecret } = req.body;
        
        if (!appId || !appSecret) {
            return res.status(400).json({ success: false, message: "App ID and App Secret are required" });
        }

        const result = await flipkartService.saveConnection(businessId, appId, appSecret);
        res.status(200).json({ success: true, message: "Successfully connected to Flipkart", data: result });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

exports.disconnectAccount = async (req, res) => {
    try {
        const businessId = req.user.businessId;
        await flipkartService.removeConnection(businessId);
        res.status(200).json({ success: true, message: "Disconnected from Flipkart" });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// 2. Product Push Controllers
exports.pushProduct = async (req, res) => {
    try {
        const businessId = req.user.businessId;
        const { productId } = req.body;

        if (!productId) {
            return res.status(400).json({ success: false, message: "Product ID is required" });
        }

        const result = await flipkartService.pushSingleProduct(businessId, productId);
        res.status(200).json({ success: true, message: "Product push initiated", data: result });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

exports.bulkPushProducts = async (req, res) => {
    try {
        const businessId = req.user.businessId;
        const { productIds } = req.body;

        if (!productIds || !Array.isArray(productIds)) {
            return res.status(400).json({ success: false, message: "Array of Product IDs is required" });
        }

        // Ideally handled asynchronously / background job, but for now we wait
        const result = await flipkartService.pushBulkProducts(businessId, productIds);
        res.status(200).json({ success: true, message: "Bulk push processed", data: result });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// 3. Webhook Controller
exports.handleOrderWebhook = async (req, res) => {
    try {
        // Flipkart Signature Verification will happen here
        const webhookData = req.body;
        await flipkartService.processIncomingOrder(webhookData);
        res.status(200).send("OK");
    } catch (error) {
        console.error("Webhook Error:", error);
        res.status(500).send("Error processing webhook");
    }
};
