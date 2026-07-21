const CustomDomain = require("../models/CustomDomain");
const Business = require("../models/Business");

exports.resolveDomain = async (req, res) => {
  try {
    const { domain } = req.query;
    if (!domain) {
      return res.status(400).json({ success: false, message: "Domain is required" });
    }

    const customDomain = await CustomDomain.findOne({ domain: domain.toLowerCase().trim() });
    if (!customDomain) {
      return res.status(404).json({ success: false, message: "Domain not found" });
    }

    const business = await Business.findById(customDomain.businessId);

    res.status(200).json({
      success: true,
      businessId: customDomain.businessId,
      businessName: business ? business.businessName : "Unknown",
      domain: customDomain.domain,
    });
  } catch (error) {
    console.error("Error resolving domain:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};
