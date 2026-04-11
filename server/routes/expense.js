const express = require('express');
const mongoose = require('mongoose');
const router = express.Router();
const Expense = require('../models/Expense');

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

    res.status(201).json({ success: true, expense });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;