const mongoose = require("mongoose");

const productSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },
    sku: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    barcode: {
      type: String,
      default: "",
      trim: true,
    },
    price: {
      type: Number,
      required: true,
      min: 0,
    },
    cost: {
      type: Number,
      default: 0,
      min: 0,
    },
    stock: {
      type: Number,
      default: 0,
      min: 0,
    },
    variants: {
      type: Array,
      default: [],
    },
    category: {
      type: String,
      default: "",
      trim: true,
    },
    description: {
      type: String,
      default: "",
      trim: true,
    },
    imageUrl: {
      type: String,
      default: "",
      trim: true,
    },
    reorderLevel: {
      type: Number,
      default: 10,
      min: 0,
    },
    unit: {
      type: String,
      default: "pcs",
      trim: true,
    },
    source: {
      type: String,
      enum: ["internal", "woo", "external"],
      default: "internal",
    },
    lastSyncedAt: {
      type: Date,
      default: null,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    clientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Business",
      required: false,
    },
  },
  { timestamps: true }
);

productSchema.index({ clientId: 1, barcode: 1 });
productSchema.index({ barcode: 1 });

module.exports = mongoose.model("Product", productSchema);