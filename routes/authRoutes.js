const express = require("express");
const { loginUser, googleLogin, registerUser } = require("../controllers/authController");

const router = express.Router();

router.post("/login", loginUser);
router.post("/google-login", googleLogin);
router.post("/register", registerUser);

module.exports = router;