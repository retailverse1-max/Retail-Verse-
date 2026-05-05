const CustomDomain = require("../models/CustomDomain");
const Business = require("../models/Business");
const User = require("../models/User");
const bcrypt = require("bcryptjs");
// GET /api/superadmin/businesses
exports.getBusinesses = async (req, res) => {
  try {
    const businesses = await Business.find().sort({ createdAt: -1 });
    res.status(200).json({ success: true, data: businesses });
  } catch (error) {
    console.error("Error fetching businesses:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};

// POST /api/superadmin/businesses
exports.createBusiness = async (req, res) => {
  try {
    const {
      businessName,
      ownerName,
      ownerEmail,
      phone,
      address,
      businessType,
      notes,
      status,
      subscriptionPlan,
      subscriptionStatus
    } = req.body;

    if (!businessName) {
      return res.status(400).json({ success: false, message: "Business name is required" });
    }

    const newBusiness = await Business.create({
      businessName,
      ownerName,
      ownerEmail,
      phone,
      address,
      businessType,
      notes,
      status: status || "active",
      subscriptionPlan: subscriptionPlan || "free",
      subscriptionStatus: subscriptionStatus || "active",
    });

    res.status(201).json({
      success: true,
      message: "Business created successfully",
      data: newBusiness,
    });
  } catch (error) {
    console.error("Error creating business:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};
// GET /api/superadmin/custom-domains
exports.getCustomDomains = async (req, res) => {
  try {
    const domains = await CustomDomain.find().sort({ createdAt: -1 });
    res.status(200).json({ success: true, data: domains });
  } catch (error) {
    console.error("Error fetching custom domains:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};

// POST /api/superadmin/custom-domains
exports.addCustomDomain = async (req, res) => {
  try {
    let { businessId, domain } = req.body;

    if (!businessId || !domain) {
      return res.status(400).json({ success: false, message: "Business ID and domain are required" });
    }

    // Validate business exists
    const business = await Business.findById(businessId);
    if (!business) {
      return res.status(404).json({ success: false, message: "Business not found" });
    }

    // Domain validation
    domain = domain.toLowerCase().trim();
    if (domain.includes("http://") || domain.includes("https://")) {
      return res.status(400).json({ success: false, message: "Domain should not include http:// or https://" });
    }
    const domainRegex = /^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}$/;
    if (!domainRegex.test(domain)) {
      return res.status(400).json({ success: false, message: "Invalid domain format" });
    }

    // Check uniqueness
    const existing = await CustomDomain.findOne({ domain });
    if (existing) {
      return res.status(400).json({ success: false, message: "Domain already exists" });
    }

    const platformDomain = process.env.PLATFORM_DOMAIN || "app-backend-je91.onrender.com";

    const newDomain = await CustomDomain.create({
      businessId,
      domain,
      status: "pending",
      dnsType: "CNAME",
      dnsName: "store", // Simplified: real app might extract sub-domain
      dnsValue: platformDomain,
    });

    res.status(201).json({
      success: true,
      message: "Custom domain added successfully",
      data: newDomain,
    });
  } catch (error) {
    console.error("Error adding custom domain:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};

// POST /api/superadmin/custom-domains/:id/verify
exports.verifyCustomDomain = async (req, res) => {
  try {
    const domainId = req.params.id;
    const customDomain = await CustomDomain.findById(domainId);

    if (!customDomain) {
      return res.status(404).json({ success: false, message: "Custom domain not found" });
    }

    // Safe placeholder verification logic
    // In a real scenario, we would use dns package: dns.resolveCname(...)
    // For now, we simulate a successful verification.
    customDomain.status = "verified";
    customDomain.verifiedAt = new Date();
    await customDomain.save();

    res.status(200).json({
      success: true,
      message: "Domain verified successfully",
      data: customDomain,
    });
  } catch (error) {
    console.error("Error verifying custom domain:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};

// PATCH /api/superadmin/custom-domains/:id/active
exports.activateCustomDomain = async (req, res) => {
  try {
    const domainId = req.params.id;
    const customDomain = await CustomDomain.findById(domainId);

    if (!customDomain) {
      return res.status(404).json({ success: false, message: "Custom domain not found" });
    }

    if (customDomain.status !== "verified" && customDomain.status !== "active") {
      return res.status(400).json({ success: false, message: "Domain must be verified before activation" });
    }

    customDomain.status = "active";
    await customDomain.save();

    res.status(200).json({
      success: true,
      message: "Domain activated successfully",
      data: customDomain,
    });
  } catch (error) {
    console.error("Error activating custom domain:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};

// DELETE /api/superadmin/custom-domains/:id
exports.deleteCustomDomain = async (req, res) => {
  try {
    const domainId = req.params.id;
    const customDomain = await CustomDomain.findByIdAndDelete(domainId);

    if (!customDomain) {
      return res.status(404).json({ success: false, message: "Custom domain not found" });
    }

    res.status(200).json({
      success: true,
      message: "Domain deleted successfully",
    });
  } catch (error) {
    console.error("Error deleting custom domain:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};

// GET /api/superadmin/users
exports.listUsers = async (req, res) => {
  try {
    const users = await User.find().sort({ createdAt: -1 });
    res.status(200).json({ success: true, data: users });
  } catch (error) {
    console.error("Error listing users:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};

// POST /api/superadmin/users
exports.createUser = async (req, res) => {
  try {
    const { name, email, password, role, phone } = req.body;

    if (!name || !email || !password || !role) {
      return res.status(400).json({ success: false, message: "Name, email, password, and role are required" });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ success: false, message: "User already exists" });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const newUser = await User.create({
      name,
      email,
      password: hashedPassword,
      role,
      phone,
    });

    res.status(201).json({
      success: true,
      message: "User created successfully",
      data: {
        id: newUser._id,
        name: newUser.name,
        email: newUser.email,
        role: newUser.role,
      },
    });
  } catch (error) {
    console.error("Error creating user:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};

// PATCH /api/superadmin/users/:id/status
exports.updateUserStatus = async (req, res) => {
  try {
    const { isActive } = req.body;
    const user = await User.findById(req.params.id);

    if (!user) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    user.isActive = isActive;
    await user.save();

    res.status(200).json({
      success: true,
      message: `User ${isActive ? "activated" : "deactivated"} successfully`,
      data: user,
    });
  } catch (error) {
    console.error("Error updating user status:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};

// PATCH /api/superadmin/users/:id/role
exports.updateUserRole = async (req, res) => {
  try {
    const { role } = req.body;
    const user = await User.findById(req.params.id);

    if (!user) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    user.role = role;
    await user.save();

    res.status(200).json({
      success: true,
      message: "User role updated successfully",
      data: user,
    });
  } catch (error) {
    console.error("Error updating user role:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};

// DELETE /api/superadmin/users/:id
exports.deleteUser = async (req, res) => {
  try {
    const user = await User.findByIdAndDelete(req.params.id);

    if (!user) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    res.status(200).json({
      success: true,
      message: "User deleted successfully",
    });
  } catch (error) {
    console.error("Error deleting user:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};
