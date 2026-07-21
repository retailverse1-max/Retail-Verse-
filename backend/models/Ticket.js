const mongoose = require("mongoose");

const ticketSchema = new mongoose.Schema(
  {
    ticketId: {
      type: Number,
      required: true,
      unique: true,
    },
    subject: {
      type: String,
      required: true,
    },
    clientId: {
      type: String,
    },
    message: {
      type: String,
      required: true,
    },
    userName: {
      type: String,
    },
    email: {
      type: String,
    },
    role: {
      type: String,
    },
    businessName: {
      type: String,
    },
    storeId: {
      type: String,
    },
    status: {
      type: String,
      default: "open",
    },
    priority: {
      type: String,
      default: "normal",
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Ticket", ticketSchema);
