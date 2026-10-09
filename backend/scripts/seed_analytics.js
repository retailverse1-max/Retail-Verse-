const mongoose = require("mongoose");
const Order = require("./models/Order");
const Business = require("./models/Business");
const User = require("./models/User");
const dotenv = require("dotenv");

dotenv.config();

const seed = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log("Connected to DB for seeding...");

    const businesses = await Business.find();
    if (businesses.length === 0) {
      console.log("No businesses found. Please create some first.");
      process.exit(0);
    }

    const admin = await User.findOne({ role: "superadmin" });
    if (!admin) {
      console.log("No superadmin found.");
      process.exit(0);
    }

    console.log("Deleting old orders...");
    await Order.deleteMany({});

    console.log("Seeding new orders for last 30 days...");
    const orders = [];
    const now = new Date();

    for (let i = 0; i < 100; i++) {
      const biz = businesses[Math.floor(Math.random() * businesses.length)];
      const daysAgo = Math.floor(Math.random() * 30);
      const date = new Date();
      date.setDate(now.getDate() - daysAgo);

      orders.push({
        orderId: `ORD-${Math.random().toString(36).substr(2, 9).toUpperCase()}`,
        channel: "pos",
        items: [{ productId: new mongoose.Types.ObjectId(), name: "Test Product", qty: 1, price: 100, total: 100 }],
        total: Math.floor(Math.random() * 5000) + 500,
        paymentMethod: "cash",
        paymentStatus: "paid",
        status: "completed",
        createdBy: admin._id,
        clientId: biz._id,
        createdAt: date
      });
    }

    await Order.insertMany(orders);
    console.log("Seeded 100 orders successfully.");
    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
};

seed();
