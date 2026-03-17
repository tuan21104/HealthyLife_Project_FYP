const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const Food = require('../models/Food');

// 1. API Lấy danh sách toàn bộ món ăn (App Flutter sẽ gọi API này)
router.get('/', async (req, res) => {
  try {
    const foods = await Food.find();
    res.status(200).json({ success: true, count: foods.length, foods });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi lấy dữ liệu món ăn', error });
  }
});

// 2. API "Bơm" dữ liệu khổng lồ từ file JSON nội bộ
router.post('/seed', async (req, res) => {
  try {
    // Trỏ đường dẫn tới file JSON trong thư mục data (Tuyệt chiêu dùng path cực an toàn)
    const dataPath = path.join(__dirname, '../data/vietnamese_foods.json');
    
    // Đọc và parse file JSON
    const foodData = JSON.parse(fs.readFileSync(dataPath, 'utf-8'));

    // XÓA SẠCH DỮ LIỆU CŨ trong Collection Foods để dọn rác và chống trùng lặp
    await Food.deleteMany({});
    console.log('🧹 Đã dọn sạch Database Food cũ!');
    
    // BƠM TOÀN BỘ MẢNG JSON VÀO MONGODB
    const createdFoods = await Food.insertMany(foodData);
    console.log(`🚀 Đã bơm thành công ${createdFoods.length} món ăn!`);

    res.status(201).json({ 
      success: true, 
      message: `Tuyệt vời! Đã dọn dẹp và seed thành công ${createdFoods.length} món ăn vào Database!`, 
    });
  } catch (error) {
    console.error("❌ Lỗi khi seed:", error);
    res.status(500).json({ success: false, message: 'Lỗi seed dữ liệu từ file JSON', error: error.message });
  }
});

module.exports = router;