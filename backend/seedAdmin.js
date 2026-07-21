require("dotenv").config();
const bcrypt = require("bcryptjs");
const connectDB = require("./config/db");
const User = require("./models/User");

const seedAdmin = async () => {
  try {
    await connectDB();

    const existing = await User.findOne({ email: "admin@pos.com" });
    if (existing) {
      console.log("Admin already exists");
      process.exit();
    }

    const hashedPassword = await bcrypt.hash("123456", 10);

    await User.create({
      name: "Admin",
      email: "admin@pos.com",
      password: hashedPassword,
      role: "admin",
      storeId: "main-store",
    });

    console.log("Admin created successfully");
    process.exit();
  } catch (error) {
    console.error("Seed error:", error.message);
    process.exit(1);
  }
};

seedAdmin();