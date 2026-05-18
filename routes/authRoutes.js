const express = require("express");
const { loginUser, googleLogin } = require("../controllers/authController");

const router = express.Router();

router.post("/login", loginUser);
router.post("/google-login", googleLogin);

module.exports = router;