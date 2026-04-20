const express = require('express');
const mongoose = require('mongoose');
const router = express.Router();
const Chat = require('../models/Chat');
const { generatePersonalizedReply } = require('../services/chatAssistant');

// GET /api/chat/:userId - Lấy toàn bộ lịch sử chat theo thứ tự cũ -> mới
router.get('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ success: false, message: 'userId không hợp lệ' });
    }

    const chat = await Chat.findOne({ userId }).lean();

    if (!chat) {
      return res.status(200).json({ success: true, messages: [] });
    }

    const messages = (chat.messages || []).sort(
      (a, b) => new Date(a.timestamp) - new Date(b.timestamp)
    );

    return res.status(200).json({ success: true, messages });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/chat/save - Lưu 1 tin nhắn chat
router.post('/save', async (req, res) => {
  try {
    const { userId, role, text } = req.body;

    if (!userId || !role || !text) {
      return res.status(400).json({
        success: false,
        message: 'Thiếu dữ liệu bắt buộc: userId, role, text',
      });
    }

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ success: false, message: 'userId không hợp lệ' });
    }

    if (!['user', 'model'].includes(role)) {
      return res.status(400).json({
        success: false,
        message: "role chỉ nhận 'user' hoặc 'model'",
      });
    }

    const chat = await Chat.findOneAndUpdate(
      { userId },
      {
        $push: {
          messages: {
            role,
            text,
            timestamp: new Date(),
          },
        },
      },
      {
        new: true,
        upsert: true,
        setDefaultsOnInsert: true,
      }
    );

    return res.status(200).json({
      success: true,
      message: 'Lưu lịch sử chat thành công',
      chat,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/chat/message - Tao phan hoi AI duoc ca nhan hoa tu du lieu MongoDB
router.post('/message', async (req, res) => {
  try {
    const { userId, message, imagePart } = req.body;

    const result = await generatePersonalizedReply({
      userId,
      message,
      imagePart,
    });

    return res.status(200).json({
      success: true,
      reply: result.reply,
      contextString: result.contextString,
    });
  } catch (error) {
    const statusCode = error.statusCode || 500;
    return res.status(statusCode).json({
      success: false,
      message: error.message,
    });
  }
});

module.exports = router;
