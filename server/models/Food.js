const mongoose = require('mongoose');

const foodSchema = new mongoose.Schema({
  name: { type: String, required: true }, 
  calories: { type: Number, required: true }, 
  protein: { type: Number, required: true }, 
  fat: { type: Number, required: true }, 
  carbs: { type: Number, required: true }, 
  category: { type: String, default: 'General' }, 
  pricePer100g: { type: Number, required: true }, 
  imageUrl: { type: String, default: '' } // Chuẩn bị sẵn cho tương lai nếu muốn thêm ảnh
}, { timestamps: true });

module.exports = mongoose.model('Food', foodSchema);