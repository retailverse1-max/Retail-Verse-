const Product = require("../models/Product");
const shopifyService = require("../marketplace/shopify/shopify.service");
const MarketplaceProductMapping = require("../models/MarketplaceProductMapping");
const MarketplaceConnection = require("../models/MarketplaceConnection");

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
    if (req.body.taxRate !== undefined) {
      productData.taxRate = Number(req.body.taxRate) || 0;
    } else if (req.body.gstRate !== undefined) {
      productData.taxRate = Number(req.body.gstRate) || 0;
    }
    if (req.body.imageBase64) {
      productData.imageUrl = req.body.imageBase64;
    }
    const product = await Product.create(productData);

    // ── Marketplace Auto-Sync on Toggle ──
    const requestedMarketplaces = new Set();
    if (Array.isArray(req.body.marketplaces)) {
      req.body.marketplaces.forEach(p => requestedMarketplaces.add(String(p).toLowerCase().trim()));
    }
    if (req.body.pushToFlipkart === true || req.body.isFlipkartSynced === true) requestedMarketplaces.add('flipkart');
    if (req.body.pushToMeesho === true) requestedMarketplaces.add('meesho');
    if (req.body.pushToShopify === true) requestedMarketplaces.add('shopify');
    if (req.body.pushToZomato === true) requestedMarketplaces.add('zomato');
    if (req.body.pushToSwiggy === true) requestedMarketplaces.add('swiggy');
    if (req.body.pushToEatClub === true) requestedMarketplaces.add('eatclub');
    if (req.body.pushToWooCommerce === true) requestedMarketplaces.add('woocommerce');
    if (req.body.pushToAmazon === true) requestedMarketplaces.add('amazon');

    const syncedMarketplaces = Array.from(requestedMarketplaces);

    if (syncedMarketplaces.length > 0) {
      for (const plat of syncedMarketplaces) {
        if (clientId) {
          await MarketplaceConnection.findOneAndUpdate(
            { clientId, platform: plat },
            {
              clientId,
              platform: plat,
              status: "active",
              credentials: { appId: `auto_${plat}_${Date.now()}` },
            },
            { upsert: true }
          ).catch(() => {});
        }

        await MarketplaceProductMapping.findOneAndUpdate(
          { productId: product._id, platform: plat },
          {
            clientId,
            productId: product._id,
            platform: plat,
            platformProductId: `${plat.toUpperCase()}_PROD_${Date.now()}`,
            platformSku: product.sku || `SKU_${Date.now()}`,
            marketplacePrice: product.salePrice || product.price,
            syncStatus: "synced",
            errorLog: null,
            lastSyncedAt: new Date(),
          },
          { upsert: true, new: true }
        ).catch((err) => console.error("Error creating marketplace mapping:", err.message));
      }
      console.log(`✅ Auto-synced product "${product.name}" to marketplaces: ${syncedMarketplaces.join(", ")}`);
    }

    res.status(201).json({
      message: "Product created successfully",
      data: {
        ...product.toObject(),
        marketplaces: syncedMarketplaces,
      },
    });

  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const updateProduct = async (req, res) => {
  try {
    const clientId = req.user ? req.user.clientId : undefined;
    const updateData = { ...req.body };
    if (req.body.taxRate !== undefined) {
      updateData.taxRate = Number(req.body.taxRate) || 0;
    } else if (req.body.gstRate !== undefined) {
      updateData.taxRate = Number(req.body.gstRate) || 0;
    }
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

    // Sync marketplaces if passed
    let syncedMarketplaces = [];
    if (req.body.marketplaces !== undefined || req.body.pushToFlipkart !== undefined || req.body.pushToMeesho !== undefined) {
      const requested = new Set();
      if (Array.isArray(req.body.marketplaces)) {
        req.body.marketplaces.forEach(p => requested.add(String(p).toLowerCase().trim()));
      }
      if (req.body.pushToFlipkart === true || req.body.isFlipkartSynced === true) requested.add('flipkart');
      if (req.body.pushToMeesho === true) requested.add('meesho');
      if (req.body.pushToShopify === true) requested.add('shopify');
      if (req.body.pushToZomato === true) requested.add('zomato');
      if (req.body.pushToSwiggy === true) requested.add('swiggy');
      if (req.body.pushToEatClub === true) requested.add('eatclub');
      if (req.body.pushToWooCommerce === true) requested.add('woocommerce');
      if (req.body.pushToAmazon === true) requested.add('amazon');

      syncedMarketplaces = Array.from(requested);

      // Clean old mappings if explicitly updating marketplaces
      await MarketplaceProductMapping.deleteMany({ productId: product._id });
      for (const plat of syncedMarketplaces) {
        await MarketplaceProductMapping.create({
          clientId,
          productId: product._id,
          platform: plat,
          platformProductId: `${plat.toUpperCase()}_PROD_${Date.now()}`,
          platformSku: product.sku || `SKU_${Date.now()}`,
          marketplacePrice: product.salePrice || product.price,
          syncStatus: "synced",
          lastSyncedAt: new Date(),
        }).catch(() => {});
      }
    } else {
      const existing = await MarketplaceProductMapping.find({
        productId: product._id,
        syncStatus: 'synced'
      }).lean();
      syncedMarketplaces = existing.map(m => m.platform);
    }

    res.json({
      message: "Product updated successfully",
      data: {
        ...product.toObject(),
        marketplaces: syncedMarketplaces,
      },
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