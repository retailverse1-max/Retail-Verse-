const express = require("express");
const { createTicket, getSupportStats, getRecentTickets, updateTicketStatus, deleteTicket } = require("../controllers/supportController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.post(["/tickets", "/ticket"], protect, createTicket);
router.get(["/tickets/stats", "/stats"], protect, getSupportStats);
router.get("/tickets", protect, getRecentTickets);
router.put(["/tickets/:id", "/ticket/:id"], protect, updateTicketStatus);
router.delete(["/tickets/:id", "/ticket/:id"], protect, deleteTicket);

module.exports = router;
