const express = require('express');
const router = express.Router();
const { sendPushNotification } = require('../services/firebaseService');

router.post('/push', async (req, res) => {
  try {
    const { fcmToken, title, body, data } = req.body;

    if (!fcmToken || typeof fcmToken !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'fcmToken là bắt buộc và phải là chuỗi',
      });
    }

    if (!title || typeof title !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'title là bắt buộc và phải là chuỗi',
      });
    }

    if (!body || typeof body !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'body là bắt buộc và phải là chuỗi',
      });
    }

    const result = await sendPushNotification(
      fcmToken.trim(),
      title.trim(),
      body.trim(),
      data && typeof data === 'object' ? data : {}
    );

    const statusCode = result.success ? 200 : 400;
    return res.status(statusCode).json({
      success: result.success,
      request: {
        hasToken: true,
        title: title.trim(),
        body: body.trim(),
      },
      result,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
