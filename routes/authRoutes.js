const express = require("express");
const { loginUser, googleLogin, registerUser, phoneLogin } = require("../controllers/authController");

const router = express.Router();

router.post("/login", loginUser);
router.post("/google-login", googleLogin);
router.post("/register", registerUser);
router.post("/phone-login", phoneLogin);

module.exports = router;