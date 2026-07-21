const mongoose = require("mongoose");

const subscriptionPlanSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    price: { type: Number, required: true },
    billingCycle: { type: String, enum: ["monthly", "yearly"], default: "monthly" },
    features: [{ type: String }],
    isActive: { type: Boolean, default: true },
    maxProducts: { type: Number, default: 100 },
    maxUsers: { type: Number, default: 5 },
  },
  { timestamps: true }
);

module.exports = mongoose.model("SubscriptionPlan", subscriptionPlanSchema);
