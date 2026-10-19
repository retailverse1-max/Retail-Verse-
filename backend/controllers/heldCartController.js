const HeldCart = require("../models/HeldCart");

/**
 * Get all active held carts for this store/client
 * GET /api/pos/held-carts
 */
const getHeldCarts = async (req, res) => {
  try {
    const clientId = req.user?.clientId;
    const query = clientId ? { clientId } : {};

    const heldCarts = await HeldCart.find(query)
      .sort({ heldAt: -1 })
      .populate("heldBy", "name email");

    return res.status(200).json({
      success: true,
      heldCarts,
    });
  } catch (error) {
    console.error("getHeldCarts error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * Save a new cart on hold
 * POST /api/pos/held-carts
 */
const createHeldCart = async (req, res) => {
  try {
    const {
      referenceLabel,
      customerName,
      customerPhone,
      customerEmail,
      customerAddress,
      orderNotes,
      items,
      subtotal,
      discount,
      appliedCouponCode,
      taxRate,
      extraCharges,
    } = req.body;

    if (!items || !items.length) {
      return res.status(400).json({ success: false, message: "Cart has no items to hold" });
    }

    const clientId = req.user?.clientId;
    if (!clientId) {
      return res.status(400).json({ success: false, message: "Client ID required" });
    }

    const heldCart = await HeldCart.create({
      clientId,
      heldBy: req.user._id,
      referenceLabel: referenceLabel || "Walk-in Customer",
      customerName,
      customerPhone,
      customerEmail,
      customerAddress,
      orderNotes,
      items,
      subtotal: Number(subtotal) || 0,
      discount: Number(discount) || 0,
      appliedCouponCode: appliedCouponCode ? appliedCouponCode.trim().toUpperCase() : undefined,
      taxRate: Number(taxRate) || 0.18,
      extraCharges: Number(extraCharges) || 0,
      heldAt: new Date(),
    });

    return res.status(201).json({
      success: true,
      message: "Cart held successfully",
      heldCart,
    });
  } catch (error) {
    console.error("createHeldCart error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * Delete / Remove held cart (resumed or discarded)
 * DELETE /api/pos/held-carts/:id
 */
const deleteHeldCart = async (req, res) => {
  try {
    const { id } = req.params;
    const clientId = req.user?.clientId;

    const query = { _id: id };
    if (clientId) query.clientId = clientId;

    const deleted = await HeldCart.findOneAndDelete(query);
    if (!deleted) {
      return res.status(404).json({ success: false, message: "Held cart not found" });
    }

    return res.status(200).json({
      success: true,
      message: "Held cart removed successfully",
    });
  } catch (error) {
    console.error("deleteHeldCart error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getHeldCarts,
  createHeldCart,
  deleteHeldCart,
};
