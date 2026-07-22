const mongoose = require('mongoose');
const SubscriptionPlan = require('./models/SubscriptionPlan');

const uri = "mongodb+srv://Omni12345Secure:HexervePOS2026@cluster0.fxylakb.mongodb.net/omnicommerce?retryWrites=true&w=majority&appName=Cluster0";

async function fixDatabaseBug() {
  await mongoose.connect(uri);
  console.log("Connected to Cloud MongoDB!");

  try {
    // 1. Drop the bad index that is blocking plan creation
    console.log("Dropping the old blocking index...");
    await SubscriptionPlan.collection.dropIndex("code_1_billingPeriod_1");
    console.log("Successfully dropped index!");
  } catch (error) {
    console.log("Index might already be dropped or not found. Ignoring error.");
  }

  // 2. Now properly create/update the plans (including Premium)
  console.log("Updating Plan Limits...");
  await SubscriptionPlan.updateOne({ name: "Premium" }, { $set: { maxUsers: 999999, price: 4999 } }, { upsert: true });
  await SubscriptionPlan.updateOne({ name: "Plus" }, { $set: { maxUsers: 20, price: 1999 } }, { upsert: true });
  await SubscriptionPlan.updateOne({ name: "Basic" }, { $set: { maxUsers: 4, price: 999 } }, { upsert: true });

  console.log("Database fixed completely! Premium plan now exists with 999999 limit.");
  process.exit();
}

fixDatabaseBug();
