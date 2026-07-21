const mongoose = require('mongoose');
require('dotenv').config();
const User = require('./models/User'); 
const Business = require('./models/Business');

async function fix() {
  await mongoose.connect(process.env.MONGO_URI);
  const user = await User.findOne({ email: /sumit/i });
  if (!user) {
    console.log("User not found");
    process.exit(1);
  }
  
  if (user.clientId) {
    const business = await Business.findById(user.clientId);
    if (business) {
      business.subscriptionPlan = "Plus";
      business.subscriptionStatus = "active";
      const expiry = new Date();
      expiry.setDate(expiry.getDate() + 30);
      business.subscriptionExpiry = expiry;
      await business.save();
      console.log("Business successfully updated to Plus for 30 days");
    } else {
      console.log("Business not found for user clientId:", user.clientId);
    }
  } else {
    console.log("User has no clientId");
  }
  process.exit(0);
}
fix();
