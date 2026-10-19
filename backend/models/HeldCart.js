const mongoose = require("mongoose");

const heldCartItemSchema = new mongoose.Schema(
  {
    productId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Product",
      required: true,
    },
    name: {
      type: String,
      required: true,
    },
    price: {
      type: Number,
      required: true,
    },
    quantity: {
      type: Number,
      required: true,
      min: 1,
    },
    total: {
      type: Number,
      required: true,
    },
  },
  { _id: false }
);

const heldCartSchema = new mongoose.Schema(
  {
    clientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Business",
      required: true,
    },
    heldBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    referenceLabel: {
      type: String,
      default: "Customer Cart",
      trim: true,
    },
    customerName: {
      type: String,
      trim: true,
    },
    customerPhone: {
      type: String,
      trim: true,
    },
    customerEmail: {
      type: String,
      trim: true,
    },
    customerAddress: {
      type: String,
      trim: true,
    },
    orderNotes: {
      type: String,
      trim: true,
    },
    items: [heldCartItemSchema],
    subtotal: {
      type: Number,
      default: 0,
    },
    discount: {
      type: Number,
      default: 0,
    },
    appliedCouponCode: {
      type: String,
      trim: true,
      uppercase: true,
    },
    taxRate: {
      type: Number,
      default: 0.18,
    },
    extraCharges: {
      type: Number,
      default: 0,
    },
    heldAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("HeldCart", heldCartSchema);
