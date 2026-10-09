const mongoose = require("mongoose");

const marketplaceConnectionSchema = new mongoose.Schema({
  clientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Business",
    required: true,
  },
  platform: {
    type: String,
    enum: ["flipkart", "amazon", "blinkit", "zepto", "shopify", "meesho", "zomato", "swiggy", "eatclub", "woocommerce"],
    required: true,
  },
  status: {
    type: String,
    enum: ["active", "inactive", "expired", "error"],
    default: "active",
  },
  credentials: {
    appId: String,
    appSecret: String,
    accessToken: String,
    refreshToken: String,
    tokenExpiresAt: Date,
  },
  settings: {
    autoSyncInventory: { type: Boolean, default: true },
    autoImportOrders: { type: Boolean, default: true },
  }
}, { timestamps: true });

marketplaceConnectionSchema.index({ clientId: 1, platform: 1 }, { unique: true });

module.exports = mongoose.model("MarketplaceConnection", marketplaceConnectionSchema);
