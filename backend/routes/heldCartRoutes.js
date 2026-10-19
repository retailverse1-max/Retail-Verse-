const express = require("express");
const router = express.Router();
const {
  getHeldCarts,
  createHeldCart,
  deleteHeldCart,
} = require("../controllers/heldCartController");
const { protect } = require("../middleware/authMiddleware");

router.get("/", protect, getHeldCarts);
router.post("/", protect, createHeldCart);
router.delete("/:id", protect, deleteHeldCart);

module.exports = router;
