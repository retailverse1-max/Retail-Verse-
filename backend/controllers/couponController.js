const Coupon = require("../models/Coupon");
const Order = require("../models/Order");

// Auto-seed default coupons if collection is empty
const seedDefaultCouponsIfNeeded = async (clientId) => {
  try {
    const count = await Coupon.countDocuments({});
    if (count === 0) {
      await Coupon.create([
        {
          code: "SAVE300",
          description: "Flat ₹300 OFF on orders of ₹3,000 and above",
          discountType: "flat",
          discountValue: 300,
          minOrderAmount: 3000,
          isActive: true,
          clientId: null, // Universal
        },
        {
          code: "WELCOME100",
          description: "Flat ₹100 OFF on orders of ₹1,000 and above",
          discountType: "flat",
          discountValue: 100,
          minOrderAmount: 1000,
          isActive: true,
          clientId: null,
        },
        {
          code: "SUPER10",
          description: "10% OFF on orders of ₹1,500 and above (Max discount ₹500)",
          discountType: "percentage",
          discountValue: 10,
          maxDiscountAmount: 500,
          minOrderAmount: 1500,
          isActive: true,
          clientId: null,
        },
      ]);
      console.log("✅ Seeded default promotional coupons (SAVE300, WELCOME100, SUPER10)");
    }
  } catch (err) {
    console.error("Coupon seed error:", err.message);
  }
};

/**
 * Validate and calculate coupon discount for cart
 * POST /api/coupons/validate
 */
const validateCoupon = async (req, res) => {
  try {
    const { code, cartSubtotal, customerPhone } = req.body;

    if (!code || typeof code !== "string" || !code.trim()) {
      return res.status(400).json({ success: false, message: "Coupon code is required" });
    }

    const cleanCode = code.trim().toUpperCase();
    const subtotal = Number(cartSubtotal) || 0;

    await seedDefaultCouponsIfNeeded(req.user?.clientId);

    const query = {
      code: cleanCode,
      $or: [
        { clientId: req.user?.clientId },
        { clientId: null },
      ],
    };

    const coupon = await Coupon.findOne(query);

    if (!coupon) {
      return res.status(404).json({
        success: false,
        message: `Coupon "${cleanCode}" is not valid or does not exist`,
      });
    }

    if (!coupon.isActive) {
      return res.status(400).json({
        success: false,
        message: `Coupon "${cleanCode}" is currently inactive`,
      });
    }

    const now = new Date();
    if (coupon.validFrom && now < coupon.validFrom) {
      return res.status(400).json({
        success: false,
        message: `Coupon "${cleanCode}" is not active yet`,
      });
    }

    if (coupon.validUntil && now > coupon.validUntil) {
      return res.status(400).json({
        success: false,
        message: `Coupon "${cleanCode}" has expired`,
      });
    }

    if (coupon.usageLimit && coupon.usedCount >= coupon.usageLimit) {
      return res.status(400).json({
        success: false,
        message: `Coupon "${cleanCode}" usage limit has been reached`,
      });
    }

    if (subtotal < coupon.minOrderAmount) {
      return res.status(400).json({
        success: false,
        message: `Coupon "${cleanCode}" is valid only on a minimum subtotal of ₹${coupon.minOrderAmount.toLocaleString("en-IN")} (Current: ₹${subtotal.toFixed(2)})`,
      });
    }

    // Per-customer usage check if phone number provided and limit set
    if (coupon.perCustomerLimit && customerPhone) {
      const cleanPhone = customerPhone.replace(/[^0-9]/g, "");
      if (cleanPhone.length >= 10) {
        const userUsageCount = await Order.countDocuments({
          customerPhone: { $regex: cleanPhone.slice(-10) },
          couponCode: cleanCode,
          status: { $ne: "cancelled" },
        });

        if (userUsageCount >= coupon.perCustomerLimit) {
          return res.status(400).json({
            success: false,
            message: `You have already used coupon "${cleanCode}" the maximum allowed times (${coupon.perCustomerLimit})`,
          });
        }
      }
    }

    // Calculate discount
    let calculatedDiscount = 0;
    if (coupon.discountType === "flat") {
      calculatedDiscount = Math.min(coupon.discountValue, subtotal);
    } else if (coupon.discountType === "percentage") {
      let percentAmount = (subtotal * coupon.discountValue) / 100;
      if (coupon.maxDiscountAmount && coupon.maxDiscountAmount > 0) {
        percentAmount = Math.min(percentAmount, coupon.maxDiscountAmount);
      }
      calculatedDiscount = Math.min(percentAmount, subtotal);
    }

    calculatedDiscount = Math.round(calculatedDiscount * 100) / 100;

    return res.status(200).json({
      success: true,
      valid: true,
      coupon: {
        code: coupon.code,
        description: coupon.description,
        discountType: coupon.discountType,
        discountValue: coupon.discountValue,
        maxDiscountAmount: coupon.maxDiscountAmount,
        minOrderAmount: coupon.minOrderAmount,
        calculatedDiscount,
      },
      message: `Coupon "${coupon.code}" applied! You saved ₹${calculatedDiscount.toFixed(2)}.`,
    });
  } catch (error) {
    console.error("validateCoupon error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error while validating coupon: " + error.message,
    });
  }
};

/**
 * Get active available coupons for checkout suggestion chips
 * GET /api/coupons/active
 */
const getActiveCoupons = async (req, res) => {
  try {
    await seedDefaultCouponsIfNeeded(req.user?.clientId);

    const now = new Date();
    const query = {
      isActive: true,
      $or: [
        { clientId: req.user?.clientId },
        { clientId: null },
      ],
      $and: [
        { $or: [{ validFrom: { $exists: false } }, { validFrom: null }, { validFrom: { $lte: now } }] },
        { $or: [{ validUntil: { $exists: false } }, { validUntil: null }, { validUntil: { $gte: now } }] },
      ],
    };

    const coupons = await Coupon.find(query).sort({ minOrderAmount: 1 }).lean();

    // Filter out coupons that have reached total usage limit
    const availableCoupons = coupons.filter((c) => {
      if (c.usageLimit && c.usedCount >= c.usageLimit) return false;
      return true;
    });

    return res.status(200).json({
      success: true,
      coupons: availableCoupons,
    });
  } catch (error) {
    console.error("getActiveCoupons error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error while fetching active coupons",
    });
  }
};

/**
 * List all coupons (for store settings/admin)
 * GET /api/coupons
 */
const getAllCoupons = async (req, res) => {
  try {
    await seedDefaultCouponsIfNeeded(req.user?.clientId);

    const query = req.user?.clientId
      ? { $or: [{ clientId: req.user.clientId }, { clientId: null }] }
      : {};

    const coupons = await Coupon.find(query).sort({ createdAt: -1 });
    return res.status(200).json({ success: true, coupons });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * Create a new coupon
 * POST /api/coupons
 */
const createCoupon = async (req, res) => {
  try {
    const {
      code,
      description,
      discountType,
      discountValue,
      maxDiscountAmount,
      minOrderAmount,
      validFrom,
      validUntil,
      usageLimit,
      perCustomerLimit,
      isActive,
    } = req.body;

    if (!code || !discountValue) {
      return res.status(400).json({ success: false, message: "Code and discountValue are required" });
    }

    const cleanCode = code.trim().toUpperCase();
    const existing = await Coupon.findOne({
      code: cleanCode,
      clientId: req.user?.clientId || null,
    });

    if (existing) {
      return res.status(400).json({ success: false, message: `Coupon "${cleanCode}" already exists` });
    }

    const newCoupon = await Coupon.create({
      code: cleanCode,
      description: description || "",
      discountType: discountType === "percentage" ? "percentage" : "flat",
      discountValue: Number(discountValue),
      maxDiscountAmount: maxDiscountAmount ? Number(maxDiscountAmount) : null,
      minOrderAmount: Number(minOrderAmount) || 0,
      validFrom: validFrom ? new Date(validFrom) : new Date(),
      validUntil: validUntil ? new Date(validUntil) : null,
      usageLimit: usageLimit ? Number(usageLimit) : null,
      perCustomerLimit: perCustomerLimit ? Number(perCustomerLimit) : null,
      isActive: isActive !== false,
      clientId: req.user?.clientId || null,
    });

    return res.status(201).json({ success: true, coupon: newCoupon });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * Update coupon
 * PUT /api/coupons/:id
 */
const updateCoupon = async (req, res) => {
  try {
    const coupon = await Coupon.findById(req.params.id);
    if (!coupon) {
      return res.status(404).json({ success: false, message: "Coupon not found" });
    }

    const allowed = [
      "description",
      "discountType",
      "discountValue",
      "maxDiscountAmount",
      "minOrderAmount",
      "validFrom",
      "validUntil",
      "usageLimit",
      "perCustomerLimit",
      "isActive",
    ];

    allowed.forEach((field) => {
      if (req.body[field] !== undefined) {
        coupon[field] = req.body[field];
      }
    });

    if (req.body.code) {
      coupon.code = req.body.code.trim().toUpperCase();
    }

    await coupon.save();
    return res.status(200).json({ success: true, coupon });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * Delete coupon
 * DELETE /api/coupons/:id
 */
const deleteCoupon = async (req, res) => {
  try {
    const coupon = await Coupon.findByIdAndDelete(req.params.id);
    if (!coupon) {
      return res.status(404).json({ success: false, message: "Coupon not found" });
    }
    return res.status(200).json({ success: true, message: "Coupon deleted successfully" });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  validateCoupon,
  getActiveCoupons,
  getAllCoupons,
  createCoupon,
  updateCoupon,
  deleteCoupon,
};
