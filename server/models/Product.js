const mongoose = require('mongoose');

const productSchema = new mongoose.Schema({
  name: { type: String, required: true },
  priceCalo: { type: Number, required: true },
  priceVND: { type: Number, required: true },
  imageUrl: { type: String },
  description: { type: String },
  // 'food' thì ghi vào diary, 'equipment' thì không
  category: { type: String, enum: ['food', 'equipment'], default: 'food' },
  calories: { type: Number, default: 0 },
  carbs: { type: Number, default: 0 },
  protein: { type: Number, default: 0 },
  fat: { type: Number, default: 0 },
  fiber: { type: Number, default: 0 }
});

module.exports = mongoose.model('Product', productSchema, 'products');