const Order = require("../models/Order");
const Product = require("../models/Product");
const User = require("../models/User");
const Customer = require("../models/Customer");

exports.getDashboardStats = async (req, res) => {
  try {
    const clientId = req.user?.clientId;

    // Build filter: if user has clientId, filter by it
    const filter = clientId ? { clientId } : {};
    const orderFilter = { ...filter, status: { $ne: "cancelled" } };

    // Today's date range
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date();
    endOfDay.setHours(23, 59, 59, 999);

    // This month range
    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);

    // Parallel queries for performance
    const [
      totalOrdersCount,
      totalProducts,
      totalRevenueAgg,
      todaySalesAgg,
      totalCustomers,
      lowStockCount,
      monthSalesAgg,
    ] = await Promise.all([
      Order.countDocuments(orderFilter),
      Product.countDocuments(filter),
      Order.aggregate([
        { $match: orderFilter },
        { $group: { _id: null, total: { $sum: "$total" } } },
      ]),
      Order.aggregate([
        {
          $match: {
            ...orderFilter,
            createdAt: { $gte: startOfDay, $lte: endOfDay },
          },
        },
        { $group: { _id: null, total: { $sum: "$total" } } },
      ]),
      Customer.countDocuments(filter),
      Product.countDocuments({ ...filter, stock: { $lte: 10 } }),
      Order.aggregate([
        {
          $match: {
            ...orderFilter,
            createdAt: { $gte: startOfMonth },
          },
        },
        { $group: { _id: null, total: { $sum: "$total" } } },
      ]),
    ]);

    const totalSales = totalRevenueAgg[0]?.total ?? 0;
    const todaySales = todaySalesAgg[0]?.total ?? 0;
    const monthlySales = monthSalesAgg[0]?.total ?? 0;
    const avgSale = totalOrdersCount > 0 ? totalSales / totalOrdersCount : 0;

    res.status(200).json({
      success: true,
      data: {
        totalOrders: totalOrdersCount,
        totalProducts,
        totalSales,
        todaySales,
        monthlySales,
        avgSale,
        totalCustomers,
        lowStockItems: lowStockCount,
      },
    });
  } catch (error) {
    console.error("getDashboardStats error:", error);
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getRecentActivities = async (req, res) => {
  try {
    const clientId = req.user?.clientId;
    const filter = clientId ? { clientId } : {};

    const activities = await Order.find(filter)
      .sort({ createdAt: -1 })
      .limit(10)
      .select("orderNumber total status createdAt paymentMethod");

    res.status(200).json({
      success: true,
      data: activities,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getCustomers = async (req, res) => {
  try {
    const clientId = req.user?.clientId;
    const filter = clientId ? { clientId } : {};

    const customers = await Customer.find(filter).sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      data: customers,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.addCustomer = async (req, res) => {
  try {
    const { name, phone, email, address } = req.body;
    const clientId = req.user?.clientId;

    if (!name || !phone) {
      return res.status(400).json({ success: false, message: "Name and Phone are required" });
    }

    // Logging for debugging (Check your Render logs)
    console.log("Adding customer for clientId:", clientId);

    const customerData = {
      name,
      phone,
      email,
      address,
    };

    if (clientId) {
      customerData.clientId = clientId;
    } else {
      // Fallback: If no clientId, find the first business or handle accordingly
      // For now, we'll return an error if clientId is strictly required in model
      return res.status(400).json({ success: false, message: "User has no associated Business (clientId)" });
    }

    const customer = await Customer.create(customerData);

    res.status(201).json({
      success: true,
      message: "Customer added successfully",
      data: customer,
    });
  } catch (error) {
    console.error("ADD CUSTOMER ERROR:", error);
    if (error.code === 11000) {
      return res.status(400).json({ success: false, message: "Customer with this phone already exists" });
    }
    res.status(500).json({ success: false, message: error.message });
  }
};
