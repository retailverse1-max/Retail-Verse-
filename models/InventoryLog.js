const mongoose = require("mongoose");

const inventoryLogSchema = new mongoose.Schema(
  {
    productId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Product",
      required: true,
    },
    type: {
      type: String,
      enum: ["sale", "purchase", "adjustment"],
      required: true,
    },
    quantity: {
      type: Number,
      required: true,
      min: 1,
    },
    beforeStock: {
      type: Number,
      required: true,
      min: 0,
    },
    afterStock: {
      type: Number,
      required: true,
      min: 0,
    },
    referenceId: {
      type: String,
      default: "",
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("InventoryLog", inventoryLogSchema);