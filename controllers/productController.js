const Product = require("../models/Product");

const getProducts = async (req, res) => {
  try {
    const filter = {};
    if (req.user && req.user.clientId) {
      filter.clientId = req.user.clientId;
    }
    const products = await Product.find(filter).sort({ createdAt: -1 });

    res.json({
      message: "Products fetched successfully",
      data: products,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const getProductById = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      return res.status(404).json({ message: "Product not found" });
    }
    res.json({
      message: "Product fetched successfully",
      data: product,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const Business = require("../models/Business");
const SubscriptionPlan = require("../models/SubscriptionPlan");

const createProduct = async (req, res) => {
  try {
    // ClientId is always supplied by the JWT and attached by auth middleware
    const clientId = req.user?.clientId;
    if (!clientId) {
      return res.status(400).json({ message: "Client ID missing in token" });
    }
    
    // Enforce Product Limit based on Subscription
    if (clientId) {
      const business = await Business.findById(clientId);
      if (business) {
        const planName = business.subscriptionPlan || "Basic";
        const plan = await SubscriptionPlan.findOne({ name: planName });
        const maxProducts = plan ? plan.maxProducts : 100;

        const currentProducts = await Product.countDocuments({ clientId });
        if (currentProducts >= maxProducts) {
          return res.status(403).json({ 
            message: `Product limit reached for ${planName} plan. Please upgrade to add more products.` 
          });
        }
      }
    }

    const productData = {
      ...req.body,
      clientId,
    };
    if (req.body.imageBase64) {
      productData.imageUrl = req.body.imageBase64;
    }
    const product = await Product.create(productData);

    res.status(201).json({
      message: "Product created successfully",
      data: product,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const updateProduct = async (req, res) => {
  try {
    const updateData = { ...req.body };
    if (req.body.imageBase64) {
      updateData.imageUrl = req.body.imageBase64;
    }
    const product = await Product.findByIdAndUpdate(req.params.id, updateData, {
      new: true,
      runValidators: true,
    });

    if (!product) {
      return res.status(404).json({ message: "Product not found" });
    }

    res.json({
      message: "Product updated successfully",
      data: product,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const deleteProduct = async (req, res) => {
  try {
    const product = await Product.findByIdAndDelete(req.params.id);
    if (!product) {
      return res.status(404).json({ message: "Product not found" });
    }

    res.status(204).send();
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = {
  getProducts,
  getProductById,
  createProduct,
  updateProduct,
  deleteProduct,
};