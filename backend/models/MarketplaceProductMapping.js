const mongoose = require("mongoose");

const marketplaceProductMappingSchema = new mongoose.Schema({
  clientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Business",
    required: true,
  },
  productId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Product",
    required: true,
  },
  platform: {
    type: String,
    required: true,
  },
  platformProductId: {
    type: String,
    required: true,
  },
  platformSku: {
    type: String,
    required: true,
  },
  marketplacePrice: {
    type: Number,
  },
  syncStatus: {
    type: String,
    enum: ["synced", "pending", "failed"],
    default: "pending",
  },
  lastSyncedAt: Date,
  errorLog: String,
}, { timestamps: true });

module.exports = mongoose.model("MarketplaceProductMapping", marketplaceProductMappingSchema);
