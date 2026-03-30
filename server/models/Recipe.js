const mongoose = require('mongoose');

const recipeSchema = new mongoose.Schema({
  userId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'User', 
    required: true 
  },
  name: { type: String, required: true },
  description: { type: String },
  // Tổng Macros của cả công thức
  totalCalories: { type: Number, default: 0 },
  totalProtein: { type: Number, default: 0 },
  totalFat: { type: Number, default: 0 },
  totalCarbs: { type: Number, default: 0 },
  // Danh sách nguyên liệu
  ingredients: [{
    foodName: String,
    amount: String,
    calories: Number
  }],
  // Các bước thực hiện
  instructions: { type: String }
}, { timestamps: true });

module.exports = mongoose.model('Recipe', recipeSchema);