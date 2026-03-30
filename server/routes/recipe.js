const express = require('express');
const router = express.Router();
const Recipe = require('../models/Recipe');

// Lấy danh sách công thức của 1 User
router.get('/:userId', async (req, res) => {
  try {
    const recipes = await Recipe.find({ userId: req.params.userId }).sort({ createdAt: -1 });
    res.status(200).json({ success: true, recipes });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Thêm công thức mới
router.post('/', async (req, res) => {
  try {
    const newRecipe = new Recipe(req.body);
    await newRecipe.save();
    res.status(201).json({ success: true, recipe: newRecipe });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Xóa công thức
router.delete('/:id', async (req, res) => {
  try {
    await Recipe.findByIdAndDelete(req.params.id);
    res.status(200).json({ success: true, message: 'Đã xóa công thức' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;