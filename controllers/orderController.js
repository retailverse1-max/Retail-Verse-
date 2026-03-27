const Order = require("../models/Order");
const Product = require("../models/Product");
const InventoryLog = require("../models/InventoryLog");

const createOrder = async (req, res) => {
  try {
    const { items, paymentMethod, total } = req.body;

    if (!items || !items.length) {
      return res.status(400).json({ message: "Order items are required" });
    }

    if (!paymentMethod) {
      return res.status(400).json({ message: "Payment method is required" });
    }

    let finalItems = [];
    let computedTotal = 0;

    for (const item of items) {
      const product = await Product.findById(item.productId);

      if (!product) {
        return res.status(404).json({ message: `Product not found: ${item.productId}` });
      }

      if (product.stock < item.qty) {
        return res.status(400).json({ message: `Insufficient stock for ${product.name}` });
      }

      const itemTotal = product.price * item.qty;
      computedTotal += itemTotal;

      finalItems.push({
        productId: product._id,
        name: product.name,
        qty: item.qty,
        price: product.price,
        total: itemTotal,
      });
    }

    const order = await Order.create({
      channel: "pos",
      items: finalItems,
      total: total || computedTotal,
      paymentMethod,
      status: "completed",
      createdBy: req.user._id,
    });

    for (const item of finalItems) {
      const product = await Product.findById(item.productId);
      const beforeStock = product.stock;
      const afterStock = beforeStock - item.qty;

      product.stock = afterStock;
      await product.save();

      await InventoryLog.create({
        productId: product._id,
        type: "sale",
        quantity: item.qty,
        beforeStock,
        afterStock,
        referenceId: order._id.toString(),
      });
    }

    res.status(201).json({
      message: "Order created successfully",
      order,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
const getOrders = async (req, res) => {
  try {
    const orders = await Order.find()
      .populate("createdBy", "name email role")
      .sort({ createdAt: -1 });

    res.json({
      message: "Orders fetched successfully",
      data: orders,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { createOrder, getOrders };