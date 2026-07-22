const express = require("express");
const { loginUser, googleLogin, registerUser, phoneLogin, updateFcmToken, forgotPassword, resetPassword, changePassword, updateProfile, deleteProfile } = require("../controllers/authController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/login", loginUser);
router.post("/google-login", googleLogin);
router.post("/register", registerUser);
router.post("/phone-login", phoneLogin);
router.post("/update-fcm-token", protect, updateFcmToken);
router.post("/forgot-password", forgotPassword);
router.post("/reset-password", resetPassword);
router.post("/change-password", protect, changePassword);
router.patch("/me", protect, updateProfile);
router.delete("/me", protect, deleteProfile);

module.exports = router;