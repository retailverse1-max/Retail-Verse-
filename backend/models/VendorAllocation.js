const mongoose = require("mongoose");

const vendorSplitSchema = new mongoose.Schema(
  {
    vendorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Vendor",
      required: false,
    },
    vendorName: {
      type: String,
      required: true,
      trim: true,
    },
    units: {
      type: Number,
      required: true,
      min: 1,
    },
    targetDeliveryDate: {
      type: Date,
      default: () => new Date(Date.now() + 6 * 24 * 60 * 60 * 1000),
    },
    status: {
      type: String,
      default: "Allocated",
    },
  },
  { _id: true }
);

const vendorAllocationSchema = new mongoose.Schema(
  {
    productId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Product",
      required: false,
    },
    productName: {
      type: String,
      default: "Grocery",
      trim: true,
    },
    productSku: {
      type: String,
      default: "RV-134045-3890",
      trim: true,
    },
    threshold: {
      type: Number,
      default: 5, // Triggers when stock drops to <= 5
      min: 0,
    },
    totalUnitsNeeded: {
      type: Number,
      default: 20,
      min: 1,
    },
    splits: [vendorSplitSchema],
    autoTriggerEnabled: {
      type: Boolean,
      default: true,
    },
    lastTriggeredAt: {
      type: Date,
      default: null,
    },
    clientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Business",
      required: false,
    },
    history: [
      {
        orderId: String,
        productName: String,
        productSku: String,
        stockAtTrigger: Number,
        totalUnitsNeeded: Number,
        splits: Array,
        triggeredBy: {
          type: String,
          enum: ["auto_low_stock", "manual_admin", "admin_save_low_stock"],
          default: "auto_low_stock",
        },
        readReceipts: [
          {
            vendorName: String,
            readAt: Date,
            status: { type: String, default: "Delivered" },
          },
        ],
        createdAt: {
          type: Date,
          default: Date.now,
        },
      },
    ],
  },
  { timestamps: true }
);

vendorAllocationSchema.index({ clientId: 1, productSku: 1 });
vendorAllocationSchema.index({ clientId: 1, productId: 1 });

module.exports = mongoose.model("VendorAllocation", vendorAllocationSchema);
