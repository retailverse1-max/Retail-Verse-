const mongoose = require("mongoose");
const SubscriptionPlan = require("./models/SubscriptionPlan");
require("dotenv").config();

mongoose.connect(process.env.MONGO_URI || "mongodb://127.0.0.1:27017/omnicommerce")
  .then(async () => {
    console.log("Connected to MongoDB.");
    const plans = await SubscriptionPlan.find();
    console.log("Subscription plans in DB:", JSON.stringify(plans, null, 2));
    mongoose.connection.close();
  })
  .catch(err => {
    console.error("DB connection error:", err);
  });
