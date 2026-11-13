const Vendor = require("../models/Vendor");
const VendorAllocation = require("../models/VendorAllocation");
const Product = require("../models/Product");
const { checkAndTriggerVendorAllocation } = require("../services/vendorAllocationService");

const defaultSeedVendors = [
  {
    name: "shreya",
    companyName: "shreya Supplies",
    phone: "6205650658",
    email: "shreya@gmail.com",
    category: "General Supplies",
    address: "Noida",
    gstin: "07AABCU9603R1ZX",
    rating: 5.0,
    isActive: true,
  },
  {
    name: "Metro Wholesale",
    companyName: "Metro Cash & Carry India",
    phone: "+91 91234 56789",
    email: "b2b.metro@wholesalesupply.in",
    category: "FMCG & Beverages",
    address: "Plot 22, Industrial Area Phase II",
    gstin: "07AAACM1234F1Z8",
    rating: 4.7,
    isActive: true,
  },
  {
    name: "Apex Distributors",
    companyName: "Apex Food Logistics Pvt Ltd",
    phone: "+91 98111 22334",
    email: "dispatch@apexlogistics.com",
    category: "Packaged Foods & Dairy",
    address: "Warehouse 4B, Ring Road Logistics Hub",
    gstin: "29ABCDE1234F2Z5",
    rating: 4.8,
    isActive: true,
  },
  {
    name: "Farm Fresh Agro",
    companyName: "Farm Fresh Organic Mandi",
    phone: "+91 94555 66778",
    email: "supply@farmfreshmandi.com",
    category: "Produce & Grains",
    address: "Subzi Mandi Gate 2, Central Depot",
    gstin: "19AAECF5678P1ZQ",
    rating: 4.6,
    isActive: true,
  },
];

/**
 * 1. GET /api/vendors - Get all vendors (seeds default vendors if empty)
 */
const getVendors = async (req, res) => {
  try {
    const clientId = req.user?.clientId;
    const filter = { isActive: true };
    if (clientId) {
      filter.$or = [{ clientId }, { clientId: null }];
    }

    let vendors = await Vendor.find(filter).sort({ createdAt: -1 });

    if (vendors.length === 0) {
      // Seed default vendors
      const seeded = await Vendor.insertMany(
        defaultSeedVendors.map((v) => ({ ...v, clientId }))
      );
      vendors = seeded;
    }

    res.json({
      success: true,
      message: "Vendors fetched successfully",
      data: vendors,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * 2. POST /api/vendors - Add new vendor profile
 */
const createVendor = async (req, res) => {
  try {
    const { name, companyName, phone, email, category, address, gstin } = req.body;
    if (!name || !phone) {
      return res.status(400).json({ success: false, message: "Vendor name and phone are required" });
    }

    const clientId = req.user?.clientId;

    let vendor = await Vendor.findOne({
      name: new RegExp(`^${name.trim()}$`, "i"),
      isActive: true,
      ...(clientId ? { clientId } : {}),
    });

    if (vendor) {
      vendor.companyName = companyName ? companyName.trim() : vendor.companyName;
      vendor.phone = phone.trim();
      vendor.email = email ? email.trim() : vendor.email;
      vendor.category = category ? category.trim() : vendor.category;
      vendor.address = address ? address.trim() : vendor.address;
      vendor.gstin = gstin ? gstin.trim() : vendor.gstin;
      await vendor.save();
    } else {
      vendor = await Vendor.create({
        name: name.trim(),
        companyName: companyName ? companyName.trim() : name.trim(),
        phone: phone.trim(),
        email: email ? email.trim() : "",
        category: category ? category.trim() : "General Supply",
        address: address ? address.trim() : "",
        gstin: gstin ? gstin.trim() : "",
        clientId,
      });
    }

    // Auto-create or link User login account with role 'vendor' so the vendor can log in immediately!
    const vendorEmail = (email && email.trim().length > 0)
      ? email.trim().toLowerCase()
      : `${name.trim().toLowerCase().replace(/[^a-z0-9]/g, "")}@gmail.com`;

    let vendorUser = await User.findOne({ email: vendorEmail });
    if (!vendorUser) {
      const bcrypt = require("bcryptjs");
      const hashedPassword = await bcrypt.hash("12345678", 10);
      vendorUser = await User.create({
        name: name.trim(),
        email: vendorEmail,
        phone: phone ? phone.trim() : undefined,
        password: hashedPassword,
        role: "vendor",
        vendorName: vendor.name,
        vendorId: vendor._id,
        clientId,
      });
    } else {
      vendorUser.role = "vendor";
      vendorUser.vendorName = vendor.name;
      vendorUser.vendorId = vendor._id;
      await vendorUser.save();
    }

    res.status(201).json({
      success: true,
      message: `Vendor "${vendor.name}" created successfully! Login: ${vendorEmail} / 12345678`,
      data: vendor,
      login: {
        email: vendorEmail,
        password: "Default password: 12345678",
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * 3. DELETE /api/vendors/:id - Delete vendor
 */
const deleteVendor = async (req, res) => {
  try {
    const { id } = req.params;
    await Vendor.findByIdAndUpdate(id, { isActive: false });
    res.json({ success: true, message: "Vendor deleted successfully" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * 4. GET /api/vendors/allocation - Get current allocation config
 */
const getAllocation = async (req, res) => {
  try {
    const clientId = req.user?.clientId;
    const { productSku, productId } = req.query;

    const filter = {};
    if (clientId) filter.clientId = clientId;
    if (productSku) filter.productSku = productSku;
    if (productId) filter.productId = productId;

    let allocation = await VendorAllocation.findOne(filter).sort({ updatedAt: -1 });

    if (!allocation) {
      // Find or default to "Grocery" product
      const product = await Product.findOne(
        clientId ? { clientId, isActive: true } : { isActive: true }
      );

      allocation = {
        productName: product ? product.name : "Grocery",
        productSku: product ? product.sku : "RV-134045-3890",
        currentStock: product ? product.stock : 5,
        threshold: 5,
        totalUnitsNeeded: 20,
        splits: [
          {
            vendorName: "shreya",
            units: 10,
            targetDeliveryDate: new Date(Date.now() + 6 * 24 * 60 * 60 * 1000),
            status: "Allocated",
          },
          {
            vendorName: "Metro Wholesale",
            units: 10,
            targetDeliveryDate: new Date(Date.now() + 8 * 24 * 60 * 60 * 1000),
            status: "Allocated",
          },
        ],
        history: [],
      };
    }

    res.json({
      success: true,
      data: allocation,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * 5. POST /api/vendors/allocation - Save/Update Allocation Rule
 */
const saveAllocation = async (req, res) => {
  try {
    const clientId = req.user?.clientId;
    const {
      productId,
      productName,
      productSku,
      threshold,
      totalUnitsNeeded,
      splits,
    } = req.body;

    const filter = {
      productSku: productSku || "RV-134045-3890",
      ...(clientId ? { clientId } : {}),
    };

    let allocation = await VendorAllocation.findOne(filter);

    if (allocation) {
      if (threshold !== undefined) allocation.threshold = Number(threshold);
      if (totalUnitsNeeded !== undefined) allocation.totalUnitsNeeded = Number(totalUnitsNeeded);
      if (productName) allocation.productName = productName;
      if (productId) allocation.productId = productId;
      if (splits && Array.isArray(splits)) allocation.splits = splits;
      await allocation.save();
    } else {
      allocation = await VendorAllocation.create({
        productId,
        productName: productName || "Grocery",
        productSku: productSku || "RV-134045-3890",
        threshold: threshold !== undefined ? Number(threshold) : 5,
        totalUnitsNeeded: totalUnitsNeeded !== undefined ? Number(totalUnitsNeeded) : 20,
        splits: splits || [],
        clientId,
      });
    }

    // 2. Check if current stock is already at or below threshold (e.g. <= 5)
    let product = null;
    if (productId) product = await Product.findById(productId);
    if (!product && productSku) product = await Product.findOne({ sku: productSku });
    if (!product && productName) product = await Product.findOne({ name: productName });

    const currentStock = product ? (product.stock !== undefined ? product.stock : 5) : 5;
    const activeThreshold = Number(threshold !== undefined ? threshold : (allocation.threshold || 5));

    let autoTriggered = false;
    if (currentStock <= activeThreshold) {
      await checkAndTriggerVendorAllocation({
        clientId,
        product: product || {
          _id: null,
          name: productName || "Grocery",
          sku: productSku || "RV-134045-3890",
          stock: currentStock,
        },
        currentStock,
        triggeredBy: "admin_save_low_stock",
      });
      autoTriggered = true;
    }

    res.json({
      success: true,
      message: autoTriggered
        ? `Vendor allocation settings saved and replenishment alert dispatched to vendors (Stock: ${currentStock} <= Threshold: ${activeThreshold})`
        : "Vendor allocation settings saved successfully",
      data: allocation,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * 6. POST /api/vendors/allocation/notify - MANUAL NOTIFICATION BUTTON TRIGGER
 * Saves changes and immediately broadcasts replenishment notification with Read-Receipt tracking
 */
const manualNotifyVendors = async (req, res) => {
  try {
    const clientId = req.user?.clientId;
    const {
      productId,
      productName = "Grocery",
      productSku = "RV-134045-3890",
      threshold = 5,
      totalUnitsNeeded = 20,
      splits = [],
    } = req.body;

    // 1. Save or update settings first
    const filter = {
      productSku,
      ...(clientId ? { clientId } : {}),
    };

    let allocation = await VendorAllocation.findOne(filter);
    if (allocation) {
      allocation.threshold = Number(threshold);
      allocation.totalUnitsNeeded = Number(totalUnitsNeeded);
      allocation.productName = productName;
      if (splits.length) allocation.splits = splits;
      await allocation.save();
    } else {
      allocation = await VendorAllocation.create({
        productId,
        productName,
        productSku,
        threshold: Number(threshold),
        totalUnitsNeeded: Number(totalUnitsNeeded),
        splits,
        clientId,
      });
    }

    // 2. Resolve product details
    let product = null;
    if (productId) {
      product = await Product.findById(productId);
    }
    if (!product) {
      product = await Product.findOne({ sku: productSku });
    }
    if (!product) {
      product = {
        _id: null,
        name: productName,
        sku: productSku,
        stock: 5,
      };
    }

    // 3. Trigger manual allocation and notification
    const triggerResult = await checkAndTriggerVendorAllocation({
      clientId,
      product,
      currentStock: product.stock !== undefined ? product.stock : 5,
      triggeredBy: "manual_admin",
      splits: splits && splits.length > 0 ? splits : undefined,
      totalUnitsNeeded: Number(totalUnitsNeeded) || undefined,
    });

    res.json({
      success: true,
      message: `Notification dispatched successfully to ${splits.length || 2} vendors!`,
      data: {
        poNumber: triggerResult?.poNumber || `PO-RV-${Date.now().toString().slice(-6)}`,
        allocation,
        historyEntry: triggerResult?.historyEntry,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * 7. GET /api/vendors/allocation/history - Get past split allocations & read receipts
 */
const getAllocationHistory = async (req, res) => {
  try {
    const clientId = req.user?.clientId;
    const allocations = await VendorAllocation.find(clientId ? { clientId } : {})
      .sort({ updatedAt: -1 })
      .lean();

    let allHistory = [];
    for (const a of allocations) {
      if (a.history && a.history.length > 0) {
        allHistory.push(...a.history);
      }
    }

    allHistory.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    res.json({
      success: true,
      data: allHistory,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * 8. GET /api/vendors/portal/data - Get vendor portal overview, profile, metrics & allocations
 */
const getVendorPortalData = async (req, res) => {
  try {
    const clientId = req.user?.clientId;
    let vendorName = req.query.vendorName || req.user?.vendorName || req.user?.name || "shreya";

    // 1. Find Vendor profile
    let vendor = await Vendor.findOne({
      name: new RegExp(`^${vendorName.trim()}$`, "i"),
      isActive: true,
      ...(clientId ? { $or: [{ clientId }, { clientId: null }] } : {}),
    });

    if (!vendor) {
      vendor = await Vendor.findOne({ name: "shreya" });
    }

    if (!vendor) {
      // Seed default vendors
      const seeded = await Vendor.insertMany(defaultSeedVendors.map((v) => ({ ...v, clientId })));
      vendor = seeded[0];
    }

    // 2. Fetch all allocations where this vendor has history or splits
    const allocations = await VendorAllocation.find(clientId ? { clientId } : {}).lean();

    const requirements = [];
    let allocatedUnits = 0;
    let actionRequired = 0;
    let inTransit = 0;
    let fulfilled = 0;
    const requestSet = new Set();

    // Iterate history entries
    for (const alloc of allocations) {
      if (alloc.history && alloc.history.length > 0) {
        for (const hist of alloc.history) {
          const splitItem = (hist.splits || []).find(
            (s) => s.vendorName && s.vendorName.trim().toLowerCase() === vendor.name.trim().toLowerCase()
          );

          if (splitItem) {
            requestSet.add(hist.orderId || hist._id.toString());
            const units = Number(splitItem.units) || 0;
            allocatedUnits += units;

            let rawStatus = (splitItem.status || "Pending").trim();
            let status = "Pending";
            if (rawStatus.toLowerCase().includes("transit") || rawStatus.toLowerCase().includes("dispatch")) {
              status = "In Transit";
              inTransit++;
            } else if (rawStatus.toLowerCase().includes("receive") || rawStatus.toLowerCase().includes("fulfill")) {
              status = "Received";
              fulfilled++;
            } else if (rawStatus.toLowerCase().includes("accept")) {
              status = "Accepted";
            } else {
              status = "Pending";
              actionRequired++;
            }

            requirements.push({
              id: `${hist.orderId}_${splitItem.vendorName}`,
              orderId: hist.orderId || `PO-RV-${hist._id.toString().slice(-6)}`,
              productName: hist.productName || alloc.productName || "Grocery",
              productSku: hist.productSku || alloc.productSku || "RV-134045-3890",
              vendorName: splitItem.vendorName,
              units: units,
              totalUnitsNeeded: hist.totalUnitsNeeded || alloc.totalUnitsNeeded,
              targetDeliveryDate: splitItem.targetDeliveryDate || new Date(Date.now() + 6 * 24 * 60 * 60 * 1000),
              status: status,
              createdAt: hist.createdAt,
              triggeredBy: hist.triggeredBy || "auto_low_stock",
            });
          }
        }
      }
    }

    // Sort requirements latest first
    requirements.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    res.json({
      success: true,
      data: {
        vendor: {
          id: vendor._id,
          name: vendor.name,
          companyName: vendor.companyName || `${vendor.name} Supplies`,
          phone: vendor.phone,
          email: vendor.email,
          category: vendor.category || "General Supplies",
          address: vendor.address || "Noida",
          gstin: vendor.gstin || "07AABCU9603R1ZX",
          rating: vendor.rating || 5.0,
          role: "VENDOR",
          isVerified: true,
        },
        metrics: {
          allocatedUnits,
          totalRequests: requestSet.size,
          actionRequired,
          inTransit,
          fulfilled,
        },
        requirements,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * 9. PATCH /api/vendors/portal/allocation-status - Update allocation status (Accept, Dispatch, Deliver)
 */
const updateVendorAllocationStatus = async (req, res) => {
  try {
    const { orderId, vendorName, status } = req.body;
    if (!orderId || !status) {
      return res.status(400).json({ success: false, message: "orderId and status are required" });
    }

    const clientId = req.user?.clientId;
    const allocations = await VendorAllocation.find(clientId ? { clientId } : {});

    let updated = false;
    for (const alloc of allocations) {
      if (alloc.history && alloc.history.length > 0) {
        for (const hist of alloc.history) {
          if (hist.orderId === orderId) {
            let deliveredUnits = 0;
            for (const split of hist.splits) {
              if (!vendorName || split.vendorName.trim().toLowerCase() === vendorName.trim().toLowerCase()) {
                split.status = status;
                deliveredUnits += Number(split.units) || 0;
                updated = true;
              }
            }
            if (updated) {
              if (!hist.readReceipts) hist.readReceipts = [];
              hist.readReceipts.push({
                vendorName: vendorName || "shreya",
                readAt: new Date(),
                status: `Status changed to ${status}`,
              });

              alloc.markModified("history");
              await alloc.save();

              // Automatically increment warehouse product stock when delivered!
              if (status.toLowerCase().includes("receive") && deliveredUnits > 0) {
                try {
                  const Product = require("../models/Product");
                  if (alloc.productId) {
                    await Product.findByIdAndUpdate(alloc.productId, { $inc: { stock: deliveredUnits } });
                  } else if (alloc.productSku) {
                    await Product.findOneAndUpdate({ sku: alloc.productSku }, { $inc: { stock: deliveredUnits } });
                  }
                } catch (stockErr) {
                  console.error("[VendorPortal] Error updating product stock on delivery:", stockErr);
                }
              }
              break;
            }
          }
        }
      }
      if (updated) break;
    }

    res.json({
      success: true,
      message: `Requirement status updated to ${status}`,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getVendors,
  createVendor,
  deleteVendor,
  getAllocation,
  saveAllocation,
  manualNotifyVendors,
  getAllocationHistory,
  getVendorPortalData,
  updateVendorAllocationStatus,
};

