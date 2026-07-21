const express = require("express");
const { createTicket, getSupportStats, getRecentTickets, updateTicketStatus, deleteTicket } = require("../controllers/supportController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/ticket", protect, createTicket);
router.get("/stats", protect, getSupportStats);
router.get("/tickets", protect, getRecentTickets);
router.put("/ticket/:id", protect, updateTicketStatus);
router.delete("/ticket/:id", protect, deleteTicket);

module.exports = router;
