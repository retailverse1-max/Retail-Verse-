const Category = require("../models/Category");

const getCategories = async (req, res) => {
  try {
    const filter = { isDeleted: false };
    if (req.user && req.user.role !== "super_admin") {
      filter.clientId = req.user.clientId || req.user._id;
    } else {
      const bId = req.query.businessId || req.headers["x-client-id"];
      if (bId) filter.clientId = bId;
    }
    const categories = await Category.find(filter).sort({ createdAt: -1 });

    res.json({
      message: "Categories fetched successfully",
      data: categories,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const getCategoryById = async (req, res) => {
  try {
    const category = await Category.findOne({ _id: req.params.id, isDeleted: false });
    if (!category) {
      return res.status(404).json({ message: "Category not found" });
    }
    res.json({
      message: "Category fetched successfully",
      data: category,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const createCategory = async (req, res) => {
  try {
    let clientId = req.user?.clientId || req.user?._id;
    if (req.user && req.user.role === "super_admin") {
      const bId = req.query.businessId || req.headers["x-client-id"];
      if (bId) clientId = bId;
    }
    const storeId = req.user?.storeId || "default";

    const categoryData = {
      ...req.body,
      clientId,
      storeId,
    };
    
    const category = await Category.create(categoryData);

    res.status(201).json({
      message: "Category created successfully",
      data: category,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const updateCategory = async (req, res) => {
  try {
    const category = await Category.findOneAndUpdate(
      { _id: req.params.id, isDeleted: false },
      req.body,
      { new: true, runValidators: true }
    );

    if (!category) {
      return res.status(404).json({ message: "Category not found" });
    }

    res.json({
      message: "Category updated successfully",
      data: category,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const mongoose = require("mongoose");
const Product = require("../models/Product");

const deleteCategory = async (req, res) => {
  try {
    const { id } = req.params;
    let category = null;

    if (mongoose.Types.ObjectId.isValid(id)) {
      category = await Category.findByIdAndUpdate(
        id,
        { isDeleted: true },
        { new: true }
      );
    }

    const cleanName = id.replace(/^virtual_/, '').replace(/_/g, ' ').trim();
    if (!category && cleanName) {
      category = await Category.findOneAndUpdate(
        { name: new RegExp(`^${cleanName}$`, 'i'), isDeleted: false },
        { isDeleted: true },
        { new: true }
      );
    }

    const categoryName = category ? category.name : cleanName;
    if (categoryName) {
      const filter = {
        category: new RegExp(`^${categoryName.trim()}$`, 'i'),
      };
      if (req.user && req.user.clientId) {
        filter.clientId = req.user.clientId;
      }
      await Product.deleteMany(filter);
    }

    res.status(204).send();
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = {
  getCategories,
  getCategoryById,
  createCategory,
  updateCategory,
  deleteCategory,
};
