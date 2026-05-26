const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
    },
    message: {
      type: String,
      required: true,
    },
    type: {
      type: String, // 'low_stock', 'software_update', 'plan_upgrade', 'general'
      default: "general",
    },
    targetRoles: [
      {
        type: String,
      },
    ],
    clientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Business",
      required: false, // Optional for global broadcast (like software updates)
    },
    readBy: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
  },
  { timestamps: true }
);

module.exports = mongoose.model("Notification", notificationSchema);
