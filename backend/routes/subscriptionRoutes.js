const express = require("express");
const { getPlans, upgradeSubscription } = require("../controllers/subscriptionController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.get("/plans", protect, getPlans);
router.post("/upgrade", protect, upgradeSubscription);

module.exports = router;
