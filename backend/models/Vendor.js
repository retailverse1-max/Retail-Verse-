const mongoose = require("mongoose");

const vendorSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },
    companyName: {
      type: String,
      default: "",
      trim: true,
    },
    phone: {
      type: String,
      required: true,
      trim: true,
    },
    email: {
      type: String,
      default: "",
      trim: true,
    },
    category: {
      type: String,
      default: "General Supply",
      trim: true,
    },
    address: {
      type: String,
      default: "",
      trim: true,
    },
    gstin: {
      type: String,
      default: "",
      trim: true,
    },
    rating: {
      type: Number,
      default: 4.8,
      min: 1,
      max: 5,
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

vendorSchema.index({ clientId: 1, name: 1 });

module.exports = mongoose.model("Vendor", vendorSchema);
