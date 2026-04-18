const cron = require('node-cron');
const User = require('../models/User');
const Diary = require('../models/Diary');
const { sendPushNotification } = require('../services/firebaseService');

function getVNDateString(dateInput = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(dateInput);

  const year = parts.find((p) => p.type === 'year')?.value;
  const month = parts.find((p) => p.type === 'month')?.value;
  const day = parts.find((p) => p.type === 'day')?.value;

  return `${year}-${month}-${day}`;
}

function toNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function calculateDiaryWaterMl(diary) {
  if (!diary) return 0;
  return toNumber(diary.waterIntake);
}

async function runWaterReminder() {
  try {
    const users = await User.find({
      fcmToken: { $exists: true, $nin: [null, ''] },
    }).select('_id weight fcmToken');

    if (users.length === 0) return;

    const todayVN = getVNDateString(new Date());
    const userIds = users.map((user) => user._id);

    const diaries = await Diary.find({
      userId: { $in: userIds },
      date: todayVN,
    }).select('userId waterIntake');

    const diaryMap = new Map();
    diaries.forEach((diary) => {
      diaryMap.set(String(diary.userId), diary);
    });

    for (const user of users) {
      const weight = toNumber(user.weight);
      if (weight <= 0) continue;

      const waterTargetMl = weight * 35;
      const diary = diaryMap.get(String(user._id));
      const consumedWaterMl = calculateDiaryWaterMl(diary);

      if (consumedWaterMl < waterTargetMl * 0.5) {
        await sendPushNotification(
          user.fcmToken,
          'Nhắc uống nước',
          'Cơ thể bạn đang khát! Hãy bổ sung thêm nước để đạt mục tiêu hôm nay nhé.',
          {
            type: 'water_reminder',
            userId: String(user._id),
            date: todayVN,
            consumedWaterMl: consumedWaterMl.toFixed(0),
            waterTargetMl: waterTargetMl.toFixed(0),
          }
        );
      }
    }
  } catch (error) {
    console.error('[waterReminder] Lỗi khi chạy job nhắc uống nước:', error.message);
  }
}

cron.schedule(
  '0 14,20 * * *',
  runWaterReminder,
  {
    timezone: 'Asia/Ho_Chi_Minh',
  }
);

console.log('[waterReminder] Cron job đã được đăng ký: 14:00 và 20:00 mỗi ngày (Asia/Ho_Chi_Minh).');

module.exports = {
  runWaterReminder,
};
