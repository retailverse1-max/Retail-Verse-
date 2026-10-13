const meeshoService = require('./meesho.service');

exports.checkStatus = async (req, res) => {
    try {
        const businessId = req.user.businessId || req.user._id;
        const status = await meeshoService.getConnectionStatus(businessId);
        res.status(200).json({ success: true, data: status });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

exports.connectAccount = async (req, res) => {
    try {
        const businessId = req.user.businessId || req.user._id;
        const { supplierId, phoneNumber, apiKey } = req.body;

        if (!supplierId && !phoneNumber) {
            return res.status(400).json({ 
                success: false, 
                message: "Meesho Supplier ID or Registered Phone Number is required" 
            });
        }

        const connection = await meeshoService.saveConnection(businessId, { 
            supplierId: supplierId ? String(supplierId).trim() : '', 
            phoneNumber: phoneNumber ? String(phoneNumber).trim() : '', 
            apiKey: apiKey ? String(apiKey).trim() : '' 
        });

        res.status(200).json({
            success: true,
            message: "Successfully connected to Meesho Seller Account!",
            data: {
                connected: true,
                supplierId: connection.credentials?.appId,
                phoneNumber: connection.credentials?.appSecret,
                status: connection.status
            }
        });
    } catch (error) {
        res.status(400).json({ success: false, message: error.message });
    }
};

exports.disconnectAccount = async (req, res) => {
    try {
        const businessId = req.user.businessId || req.user._id;
        await meeshoService.removeConnection(businessId);
        res.status(200).json({ success: true, message: "Disconnected Meesho seller account." });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

exports.pushProduct = async (req, res) => {
    try {
        const businessId = req.user.businessId || req.user._id;
        const { productId } = req.body;

        if (!productId) {
            return res.status(400).json({ success: false, message: "productId is required." });
        }

        const result = await meeshoService.pushSingleProduct(businessId, productId);
        res.status(200).json({
            success: true,
            message: "Product successfully published to Meesho Supplier Panel!",
            data: result
        });
    } catch (error) {
        res.status(400).json({ success: false, message: error.message });
    }
};

exports.bulkPushProducts = async (req, res) => {
    try {
        const businessId = req.user.businessId || req.user._id;
        const { productIds } = req.body;

        const results = await meeshoService.bulkPushProducts(businessId, productIds);
        res.status(200).json({
            success: true,
            message: "Bulk product sync completed for Meesho.",
            data: results
        });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};
