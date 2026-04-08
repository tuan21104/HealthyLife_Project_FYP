const express = require('express');
const router = express.Router();
const Product = require('../models/Product');
const User = require('../models/User');
const Diary = require('../models/Diary');
const Order = require('../models/Order');
const nodemailer = require('nodemailer');

const STORE_COORDINATES = { lat: 21.0285, lng: 105.8542 };
const SHIPPING_RATE_PER_KM = 5000;

function haversineDistanceKm(lat1, lng1, lat2, lng2) {
  const toRadians = (degrees) => (degrees * Math.PI) / 180;
  const earthRadiusKm = 6371;

  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusKm * c;
}

function getMealFieldByHour(hour) {
  if (hour >= 5 && hour < 10) return 'breakfast';
  if (hour >= 10 && hour < 14) return 'lunch';
  if (hour >= 14 && hour < 17) return 'snack';
  return 'dinner';
}

// --- CẤU HÌNH GỬI EMAIL ---
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'phantuan9d@gmail.com',
    pass: 'fjnz yzzb zkrk cxnz' 
  }
});

// --- API LẤY DANH SÁCH SẢN PHẨM ---
router.get('/all', async (req, res) => {
  try {
    const products = await Product.find({});
    res.json({ success: true, products });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/history/:userId', async (req, res) => {
  try {
    const orders = await Order.find({ userId: req.params.userId })
      .sort({ createdAt: -1 })
      .limit(100);

    res.json({ success: true, orders });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// --- API REDEEM (ĐẶT HÀNG & ĐỔI QUÀ) ---
router.post('/redeem', async (req, res) => {
  const { userId, productId } = req.body;
  const quantity = Math.max(1, parseInt(req.body.quantity, 10) || 1);
  const billUrl = (req.body.billUrl || '').trim();
  const address = (req.body.address || '').trim();
  const deliveryAddress = (req.body.deliveryAddress || address).trim();
  const latRaw = req.body.lat ?? req.body.coordinates?.lat;
  const lngRaw = req.body.lng ?? req.body.coordinates?.lng;
  const lat = Number(latRaw);
  const lng = Number(lngRaw);
  const today = new Date().toISOString().split('T')[0];

  try {
    const user = await User.findById(userId);
    const product = await Product.findById(productId);

    if (!user || !product) {
      return res.status(404).json({ success: false, message: "Dữ liệu không tồn tại" });
    }

    if (!deliveryAddress) {
      return res.status(400).json({ success: false, message: "Vui lòng nhập địa chỉ nhận hàng" });
    }

    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res.status(400).json({ success: false, message: 'Thiếu tọa độ giao hàng hợp lệ (lat, lng)' });
    }

    const distanceKmRaw = haversineDistanceKm(
      STORE_COORDINATES.lat,
      STORE_COORDINATES.lng,
      lat,
      lng
    );
    const distanceKm = Number(distanceKmRaw.toFixed(2));
    const shippingFee = Math.round(distanceKm * SHIPPING_RATE_PER_KM);
    const productTotalVnd = (product.priceVND || 0) * quantity;
    const totalAmount = productTotalVnd + shippingFee;

    // 1. Khấu trừ Calo nếu có
    const cost = (product.priceCalo || 0) * quantity; 
    if (user.targetCalo < cost) {
      return res.status(400).json({ success: false, message: "Không đủ Calo để đổi món này!" });
    }

    user.targetCalo -= cost;
    await user.save();

    // 2. Tự động ghi Diary nếu là FOOD
    if (product.category === 'food') {
      let diary = await Diary.findOne({ userId, date: today });
      if (!diary) diary = new Diary({ userId, date: today });

      const mealField = getMealFieldByHour(new Date().getHours());
      
      diary[mealField].push({
        name: product.name,
        amount: `${quantity} phần`,
        kcal: (product.calories || 0) * quantity,
        calories: (product.calories || 0) * quantity,
        carb: 0,
        protein: 0,
        fat: 0,
        time: new Date().toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' }),
        source: 'shop',
        productId: product._id.toString(),
      });
      await diary.save();

      await Order.create({
        userId,
        productId: product._id,
        productName: product.name,
        productCategory: product.category,
        productImageUrl: product.imageUrl || '',
        quantity,
        totalVnd: productTotalVnd,
        totalCalo: cost,
        address: deliveryAddress,
        deliveryAddress,
        coordinates: { lat, lng },
        distanceKm,
        shippingFee,
        totalAmount,
        billUrl,
        mealField,
        status: 'pending',
        createdAtText: new Date().toLocaleString('vi-VN'),
      });
    } else {
      await Order.create({
        userId,
        productId: product._id,
        productName: product.name,
        productCategory: product.category,
        productImageUrl: product.imageUrl || '',
        quantity,
        totalVnd: productTotalVnd,
        totalCalo: cost,
        address: deliveryAddress,
        deliveryAddress,
        coordinates: { lat, lng },
        distanceKm,
        shippingFee,
        totalAmount,
        billUrl,
        mealField: '',
        status: 'pending',
        createdAtText: new Date().toLocaleString('vi-VN'),
      });
    }

    // 3. Gửi Email thông báo đơn hàng cho Tuấn
    const mailOptions = {
      from: '"HealthyLife System" <phantuan9d@gmail.com>',
      to: 'phantuan9d@gmail.com',
      subject: `[ĐƠN HÀNG MỚI] - ${user.name.toUpperCase()}`,
      html: `
        <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee;">
          <h2 style="color: #76B543;">Thông tin đơn hàng mới</h2>
          <p><b>Khách hàng:</b> ${user.name} (${user.email})</p>
          <p><b>Sản phẩm:</b> ${product.name}</p>
          <p><b>Số lượng:</b> ${quantity}</p>
          <p><b>Tiền sản phẩm:</b> ${productTotalVnd} VNĐ + ${cost} kcal</p>
          <p><b>Khoảng cách:</b> ${distanceKm} km</p>
          <p><b>Phí giao hàng:</b> ${shippingFee} VNĐ</p>
          <p><b>Tổng thanh toán:</b> ${totalAmount} VNĐ</p>
          <p><b>Địa chỉ nhận:</b> <span style="color: #e74c3c;">${deliveryAddress}</span></p>
          <p><b>Tọa độ nhận:</b> ${lat}, ${lng}</p>
          ${billUrl ? `<p><b>Ảnh minh chứng thanh toán:</b></p><img src="${billUrl}" width="250" style="border-radius: 8px; border: 1px solid #ddd;"/><br><a href="${billUrl}">Xem ảnh gốc</a>` : '<p><b>Ảnh minh chứng thanh toán:</b> Không đính kèm</p>'}
        </div>
      `
    };

    try {
      await transporter.sendMail(mailOptions);
    } catch (mailError) {
      console.error('Mail send failed:', mailError.message);
    }

    res.json({
      success: true,
      message: 'Đặt hàng thành công!',
      newBalance: user.targetCalo,
      delivery: {
        distanceKm,
        shippingFee,
        totalAmount,
        storeCoordinates: STORE_COORDINATES,
        userCoordinates: { lat, lng }
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;