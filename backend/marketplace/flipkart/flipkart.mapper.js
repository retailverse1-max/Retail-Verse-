// This file handles the data translation between Retail Verse DB schema and Flipkart's required JSON schema.

exports.mapProductToFlipkart = (retailVerseProduct) => {
    // Retail Verse product model has fields like:
    // name, description, category, price, salePrice, stockQuantity, sku, images

    const flipkartPayload = {
        "skuId": retailVerseProduct.sku || `SKU_${retailVerseProduct._id}`,
        // Phase 7: Attributes & Category Mapping 
        // In a real scenario, these come from MarketplaceCategoryMapping
        "taxDetails": {
            "hsn": retailVerseProduct.hsnCode || "1234",
            "taxPercentage": 12
        },
        "listingInfo": {
            "title": retailVerseProduct.name,
            "description": retailVerseProduct.description || "No description provided",
            "mrp": retailVerseProduct.price,
            "selling_price": retailVerseProduct.salePrice || retailVerseProduct.price,
            "stock_count": retailVerseProduct.stockQuantity || 0,
            "fulfillment_profile": "SELLER_FULFILLMENT", 
            "status": "ACTIVE"
        },
        "media": retailVerseProduct.images ? retailVerseProduct.images.map(img => ({ url: img })) : [],
        "attributes": {
            "brand": "RetailVerseBrand",
            "idealFor": "Unisex"
        }
        // Note: Flipkart has very strict category-specific attributes.
        // We will need a generic attribute mapper as the system scales.
    };

    return flipkartPayload;
};

exports.mapFlipkartOrderToRetailVerse = (flipkartOrderData, businessId, retailVerseProductId) => {
    // Translates the Flipkart Webhook JSON into Retail Verse Order schema format
    const retailOrder = {
        businessId: businessId,
        channel: 'flipkart',
        items: [
            {
                product: retailVerseProductId,
                quantity: flipkartOrderData.quantity || 1,
                price: flipkartOrderData.price,
            }
        ],
        totalAmount: flipkartOrderData.price * (flipkartOrderData.quantity || 1),
        status: 'pending',
        shippingAddress: {
            name: flipkartOrderData.customerDetails?.name || 'Flipkart Customer',
            addressLine1: flipkartOrderData.customerDetails?.address || 'Provided by Flipkart',
            city: flipkartOrderData.customerDetails?.city || '',
            state: flipkartOrderData.customerDetails?.state || '',
            pincode: flipkartOrderData.customerDetails?.pincode || '',
        },
        paymentMethod: 'Prepaid', // Flipkart handles payments, usually marked prepaid internally for sellers
        paymentStatus: 'completed'
    };

    return retailOrder;
};
