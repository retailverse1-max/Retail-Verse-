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
    const Order = require("../models/Order");
    const Business = require("../models/Business");
    const User = require("../models/User");

    // 1. Total Metrics
    const totalBusinesses = await Business.countDocuments();
    const activeBusinesses = await Business.countDocuments({ status: "active" });
    
    const orderStats = await Order.aggregate([
      { $group: { _id: null, totalRevenue: { $sum: "$total" }, totalOrders: { $sum: 1 } } }
    ]);
    
    const totalRevenue = orderStats.length > 0 ? orderStats[0].totalRevenue : 0;
    const totalOrders = orderStats.length > 0 ? orderStats[0].totalOrders : 0;
    const totalCustomers = await User.countDocuments({ role: "customer" });

    // 2. Order Trends (Last 30 Days)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const dailyTrends = await Order.aggregate([
      { $match: { createdAt: { $gte: thirtyDaysAgo } } },
      {
        $group: {
          _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
          orders: { $sum: 1 },
          revenue: { $sum: "$total" }
        }
      },
      { $sort: { "_id": 1 } }
    ]);

    // 3. Business Distribution (for Pie Chart)
    const bizDistribution = await Business.aggregate([
      { $group: { _id: "$status", count: { $sum: 1 } } }
    ]);

    // 4. Per Business Performance
    const perBusinessOrders = await Order.aggregate([
      { $group: { _id: "$clientId", orders: { $sum: 1 }, revenue: { $sum: "$total" } } },
      { $sort: { revenue: -1 } },
      { $limit: 10 },
      {
        $lookup: {
          from: "businesses",
          localField: "_id",
          foreignField: "_id",
          as: "bizInfo"
        }
      },
      { $unwind: "$bizInfo" },
      {
        $project: {
          businessId: "$bizInfo.businessName",
          orders: 1,
          revenue: 1
        }
      }
    ]);

    res.status(200).json({
      success: true,
      data: {
        cards: {
          totalBusinesses,
          activeBusinesses,
          totalRevenue,
          totalOrders,
          totalCustomers,
          growthRate: "12.5%" // Mocked for now
        },
        trends: dailyTrends,
        distribution: bizDistribution,
        perBusinessOrders
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

exports.getBusinessDetails = async (req, res) => {
  try {
    const business = await Business.findById(req.params.id);
    if (!business) return res.status(404).json({ success: false, message: "Business not found" });

    // Count products for this business
    // Assuming Product model has businessId or storeId
    const Product = require("../models/Product");
    const productCount = await Product.countDocuments({ clientId: req.params.id });

    res.status(200).json({ 
      success: true, 
      data: {
        ...business.toJSON(),
        stats: {
          productCount
        }
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.updateBusiness = async (req, res) => {
  try {
    const business = await Business.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!business) return res.status(404).json({ success: false, message: "Business not found" });
    
    await AuditLog.create({
      action: "UPDATE_BUSINESS",
      performedBy: req.user._id,
      targetType: "Business",
      targetId: business._id,
      details: req.body
    });

    res.status(200).json({ success: true, data: business });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.deleteBusiness = async (req, res) => {
  try {
    const business = await Business.findByIdAndDelete(req.params.id);
    if (!business) return res.status(404).json({ success: false, message: "Business not found" });

    await AuditLog.create({
      action: "DELETE_BUSINESS",
      performedBy: req.user._id,
      targetType: "Business",
      targetId: req.params.id,
      details: { name: business.businessName }
    });

    res.status(200).json({ success: true, message: "Business deleted successfully" });
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
    const { domain } = req.body;
    // Check if domain already exists
    const existing = await CustomDomain.findOne({ domain });
    if (existing) {
      return res.status(200).json({ success: true, data: existing, message: "Domain already registered" });
    }
    const newDomain = await CustomDomain.create(req.body);
    res.status(201).json({ success: true, data: newDomain });
  } catch (error) {
    if (error.code === 11000) {
      const existing = await CustomDomain.findOne({ domain: req.body.domain });
      return res.status(200).json({ success: true, data: existing, message: "Domain already registered" });
    }
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.verifyCustomDomain = async (req, res) => {
  try {
    const domain = await CustomDomain.findByIdAndUpdate(req.params.id, { status: 'verified' }, { new: true });
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

// --- TOP PERFORMANCE STORES ---
exports.getTopPerformanceStores = async (req, res) => {
  try {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const performance = await Order.aggregate([
      {
        $match: {
          createdAt: { $gte: thirtyDaysAgo }
        }
      },
      {
        $group: {
          _id: "$businessId",
          totalRevenue: { $sum: "$total" },
          totalOrders: { $count: {} },
          uniqueCustomers: { $addToSet: "$customerId" }
        }
      },
      {
        $lookup: {
          from: "businesses",
          localField: "_id",
          foreignField: "_id",
          as: "businessInfo"
        }
      },
      { $unwind: "$businessInfo" },
      {
        $project: {
          _id: 1,
          name: "$businessInfo.name",
          revenue: "$totalRevenue",
          orders: "$totalOrders",
          customers: { $size: "$uniqueCustomers" },
          health: { $literal: 0.98 },
          growth: { $literal: "+15.2%" }
        }
      },
      { $sort: { revenue: -1 } },
      { $limit: 10 }
    ]);

    res.status(200).json({ success: true, data: performance });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
exports.fixBusinessesData = async (req, res) => {
  try {
    const businesses = await Business.find({ $or: [{ businessId: null }, { businessId: { $exists: false } }] });
    let count = 0;
    for (const b of businesses) {
      const random = Math.floor(100000 + Math.random() * 900000);
      b.businessId = `RV-${random}`;
      await b.save();
      count++;
    }
    res.status(200).json({ success: true, message: `Fixed ${count} businesses` });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
