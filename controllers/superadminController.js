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
        activeSubscriptions: totalBusinesses // Simplified
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getAnalyticsSummary = async (req, res) => {
  try {
    const totalBusinesses = await Business.countDocuments();
    const activeBusinesses = await Business.countDocuments({ status: "active" });
    
    res.status(200).json({
      success: true,
      data: {
        cards: {
          totalBusinesses,
          activeBusinesses,
          newBusinessesThisMonth: 0,
          churnRate: "0.0%"
        }
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

exports.createBusiness = async (req, res) => {
  try {
    const business = await Business.create(req.body);
    await AuditLog.create({
      action: "CREATE_BUSINESS",
      performedBy: req.user._id,
      targetType: "Business",
      targetId: business._id,
      details: req.body
    });
    res.status(201).json({ success: true, data: business });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateBusinessStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const business = await Business.findByIdAndUpdate(req.params.id, { status }, { new: true });
    res.status(200).json({ success: true, data: business });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// --- USER MANAGEMENT ---
exports.getAllUsers = async (req, res) => {
  try {
    const users = await User.find().select("-password").sort({ createdAt: -1 });
    res.status(200).json({ success: true, data: users });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.createUser = async (req, res) => {
  try {
    const user = await User.create(req.body);
    res.status(201).json({ success: true, data: user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateUserStatus = async (req, res) => {
  try {
    const user = await User.findByIdAndUpdate(req.params.id, { isActive: req.body.isActive }, { new: true });
    res.status(200).json({ success: true, data: user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateUserRole = async (req, res) => {
  try {
    const user = await User.findByIdAndUpdate(req.params.id, { role: req.body.role }, { new: true });
    res.status(200).json({ success: true, data: user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.deleteUser = async (req, res) => {
  try {
    await User.findByIdAndDelete(req.params.id);
    res.status(200).json({ success: true, message: "User deleted" });
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
    const domains = await CustomDomain.find();
    res.status(200).json({ success: true, data: domains });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.addCustomDomain = async (req, res) => {
  try {
    const domain = await CustomDomain.create(req.body);
    res.status(201).json({ success: true, data: domain });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.verifyCustomDomain = async (req, res) => {
  try {
    const domain = await CustomDomain.findByIdAndUpdate(req.params.id, { isVerified: true }, { new: true });
    res.status(200).json({ success: true, data: domain });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.activateCustomDomain = async (req, res) => {
  try {
    const domain = await CustomDomain.findByIdAndUpdate(req.params.id, { status: "active" }, { new: true });
    res.status(200).json({ success: true, data: domain });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.deleteCustomDomain = async (req, res) => {
  try {
    await CustomDomain.findByIdAndDelete(req.params.id);
    res.status(200).json({ success: true, message: "Domain deleted" });
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
