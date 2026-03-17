const mongoose = require('mongoose');

const diarySchema = new mongoose.Schema({
  userId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'User', 
    required: true 
  },
  date: { 
    type: String, 
    required: true // Định dạng: YYYY-MM-DD
  }, 
  targetCalo: { type: Number, default: 1200 },
  targetCarb: { type: Number, default: 150 },
  targetProtein: { type: Number, default: 60 },
  targetFat: { type: Number, default: 40 },
  
  // Lưu danh sách món ăn của từng bữa
  breakfast: { type: Array, default: [] },
  lunch: { type: Array, default: [] },
  snack: { type: Array, default: [] },
  dinner: { type: Array, default: [] }
}, { timestamps: true });

// Đảm bảo 1 User chỉ có 1 bản ghi duy nhất cho 1 ngày
diarySchema.index({ userId: 1, date: 1 }, { unique: true });

module.exports = mongoose.model('Diary', diarySchema);