const mongoose = require("mongoose");

const marketplaceOrderMappingSchema = new mongoose.Schema({
  clientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Business",
    required: true,
  },
  orderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Order", 
    required: true,
  },
  platform: {
    type: String,
    required: true,
  },
  platformOrderId: {
    type: String, 
    required: true,
    unique: true,
  },
  platformStatus: {
    type: String, 
  },
  shippingDetails: {
    awbNumber: String,
    courierName: String,
    labelUrl: String,
  },
}, { timestamps: true });

module.exports = mongoose.model("MarketplaceOrderMapping", marketplaceOrderMappingSchema);
