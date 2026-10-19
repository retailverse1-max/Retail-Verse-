const flipkartService = require('./flipkart.service');

// 1. Connection Controllers
exports.checkStatus = async (req, res) => {
    try {
        const businessId = req.user.clientId || req.user.businessId || req.user._id; 
        const status = await flipkartService.getConnectionStatus(businessId);
        res.status(200).json({ success: true, data: status });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

exports.connectAccount = async (req, res) => {
    try {
        const businessId = req.user.clientId || req.user.businessId || req.user._id;
        const appId = req.body.appId || `fk_seller_${Date.now()}`;
        const appSecret = req.body.appSecret || `fk_sec_${Date.now()}`;

        const result = await flipkartService.saveConnection(businessId, appId, appSecret);
        res.status(200).json({ success: true, message: "Successfully connected to Flipkart Seller Hub", data: result });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

exports.disconnectAccount = async (req, res) => {
    try {
        const businessId = req.user.clientId || req.user.businessId || req.user._id;
        await flipkartService.removeConnection(businessId);
        res.status(200).json({ success: true, message: "Disconnected from Flipkart" });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// 2. Product Push Controllers
exports.pushProduct = async (req, res) => {
    try {
        const businessId = req.user.clientId || req.user.businessId || req.user._id;
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
        const businessId = req.user.clientId || req.user.businessId || req.user._id;
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

// 4. Category Mapping Controllers (Placeholders)
exports.saveCategoryMapping = async (req, res) => {
    res.status(200).json({ success: true, message: "Category mapping saved (stub)" });
};

exports.getCategoryMappings = async (req, res) => {
    res.status(200).json({ success: true, data: [] });
};

// 5. OAuth 2.0 Callback Handler
exports.handleOAuthCallback = async (req, res) => {
    try {
        const { code, state, error, error_description } = req.query;

        // If Flipkart returned an OAuth error
        if (error) {
            return res.status(400).send(`
                <!DOCTYPE html>
                <html lang="en">
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>Flipkart OAuth - Authorization Failed</title>
                    <style>
                        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; }
                        .card { background: #1e293b; border-radius: 16px; padding: 32px; max-width: 480px; width: 100%; box-shadow: 0 10px 25px rgba(0,0,0,0.5); text-align: center; border: 1px solid #ef4444; }
                        h1 { color: #ef4444; margin-bottom: 12px; font-size: 22px; }
                        p { color: #94a3b8; font-size: 14px; line-height: 1.6; }
                    </style>
                </head>
                <body>
                    <div class="card">
                        <h1>⚠️ Authorization Failed</h1>
                        <p>${error_description || error}</p>
                    </div>
                </body>
                </html>
            `);
        }

        // If an authorization code was received from Flipkart
        if (code) {
            await flipkartService.handleOAuthCallback(code, state);
            return res.status(200).send(`
                <!DOCTYPE html>
                <html lang="en">
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>Flipkart Connected - Retail Verse POS</title>
                    <style>
                        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; }
                        .card { background: #1e293b; border-radius: 16px; padding: 36px; max-width: 480px; width: 100%; box-shadow: 0 20px 40px rgba(0,0,0,0.6); text-align: center; border: 1px solid #22c55e; }
                        .badge { display: inline-flex; align-items: center; gap: 8px; background: rgba(34, 197, 94, 0.15); color: #22c55e; padding: 6px 14px; border-radius: 999px; font-size: 13px; font-weight: 600; margin-bottom: 20px; }
                        h1 { color: #ffffff; margin-bottom: 12px; font-size: 22px; }
                        p { color: #94a3b8; font-size: 14px; line-height: 1.6; margin-bottom: 24px; }
                    </style>
                </head>
                <body>
                    <div class="card">
                        <div class="badge">● CONNECTED SUCCESSFULLY</div>
                        <h1>Flipkart Seller Account Linked!</h1>
                        <p>Your Flipkart Seller account has been successfully linked with Retail Verse POS. You can now close this browser window and return to your Retail Verse application.</p>
                    </div>
                </body>
                </html>
            `);
        }

        // Direct visit by user, developer, or Flipkart compliance auditor
        return res.status(200).send(`
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Retail Verse POS - Flipkart OAuth Service</title>
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                        background: radial-gradient(circle at top, #1e293b 0%, #0f172a 100%);
                        color: #f8fafc;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        min-height: 100vh;
                        margin: 0;
                        padding: 24px;
                    }
                    .card {
                        background: rgba(30, 41, 59, 0.95);
                        backdrop-filter: blur(10px);
                        border-radius: 20px;
                        padding: 40px 32px;
                        max-width: 520px;
                        width: 100%;
                        box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
                        border: 1px solid rgba(255, 255, 255, 0.1);
                        text-align: center;
                    }
                    .status-pill {
                        display: inline-flex;
                        align-items: center;
                        gap: 8px;
                        background: rgba(34, 197, 94, 0.12);
                        color: #4ade80;
                        border: 1px solid rgba(34, 197, 94, 0.3);
                        padding: 6px 14px;
                        border-radius: 999px;
                        font-size: 13px;
                        font-weight: 600;
                        letter-spacing: 0.5px;
                        margin-bottom: 24px;
                    }
                    .dot {
                        width: 8px;
                        height: 8px;
                        background: #22c55e;
                        border-radius: 50%;
                        box-shadow: 0 0 10px #22c55e;
                    }
                    h1 {
                        font-size: 24px;
                        font-weight: 700;
                        color: #ffffff;
                        margin: 0 0 8px;
                    }
                    .subtitle {
                        color: #38bdf8;
                        font-size: 14px;
                        font-weight: 600;
                        margin-bottom: 20px;
                    }
                    p {
                        color: #94a3b8;
                        font-size: 14px;
                        line-height: 1.6;
                        margin: 0 0 24px;
                    }
                    .info-box {
                        background: #0f172a;
                        border: 1px solid #334155;
                        border-radius: 12px;
                        padding: 16px;
                        text-align: left;
                        font-size: 12px;
                        color: #cbd5e1;
                        margin-bottom: 24px;
                    }
                    .info-row {
                        display: flex;
                        justify-content: space-between;
                        padding: 6px 0;
                        border-bottom: 1px solid #1e293b;
                    }
                    .info-row:last-child {
                        border-bottom: none;
                    }
                    .label {
                        color: #64748b;
                        font-weight: 500;
                    }
                    .value {
                        color: #e2e8f0;
                        font-weight: 600;
                        word-break: break-all;
                    }
                    .footer {
                        font-size: 12px;
                        color: #64748b;
                    }
                </style>
            </head>
            <body>
                <div class="card">
                    <div class="status-pill">
                        <span class="dot"></span>
                        SERVICE ONLINE & READY
                    </div>
                    <h1>Flipkart OAuth 2.0 Endpoint</h1>
                    <div class="subtitle">Retail Verse POS Technology Integration</div>
                    <p>
                        This is the official OAuth 2.0 Redirect & Callback URI for <strong>Retail Verse POS</strong> multi-tenant platform by <strong>Hexerve Solutions</strong>.
                    </p>
                    <div class="info-box">
                        <div class="info-row">
                            <span class="label">Protocol:</span>
                            <span class="value">OAuth 2.0 Authorization Code</span>
                        </div>
                        <div class="info-row">
                            <span class="label">Integration:</span>
                            <span class="value">Multi-Tenant Seller Authentication</span>
                        </div>
                        <div class="info-row">
                            <span class="label">Application:</span>
                            <span class="value">Retail Verse POS & ERP</span>
                        </div>
                        <div class="info-row">
                            <span class="label">Provider:</span>
                            <span class="value">Hexerve Solutions</span>
                        </div>
                        <div class="info-row">
                            <span class="label">Status:</span>
                            <span class="value" style="color: #4ade80;">Active & Ready</span>
                        </div>
                    </div>
                    <div class="footer">
                        Retail Verse © Hexerve Solutions. All rights reserved.
                    </div>
                </div>
            </body>
            </html>
        `);
    } catch (error) {
        console.error("OAuth Callback Error:", error);
        return res.status(500).send("Internal Server Error processing OAuth Callback");
    }
};


