const Order = require("../models/Order");
const Product = require("../models/Product");
const Business = require("../models/Business");
const InventoryLog = require("../models/InventoryLog");
const { createAndSendNotification } = require("../services/notificationService");

const createOrder = async (req, res) => {
  try {
    const {
      items,
      paymentMethod,
      total,
      customerName,
      customerPhone,
      customerEmail,
      customerAddress,
      notes,
    } = req.body;

    if (!items || !items.length) {
      return res.status(400).json({ message: "Order items are required" });
    }

    if (!paymentMethod) {
      return res.status(400).json({ message: "Payment method is required" });
    }

    // ── Resolve clientId ──────────────────────────────
    let clientId = req.user.clientId;
    if (!clientId) {
      // Try to find an existing Business linked to the user's email
      const biz = await Business.findOne({ ownerEmail: req.user.email });
      if (biz) {
        clientId = biz._id;
        // Back-fill the User record so this look-up won't be needed again
        req.user.clientId = biz._id;
        await req.user.save();
      } else {
        // Auto-create a Business for this user
        const newBiz = await Business.create({
          businessName: `${req.user.name}'s Business`,
          ownerName: req.user.name,
          ownerEmail: req.user.email,
          status: "active",
          subscriptionPlan: "free",
          subscriptionStatus: "active",
        });
        clientId = newBiz._id;
        req.user.clientId = newBiz._id;
        await req.user.save();
      }
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
      status: req.body.status || "completed",
      createdBy: req.user._id,
      clientId: clientId,
      customerName,
      customerPhone,
      customerEmail,
      customerAddress,
      notes,
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

      // Push notification for out of stock
      if (afterStock === 0 && beforeStock > 0) {
        await createAndSendNotification({
          title: "Product Out of Stock 🚨",
          message: `${product.name} has run out of stock! Please restock soon.`,
          type: "low_stock",
          targetRoles: ["inventory", "admin"],
          clientId: clientId,
          data: { productId: product._id.toString() },
        });
      }
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
    const filter = {};
    if (req.user && req.user.role !== "super_admin") {
      filter.clientId = req.user.clientId;
    }

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

const updateOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      items,
      paymentMethod,
      total,
      status,
      paymentStatus,
      customerName,
      customerPhone,
      customerEmail,
      customerAddress,
      notes,
      discount,
      tax,
      converted,
    } = req.body;

    const order = await Order.findById(id);
    if (!order) {
      return res.status(404).json({ success: false, message: "Order not found" });
    }

    if (order.clientId && req.user?.clientId && order.clientId.toString() !== req.user.clientId.toString()) {
      return res.status(403).json({ success: false, message: "Not authorized to update this order" });
    }

    // Adjust stock differences if items are modified
    if (items && Array.isArray(items)) {
      const oldQtyMap = {};
      for (const item of order.items) {
        oldQtyMap[item.productId.toString()] = item.qty;
      }

      const newQtyMap = {};
      for (const item of items) {
        newQtyMap[item.productId.toString()] = item.qty;
      }

      // 1. Restore stock for completely removed items
      for (const item of order.items) {
        const prodIdStr = item.productId.toString();
        if (!newQtyMap[prodIdStr]) {
          const product = await Product.findById(item.productId);
          if (product) {
            const beforeStock = product.stock;
            product.stock += item.qty;
            await product.save();

            await InventoryLog.create({
              productId: product._id,
              type: "adjustment",
              quantity: item.qty,
              beforeStock,
              afterStock: product.stock,
              referenceId: order._id.toString(),
              notes: "Stock returned due to item removal from order update",
            });
          }
        }
      }

      // 2. Adjust stock for updated/new items
      let finalItems = [];
      let computedTotal = 0;

      for (const item of items) {
        const product = await Product.findById(item.productId);
        if (!product) {
          return res.status(404).json({ success: false, message: `Product not found: ${item.productId}` });
        }

        const oldQty = oldQtyMap[product._id.toString()] || 0;
        const diff = item.qty - oldQty;

        if (diff > 0) {
          if (product.stock < diff) {
            return res.status(400).json({ success: false, message: `Insufficient stock for ${product.name}` });
          }
          const beforeStock = product.stock;
          product.stock -= diff;
          await product.save();

          await InventoryLog.create({
            productId: product._id,
            type: "sale",
            quantity: diff,
            beforeStock,
            afterStock: product.stock,
            referenceId: order._id.toString(),
          });
        } else if (diff < 0) {
          const beforeStock = product.stock;
          product.stock += Math.abs(diff);
          await product.save();

          await InventoryLog.create({
            productId: product._id,
            type: "adjustment",
            quantity: Math.abs(diff),
            beforeStock,
            afterStock: product.stock,
            referenceId: order._id.toString(),
            notes: "Stock returned due to quantity reduction in order update",
          });
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

      order.items = finalItems;
      order.total = total || computedTotal;
    }

    if (paymentMethod !== undefined) order.paymentMethod = paymentMethod.toLowerCase();
    if (status !== undefined) order.status = status.toLowerCase();
    if (paymentStatus !== undefined) order.paymentStatus = paymentStatus.toLowerCase();
    if (customerName !== undefined) order.customerName = customerName;
    if (customerPhone !== undefined) order.customerPhone = customerPhone;
    if (customerEmail !== undefined) order.customerEmail = customerEmail;
    if (customerAddress !== undefined) order.customerAddress = customerAddress;
    if (notes !== undefined) order.notes = notes;
    if (discount !== undefined) order.discount = discount;
    if (tax !== undefined) order.tax = tax;
    if (converted !== undefined) order.converted = converted;

    await order.save();

    res.json({
      success: true,
      message: "Order updated successfully",
      order,
    });
  } catch (error) {
    console.error("Order Update Error:", error);
    res.status(500).json({ success: false, message: error.message });
  }
};

const recordPayment = async (req, res) => {
  try {
    const { amount, method, remarks, type } = req.body;

    if (!amount || !method) {
      return res.status(400).json({ message: "Amount and payment method are required" });
    }

    let clientId = req.user.clientId;
    if (!clientId) {
      const biz = await Business.findOne({ ownerEmail: req.user.email });
      if (biz) {
        clientId = biz._id;
      } else {
        return res.status(400).json({ message: "No active business found for this user." });
      }
    }

    const timestamp = Date.now();
    const random = Math.floor(Math.random() * 1000);
    const orderId = `RV-PAY-${timestamp}-${random}`;

    const paymentRecord = await Order.create({
      orderId,
      channel: "pos",
      type: type || "payment_in",
      items: [], // No items for a generic payment
      total: parseFloat(amount),
      paymentMethod: method.toLowerCase(),
      status: "completed",
      paymentStatus: "paid",
      createdBy: req.user._id,
      clientId: clientId,
      customerName: remarks, // using customerName field to store remarks for now
    });

    res.status(201).json({
      success: true,
      message: "Payment recorded successfully",
      data: paymentRecord,
    });
  } catch (error) {
    console.error("Payment Record Error:", error);
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { createOrder, getOrders, updateOrder, recordPayment };