const mongoose = require('mongoose');
const Business = require('./models/Business');
require('dotenv').config();

async function fixBusinesses() {
  try {
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/omnicommerce');
    console.log('Connected to MongoDB');

    const businesses = await Business.find({ $or: [{ businessId: null }, { businessId: { $exists: false } }] });
    console.log(`Found ${businesses.length} businesses to fix`);

    for (const b of businesses) {
      const random = Math.floor(100000 + Math.random() * 900000);
      b.businessId = `RV-${random}`;
      await b.save();
      console.log(`Fixed business: ${b.businessName} -> ${b.businessId}`);
    }

    console.log('Finished fixing businesses');
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

fixBusinesses();
