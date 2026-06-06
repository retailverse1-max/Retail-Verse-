const mongoose = require('mongoose');
require('dotenv').config();
const User = require('./models/User'); // Assuming this exists

async function check() {
  await mongoose.connect(process.env.MONGO_URI);
  const users = await mongoose.connection.db.collection('users').find({ email: /sumit/i }).toArray();
  console.log(JSON.stringify(users.map(u => ({ email: u.email, subscriptionPlan: u.subscriptionPlan, subscriptionExpiry: u.subscriptionExpiry })), null, 2));
  process.exit(0);
}
check();
