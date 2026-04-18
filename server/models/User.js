const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const UserSchema = new mongoose.Schema({
    // 1. Thông tin đăng nhập (Bắt buộc)
    name: {
        type: String,
        required: true
    },
    email: {
        type: String,
        required: true,
        unique: true // Không được trùng email
    },
    phoneNumber: {
        type: String,
        default: ''
    },
    password: {
        type: String,
        required: true
    },
    isVerified: {
        type: Boolean,
        default: false
    },
    otpCode: {
        type: String,
        default: null
    },
    otpExpires: {
        type: Date,
        default: null
    },

    // 2. Thông tin chỉ số sức khỏe (Để tính BMI/TDEE)
    gender: {
        type: String,
        enum: ['Male', 'Female', 'Other'],
        default: 'Male'
    },
    age: {
        type: Number,
        default: 0
    },
    height: {
        type: Number, // cm
        default: 0
    },
    weight: {
        type: Number, // kg
        default: 0
    },
    weeklyMovement: {
        type: Number,
        default: 0
    },
    activityLevel: {
        type: String,
        enum: ['Sedentary', 'Light', 'Lightly Active', 'Moderate', 'Moderately Active', 'Active', 'Very Active'],
        default: 'Sedentary'
    },

    // 3. Mục tiêu & Ngân sách (Logic riêng của App)
    goal: {
        type: String, 
        default: 'maintain'
    },
    birthDate: {
        type: String,
        default: ''
    },
    dailyBudget: {
        type: Number, 
        default: 0
    },
    monthlyBudget: {
        type: Number,
        default: 10000000
    },
    targetWeight: {
        type: Number,
        default: null
    },
    targetWeightLoss: {
        type: Number,
        default: null
    },
    durationDays: {
        type: Number,
        default: null
    },
    maintenanceCalo: {
        type: Number,
        default: null
    },
    targetCalo: {
        type: Number,
        default: null
    },
    avatarUrl: { // Thêm trường avatarUrl
        type: String,
        default: ''
    },
    avatarIndex: { 
        type: Number, 
        default: null 
    },
    fcmToken: {
        type: String,
        default: ''
    },
    
    // 4. Kết quả tính toán (Server tự tính và lưu vào đây)
    bmi: { type: Number, default: 0 },
    tdee: { type: Number, default: 0 }
}, {
    timestamps: true // Tự động tạo ngày created_at, updated_at
});

// --- MIDDEWARE: Tự động mã hóa mật khẩu trước khi lưu ---
UserSchema.pre('save', async function() { 
    if (!this.isModified('password')) {
        return; 
    }
    
    // Nếu có thay đổi, tiến hành mã hóa
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
});

module.exports = mongoose.model('User', UserSchema);