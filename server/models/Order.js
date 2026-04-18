const mongoose = require('mongoose');

const orderSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true },
  productName: { type: String, required: true },
  productCategory: { type: String, default: 'food' },
  productImageUrl: { type: String, default: '' },
  quantity: { type: Number, default: 1 },
  totalVnd: { type: Number, required: true },
  totalCalo: { type: Number, required: true }, // Số calo bị trừ
  address: { type: String, required: true },
  deliveryAddress: { type: String, default: '' },
  phoneNumber: { type: String, default: '' },
  coordinates: {
    lat: { type: Number, default: null },
    lng: { type: Number, default: null }
  },
  distanceKm: { type: Number, default: 0 },
  shippingFee: { type: Number, default: 0 },
  totalAmount: { type: Number, default: 0 },
  billUrl: { type: String, default: '' },
  items: [
    {
      productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product' },
      productName: { type: String, default: '' },
      productCategory: { type: String, default: '' },
      productImageUrl: { type: String, default: '' },
      quantity: { type: Number, default: 1 },
      totalVnd: { type: Number, default: 0 },
      totalCalo: { type: Number, default: 0 },
    }
  ],
  mealField: { type: String, default: '' },
  status: {
    type: String,
    enum: ['pending', 'delivering', 'completed', 'cancelled'],
    default: 'pending'
  },
  createdAtText: { type: String, default: '' },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Order', orderSchema);