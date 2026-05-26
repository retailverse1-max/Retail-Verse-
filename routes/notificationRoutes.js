const express = require("express");
const { sendEmailInvoice, getNotifications, markAsRead, broadcastNotification, requestRestock } = require("../controllers/notificationController");
const { protect, superAdminOnly } = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/email", protect, sendEmailInvoice);
router.get("/", protect, getNotifications);
router.put("/read", protect, markAsRead);
router.post("/broadcast", protect, superAdminOnly, broadcastNotification);
router.post("/restock-request", protect, requestRestock);

module.exports = router;
