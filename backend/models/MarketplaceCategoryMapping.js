const mongoose = require("mongoose");

const marketplaceCategoryMappingSchema = new mongoose.Schema({
  clientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Business",
    required: true,
  },
  retailVerseCategoryId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Category", 
    required: true,
  },
  platform: {
    type: String,
    required: true,
    enum: ["flipkart", "amazon", "blinkit", "zepto", "shopify"],
  },
  platformCategoryId: {
    type: String,
    required: true, 
  },
  platformCategoryName: {
    type: String,
  },
  mandatoryAttributes: {
    type: Map,
    of: String, // e.g., { "Brand": "Nike", "HSN": "6205", "Tax": "12" }
    default: {}
  }
}, { timestamps: true });

marketplaceCategoryMappingSchema.index({ clientId: 1, retailVerseCategoryId: 1, platform: 1 }, { unique: true });

module.exports = mongoose.model("MarketplaceCategoryMapping", marketplaceCategoryMappingSchema);
