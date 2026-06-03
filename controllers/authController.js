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

    let subscriptionPlan = "free";
    let subscriptionStatus = "active";
    let subscriptionExpiry = null;

    if (user.clientId) {
      const biz = await Business.findById(user.clientId);
      if (biz) {
        subscriptionPlan = biz.subscriptionPlan || "free";
        subscriptionStatus = biz.subscriptionStatus || "active";
        subscriptionExpiry = biz.subscriptionExpiry;
      }
    }

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
        subscriptionPlan,
        subscriptionStatus,
        subscriptionExpiry,
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

    let subscriptionPlan = "free";
    let subscriptionStatus = "active";
    let subscriptionExpiry = null;

    if (user.clientId) {
      const biz = await Business.findById(user.clientId);
      if (biz) {
        subscriptionPlan = biz.subscriptionPlan || "free";
        subscriptionStatus = biz.subscriptionStatus || "active";
        subscriptionExpiry = biz.subscriptionExpiry;
      }
    }

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
        subscriptionPlan,
        subscriptionStatus,
        subscriptionExpiry,
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

    // Calculate 14 days from now for the trial
    const trialExpiry = new Date();
    trialExpiry.setDate(trialExpiry.getDate() + 14);

    // Create a Business for this new admin user so they can manage customers, products, orders
    const business = await Business.create({
      businessName: `${name}'s Business`,
      ownerName: name,
      ownerEmail: email,
      phone: phone || "",
      status: "active",
      subscriptionPlan: "trial",
      subscriptionStatus: "active",
      subscriptionExpiry: trialExpiry,
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
          subscriptionPlan: business.subscriptionPlan,
          subscriptionStatus: business.subscriptionStatus,
          subscriptionExpiry: business.subscriptionExpiry,
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

    let subscriptionPlan = "free";
    let subscriptionStatus = "active";
    let subscriptionExpiry = null;

    if (user.clientId) {
      const biz = await Business.findById(user.clientId);
      if (biz) {
        subscriptionPlan = biz.subscriptionPlan || "free";
        subscriptionStatus = biz.subscriptionStatus || "active";
        subscriptionExpiry = biz.subscriptionExpiry;
      }
    }

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
        subscriptionPlan,
        subscriptionStatus,
        subscriptionExpiry,
      },
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const updateFcmToken = async (req, res) => {
  try {
    const { fcmToken } = req.body;
    if (!fcmToken) {
      return res.status(400).json({ message: "fcmToken is required" });
    }
    
    // Update the FCM token for the currently logged in user
    req.user.fcmToken = fcmToken;
    await req.user.save();
    
    res.status(200).json({ success: true, message: "FCM token updated successfully" });
  } catch (error) {
    console.error("Update FCM Token Error:", error);
    res.status(500).json({ message: "Server error" });
  }
};

const { sendEmail } = require("../services/emailService");

const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ message: "Email is required" });

    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ message: "User not found" });

    // Generate 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expires = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes from now

    user.resetPasswordOtp = otp;
    user.resetPasswordExpires = expires;
    await user.save();

    // Send email
    await sendEmail({
      to: user.email,
      subject: "Retail Verse - Password Reset OTP",
      html: `<div style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto; background-color: #f9f9f9; border-radius: 10px;">
        <h2 style="color: #1E1B4B; text-align: center;">Password Reset Request</h2>
        <p style="color: #333; font-size: 16px;">Hello ${user.name},</p>
        <p style="color: #333; font-size: 16px;">We received a request to reset your Retail Verse password. Here is your One-Time Password (OTP):</p>
        <div style="background-color: #ffffff; padding: 15px; text-align: center; border-radius: 8px; margin: 20px 0; border: 1px solid #ddd;">
          <h1 style="color: #4CAF50; letter-spacing: 5px; margin: 0;">${otp}</h1>
        </div>
        <p style="color: #777; font-size: 14px; text-align: center;">This OTP is valid for 10 minutes. Do not share it with anyone.</p>
      </div>`
    });

    res.json({ message: "OTP sent successfully to your email" });
  } catch (error) {
    console.error("Forgot Password Error:", error);
    res.status(500).json({ message: "Failed to process forgot password request" });
  }
};

const resetPassword = async (req, res) => {
  try {
    const { email, otp, newPassword } = req.body;
    if (!email || !otp || !newPassword) {
      return res.status(400).json({ message: "Email, OTP and new password are required" });
    }

    const user = await User.findOne({ 
      email, 
      resetPasswordOtp: otp,
      resetPasswordExpires: { $gt: Date.now() } // Ensure OTP hasn't expired
    });

    if (!user) {
      return res.status(400).json({ message: "Invalid or expired OTP" });
    }

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    user.resetPasswordOtp = undefined;
    user.resetPasswordExpires = undefined;
    await user.save();

    res.json({ message: "Password reset successful" });
  } catch (error) {
    console.error("Reset Password Error:", error);
    res.status(500).json({ message: "Failed to reset password" });
  }
};

module.exports = { loginUser, googleLogin, registerUser, phoneLogin, updateFcmToken, forgotPassword, resetPassword };