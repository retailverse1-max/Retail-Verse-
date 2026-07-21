require("dotenv").config();
const app = require("./app");
const connectDB = require("./config/db");

const PORT = process.env.PORT || 5000;

connectDB().then(async () => {
  try {
    const Business = require("./models/Business");
    const businesses = await Business.find({ $or: [{ businessId: null }, { businessId: { $exists: false } }] });
    if (businesses.length > 0) {
      console.log(`Auto-Repair: Found ${businesses.length} businesses with missing IDs. Fixing...`);
      for (const b of businesses) {
        const random = Math.floor(100000 + Math.random() * 900000);
        b.businessId = `RV-${random}`;
        await b.save();
      }
      console.log("Auto-Repair: All businesses fixed.");
    }
  } catch (err) {
    console.error("Auto-Repair Failed:", err.message);
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});