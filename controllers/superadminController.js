const Business = require("../models/Business");
const Order = require("../models/Order");
const User = require("../models/User");
const CustomDomain = require("../models/CustomDomain");
const SubscriptionPlan = require("../models/SubscriptionPlan");
const AuditLog = require("../models/AuditLog");

// --- DASHBOARD & ANALYTICS ---
exports.getDashboardStats = async (req, res) => {
  try {
    const totalBusinesses = await Business.countDocuments();
    const totalOrders = await Order.countDocuments();
    const totalUsers = await User.countDocuments();
    const totalRevenue = await Order.aggregate([
      { $group: { _id: null, total: { $sum: "$total" } } }
    ]);

    res.status(200).json({
      success: true,
      data: {
        totalBusinesses,
        totalOrders,
        totalUsers,
        totalRevenue: totalRevenue[0] ? totalRevenue[0].total : 0,
        activeSubscriptions: 0 // Placeholder until we link plans
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getAnalyticsSummary = async (req, res) => {
  try {
    // Basic analytics: orders over last 30 days
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const recentOrders = await Order.find({ createdAt: { $gte: thirtyDaysAgo } });
    
    res.status(200).json({
      success: true,
      data: {
        recentOrdersCount: recentOrders.length,
        period: "30d"
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// --- BUSINESS MANAGEMENT ---
exports.getAllBusinesses = async (req, res) => {
  try {
    const businesses = await Business.find().sort({ createdAt: -1 });
    res.status(200).json({ success: true, data: businesses });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateBusinessStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const business = await Business.findByIdAndUpdate(req.params.id, { status }, { new: true });
    
    await AuditLog.create({
      action: "UPDATE_BUSINESS_STATUS",
      performedBy: req.user._id,
      targetType: "Business",
      targetId: req.params.id,
      details: { newStatus: status }
    });

    res.status(200).json({ success: true, data: business });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// --- USER MANAGEMENT (Platform Level) ---
exports.getAllUsers = async (req, res) => {
  try {
    const users = await User.find().select("-password").sort({ createdAt: -1 });
    res.status(200).json({ success: true, data: users });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// --- SUBSCRIPTION PLANS ---
exports.getAllPlans = async (req, res) => {
  try {
    const plans = await SubscriptionPlan.find();
    res.status(200).json({ success: true, data: plans });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// --- CUSTOM DOMAINS ---
exports.getAllDomains = async (req, res) => {
  try {
    const domains = await CustomDomain.find().populate("businessId", "businessName");
    res.status(200).json({ success: true, data: domains });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// --- AUDIT LOGS ---
exports.getAuditLogs = async (req, res) => {
  try {
    const logs = await AuditLog.find().populate("performedBy", "name email").sort({ createdAt: -1 }).limit(100);
    res.status(200).json({ success: true, data: logs });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
