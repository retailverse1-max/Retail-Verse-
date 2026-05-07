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

    // Generate unique order ID
    const timestamp = Date.now();
    const random = Math.floor(Math.random() * 1000);
    const orderId = `RV-POS-${timestamp}-${random}`;

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
      orderId,
      channel: "pos",
      items: finalItems,
      total: total || computedTotal,
      paymentMethod: paymentMethod.toLowerCase(),
      status: "completed",
      createdBy: req.user._id,
      clientId: req.user.clientId,
    });

    // Update stock and logs
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
      success: true,
      message: "Order created successfully",
      order,
    });
  } catch (error) {
    console.error("Order Creation Error:", error);
    res.status(500).json({ success: false, message: error.message });
  }
};

const getOrders = async (req, res) => {
  try {
    const clientId = req.user?.clientId;
    const filter = clientId ? { clientId } : {};

    const orders = await Order.find(filter)
      .populate("createdBy", "name email role")
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      message: "Orders fetched successfully",
      data: orders,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { createOrder, getOrders };