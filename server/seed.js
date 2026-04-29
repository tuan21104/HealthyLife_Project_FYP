const mongoose = require('mongoose');
const Product = require('./models/Product');
require('dotenv').config();

const seedProducts = [
  {
    name: 'Salmon Poke Bowl',
    priceCalo: 500,
    priceVND: 150000,
    imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
    category: 'food',
    calories: 450,
    carbs: 42,
    protein: 29,
    fat: 18,
    fiber: 7,
  },
  {
    name: 'Chicken Breast Quinoa Bowl',
    priceCalo: 420,
    priceVND: 135000,
    imageUrl: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061',
    category: 'food',
    calories: 390,
    carbs: 34,
    protein: 33,
    fat: 11,
    fiber: 6,
  },
  {
    name: 'Greek Yogurt Parfait',
    priceCalo: 180,
    priceVND: 65000,
    imageUrl: 'https://images.unsplash.com/photo-1488477181946-6428a0291777',
    category: 'food',
    calories: 160,
    carbs: 22,
    protein: 12,
    fat: 4,
    fiber: 3,
  },
  {
    name: 'Green Detox Juice',
    priceCalo: 120,
    priceVND: 55000,
    imageUrl: 'https://images.unsplash.com/photo-1610970881699-44a5587cabec',
    category: 'food',
    calories: 100,
    carbs: 24,
    protein: 2,
    fat: 0,
    fiber: 4,
  },
  {
    name: 'Avocado Egg Toast',
    priceCalo: 260,
    priceVND: 78000,
    imageUrl: 'https://images.unsplash.com/photo-1588137378633-dea1336ce1e2',
    category: 'food',
    calories: 240,
    carbs: 19,
    protein: 10,
    fat: 14,
    fiber: 5,
  },
  {
    name: 'Protein Oatmeal Cup',
    priceCalo: 320,
    priceVND: 69000,
    imageUrl: 'https://images.unsplash.com/photo-1517673400267-0251440c45dc',
    category: 'food',
    calories: 300,
    carbs: 36,
    protein: 18,
    fat: 8,
    fiber: 6,
  },
  {
    name: 'Barbell & Dumbbell Set',
    priceCalo: 0,
    priceVND: 890000,
    imageUrl: 'https://images.unsplash.com/photo-1526401485004-2fda9f1aabc6',
    category: 'equipment',
    calories: 0,
    carbs: 0,
    protein: 0,
    fat: 0,
    fiber: 0,
  },
  {
    name: 'Yoga Mat Pro',
    priceCalo: 0,
    priceVND: 260000,
    imageUrl: 'https://images.unsplash.com/photo-1592432678016-e910b452f9a2',
    category: 'equipment',
    calories: 0,
    carbs: 0,
    protein: 0,
    fat: 0,
    fiber: 0,
  },
  {
    name: 'Resistance Band Kit',
    priceCalo: 0,
    priceVND: 190000,
    imageUrl: 'https://images.unsplash.com/photo-1518611012118-696072aa579a',
    category: 'equipment',
    calories: 0,
    carbs: 0,
    protein: 0,
    fat: 0,
    fiber: 0,
  },
  {
    name: 'Smart Water Bottle',
    priceCalo: 0,
    priceVND: 320000,
    imageUrl: 'https://images.unsplash.com/photo-1523362628745-0c100150b504',
    category: 'equipment',
    calories: 0,
    carbs: 0,
    protein: 0,
    fat: 0,
    fiber: 0,
  },
];

mongoose
  .connect(process.env.MONGO_URI)
  .then(async () => {
    console.log('==== 🔄 ĐANG NẠP DỮ LIỆU SHOP... ====');
    await Product.deleteMany(); // Xóa dữ liệu cũ để không bị trùng (tùy chọn)
    await Product.insertMany(seedProducts);
    console.log('==== ✅ NẠP DỮ LIỆU THÀNH CÔNG! ====');
    process.exit();
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });