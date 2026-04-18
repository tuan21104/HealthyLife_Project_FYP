const express = require('express');
const router = express.Router();
const Diary = require('../models/Diary'); 

// 1. API LẤY DỮ LIỆU NHẬT KÝ TỪ CLOUD (Dùng khi đăng nhập máy mới)
router.get('/:userId/:date', async (req, res) => {
  try {
    const { userId, date } = req.params;
    const diary = await Diary.findOne({ userId, date });
    res.status(200).json({ success: true, diary });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 2. API ĐỒNG BỘ DỮ LIỆU LÊN CLOUD (Sẽ gọi ngầm mỗi khi người dùng thêm/sửa món)
router.post('/sync', async (req, res) => {
  try {
    const {
      userId,
      date,
      targetCalo,
      targetCarb,
      targetProtein,
      targetFat,
      waterIntake,
      breakfast,
      lunch,
      snack,
      dinner,
      exercise,
    } = req.body;

    const parsedWaterIntake = Number(waterIntake);
    const normalizedWaterIntake = Number.isFinite(parsedWaterIntake) && parsedWaterIntake >= 0
      ? parsedWaterIntake
      : 0;

    // Upsert: Cập nhật bản ghi cũ hoặc tạo mới nếu đây là ngày mới
    const diary = await Diary.findOneAndUpdate(
      { userId, date },
      {
        targetCalo,
        targetCarb,
        targetProtein,
        targetFat,
        waterIntake: normalizedWaterIntake,
        breakfast,
        lunch,
        snack,
        dinner,
        exercise,
      },
      { new: true, upsert: true }
    );

    res.status(200).json({ success: true, message: 'Đã đồng bộ lên Cloud thành công!', diary });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;