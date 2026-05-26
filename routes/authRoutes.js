const express = require("express");
const { loginUser, googleLogin, registerUser, phoneLogin, updateFcmToken } = require("../controllers/authController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/login", loginUser);
router.post("/google-login", googleLogin);
router.post("/register", registerUser);
router.post("/phone-login", phoneLogin);
router.post("/update-fcm-token", protect, updateFcmToken);

module.exports = router;