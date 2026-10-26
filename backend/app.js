const express = require("express");
const cors = require("cors");
const authRoutes = require("./routes/authRoutes");
const productRoutes = require("./routes/productRoutes");
const orderRoutes = require("./routes/orderRoutes");
const inventoryRoutes = require("./routes/inventoryRoutes");
const paymentRoutes = require("./routes/paymentRoutes");
const supportRoutes = require("./routes/supportRoutes");
const superadminRoutes = require("./routes/superadminRoutes");
const publicRoutes = require("./routes/publicRoutes");
const aiRoutes = require("./routes/aiRoutes");
const dashboardRoutes = require("./routes/dashboardRoutes");
const notificationRoutes = require("./routes/notificationRoutes");
const subscriptionRoutes = require("./routes/subscriptionRoutes");
const categoryRoutes = require("./routes/categoryRoutes");
const couponRoutes = require("./routes/couponRoutes");
const heldCartRoutes = require("./routes/heldCartRoutes");
const flipkartRoutes = require("./marketplace/flipkart/flipkart.routes");
const shopifyRoutes = require("./marketplace/shopify/shopify.routes");
const meeshoRoutes = require("./marketplace/meesho/meesho.routes");
const marketplaceRoutes = require("./marketplace/marketplace.routes");
const app = express();

app.use(cors());

// Preserve raw body for Shopify webhook HMAC verification
app.use(express.json({
  limit: "50mb",
  verify: (req, res, buf) => { req.rawBody = buf; }
}));
app.use(express.urlencoded({ limit: "50mb", extended: true }));


app.get("/", (req, res) => {
  res.send("POS Backend running 🚀");
});

app.get("/health", (req, res) => {
  res.status(200).json({ status: "ok", uptime: process.uptime() });
});

app.use("/api/auth", authRoutes);
app.use("/api/products", productRoutes);
app.use("/api/orders", orderRoutes);
app.use("/api/inventory", inventoryRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/support", supportRoutes);
app.use(["/api/superadmin", "/api/super-admin"], superadminRoutes);
app.use("/api/users", superadminRoutes);
app.use("/api/public", publicRoutes);
app.use("/api/ai", aiRoutes);
app.use("/api/dashboard", dashboardRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/subscriptions", subscriptionRoutes);
app.use("/api/categories", categoryRoutes);
app.use("/api/coupons", couponRoutes);
app.use("/api/pos/held-carts", heldCartRoutes);

// Marketplace Routes
app.use(["/api/marketplace", "/api/api/marketplace"], marketplaceRoutes);
app.use(["/api/marketplace/flipkart", "/api/api/marketplace/flipkart"], flipkartRoutes);
app.use(["/api/marketplace/shopify", "/api/api/marketplace/shopify"], shopifyRoutes);
app.use(["/api/marketplace/meesho", "/api/api/marketplace/meesho"], meeshoRoutes);

module.exports = app;