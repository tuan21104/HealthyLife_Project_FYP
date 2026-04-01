const mongoose = require('mongoose');

const orderSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true },
  totalCalo: { type: Number, required: true }, // Số calo bị trừ
  status: { type: String, default: 'Pending' }, // Pending, Completed
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Order', orderSchema);