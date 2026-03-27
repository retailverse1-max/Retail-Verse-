const Product = require("../models/Product");
const InventoryLog = require("../models/InventoryLog");

const getInventory = async (req, res) => {
  try {
    const products = await Product.find({ isActive: true }).sort({ createdAt: -1 });

    res.json({
      message: "Inventory fetched successfully",
      data: products,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const getLowStockProducts = async (req, res) => {
  try {
    const products = await Product.find({
      isActive: true,
      stock: { $lte: 10 },
    }).sort({ stock: 1 });

    res.json({
      message: "Low stock products fetched successfully",
      data: products,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const adjustStock = async (req, res) => {
  try {
    const { productId, operation, quantity, reason } = req.body;

    if (!productId || !operation || !quantity) {
      return res.status(400).json({
        message: "productId, operation and quantity are required",
      });
    }

    if (!["add", "reduce"].includes(operation)) {
      return res.status(400).json({
        message: "Operation must be add or reduce",
      });
    }

    const product = await Product.findById(productId);

    if (!product) {
      return res.status(404).json({ message: "Product not found" });
    }

    const beforeStock = product.stock;
    let afterStock = beforeStock;

    if (operation === "add") {
      afterStock = beforeStock + Number(quantity);
    } else {
      afterStock = beforeStock - Number(quantity);

      if (afterStock < 0) {
        return res.status(400).json({ message: "Stock cannot go below 0" });
      }
    }

    product.stock = afterStock;
    await product.save();

    await InventoryLog.create({
      productId: product._id,
      type: "adjustment",
      quantity: Number(quantity),
      beforeStock,
      afterStock,
      referenceId: reason || "manual-adjustment",
    });

    res.json({
      message: "Stock adjusted successfully",
      data: {
        productId: product._id,
        productName: product.name,
        beforeStock,
        afterStock,
        operation,
        quantity,
      },
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = {
  getInventory,
  getLowStockProducts,
  adjustStock,
};