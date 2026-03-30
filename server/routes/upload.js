require('dotenv').config();
const express = require('express');
const router = express.Router();
const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const fs = require('fs'); // Thư viện có sẵn của Node.js để thao tác file

// 1. Cấu hình API key Cloudinary chính chủ
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

// 2. Cấu hình Multer: Chỉ làm nhiệm vụ lưu tạm ảnh vào thư mục 'uploads/'
const upload = multer({ dest: 'uploads/' });

// 3. API nhận ảnh
router.post('/', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'Không tìm thấy ảnh tải lên' });
    }

    // Tự tay đẩy bức ảnh tạm lên kho Cloudinary
    const result = await cloudinary.uploader.upload(req.file.path, {
      folder: 'healthylife_foods',
    });

    // Tải xong rồi thì xóa file tạm đi cho sạch máy tính
    fs.unlinkSync(req.file.path);

    console.log("==== ✅ ĐÃ ĐẨY ẢNH LÊN MÂY THÀNH CÔNG ====");
    
    // Gửi trả đường link bảo mật (https) cho Flutter
    res.status(200).json({ success: true, imageUrl: result.secure_url });

  } catch (error) {
    console.error("==== 🚨 LỖI TẠI CLOUDINARY: ====", error);
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;