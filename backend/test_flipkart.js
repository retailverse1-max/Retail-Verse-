const mongoose = require('mongoose');
const flipkartService = require('./marketplace/flipkart/flipkart.service');

// A simple script you can run later via `node test_flipkart.js`
// Ensure you have MongoDB running locally or a valid connection URI in your .env
async function runTest() {
    console.log("🚀 Starting Flipkart API Logic Test...");
    
    // Connect to DB (You might need to adjust the URI based on your local setup)
    try {
        await mongoose.connect('mongodb://127.0.0.1:27017/retail_verse_test', {
            useNewUrlParser: true,
            useUnifiedTopology: true
        });
        console.log("✅ Connected to local MongoDB for testing.");
    } catch (e) {
        console.error("❌ DB Connection Failed:", e.message);
        return;
    }

    // Mock Business ID
    const dummyBusinessId = new mongoose.Types.ObjectId();
    const dummyAppId = "test_app_id_123";
    const dummyAppSecret = "test_app_secret_abc";

    try {
        console.log("\n--- Testing Connection Logic ---");
        const connection = await flipkartService.saveConnection(dummyBusinessId, dummyAppId, dummyAppSecret);
        console.log("✅ Connection Saved Successfully!");
        console.log(`Access Token Generated: ${connection.credentials.accessToken}`);

        const status = await flipkartService.getConnectionStatus(dummyBusinessId);
        console.log(`Status Check: ${status.connected ? 'Connected' : 'Disconnected'}`);

    } catch (error) {
        console.error("❌ Test Failed:", error.message);
    } finally {
        await mongoose.disconnect();
        console.log("\n🛑 Disconnected from DB. Test Complete.");
    }
}

runTest();
