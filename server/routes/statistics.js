const express = require('express');
const router = express.Router();
const Diary = require('../models/Diary');
const User = require('../models/User'); // Đảm bảo dòng này có để lấy Avatar
const Expense = require('../models/Expense');

function toVNDateString(dateInput) {
    const parts = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Asia/Ho_Chi_Minh',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit'
    }).formatToParts(new Date(dateInput));

    const year = parts.find((p) => p.type === 'year')?.value;
    const month = parts.find((p) => p.type === 'month')?.value;
    const day = parts.find((p) => p.type === 'day')?.value;

    return `${year}-${month}-${day}`;
}

function formatYYYYMMDDUTC(date) {
    const year = date.getUTCFullYear();
    const month = String(date.getUTCMonth() + 1).padStart(2, '0');
    const day = String(date.getUTCDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

router.get('/home/:userId', async (req, res) => {
    console.log("==== 📥 SERVER NHẬN REQ THỐNG KÊ CHO:", req.params.userId);

    try {
        const userId = req.params.userId;
        const past7Days = [];

        // 1. Tạo mảng 7 ngày (Local Time VN)
        const vnTodayString = toVNDateString(new Date());
        const [todayYear, todayMonth, todayDay] = vnTodayString.split('-').map(Number);
        const vnToday = new Date(Date.UTC(todayYear, todayMonth - 1, todayDay));

        for (let i = 6; i >= 0; i--) {
            const d = new Date(vnToday);
            d.setUTCDate(vnToday.getUTCDate() - i);
            past7Days.push(formatYYYYMMDDUTC(d));
        }

        // 2. Tìm thông tin Avatar của User
        let userAvatarUrl = '';
        let avatarIndex = null;
        const user = await User.findById(userId);
        if (user) {
            if (user.avatarUrl) userAvatarUrl = user.avatarUrl;
            if (user.avatarIndex !== undefined) avatarIndex = user.avatarIndex;
        }

        // 3. Truy vấn Diary
        const diaries = await Diary.find({
            userId: userId,
            date: { $in: past7Days }
        });

        const expenses = await Expense.find({ userId }).select('amount date');

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

        // 5. Đổ dữ liệu chi tiêu từ collection Expense
        expenses.forEach((expense) => {
            const dateStr = toVNDateString(expense.date);
            const idx = past7Days.indexOf(dateStr);
            if (idx !== -1) {
                weeklyExpense[idx] += Number(expense.amount || 0);
            }
        });

        todayExpense = weeklyExpense[6] || 0;

        // 6. PHẢI TRẢ VỀ JSON NHƯ THẾ NÀY (Đúng cú pháp)
        res.status(200).json({
            success: true,
            data: {
                todayCalo,
                todayBurned,
                targetCalo,
                todayExpense,
                weeklyCalo,
                weeklyExpense,
                avatarUrl: userAvatarUrl,
                avatarIndex
            }
        });

    } catch (error) {
        console.error("❌ LỖI SERVER STATISTICS:", error.message);
        res.status(500).json({ success: false, message: error.message });
    }
});

module.exports = router;