require("dotenv").config();
const connectDB = require("./config/db");
const Product = require("./models/Product");

const seedProducts = async () => {
  try {
    await connectDB();

    await Product.deleteMany();

    await Product.insertMany([
      {
        name: "Milk 1L",
        sku: "MLK001",
        barcode: "10001",
        price: 60,
        cost: 45,
        stock: 50,
      },
      {
        name: "Bread",
        sku: "BRD001",
        barcode: "10002",
        price: 40,
        cost: 28,
        stock: 35,
      },
      {
        name: "Eggs 12 Pack",
        sku: "EGG001",
        barcode: "10003",
        price: 90,
        cost: 70,
        stock: 20,
      }
    ]);

    console.log("Products seeded successfully");
    process.exit();
  } catch (error) {
    console.error("Seed error:", error.message);
    process.exit(1);
  }
};

seedProducts();