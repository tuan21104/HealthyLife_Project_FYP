const express = require('express');
const router = express.Router();
const UserFood = require('../models/UserFood');

// [GET] Lấy danh sách món ăn riêng của 1 User
router.get('/:userId', async (req, res) => {
  try {
    const foods = await UserFood.find({ userId: req.params.userId }).sort({ createdAt: -1 });
    res.status(200).json({ success: true, foods });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// [POST] Thêm món ăn mới (createMyFood)
router.post('/', async (req, res) => {
  try {
    const newFood = new UserFood(req.body);
    await newFood.save();
    res.status(201).json({ success: true, food: newFood });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ==========================================================
// --- [NEW] 1. API SỬA MÓN ĂN MÓN ĂN MY FOOD (PUT) ---
// ==========================================================
router.put('/:id', async (req, res) => {
  try {
    // Ta tìm và cập nhật món ăn, hỗ trợ đổi link ảnh mới
    const updatedFood = await UserFood.findByIdAndUpdate(req.params.id, req.body, { new: true });
    res.status(200).json({ success: true, food: updatedFood });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ==========================================================
// --- [NEW] 2. API XÓA MÓN ĂN MY FOOD (DELETE) ---
// --- Note: Frontend lo ownership check trước khi gọi API ---
// ==========================================================
router.delete('/:id', async (req, res) => {
  try {
    await UserFood.findByIdAndDelete(req.params.id);
    res.status(200).json({ success: true, message: 'Đã xóa món ăn' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;