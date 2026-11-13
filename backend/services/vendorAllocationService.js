const VendorAllocation = require("../models/VendorAllocation");
const Vendor = require("../models/Vendor");
const { createAndSendNotification } = require("./notificationService");

/**
 * Checks if stock has fallen below or equal to the configured threshold (default 5).
 * If so, automatically triggers the multi-vendor split allocation & dispatches notifications.
 */
const checkAndTriggerVendorAllocation = async ({
  clientId,
  product,
  currentStock,
  triggeredBy = "auto_low_stock",
  splits: overrideSplits,
  totalUnitsNeeded: overrideTotalUnits,
}) => {
  try {
    if (!product) return null;

    // 1. Find matching allocation rule by product ID or SKU or general fallback
    let allocation = null;
    if (product._id) {
      allocation = await VendorAllocation.findOne({
        productId: product._id,
        ...(clientId ? { clientId } : {}),
      });
    }
    if (!allocation && product.sku) {
      allocation = await VendorAllocation.findOne({
        productSku: product.sku,
        ...(clientId ? { clientId } : {}),
      });
    }
    if (!allocation && product.name) {
      allocation = await VendorAllocation.findOne({
        productName: new RegExp(`^${product.name}$`, "i"),
        ...(clientId ? { clientId } : {}),
      });
    }

    // If no specific allocation exists, check if there's a default allocation
    if (!allocation) {
      allocation = await VendorAllocation.findOne({
        ...(clientId ? { clientId } : {}),
      }).sort({ updatedAt: -1 });
    }

    // Default threshold is 5 units if not configured
    const threshold = allocation ? allocation.threshold : 5;

    // Only auto-trigger if stock is at or below threshold (e.g. <= 5); manual admin triggers ALWAYS proceed
    if (triggeredBy !== "manual_admin" && currentStock > threshold) {
      return null;
    }

    // Avoid duplicate auto-triggers within 5 minutes for the same product
    if (triggeredBy === "auto_low_stock" && allocation && allocation.lastTriggeredAt) {
      const diffMs = Date.now() - new Date(allocation.lastTriggeredAt).getTime();
      if (diffMs < 5 * 60 * 1000) {
        console.log(`[VendorAllocation] Skipping duplicate low-stock trigger for ${product.name} (triggered ${Math.round(diffMs / 1000)}s ago)`);
        return null;
      }
    }

    const totalUnitsNeeded = overrideTotalUnits || (allocation ? allocation.totalUnitsNeeded : 20);
    const splits = (overrideSplits && overrideSplits.length > 0)
      ? overrideSplits
      : (allocation && allocation.splits && allocation.splits.length > 0
          ? allocation.splits
          : [
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
            ]);

    const vendorNames = splits.map((s) => s.vendorName).join(", ");
    const poNumber = `PO-RV-${Date.now().toString().slice(-6)}`;

    const historyEntry = {
      orderId: poNumber,
      productName: product.name,
      productSku: product.sku || "RV-SKU",
      stockAtTrigger: currentStock,
      totalUnitsNeeded,
      splits: splits.map((s) => ({
        vendorName: s.vendorName,
        units: s.units,
        targetDeliveryDate: s.targetDeliveryDate,
        status: "Dispatched",
      })),
      triggeredBy,
      readReceipts: splits.map((s) => ({
        vendorName: s.vendorName,
        readAt: new Date(),
        status: "Delivered to Portal",
      })),
      createdAt: new Date(),
    };

    if (allocation) {
      allocation.lastTriggeredAt = new Date();
      allocation.history.unshift(historyEntry);
      if (allocation.history.length > 50) allocation.history.pop();
      await allocation.save();
    } else {
      // Auto-create initial allocation record for this product
      allocation = await VendorAllocation.create({
        productId: product._id,
        productName: product.name,
        productSku: product.sku,
        threshold: 5,
        totalUnitsNeeded: 20,
        splits,
        clientId,
        lastTriggeredAt: new Date(),
        history: [historyEntry],
      });
    }

    const User = require("../models/User");

    // 1. Dispatch Notification to Admin & Inventory
    const notifTitle = triggeredBy === "manual_admin"
      ? `📦 Vendor Split Dispatched: ${product.name} (${totalUnitsNeeded} Units)`
      : `🚨 LOW STOCK TRIGGER (Stock: ${currentStock}): Multi-Vendor Split Dispatched`;

    const notifMessage = triggeredBy === "manual_admin"
      ? `Manual replenishment order #${poNumber} allocated for ${product.name}. Volume split across: ${vendorNames}.`
      : `Stock for ${product.name} reached ${currentStock} units (Threshold: ${threshold}). Multi-vendor replenishment of ${totalUnitsNeeded} units automatically allocated to: ${vendorNames}.`;

    await createAndSendNotification({
      title: notifTitle,
      message: notifMessage,
      type: "vendor_split_allocation",
      targetRoles: ["admin", "inventory"],
      clientId,
      data: {
        poNumber,
        productId: product._id ? product._id.toString() : "",
        productName: product.name,
        productSku: product.sku,
        currentStock,
        threshold,
        totalUnitsNeeded,
        triggeredBy,
        splits: JSON.stringify(splits),
      },
    });

    // 2. Dispatch Dedicated Notification to Vendor login accounts
    for (const split of splits) {
      const vName = split.vendorName ? split.vendorName.trim() : "";
      if (!vName) continue;

      const vendorTitle = triggeredBy === "manual_admin"
        ? `📦 Purchase Order Dispatched: ${product.name} (${split.units} Units)`
        : `🚨 Low Stock Replenishment: ${product.name} (${split.units} Units Needed)`;

      const vendorMessage = `You have been allocated ${split.units} units for ${product.name} (PO #${poNumber}) by Retail Verse Admin. Target delivery: ${new Date(split.targetDeliveryDate).toLocaleDateString()}. Please open your Vendor Portal to review and accept.`;

      // Find if this vendor has a login account
      const vendorUser = await User.findOne({
        role: "vendor",
        $or: [
          { vendorName: new RegExp(`^${vName}$`, "i") },
          { name: new RegExp(`^${vName}$`, "i") },
        ],
      });

      await createAndSendNotification({
        title: vendorTitle,
        message: vendorMessage,
        type: "vendor_split_allocation",
        targetRoles: ["vendor"],
        clientId: vendorUser?.clientId || clientId || null,
        data: {
          poNumber,
          orderId: poNumber,
          vendorName: vName,
          vendorEmail: vendorUser?.email || "",
          productId: product._id ? product._id.toString() : "",
          productName: product.name,
          productSku: product.sku,
          allocatedUnits: split.units,
          totalUnitsNeeded,
          targetDeliveryDate: split.targetDeliveryDate,
          status: "Dispatched",
          triggeredBy,
        },
      });
    }

    console.log(`[VendorAllocation] Successfully dispatched ${triggeredBy} for ${product.name} (${totalUnitsNeeded} units to ${vendorNames})`);
    return {
      success: true,
      poNumber,
      allocation,
      historyEntry,
    };
  } catch (error) {
    console.error("[VendorAllocation] Trigger error:", error);
    return null;
  }
};

module.exports = {
  checkAndTriggerVendorAllocation,
};
