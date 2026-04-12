const router = require('express').Router();
const User = require('../models/User'); 
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { sendMail } = require('../services/mailer');
const JWT_SECRET = process.env.JWT_SECRET || 'SECRET_KEY_CUA_BAN';

function generateOtpCode() {
    return String(Math.floor(100000 + Math.random() * 900000));
}

function getOtpExpiry(minutes = 10) {
    return new Date(Date.now() + minutes * 60 * 1000);
}

function buildOtpMail({ name, otpCode, purpose }) {
    const safeName = name || 'bạn';
    const actionText = purpose === 'verify' ? 'xac thuc email' : 'dat lai mat khau';

    return {
        subject: `[HealthyLife] Ma OTP ${actionText}`,
        text: `Xin chao ${safeName},\n\nMa OTP de ${actionText} cua ban la: ${otpCode}\nMa co hieu luc trong 10 phut.\n\nNeu ban khong thuc hien yeu cau nay, vui long bo qua email nay.`,
        html: `<p>Xin chao <strong>${safeName}</strong>,</p><p>Ma OTP de <strong>${actionText}</strong> cua ban la:</p><h2 style="letter-spacing:2px;">${otpCode}</h2><p>Ma co hieu luc trong <strong>10 phut</strong>.</p><p>Neu ban khong thuc hien yeu cau nay, vui long bo qua email nay.</p>`,
    };
}

// --- API 1: ĐĂNG KÝ (REGISTER) ---
// Endpoint: POST http://localhost:3000/api/auth/register
router.post('/register', async (req, res) => {
    try {
        // 1. Nhận dữ liệu từ form Sign Up (Figma)
        const { email, password, name } = req.body;

        // 2. Kiểm tra xem email này đã đăng ký chưa
        const userExists = await User.findOne({ email });
        if (userExists) {
            if (userExists.isVerified) {
                return res.status(400).json({ message: 'Email này đã được sử dụng!' });
            }

            const otpCode = generateOtpCode();
            userExists.password = password;
            userExists.name = name || userExists.name || 'New User';
            userExists.otpCode = otpCode;
            userExists.otpExpires = getOtpExpiry(10);
            await userExists.save();

            const mail = buildOtpMail({
                name: userExists.name,
                otpCode,
                purpose: 'verify',
            });

            await sendMail({
                to: userExists.email,
                subject: mail.subject,
                text: mail.text,
                html: mail.html,
            });

            return res.status(200).json({
                message: 'Tai khoan chua xac thuc. OTP moi da duoc gui lai vao email cua ban.',
            });
        }

        // 3. Tạo user mới 
        const otpCode = generateOtpCode();
        const otpExpires = getOtpExpiry(10);

        const newUser = new User({
            name: name || "New User", 
            email,
            password,
            otpCode,
            otpExpires,
            isVerified: false,
        });

        // 4. Lưu vào MongoDB
        await newUser.save();

        const mail = buildOtpMail({
            name: newUser.name,
            otpCode,
            purpose: 'verify',
        });

        try {
            await sendMail({
                to: email,
                subject: mail.subject,
                text: mail.text,
                html: mail.html,
            });
        } catch (mailError) {
            await User.deleteOne({ _id: newUser._id });
            throw mailError;
        }

        res.status(201).json({ message: 'Đăng ký thành công! Vui lòng kiểm tra email để xác thực OTP.' });

    } catch (error) {
        if (error.message && error.message.includes('EMAIL_CONFIG_MISSING')) {
            return res.status(500).json({
                message: 'Cau hinh email chua day du. Vui long cap nhat MAIL_USER/MAIL_PASS hoac MAILTRAP_USER/MAILTRAP_PASS trong server/.env',
            });
        }
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
        const token = jwt.sign({ _id: user._id }, JWT_SECRET, { expiresIn: '7d' });

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
        const verified = jwt.verify(token, JWT_SECRET); 

        // 3. Tìm user trong Database theo ID vừa giải mã (Ẩn đi trường password cho an toàn)
        const user = await User.findById(verified._id).select('-password');
        if (!user) return res.status(404).json({ message: 'Không tìm thấy người dùng!' });

        // 4. Trả dữ liệu về cho App
        res.json({ success: true, user });

    } catch (error) {
        res.status(400).json({ message: 'Token không hợp lệ hoặc đã hết hạn!' });
    }
});

// --- API 5: QUÊN MẬT KHẨU (FORGOT PASSWORD) ---
// Endpoint: POST http://localhost:3000/api/auth/forgot-password
router.post('/forgot-password', async (req, res) => {
    try {
        const { email } = req.body;
        if (!email) {
            return res.status(400).json({ message: 'Email là bắt buộc.' });
        }

        const user = await User.findOne({ email });
        if (!user) {
            return res.status(404).json({ message: 'Email không tồn tại trong hệ thống.' });
        }

        const otpCode = generateOtpCode();
        user.otpCode = otpCode;
        user.otpExpires = getOtpExpiry(10);
        await user.save();

        const mail = buildOtpMail({
            name: user.name,
            otpCode,
            purpose: 'reset',
        });

        await sendMail({
            to: user.email,
            subject: mail.subject,
            text: mail.text,
            html: mail.html,
        });

        return res.status(200).json({ message: 'OTP đã được gửi đến email của bạn.' });
    } catch (error) {
        return res.status(500).json({ message: 'Lỗi Server: ' + error.message });
    }
});

// --- API 5.1: KIỂM TRA OTP QUÊN MẬT KHẨU (VERIFY RESET OTP) ---
// Endpoint: POST http://localhost:3000/api/auth/verify-reset-otp
router.post('/verify-reset-otp', async (req, res) => {
    try {
        const { email, otpCode } = req.body;
        if (!email || !otpCode) {
            return res.status(400).json({ message: 'Thiếu thông tin email hoặc otpCode.' });
        }

        const user = await User.findOne({ email });
        if (!user) {
            return res.status(404).json({ message: 'Email không tồn tại trong hệ thống.' });
        }

        const isOtpMatched = user.otpCode && user.otpCode === String(otpCode).trim();
        const isOtpExpired = !user.otpExpires || new Date(user.otpExpires).getTime() < Date.now();

        if (!isOtpMatched || isOtpExpired) {
            return res.status(400).json({ message: 'OTP không hợp lệ hoặc đã hết hạn.' });
        }

        return res.status(200).json({ message: 'OTP hợp lệ.' });
    } catch (error) {
        return res.status(500).json({ message: 'Lỗi Server: ' + error.message });
    }
});

// --- API 5.2: GỬI LẠI OTP XÁC THỰC ĐĂNG KÝ ---
// Endpoint: POST http://localhost:3000/api/auth/resend-signup-otp
router.post('/resend-signup-otp', async (req, res) => {
    try {
        const { email } = req.body;
        if (!email) {
            return res.status(400).json({ message: 'Email là bắt buộc.' });
        }

        const user = await User.findOne({ email });
        if (!user) {
            return res.status(404).json({ message: 'Email không tồn tại trong hệ thống.' });
        }

        if (user.isVerified) {
            return res.status(400).json({ message: 'Tài khoản đã được xác thực trước đó.' });
        }

        const otpCode = generateOtpCode();
        user.otpCode = otpCode;
        user.otpExpires = getOtpExpiry(10);
        await user.save();

        const mail = buildOtpMail({
            name: user.name,
            otpCode,
            purpose: 'verify',
        });

        await sendMail({
            to: user.email,
            subject: mail.subject,
            text: mail.text,
            html: mail.html,
        });

        return res.status(200).json({ message: 'Đã gửi lại OTP xác thực email.' });
    } catch (error) {
        return res.status(500).json({ message: 'Lỗi Server: ' + error.message });
    }
});

// --- API 6: ĐẶT LẠI MẬT KHẨU (RESET PASSWORD) ---
// Endpoint: POST http://localhost:3000/api/auth/reset-password
router.post('/reset-password', async (req, res) => {
    try {
        const { email, otpCode, newPassword } = req.body;
        if (!email || !otpCode || !newPassword) {
            return res.status(400).json({ message: 'Thiếu thông tin email, otpCode hoặc newPassword.' });
        }

        const user = await User.findOne({ email });
        if (!user) {
            return res.status(404).json({ message: 'Email không tồn tại trong hệ thống.' });
        }

        const isOtpMatched = user.otpCode && user.otpCode === String(otpCode).trim();
        const isOtpExpired = !user.otpExpires || new Date(user.otpExpires).getTime() < Date.now();

        if (!isOtpMatched || isOtpExpired) {
            return res.status(400).json({ message: 'OTP không hợp lệ hoặc đã hết hạn.' });
        }

        const hashedPassword = await bcrypt.hash(newPassword, 10);
        await User.findByIdAndUpdate(user._id, {
            password: hashedPassword,
            otpCode: null,
            otpExpires: null,
        });

        return res.status(200).json({ message: 'Đặt lại mật khẩu thành công.' });
    } catch (error) {
        return res.status(500).json({ message: 'Lỗi Server: ' + error.message });
    }
});

// --- API 7: XÁC THỰC EMAIL (VERIFY EMAIL) ---
// Endpoint: POST http://localhost:3000/api/auth/verify-email
router.post('/verify-email', async (req, res) => {
    try {
        const { email, otpCode } = req.body;
        if (!email || !otpCode) {
            return res.status(400).json({ message: 'Thiếu thông tin email hoặc otpCode.' });
        }

        const user = await User.findOne({ email });
        if (!user) {
            return res.status(404).json({ message: 'Email không tồn tại trong hệ thống.' });
        }

        const isOtpMatched = user.otpCode && user.otpCode === String(otpCode).trim();
        const isOtpExpired = !user.otpExpires || new Date(user.otpExpires).getTime() < Date.now();

        if (!isOtpMatched || isOtpExpired) {
            return res.status(400).json({ message: 'OTP không hợp lệ hoặc đã hết hạn.' });
        }

        user.isVerified = true;
        user.otpCode = null;
        user.otpExpires = null;
        await user.save();

        return res.status(200).json({ message: 'Xác thực email thành công.' });
    } catch (error) {
        return res.status(500).json({ message: 'Lỗi Server: ' + error.message });
    }
});

module.exports = router;