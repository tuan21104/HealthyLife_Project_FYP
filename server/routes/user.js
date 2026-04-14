const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const User = require('../models/User');

function normalizeActivityLevel(value) {
  if (typeof value !== 'string') return value;
  const normalized = value.trim();
  const alias = {
    'Lightly Active': 'Lightly Active',
    'Moderately Active': 'Moderately Active',
    'Very Active': 'Very Active',
    Sedentary: 'Sedentary',
    Light: 'Lightly Active',
    Moderate: 'Moderately Active',
    Active: 'Very Active',
  };
  return alias[normalized] || normalized;
}

function normalizeGender(value) {
  if (typeof value !== 'string') return value;
  const normalized = value.trim();
  const alias = {
    Male: 'Male',
    male: 'Male',
    Female: 'Female',
    female: 'Female',
    Other: 'Other',
    other: 'Other',
    'onboarding.male': 'Male',
    'onboarding.female': 'Female',
    'onboarding.other': 'Other',
  };
  return alias[normalized] || normalized;
}

// 1. API LẤY THÔNG TIN PROFILE
router.get('/:id', async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('-password'); 
    if (!user) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy người dùng' });
    }
    res.status(200).json({ success: true, user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

//2 update
router.put('/update', async (req, res) => {
  // LOG 1: Xem App gửi cái gì lên
  console.log("==== 📥 SERVER NHẬN REQ UPDATE PROFILE ====");
  console.log("Body nhận được:", req.body); 

  try {
    const { userId, ...updateData } = req.body;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ success: false, message: 'userId không hợp lệ' });
    }

    const user = await User.findById(userId);
    if (!user) {
      console.log("==== ❌ KHÔNG TÌM THẤY USER ID:", userId);
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const allowedFields = [
      'name',
      'email',
      'phoneNumber',
      'avatarUrl',
      'avatarIndex',
      'gender',
      'age',
      'height',
      'weight',
      'weeklyMovement',
      'activityLevel',
      'goal',
      'birthDate',
      'dailyBudget',
      'monthlyBudget',
      'targetWeight',
      'targetWeightLoss',
      'durationDays',
      'maintenanceCalo',
      'targetCalo'
    ];

    const sanitizedUpdate = {};
    for (const field of allowedFields) {
      if (updateData[field] !== undefined) {
        sanitizedUpdate[field] = updateData[field];
      }
    }

    if (sanitizedUpdate.activityLevel !== undefined) {
      sanitizedUpdate.activityLevel = normalizeActivityLevel(sanitizedUpdate.activityLevel);
    }

    if (sanitizedUpdate.gender !== undefined) {
      sanitizedUpdate.gender = normalizeGender(sanitizedUpdate.gender);
      if (!['Male', 'Female', 'Other'].includes(sanitizedUpdate.gender)) {
        return res.status(400).json({ success: false, message: 'gender không hợp lệ' });
      }
    }

    if (sanitizedUpdate.phoneNumber !== undefined) {
      sanitizedUpdate.phoneNumber = String(sanitizedUpdate.phoneNumber).trim();
    }

    const numericFields = [
      'age',
      'height',
      'weight',
      'weeklyMovement',
      'dailyBudget',
      'monthlyBudget',
      'targetWeight',
      'targetWeightLoss',
      'durationDays',
      'maintenanceCalo',
      'targetCalo',
      'avatarIndex',
    ];

    for (const field of numericFields) {
      if (sanitizedUpdate[field] === null) continue;
      if (sanitizedUpdate[field] !== undefined) {
        const parsed = Number(sanitizedUpdate[field]);
        if (Number.isFinite(parsed)) {
          sanitizedUpdate[field] = parsed;
        } else {
          delete sanitizedUpdate[field];
        }
      }
    }

    console.log("==== 🧼 SANITIZED UPDATE ====");
    console.log(sanitizedUpdate);

    Object.entries(sanitizedUpdate).forEach(([key, value]) => {
      user.set(key, value);
    });

    const updatedUser = await user.save();

    console.log("==== ✅ CẬP NHẬT DB THÀNH CÔNG ====");
    console.log({
      _id: updatedUser._id,
      height: updatedUser.height,
      weight: updatedUser.weight,
      activityLevel: updatedUser.activityLevel,
      avatarUrl: updatedUser.avatarUrl,
      updatedAt: updatedUser.updatedAt,
    });
    
    res.status(200).json({ success: true, user: updatedUser.toObject({ versionKey: false, transform: (_, ret) => { delete ret.password; return ret; } }) });
  } catch (error) {
    console.error("==== 💥 LỖI SERVER KHI UPDATE:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

// 3. API CẬP NHẬT NGÂN SÁCH THÁNG
router.put('/:userId/budget', async (req, res) => {
  try {
    const { userId } = req.params;
    const { newBudget } = req.body;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ success: false, message: 'userId không hợp lệ' });
    }

    const parsedBudget = Number(newBudget);
    if (!Number.isFinite(parsedBudget) || parsedBudget < 0) {
      return res.status(400).json({ success: false, message: 'newBudget phải là số không âm' });
    }

    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { monthlyBudget: parsedBudget },
      { new: true }
    ).select('-password');

    if (!updatedUser) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy người dùng' });
    }

    return res.status(200).json({ success: true, user: updatedUser });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;