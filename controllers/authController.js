const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const User = require("../models/User");
const Business = require("../models/Business");

const loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: "Email and password are required" });
    }

    const user = await User.findOne({ email });

    if (!user || !user.isActive) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const token = jwt.sign(
      { id: user._id, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.json({
      message: "Login successful",
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        storeId: user.storeId,
        clientId: user.clientId,
      },
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const googleLogin = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ message: "Email is required" });

    const user = await User.findOne({ email });
    if (!user || !user.isActive) {
      return res.status(404).json({ message: "User not found or inactive" });
    }

    if (user.role !== "admin" && user.role !== "super_admin") {
      return res.status(403).json({ message: "Only admins can login via Google" });
    }

    const token = jwt.sign(
      { id: user._id, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.json({
      message: "Login successful",
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        storeId: user.storeId,
        clientId: user.clientId,
      },
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const registerUser = async (req, res) => {
  try {
    const { name, email, phone, password } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ message: "Name, email and password are required" });
    }

    const userExists = await User.findOne({ email });
    if (userExists) {
      return res.status(400).json({ message: "User already exists with this email" });
    }

    if (phone) {
      const phoneExists = await User.findOne({ phone });
      if (phoneExists) {
        return res.status(400).json({ message: "User already exists with this phone number" });
      }
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // Create a Business for this new admin user so they can manage customers, products, orders
    const business = await Business.create({
      businessName: `${name}'s Business`,
      ownerName: name,
      ownerEmail: email,
      phone: phone || "",
      status: "active",
      subscriptionPlan: "free",
      subscriptionStatus: "active",
    });

    const user = await User.create({
      name,
      email,
      phone,
      password: hashedPassword,
      role: "admin",
      clientId: business._id,
    });

    if (user) {
      const token = jwt.sign(
        { id: user._id, email: user.email, role: user.role },
        process.env.JWT_SECRET,
        { expiresIn: "7d" }
      );

      res.status(201).json({
        message: "User registered successfully",
        token,
        user: {
          id: user._id,
          name: user.name,
          email: user.email,
          role: user.role,
          storeId: user.storeId,
          clientId: user.clientId,
        },
      });
    } else {
      res.status(400).json({ message: "Invalid user data" });
    }
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const phoneLogin = async (req, res) => {
  try {
    const { phone } = req.body;
    if (!phone) return res.status(400).json({ message: "Phone number is required" });

    // Extract the last 10 digits to ignore country codes like +91
    const numericPhone = phone.replace(/\D/g, ''); 
    let basePhone = numericPhone;
    if (basePhone.length > 10) {
      basePhone = basePhone.slice(-10);
    }
    const phoneRegex = new RegExp(`${basePhone}$`);

    // Pick the most recently created account in case there are duplicates from before the duplicate check was added
    const user = await User.findOne({ phone: phoneRegex }).sort({ createdAt: -1 });
    if (!user || !user.isActive) {
      return res.status(404).json({ message: "User not found with this phone number or inactive" });
    }

    const token = jwt.sign(
      { id: user._id, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.json({
      message: "Login successful",
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        storeId: user.storeId,
        clientId: user.clientId,
      },
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { loginUser, googleLogin, registerUser, phoneLogin };