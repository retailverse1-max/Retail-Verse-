const Order = require("../models/Order");
const Product = require("../models/Product");

exports.getDashboardStats = async (req, res) => {
  try {
    const totalOrders = await Order.countDocuments();
    const totalProducts = await Product.countDocuments();
    const totalRevenue = await Order.aggregate([
      { $group: { _id: null, total: { $sum: "$total" } } }
    ]);

    res.status(200).json({
      success: true,
      data: {
        totalOrders,
        totalProducts,
        totalRevenue: totalRevenue[0] ? totalRevenue[0].total : 0,
        lowStockItems: 0 // Placeholder
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getRecentActivities = async (req, res) => {
  try {
    const activities = await Order.find()
      .sort({ createdAt: -1 })
      .limit(10)
      .select("orderNumber total status createdAt");
    
    res.status(200).json({
      success: true,
      data: activities
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
