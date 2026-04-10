const express = require('express');
const router = express.Router();
const Product = require('../models/Product');
const User = require('../models/User');
const Diary = require('../models/Diary');
const Order = require('../models/Order');
const nodemailer = require('nodemailer');

const IMAGE_FALLBACKS = {
  food:
    'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80',
  equipment:
    'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&w=1200&q=80',
  default:
    'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&w=1200&q=80',
};

const IMAGE_CHECK_TIMEOUT_MS = 3500;
const IMAGE_CHECK_CACHE_TTL_MS = 1000 * 60 * 60 * 6;
const imageHealthCache = new Map();

function getCategoryFallback(category) {
  const key = (category || '').toString().toLowerCase();
  return IMAGE_FALLBACKS[key] || IMAGE_FALLBACKS.default;
}

function normalizeImageUrl(url) {
  const raw = (url || '').toString().trim();
  if (!raw) return '';

  if (raw.includes('images.unsplash.com') && !raw.includes('?')) {
    return `${raw}?auto=format&fit=crop&w=1200&q=80`;
  }

  return raw;
}

function hasFreshCache(url) {
  const entry = imageHealthCache.get(url);
  return !!entry && entry.expiresAt > Date.now();
}

async function isImageUrlReachable(url) {
  if (!url) return false;

  if (hasFreshCache(url)) {
    return imageHealthCache.get(url).ok;
  }

  let ok = false;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), IMAGE_CHECK_TIMEOUT_MS);

  try {
    const response = await fetch(url, {
      method: 'GET',
      signal: controller.signal,
      headers: {
        'User-Agent': 'HealthyLife-Image-Checker/1.0',
      },
    });

    const contentType = (response.headers.get('content-type') || '').toLowerCase();
    ok = response.ok && contentType.startsWith('image/');
  } catch (_) {
    ok = false;
  } finally {
    clearTimeout(timeout);
  }

  imageHealthCache.set(url, {
    ok,
    expiresAt: Date.now() + IMAGE_CHECK_CACHE_TTL_MS,
  });

  return ok;
}

async function resolveImageUrlOrFallback(imageUrl, category) {
  const normalized = normalizeImageUrl(imageUrl);
  const fallback = getCategoryFallback(category);

  if (!normalized) return fallback;

  const reachable = await isImageUrlReachable(normalized);
  return reachable ? normalized : fallback;
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
    const safeProducts = await Promise.all(
      products.map(async (productDoc) => {
        const product = productDoc.toObject();
        product.imageUrl = await resolveImageUrlOrFallback(
          product.imageUrl,
          product.category
        );
        return product;
      })
    );
    res.json({ success: true, products: safeProducts });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/history/:userId', async (req, res) => {
  try {
    const orders = await Order.find({ userId: req.params.userId })
      .sort({ createdAt: -1 })
      .limit(100);

    const safeOrders = await Promise.all(
      orders.map(async (orderDoc) => {
        const order = orderDoc.toObject();
        order.productImageUrl = await resolveImageUrlOrFallback(
          order.productImageUrl,
          order.productCategory
        );
        return order;
      })
    );

    res.json({ success: true, orders: safeOrders });
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
  const distanceKmRaw = Number(req.body.distanceKm);
  const shippingFeeRaw = Number(req.body.shippingFee);
  const distanceKm = Number.isFinite(distanceKmRaw)
    ? Number(distanceKmRaw.toFixed(2))
    : 0;
  const shippingFee = Number.isFinite(shippingFeeRaw)
    ? Math.max(0, Math.round(shippingFeeRaw))
    : 0;
  const hasValidCoordinates =
    Number.isFinite(lat) && Number.isFinite(lng) && !(lat === 0 && lng === 0);
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

    const productTotalVnd = (product.priceVND || 0) * quantity;
    const totalAmount = productTotalVnd + shippingFee;
    const safeProductImageUrl = await resolveImageUrlOrFallback(
      product.imageUrl,
      product.category
    );

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
        productImageUrl: safeProductImageUrl,
        quantity,
        totalVnd: productTotalVnd,
        totalCalo: cost,
        address: deliveryAddress,
        deliveryAddress,
        ...(hasValidCoordinates ? { coordinates: { lat, lng } } : {}),
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
        productImageUrl: safeProductImageUrl,
        quantity,
        totalVnd: productTotalVnd,
        totalCalo: cost,
        address: deliveryAddress,
        deliveryAddress,
        ...(hasValidCoordinates ? { coordinates: { lat, lng } } : {}),
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
        totalAmount
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;