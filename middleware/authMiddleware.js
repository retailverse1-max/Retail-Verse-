const jwt = require("jsonwebtoken");
const User = require("../models/User");
const Business = require("../models/Business");

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

    // Auto-associate a Business if user does not have one, and role is not super_admin
    if (!user.clientId && user.role !== "super_admin") {
      let business = await Business.findOne({ ownerEmail: user.email });
      if (!business) {
        business = await Business.create({
          businessName: `${user.name}'s Business`,
          ownerName: user.name,
          ownerEmail: user.email,
          phone: user.phone || "",
        });
      }
      user.clientId = business._id;
      await user.save();
    }

    req.user = user;
    next();
  } catch (error) {
    res.status(401).json({ message: "Invalid token" });
  }
};
const superAdminOnly = (req, res, next) => {
  if (req.user && req.user.role === "super_admin") {
    next();
  } else {
    res.status(403).json({ success: false, message: "Forbidden. Super admin only." });
  }
};

module.exports = { protect, superAdminOnly };