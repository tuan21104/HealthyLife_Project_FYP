const express = require('express');
const router = express.Router();
const Product = require('../models/Product');
const User = require('../models/User');
const Diary = require('../models/Diary');
const nodemailer = require('nodemailer');

// --- CẤU HÌNH GỬI EMAIL ---
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'phantuan9d@gmail.com',
    pass: 'fjnz yzzb zkrk cxnz' // Tuấn nhớ bảo mật mã này khi nộp đồ án nhé!
  }
});

// --- API REDEEM (ĐỔI QUÀ) ---
router.post('/redeem', async (req, res) => {
  const { userId, productId, billUrl, address } = req.body;
  const today = new Date().toISOString().split('T')[0];

  try {
    const user = await User.findById(userId);
    const product = await Product.findById(productId);

    if (!user || !product) {
      return res.status(404).json({ success: false, message: "Không tìm thấy dữ liệu người dùng hoặc sản phẩm" });
    }

    // 1. Kiểm tra số dư Calo (Dùng priceCalo để khớp với Model mới)
    // Nếu món đồ là Equipment (tạ, thảm) và priceCalo = 0 thì sẽ bỏ qua bước này
    const cost = product.priceCalo || 0; 
    if (user.targetCalo < cost) {
      return res.status(400).json({ success: false, message: "Bạn không đủ Calo trong ví để đổi món này!" });
    }

    // 2. Trừ Calo trong DB
    user.targetCalo -= cost;
    await user.save();

    // 3. NẾU LÀ ĐỒ ĂN -> Tự động ghi vào Diary
    if (product.category === 'food') {
      let diary = await Diary.findOne({ userId, date: today });
      if (!diary) {
        diary = new Diary({ userId, date: today, meals: [] });
      }

      diary.meals.push({
        foodName: `[Shop] ${product.name}`,
        calories: product.calories || 0,
        time: new Date().toLocaleTimeString('vi-VN') // Hiện giờ VN cho chuẩn
      });
      await diary.save();
    }

    // 4. GỬI EMAIL THÔNG BÁO CHO ADMIN (TUẤN)
    const mailOptions = {
      from: '"HealthyLife System" <phantuan9d@gmail.com>',
      to: 'phantuan9d@gmail.com',
      subject: `[ĐƠN HÀNG MỚI] - ${user.name.toUpperCase()}`,
      html: `
        <div style="font-family: sans-serif; line-height: 1.5; color: #333;">
          <h2 style="color: #76B543;">Thông tin đơn hàng mới từ App</h2>
          <p><b>Người mua:</b> ${user.name} (${user.email})</p>
          <p><b>Địa chỉ giao hàng:</b> <span style="color: red;">${address || 'Khách chưa nhập'}</span></p>
          <p><b>Sản phẩm:</b> ${product.name}</p>
          <p><b>Giá trị:</b> ${cost} kcal | <b>Tiền mặt:</b> ${product.priceVND || 0} VNĐ</p>
          <p><b>Minh chứng thanh toán:</b></p>
          <a href="${billUrl}" target="_blank">
            <img src="${billUrl}" width="300" style="border: 1px solid #ddd; border-radius: 10px;" />
          </a>
          <p style="font-size: 12px; color: #888;">Hãy kiểm tra tài khoản ngân hàng trước khi giao hàng!</p>
        </div>
      `
    };

    // Gửi mail và bắt lỗi nếu có
    transporter.sendMail(mailOptions, (error, info) => {
      if (error) console.log("🚨 LỖI GỬI EMAIL: ", error);
      else console.log("📧 Email đơn hàng đã gửi: " + info.response);
    });

    res.json({ 
      success: true, 
      message: "Đơn hàng của bạn đã được gửi thành công!", 
      newBalance: user.targetCalo 
    });

  } catch (error) {
    console.error("🚨 LỖI REDEEM:", error);
    res.status(500).json({ success: false, error: error.message });
  }
});

router.get('/all', async (req, res) => {
  try {
    const products = await Product.find({});
    res.json({ success: true, products: products });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;