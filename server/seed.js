const mongoose = require('mongoose');
const Product = require('./models/Product');
require('dotenv').config();

const seedProducts = [
  {
    name: "Salmon Poke Bowl",
    priceCalo: 500,
    priceVND: 150000,
    imageUrl: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c",
    category: "food",
    calories: 450
  },
  {
    name: "Kettlebell 8kg",
    priceCalo: 0,
    priceVND: 350000,
    imageUrl: "https://images.unsplash.com/photo-1583454110551-21f2fa2adfcd",
    category: "equipment",
    calories: 0
  },
  {
    name: "Green Detox Juice",
    priceCalo: 120,
    priceVND: 55000,
    imageUrl: "https://images.unsplash.com/photo-1610970881699-44a5587cabec",
    category: "food",
    calories: 100
  }
];

mongoose.connect(process.env.MONGO_URI)
  .then(async () => {
    console.log("==== 🔄 ĐANG NẠP DỮ LIỆU SHOP... ====");
    await Product.deleteMany(); // Xóa dữ liệu cũ để không bị trùng (tùy chọn)
    await Product.insertMany(seedProducts);
    console.log("==== ✅ NẠP DỮ LIỆU THÀNH CÔNG! ====");
    process.exit();
  })
  .catch(err => {
    console.error(err);
    process.exit(1);
  });