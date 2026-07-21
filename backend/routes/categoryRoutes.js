const express = require("express");
const {
  getCategories,
  getCategoryById,
  createCategory,
  updateCategory,
  deleteCategory,
} = require("../controllers/categoryController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.route("/")
  .get(protect, getCategories)
  .post(protect, createCategory);

router.route("/:id")
  .get(protect, getCategoryById)
  .put(protect, updateCategory)
  .delete(protect, deleteCategory);

module.exports = router;
