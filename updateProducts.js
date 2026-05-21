const mongoose = require('mongoose');
require('dotenv').config();
const connectDB = require('./config/db');
const Product = require('./models/Product');
const User = require('./models/User');

async function fix() {
  await connectDB();
  const admin = await User.findOne({ role: 'admin' });
  if (!admin) {
    console.log("No admin found");
    process.exit(1);
  }
  const clientId = admin.clientId || admin._id;
  console.log("Admin clientId:", clientId);
  
  const res = await Product.updateMany(
    { $or: [{ clientId: null }, { clientId: { $exists: false } }] },
    { $set: { clientId: clientId } }
  );
  console.log("Updated products:", res.modifiedCount);
  process.exit(0);
}
fix().catch(console.error);
