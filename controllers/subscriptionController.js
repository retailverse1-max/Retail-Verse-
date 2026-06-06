const SubscriptionPlan = require("../models/SubscriptionPlan");
const Business = require("../models/Business");
const User = require("../models/User");

// Initialize dummy plans if they don't exist
const initializeDummyPlans = async () => {
  try {
    // Auto-migrate old names to new names
    await SubscriptionPlan.updateMany({ name: "Pro" }, { $set: { name: "Plus" } });
    await SubscriptionPlan.updateMany({ name: "Enterprise" }, { $set: { name: "Premium" } });
    await SubscriptionPlan.updateMany({ name: "Basic" }, { $set: { price: 1 } });

    const defaultPlans = [
      {
        name: "Basic",
        price: 999,
        billingCycle: "monthly",
        features: ["Up to 100 Products", "3 Admin Users", "Basic POS", "Email Support"],
        isActive: true,
        maxProducts: 100,
        maxUsers: 3
      },
      {
        name: "Plus",
        price: 1999,
        billingCycle: "monthly",
        features: ["Unlimited Products", "10 Admin Users", "Advanced POS & Inventory", "Priority Support", "Analytics"],
        isActive: true,
        maxProducts: 999999,
        maxUsers: 10
      },
      {
        name: "Premium",
        price: 4999,
        billingCycle: "monthly",
        features: ["Unlimited Everything", "Custom Domain", "Dedicated Account Manager", "Custom Integrations", "24/7 Support"],
        isActive: true,
        maxProducts: 9999999,
        maxUsers: 999
      }
    ];

    for (const planData of defaultPlans) {
      const exists = await SubscriptionPlan.findOne({ name: planData.name });
      if (!exists) {
        await SubscriptionPlan.create(planData);
        console.log(`Seeded missing subscription plan: ${planData.name}`);
      }
    }
  } catch (err) {
    console.error("Error initializing dummy plans:", err);
  }
};

// Call initialization
initializeDummyPlans();

exports.getPlans = async (req, res) => {
  try {
    const plans = await SubscriptionPlan.find({ isActive: true });
    res.status(200).json(plans);
  } catch (error) {
    console.error("Get Plans Error:", error);
    res.status(500).json({ message: "Failed to fetch subscription plans" });
  }
};

exports.upgradeSubscription = async (req, res) => {
  try {
    const { planId } = req.body;
    const clientId = req.user.clientId; // Assuming standard tenant id

    if (!clientId) {
      return res.status(400).json({ message: "No client/business ID found for user" });
    }

    const plan = await SubscriptionPlan.findById(planId);
    if (!plan) {
      return res.status(404).json({ message: "Plan not found" });
    }

    // Update business
    const business = await Business.findById(clientId);
    if (!business) {
      return res.status(404).json({ message: "Business not found" });
    }

    // Set expiration to +30 days from now
    const expiry = new Date();
    expiry.setDate(expiry.getDate() + 30);

    business.subscriptionPlan = plan.name;
    business.subscriptionStatus = "active";
    business.subscriptionExpiry = expiry;
    await business.save();

    res.status(200).json({ 
      message: "Subscription upgraded successfully", 
      business: {
        subscriptionPlan: business.subscriptionPlan,
        subscriptionStatus: business.subscriptionStatus,
        subscriptionExpiry: business.subscriptionExpiry
      }
    });
  } catch (error) {
    console.error("Upgrade Subscription Error:", error);
    res.status(500).json({ message: "Failed to upgrade subscription" });
  }
};
