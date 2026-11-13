const jwt = require("jsonwebtoken");
const User = require("../models/User");

const protect = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ message: "Not authorized" });
    }

    const token = authHeader.split(" ")[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const user = await User.findById(decoded.id).select("-password");

    if (!user) {
      return res.status(401).json({ message: "User not found" });
    }

    req.user = user;
    if (!user.clientId && user.role !== 'super_admin') {
      const Business = require("../models/Business");
      let biz = await Business.findOne({ ownerEmail: user.email });
      if (!biz) {
        biz = await Business.create({
          businessName: `${user.name || 'My'}'s Store`,
          ownerName: user.name || 'Store Owner',
          ownerEmail: user.email,
          status: 'active',
          subscriptionPlan: 'trial',
        });
      }
      user.clientId = biz._id;
      await user.save().catch(() => {});
    }
    // Attach clientId from JWT payload (or fallback to DB) for all users
    req.user.clientId = decoded.clientId || user.clientId;
    if (req.user.role === 'super_admin' && req.headers['x-client-id']) {
      req.user.originalRole = 'super_admin';
      req.user.role = 'admin';
      // Keep existing fallback only if JWT didn't provide clientId
      req.user.clientId = req.user.clientId || req.headers['x-client-id'];
    }
    next();
  } catch (error) {
    res.status(401).json({ message: "Invalid token" });
  }
};
const superAdminOnly = (req, res, next) => {
  if (req.user && (req.user.role === "super_admin" || req.user.originalRole === "super_admin")) {
    next();
  } else {
    res.status(403).json({ success: false, message: "Forbidden. Super admin only." });
  }
};

module.exports = { protect, superAdminOnly };