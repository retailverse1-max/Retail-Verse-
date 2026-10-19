const mongoose = require("mongoose");

const couponSchema = new mongoose.Schema(
  {
    code: {
      type: String,
      required: true,
      uppercase: true,
      trim: true,
    },
    description: {
      type: String,
      default: "",
    },
    discountType: {
      type: String,
      enum: ["flat", "percentage"],
      default: "flat",
    },
    discountValue: {
      type: Number,
      required: true,
      min: 0,
    },
    maxDiscountAmount: {
      type: Number,
      default: null, // For percentage discount capping, e.g. 20% up to ₹500
    },
    minOrderAmount: {
      type: Number,
      default: 0,
    },
    validFrom: {
      type: Date,
      default: Date.now,
    },
    validUntil: {
      type: Date,
      default: null, // null means no expiration
    },
    usageLimit: {
      type: Number,
      default: null, // total redemptions allowed across all users
    },
    usedCount: {
      type: Number,
      default: 0,
    },
    perCustomerLimit: {
      type: Number,
      default: null, // max uses per customer phone (null = unlimited)
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    clientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Business",
      default: null, // null means universal/default, or scoped to store
    },
  },
  { timestamps: true }
);

couponSchema.index({ code: 1, clientId: 1 });

module.exports = mongoose.model("Coupon", couponSchema);
