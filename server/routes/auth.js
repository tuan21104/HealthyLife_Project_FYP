const router = require('express').Router();
const User = require('../models/User'); 
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// --- API 1: ĐĂNG KÝ (REGISTER) ---
// Endpoint: POST http://localhost:3000/api/auth/register
router.post('/register', async (req, res) => {
    try {
        // 1. Nhận dữ liệu từ form Sign Up (Figma)
        const { email, password, name } = req.body;

        // 2. Kiểm tra xem email này đã đăng ký chưa
        const userExists = await User.findOne({ email });
        if (userExists) {
            return res.status(400).json({ message: 'Email này đã được sử dụng!' });
        }

        // 3. Tạo user mới 
        const newUser = new User({
            name: name || "New User", 
            email,
            password
        });

        // 4. Lưu vào MongoDB
        await newUser.save();

        res.status(201).json({ message: 'Đăng ký thành công! Hãy đăng nhập.' });

    } catch (error) {
        res.status(500).json({ message: 'Lỗi Server: ' + error.message });
    }
});

// --- API 2: ĐĂNG NHẬP (LOGIN) ---
// Endpoint: POST http://localhost:3000/api/auth/login
router.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        // 1. Tìm user theo email
        const user = await User.findOne({ email });
        if (!user) return res.status(400).json({ message: 'Email hoặc mật khẩu sai!' });

        // 2. So sánh mật khẩu (User nhập vs Database)
        const validPass = await bcrypt.compare(password, user.password);
        if (!validPass) return res.status(400).json({ message: 'Email hoặc mật khẩu sai!' });

        // 3. Tạo "thẻ bài" (Token) để user cầm đi lại trong app
        const token = jwt.sign({ _id: user._id }, 'SECRET_KEY_CUA_BAN', { expiresIn: '7d' });

        res.json({
            token,
            user: {
                id: user._id,
                name: user.name,
                email: user.email,
                bmi: user.bmi
            }
        });

    } catch (error) {
        res.status(500).json({ message: 'Lỗi Server: ' + error.message });
    }
});

// --- API 3: CẬP NHẬT HỒ SƠ (UPDATE PROFILE) ---
// Endpoint: POST http://localhost:3000/api/auth/update-profile
router.post('/update-profile', async (req, res) => {
    try {
        const { email, ...updateData } = req.body; // Lấy email để tìm user, các dữ liệu còn lại để update

        // Tìm user theo email và cập nhật dữ liệu mới
        const updatedUser = await User.findOneAndUpdate(
            { email: email },
            { $set: updateData },
            { new: true } 
        );

        if (!updatedUser) {
            return res.status(404).json({ success: false, message: 'User không tồn tại!' });
        }

        res.json({
            success: true, 
            message: 'Cập nhật thành công!',
            user: updatedUser
        });

    } catch (error) {
        res.status(500).json({ success: false, message: 'Lỗi Server: ' + error.message });
    }
});

module.exports = router;