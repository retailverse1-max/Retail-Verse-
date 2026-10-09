const mongoose = require("mongoose");
const User = require("./models/User");
const Business = require("./models/Business");
require("dotenv").config();

async function upgradeUser() {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log("Connected to MongoDB.");

        const user = await User.findOne({ email: { $regex: /sumit@gmail/i } });
        if (!user) {
            console.log("User sumit@gmail not found.");
            process.exit(1);
        }

        console.log(`Found user: ${user.email} (Role: ${user.role})`);

        if (!user.clientId) {
            console.log("User does not have an associated Business (clientId).");
            process.exit(1);
        }

        const business = await Business.findById(user.clientId);
        if (!business) {
            console.log("Business not found for this user.");
            process.exit(1);
        }

        console.log(`Found business: ${business.businessName}. Current plan: ${business.subscriptionPlan}`);

        // Update business subscription
        business.subscriptionPlan = "lifetime"; // or premium
        business.subscriptionStatus = "active";
        
        // Give 100 years of access
        const expiryDate = new Date();
        expiryDate.setFullYear(expiryDate.getFullYear() + 100);
        business.subscriptionExpiry = expiryDate;

        await business.save();

        console.log(`✅ Success! Updated subscription plan to "lifetime" with expiry ${expiryDate.toISOString()}.`);
        process.exit(0);

    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

upgradeUser();
