const express = require('express');
const router = express.Router();
const Diary = require('../models/Diary');
const User = require('../models/User'); // Đảm bảo dòng này có để lấy Avatar

router.get('/home/:userId', async (req, res) => {
    console.log("==== 📥 SERVER NHẬN REQ THỐNG KÊ CHO:", req.params.userId);

    try {
        const userId = req.params.userId;
        const past7Days = [];

        // 1. Tạo mảng 7 ngày (Local Time VN)
        const now = new Date();
        const offset = now.getTimezoneOffset() === 0 ? 7 * 60 * 60 * 1000 : 0;
        const vnToday = new Date(now.getTime() + offset);

        for (let i = 6; i >= 0; i--) {
            const d = new Date(vnToday);
            d.setDate(vnToday.getDate() - i);
            const year = d.getFullYear();
            const month = String(d.getMonth() + 1).padStart(2, '0');
            const day = String(d.getDate()).padStart(2, '0');
            past7Days.push(`${year}-${month}-${day}`);
        }

        // 2. Tìm thông tin Avatar của User
        let userAvatarUrl = '';
        const user = await User.findById(userId);
        if (user && user.avatarUrl) {
            userAvatarUrl = user.avatarUrl;
        }

        // 3. Truy vấn Diary
        const diaries = await Diary.find({
            userId: userId,
            date: { $in: past7Days }
        });

        let weeklyCalo = [0, 0, 0, 0, 0, 0, 0];
        let weeklyExpense = [0, 0, 0, 0, 0, 0, 0];
        let todayCalo = 0;
        let todayBurned = 0;
        let todayExpense = 0;
        let targetCalo = 1800;

        // 4. Đổ dữ liệu vào mảng
        past7Days.forEach((dateStr, index) => {
            const diary = diaries.find(d => d.date === dateStr);
            if (diary) {
                let calo = 0;
                let burned = 0;

                ['breakfast', 'lunch', 'snack', 'dinner'].forEach(meal => {
                    if (diary[meal]) {
                        diary[meal].forEach(f => calo += (f.kcal || f.calories || 0));
                    }
                });

                if (diary.exercise) {
                    diary.exercise.forEach(ex => burned += (ex.burnedCalories || 0));
                }

                weeklyCalo[index] = calo;
                if (index === 6) {
                    todayCalo = calo;
                    todayBurned = burned;
                    if (diary.targetCalo) targetCalo = diary.targetCalo;
                }
            }
        });

        // 5. PHẢI TRẢ VỀ JSON NHƯ THẾ NÀY (Đúng cú pháp)
        res.status(200).json({
            success: true,
            data: {
                todayCalo,
                todayBurned,
                targetCalo,
                todayExpense,
                weeklyCalo,
                weeklyExpense,
                avatarUrl: userAvatarUrl // <--- Avatar đã nằm gọn trong data
            }
        });

    } catch (error) {
        console.error("❌ LỖI SERVER STATISTICS:", error.message);
        res.status(500).json({ success: false, message: error.message });
    }
});

module.exports = router;