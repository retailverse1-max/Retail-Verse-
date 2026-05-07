const mongoose = require("mongoose");

const customDomainSchema = new mongoose.Schema(
  {
    businessId: {
      type: String,
      required: true,
    },
    domain: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    status: {
      type: String,
      enum: ["pending", "verified", "active", "failed"],
      default: "pending",
    },
    dnsType: {
      type: String,
      default: "CNAME",
    },
    dnsName: {
      type: String,
      default: "store",
    },
    dnsValue: {
      type: String,
      default: "app.omnicommerce.in",
    },
    verifiedAt: {
      type: Date,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("CustomDomain", customDomainSchema);
