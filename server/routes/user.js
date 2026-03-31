const express = require('express');
const router = express.Router();
const User = require('../models/User');

// 1. API LẤY THÔNG TIN PROFILE
router.get('/:id', async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('-password'); 
    if (!user) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy người dùng' });
    }
    res.status(200).json({ success: true, user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

//2 update
router.put('/update', async (req, res) => {
  // LOG 1: Xem App gửi cái gì lên
  console.log("==== 📥 SERVER NHẬN REQ UPDATE PROFILE ====");
  console.log("Body nhận được:", req.body); 

  try {
    const { userId, avatarUrl, avatarIndex, name } = req.body;

    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { avatarUrl, avatarIndex, name },
      { new: true }
    ).select('-password');

    if (!updatedUser) {
      console.log("==== ❌ KHÔNG TÌM THẤY USER ID:", userId);
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // LOG 2: Xem sau khi lưu xong thì DB trả về cái gì
    console.log("==== ✅ CẬP NHẬT DB THÀNH CÔNG. AvatarUrl mới:", updatedUser.avatarUrl);
    
    res.status(200).json({ success: true, user: updatedUser });
  } catch (error) {
    console.error("==== 💥 LỖI SERVER KHI UPDATE:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;