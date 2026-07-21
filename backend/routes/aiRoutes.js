const express = require("express");
const router = express.Router();
const multer = require("multer");
const { scanProductImage } = require("../controllers/aiController");

// Configure multer for memory storage
const storage = multer.memoryStorage();
const upload = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB limit
});

// POST /api/ai/product-scan
// Expects multipart/form-data with an "image" field
router.post("/product-scan", upload.single("image"), scanProductImage);

module.exports = router;
