const express = require("express");
const { resolveDomain } = require("../controllers/publicController");

const router = express.Router();

router.get("/resolve-domain", resolveDomain);

module.exports = router;
