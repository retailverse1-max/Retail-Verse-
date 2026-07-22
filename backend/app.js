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
// const flipkartRoutes = require("./marketplace/flipkart/flipkart.routes");
const shopifyRoutes = require("./marketplace/shopify/shopify.routes");
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

// Marketplace Routes
// app.use("/api/marketplace/flipkart", flipkartRoutes);
app.use("/api/marketplace/shopify", shopifyRoutes);

module.exports = app;