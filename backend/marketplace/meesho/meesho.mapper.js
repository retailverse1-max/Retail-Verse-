// Handles data translation between Retail Verse DB schema and Meesho Supplier API schema.

exports.mapProductToMeesho = (product) => {
    return {
        catalog_name: product.name,
        description: product.description || product.name,
        category: product.category || 'General',
        sku_id: product.sku || `MEESHO_${product._id}`,
        mrp: product.price,
        selling_price: product.salePrice || product.price,
        inventory_quantity: product.stockQuantity || product.stock || 0,
        images: product.images && product.images.length > 0 ? product.images : (product.imageUrl ? [product.imageUrl] : []),
        attributes: {
            brand: product.brand || 'Generic',
            country_of_origin: 'India',
        },
        status: 'ACTIVE'
    };
};

exports.mapMeeshoOrderToRetailVerse = (meeshoOrderData, businessId, retailVerseProductId) => {
    return {
        businessId: businessId,
        channel: 'meesho',
        items: [
            {
                product: retailVerseProductId,
                quantity: meeshoOrderData.quantity || 1,
                price: meeshoOrderData.price,
            }
        ],
        totalAmount: meeshoOrderData.price * (meeshoOrderData.quantity || 1),
        status: 'pending',
        shippingAddress: {
            name: meeshoOrderData.customerName || 'Meesho Customer',
            addressLine1: meeshoOrderData.address || 'Provided by Meesho',
            city: meeshoOrderData.city || '',
            state: meeshoOrderData.state || '',
            pincode: meeshoOrderData.pincode || '',
        },
        paymentMethod: 'Prepaid',
        paymentStatus: 'completed'
    };
};
