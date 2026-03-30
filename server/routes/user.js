const express = require('express');
const router = express.Router();
const User = require('../models/User'); // Gọi model User của bạn

// API lấy thông tin Profile dựa vào ID
router.get('/:id', async (req, res) => {
  try {
    // Tìm user theo ID và loại bỏ trường password cho an toàn
    const user = await User.findById(req.params.id).select('-password'); 
    
    if (!user) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy người dùng' });
    }
    
    res.status(200).json({ success: true, user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;