const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

// Initialize Firebase Admin
let isInitialized = false;

try {
  const serviceAccountPath = path.join(__dirname, "../firebaseServiceAccountKey.json");
  if (process.env.FIREBASE_CREDENTIALS) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_CREDENTIALS);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    isInitialized = true;
    console.log("Firebase Admin initialized successfully from ENV.");
  } else if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    isInitialized = true;
    console.log("Firebase Admin initialized successfully from file.");
  } else {
    console.warn("FCM setup skipped: firebase credentials not found.");
  }
} catch (error) {
  console.error("Error initializing Firebase Admin:", error.message);
}

/**
 * Send a push notification to a list of tokens.
 */
const sendPushNotificationToTokens = async (tokens, title, body, data = {}) => {
  if (!isInitialized || !tokens || tokens.length === 0) return;

  const validTokens = tokens.filter((t) => t && t.trim() !== "");
  if (validTokens.length === 0) return;

  const message = {
    notification: {
      title,
      body,
    },
    data,
    tokens: validTokens,
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`FCM Multicast sent: ${response.successCount} successes, ${response.failureCount} failures.`);
  } catch (error) {
    console.error("Error sending FCM notification:", error);
  }
};

module.exports = {
  sendPushNotificationToTokens,
};
