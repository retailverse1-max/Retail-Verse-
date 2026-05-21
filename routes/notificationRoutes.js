const express = require("express");
const { sendEmailInvoice } = require("../controllers/notificationController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/email", protect, sendEmailInvoice);

module.exports = router;
