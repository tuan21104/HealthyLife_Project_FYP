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
  billUrl: { type: String, default: '' },
  mealField: { type: String, default: '' },
  status: { type: String, default: 'Pending' }, // Pending, Completed
  createdAtText: { type: String, default: '' },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Order', orderSchema);