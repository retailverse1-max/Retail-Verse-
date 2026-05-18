const mongoose = require("mongoose");

const businessSchema = new mongoose.Schema(
  {
    businessName: {
      type: String,
      required: true,
      trim: true,
    },
    ownerName: {
      type: String,
      trim: true,
    },
    ownerEmail: {
      type: String,
      trim: true,
      lowercase: true,
    },
    phone: {
      type: String,
      trim: true,
    },
    address: {
      type: String,
      trim: true,
    },
    businessType: {
      type: String,
      trim: true,
    },
    notes: {
      type: String,
      trim: true,
    },
    status: {
      type: String,
      enum: ["active", "inactive"],
      default: "active",
    },
    subscriptionPlan: {
      type: String,
      enum: ["free", "basic", "pro"],
      default: "free",
    },
    subscriptionStatus: {
      type: String,
      enum: ["active", "expired"],
      default: "active",
    },
    subscriptionExpiry: {
      type: Date,
    },
    businessId: {
      type: String,
      unique: true,
      sparse: true,
      trim: true,
    },
  },
  { timestamps: true }
);

// Auto-generate businessId if not present
businessSchema.pre('save', function(next) {
  if (!this.businessId) {
    const random = Math.floor(100000 + Math.random() * 900000);
    this.businessId = `RV-${random}`;
  }
  next();
});

businessSchema.set('toJSON', {
  virtuals: true,
  transform: (doc, ret) => {
    if (ret._id) ret.id = ret._id.toString();
    delete ret.__v;
  }
});

module.exports = mongoose.model("Business", businessSchema);
