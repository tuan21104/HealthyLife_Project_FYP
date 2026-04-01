const mongoose = require('mongoose');

const productSchema = new mongoose.Schema({
  name: { type: String, required: true },
  priceCalo: { type: Number, required: true },
  priceVND: { type: Number, required: true },
  imageUrl: { type: String },
  description: { type: String },
  // 'food' thì ghi vào diary, 'equipment' thì không
  category: { type: String, enum: ['food', 'equipment'], default: 'food' }, 
  calories: { type: Number, default: 0 } // Lượng calo nạp vào nếu là food
});

module.exports = mongoose.model('Product', productSchema, 'products');