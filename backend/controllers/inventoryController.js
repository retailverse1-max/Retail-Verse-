const Product = require("../models/Product");
const InventoryLog = require("../models/InventoryLog");

const getInventory = async (req, res) => {
  try {
    const filter = { isActive: true };
    if (req.user && req.user.role !== "super_admin") {
      filter.clientId = req.user.clientId;
    }
    const products = await Product.find(filter).sort({ createdAt: -1 });

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
    const filter = {
      isActive: true,
      stock: { $lte: 10 },
    };
    if (req.user && req.user.role !== "super_admin") {
      filter.clientId = req.user.clientId;
    }
    const products = await Product.find(filter).sort({ stock: 1 });

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

const quickInward = async (req, res) => {
  try {
    const { barcode, productId, quantity, costPrice, batchNo, expiryDate, supplierName } = req.body;

    if (!quantity || Number(quantity) <= 0) {
      return res.status(400).json({ message: "Valid inward quantity is required" });
    }

    const filter = {};
    if (productId) {
      filter._id = productId;
    } else if (barcode) {
      filter.barcode = String(barcode).trim();
    } else {
      return res.status(400).json({ message: "Either productId or barcode is required" });
    }

    if (req.user && req.user.clientId) {
      filter.clientId = req.user.clientId;
    }

    const product = await Product.findOne(filter);
    if (!product) {
      return res.status(404).json({
        success: false,
        notFound: true,
        message: "Product not found for inwarding",
        barcode,
      });
    }

    const beforeStock = product.stock || 0;
    const inwardQty = Number(quantity);
    const afterStock = beforeStock + inwardQty;

    product.stock = afterStock;
    if (costPrice && Number(costPrice) > 0) {
      product.cost = Number(costPrice);
    }
    await product.save();

    const referenceParts = [];
    if (batchNo) referenceParts.push(`Batch: ${batchNo}`);
    if (expiryDate) referenceParts.push(`Exp: ${expiryDate}`);
    if (supplierName) referenceParts.push(`Supplier: ${supplierName}`);
    const referenceId = referenceParts.length > 0 ? referenceParts.join(" | ") : "Shipment Inward";

    const log = await InventoryLog.create({
      productId: product._id,
      type: "purchase",
      quantity: inwardQty,
      beforeStock,
      afterStock,
      referenceId,
    });

    res.status(200).json({
      success: true,
      message: `Successfully inwarded ${inwardQty} units of ${product.name}`,
      data: {
        productId: product._id,
        name: product.name,
        barcode: product.barcode,
        inwardQuantity: inwardQty,
        beforeStock,
        afterStock,
        logId: log._id,
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
  quickInward,
};