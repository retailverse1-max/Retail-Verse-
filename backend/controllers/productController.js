const Product = require("../models/Product");
const shopifyService = require("../marketplace/shopify/shopify.service");
const MarketplaceProductMapping = require("../models/MarketplaceProductMapping");

const getProducts = async (req, res) => {
  try {
    const filter = {};
    if (req.user && req.user.clientId) {
      filter.clientId = req.user.clientId;
    }
    // Fetch products
    const products = await Product.find(filter).sort({ createdAt: -1 }).lean();

    // Fetch mappings for these products to know which platforms they are pushed to
    const mappings = await MarketplaceProductMapping.find({
      productId: { $in: products.map(p => p._id) },
      syncStatus: 'synced' // Only consider successfully synced products
    }).lean();

    // Attach marketplace info to products so the frontend can show icons
    const productsWithMarketplaces = products.map(product => {
      const productMappings = mappings.filter(m => m.productId.toString() === product._id.toString());
      const marketplaces = productMappings.map(m => m.platform);
      return { ...product, marketplaces };
    });

    res.json({
      message: "Products fetched successfully",
      data: productsWithMarketplaces,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const getProductById = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id).lean();
    if (!product) {
      return res.status(404).json({ message: "Product not found" });
    }
    
    const mappings = await MarketplaceProductMapping.find({
      productId: product._id,
      syncStatus: 'synced'
    }).lean();
    
    product.marketplaces = mappings.map(m => m.platform);

    res.json({
      message: "Product fetched successfully",
      data: product,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const getProductByBarcode = async (req, res) => {
  try {
    const { code } = req.params;
    if (!code) {
      return res.status(400).json({ message: "Barcode parameter is required" });
    }

    const filter = { barcode: code.trim() };
    if (req.user && req.user.clientId) {
      filter.clientId = req.user.clientId;
    }

    const product = await Product.findOne(filter).lean();
    if (!product) {
      return res.status(404).json({
        success: false,
        notFound: true,
        message: "Product not found with barcode",
        barcode: code.trim(),
      });
    }

    const mappings = await MarketplaceProductMapping.find({
      productId: product._id,
      syncStatus: "synced",
    }).lean();

    product.marketplaces = mappings.map((m) => m.platform);

    res.json({
      success: true,
      message: "Product found by barcode",
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

    // ── Check Push Toggles ──
    // If user turned on Shopify toggle, push it to Shopify in background
    if (clientId && req.body.pushToShopify === true) {
      shopifyService.checkStatus(clientId).then((isConnected) => {
        if (isConnected) {
          shopifyService.pushProduct(clientId, product._id.toString())
            .then(() => console.log(`✅ Auto-pushed product "${product.name}" to Shopify`))
            .catch((err) => console.error(`⚠️ Shopify push failed for "${product.name}":`, err.message));
        } else {
          console.log(`Shopify toggle was ON but merchant is not connected.`);
        }
      }).catch(() => {});
    }

    // ── Flipkart Push (Requires flipkart.service.js) ──
    if (clientId && req.body.pushToFlipkart === true) {
      // You can add flipkart push logic here similar to Shopify when the Flipkart service is ready
      console.log(`Flipkart push toggle was ON for product: ${product.name}`);
    }

    res.status(201).json({
      message: "Product created successfully",
      data: {
        ...product.toObject(),
        marketplaces: [] // Initially empty until background push completes
      },
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
  getProductByBarcode,
  createProduct,
  updateProduct,
  deleteProduct,
};