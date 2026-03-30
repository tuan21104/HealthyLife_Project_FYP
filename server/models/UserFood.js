const mongoose = require('mongoose');

const userFoodSchema = new mongoose.Schema({
  userId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'User', 
    required: true 
  },
  name: { type: String, required: true },
  calories: { type: Number, required: true },
  protein: { type: Number, required: true },
  fat: { type: Number, required: true },
  carbs: { type: Number, required: true },
  category: { type: String, default: 'My Foods' },
  amount: { type: String, default: '100g' } ,
  imageUrl: { type: String, default: "" }
}, { timestamps: true });

module.exports = mongoose.model('UserFood', userFoodSchema);