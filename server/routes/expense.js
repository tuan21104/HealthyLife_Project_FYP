const express = require('express');
const mongoose = require('mongoose');
const router = express.Router();
const Expense = require('../models/Expense');
const User = require('../models/User');
const { sendPushNotification } = require('../services/firebaseService');

function getDayRange(date) {
  const start = new Date(date);
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(end.getDate() + 1);
  return { start, end };
}

function getMonthRange(date) {
  const year = date.getFullYear();
  const month = date.getMonth();
  const start = new Date(year, month, 1);
  const end = new Date(year, month + 1, 1);
  return { start, end };
}

function getDaysRemainingInMonth(date) {
  const year = date.getFullYear();
  const month = date.getMonth();
  const lastDay = new Date(year, month + 1, 0).getDate();
  return Math.max(1, lastDay - date.getDate() + 1);
}

async function getExpenseSum(userId, startDate, endDate) {
  const result = await Expense.aggregate([
    {
      $match: {
        userId: new mongoose.Types.ObjectId(userId),
        date: { $gte: startDate, $lt: endDate },
      },
    },
    {
      $group: {
        _id: null,
        totalAmount: { $sum: '$amount' },
      },
    },
  ]);

  return Number(result[0]?.totalAmount || 0);
}

router.get('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ success: false, message: 'userId không hợp lệ' });
    }

    const expenses = await Expense.find({ userId }).sort({ date: -1, createdAt: -1 });

    res.status(200).json({ success: true, expenses });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/add', async (req, res) => {
  try {
    const { userId, amount, category, note, date } = req.body;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ success: false, message: 'userId không hợp lệ' });
    }

    const parsedAmount = Number(amount);
    if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
      return res.status(400).json({ success: false, message: 'amount phải là số lớn hơn 0' });
    }

    if (!category || typeof category !== 'string' || !category.trim()) {
      return res.status(400).json({ success: false, message: 'category là bắt buộc' });
    }

    const expenseDate = date ? new Date(date) : new Date();
    if (Number.isNaN(expenseDate.getTime())) {
      return res.status(400).json({ success: false, message: 'date không hợp lệ' });
    }

    const expense = await Expense.create({
      userId,
      amount: parsedAmount,
      category: category.trim(),
      note: typeof note === 'string' ? note.trim() : '',
      date: expenseDate
    });

    const user = await User.findById(userId).select('monthlyBudget fcmToken');

    if (user) {
      const { start: dayStart, end: dayEnd } = getDayRange(expenseDate);
      const { start: monthStart, end: monthEnd } = getMonthRange(expenseDate);

      const totalSpentToday = await getExpenseSum(userId, dayStart, dayEnd);
      const totalSpentThisMonth = await getExpenseSum(userId, monthStart, monthEnd);

      const monthlyBudget = Number(user.monthlyBudget || 0);
      const daysRemaining = getDaysRemainingInMonth(expenseDate);
      const safeDailyBudget = (monthlyBudget - totalSpentThisMonth) / daysRemaining;
      const overspendingThreshold = safeDailyBudget * 1.2;

      if (totalSpentToday > overspendingThreshold && user.fcmToken) {
        await sendPushNotification(
          user.fcmToken,
          'Cảnh báo chi tiêu',
          'Cảnh báo: Bạn đã tiêu quá mức trung bình ngày hôm nay!',
          {
            type: 'expense_alert',
            userId: String(userId),
            date: expenseDate.toISOString(),
            totalSpentToday: totalSpentToday.toFixed(2),
            safeDailyBudget: safeDailyBudget.toFixed(2),
          }
        );
      }
    }

    res.status(201).json({ success: true, expense });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/expenses/:id?userId=... - Xoa 1 ban ghi chi tieu cua dung user
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const userId = (req.query.userId || req.body?.userId || '').toString().trim();

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ success: false, message: 'expenseId không hợp lệ' });
    }

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ success: false, message: 'userId không hợp lệ' });
    }

    const deletedExpense = await Expense.findOneAndDelete({
      _id: id,
      userId,
    });

    if (!deletedExpense) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy chi tiêu hoặc bạn không có quyền xoá',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Xoá chi tiêu thành công',
      expense: deletedExpense,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;