const express = require("express");
const { createTicket } = require("../controllers/supportController");

const router = express.Router();

router.post("/ticket", createTicket);

module.exports = router;
