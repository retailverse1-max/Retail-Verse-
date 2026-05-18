const express = require("express");
const { createTicket, getSupportStats, getRecentTickets } = require("../controllers/supportController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/ticket", protect, createTicket);
router.get("/stats", protect, getSupportStats);
router.get("/tickets", protect, getRecentTickets);

module.exports = router;
