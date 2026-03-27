const Product = require("../models/Product");

const getProducts = async (req, res) => {
  try {
    const products = await Product.find({ isActive: true }).sort({ createdAt: -1 });

    res.json({
      message: "Products fetched successfully",
      data: products,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { getProducts };