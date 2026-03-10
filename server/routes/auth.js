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

        // 4. KIỂM TRA XEM ĐÃ NHẬP PROFILE CHƯA
        // Nếu user có lưu chiều cao (height) thì coi như đã làm xong Onboarding
        const hasProfile = !!user.height && user.height !== 0 && user.height !== "0";

        res.status(200).json({
            message: "Đăng nhập thành công", // Thêm dòng này để Frontend dễ bắt thông báo
            token,
            hasProfile: hasProfile, // Gửi cờ báo hiệu về cho App Flutter
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
        
        // In ra Terminal để kiểm tra xem App có gửi avatarIndex lên không
        console.log(`[Update Profile] Đang cập nhật cho email: ${email}`);
        console.log(`[Update Profile] Dữ liệu nhận được:`, updateData); 

        // Tìm user theo email và cập nhật dữ liệu mới
        const updatedUser = await User.findOneAndUpdate(
            { email: email },
            { $set: updateData },
            { new: true } // Trả về document sau khi đã update
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
        console.error("[Update Profile] Lỗi Server:", error);
        res.status(500).json({ success: false, message: 'Lỗi Server: ' + error.message });
    }
});

// --- API 4: LẤY THÔNG TIN USER (GET PROFILE) ---
// Endpoint: GET http://localhost:3000/api/auth/me
router.get('/me', async (req, res) => {
    try {
        // 1. Lấy Token từ header do App gửi lên
        const token = req.header('Authorization')?.replace('Bearer ', '');
        if (!token) return res.status(401).json({ message: 'Không có token, từ chối truy cập!' });

        // 2. Giải mã Token để biết đây là ai (Nhớ dùng đúng Secret Key lúc Login)
        const verified = jwt.verify(token, 'SECRET_KEY_CUA_BAN'); 

        // 3. Tìm user trong Database theo ID vừa giải mã (Ẩn đi trường password cho an toàn)
        const user = await User.findById(verified._id).select('-password');
        if (!user) return res.status(404).json({ message: 'Không tìm thấy người dùng!' });

        // 4. Trả dữ liệu về cho App
        res.json({ success: true, user });

    } catch (error) {
        res.status(400).json({ message: 'Token không hợp lệ hoặc đã hết hạn!' });
    }
});

module.exports = router;