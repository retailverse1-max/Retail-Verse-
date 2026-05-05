const Razorpay = require("razorpay");
const crypto = require("crypto");
const Order = require("../models/Order");

// create razorpay instance lazily
const getRazorpayInstance = () => {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  
  if (!keyId || !keySecret) {
    throw new Error("Razorpay credentials missing in environment variables");
  }

  return new Razorpay({
    key_id: keyId,
    key_secret: keySecret,
  });
};

// POST /api/payments/razorpay/create-order
exports.createRazorpayOrder = async (req, res) => {
  try {
    const { amount, receipt } = req.body;
    
    if (!amount) {
      return res.status(400).json({ success: false, message: "Amount is required" });
    }

    const razorpay = getRazorpayInstance();
    const options = {
      amount: Math.round(amount * 100), // convert to paise
      currency: "INR",
      receipt: receipt || `receipt_${Date.now()}`,
    };

    const order = await razorpay.orders.create(options);
    
    res.status(200).json({
      success: true,
      keyId: process.env.RAZORPAY_KEY_ID,
      razorpayOrderId: order.id,
      amount: order.amount,
      currency: order.currency,
    });
  } catch (error) {
    console.error("Error creating Razorpay order:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};

// POST /api/payments/razorpay/verify
exports.verifyRazorpayPayment = async (req, res) => {
  try {
    const { 
      razorpay_order_id, 
      razorpay_payment_id, 
      razorpay_signature, 
      posOrderId 
    } = req.body;

    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return res.status(400).json({ success: false, message: "Missing required verification parameters" });
    }

    const secret = process.env.RAZORPAY_KEY_SECRET;
    const body = razorpay_order_id + "|" + razorpay_payment_id;

    const expectedSignature = crypto
      .createHmac("sha256", secret)
      .update(body.toString())
      .digest("hex");

    const isAuthentic = expectedSignature === razorpay_signature;

    if (isAuthentic) {
      // Update POS Order if ID provided
      if (posOrderId) {
        await Order.findByIdAndUpdate(posOrderId, {
          paymentStatus: "paid",
          status: "completed",
          razorpayOrderId: razorpay_order_id,
          razorpayPaymentId: razorpay_payment_id,
          razorpaySignature: razorpay_signature
        });
      }

      res.status(200).json({
        success: true,
        message: "Payment verified successfully",
      });
    } else {
      if (posOrderId) {
        await Order.findByIdAndUpdate(posOrderId, {
          paymentStatus: "failed",
          razorpayOrderId: razorpay_order_id,
          razorpayPaymentId: razorpay_payment_id
        });
      }
      res.status(400).json({
        success: false,
        message: "Invalid signature verification failed",
      });
    }
  } catch (error) {
    console.error("Error verifying payment:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};
