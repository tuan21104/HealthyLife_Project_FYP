const mongoose = require('mongoose');
const User = require('../models/User');
const Diary = require('../models/Diary');
const Expense = require('../models/Expense');
const Product = require('../models/Product');
const Chat = require('../models/Chat');

const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash';
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const MAX_HISTORY_MESSAGES = 15;

function getVietnamDateString(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);

  const year = parts.find((part) => part.type === 'year')?.value;
  const month = parts.find((part) => part.type === 'month')?.value;
  const day = parts.find((part) => part.type === 'day')?.value;

  return `${year}-${month}-${day}`;
}

function getMonthRange(date = new Date()) {
  const year = date.getFullYear();
  const month = date.getMonth();

  return {
    start: new Date(year, month, 1),
    end: new Date(year, month + 1, 1),
  };
}

function formatMoney(amount) {
  const value = Number(amount || 0);
  return `${new Intl.NumberFormat('vi-VN').format(Math.max(0, value))} VND`;
}

function asReadableValue(value, fallback) {
  if (value === null || value === undefined || value === '') {
    return fallback;
  }

  if (typeof value === 'number') {
    if (!Number.isFinite(value) || value <= 0) {
      return fallback;
    }
    return String(value);
  }

  const normalized = String(value).trim();
  return normalized || fallback;
}

function sumFoodCalories(mealEntries) {
  if (!Array.isArray(mealEntries)) {
    return 0;
  }

  return mealEntries.reduce((total, item) => {
    const calories = Number(item?.kcal ?? item?.calories ?? 0);
    return total + (Number.isFinite(calories) ? calories : 0);
  }, 0);
}

function sumBurnedCalories(exerciseEntries) {
  if (!Array.isArray(exerciseEntries)) {
    return 0;
  }

  return exerciseEntries.reduce((total, item) => {
    const burnedCalories = Number(item?.burnedCalories ?? 0);
    return total + (Number.isFinite(burnedCalories) ? burnedCalories : 0);
  }, 0);
}

function normalizeHistoryMessages(messages) {
  if (!Array.isArray(messages)) {
    return [];
  }

  return messages
    .map((message) => ({
      role: String(message?.role || '').trim(),
      text: String(message?.text || '').trim(),
    }))
    .filter((message) => ['user', 'model'].includes(message.role) && message.text.length > 0);
}

function buildContextString({ profile, diary, monthlySpent, products }) {
  const name = asReadableValue(profile?.name, 'Người dùng');
  const age = asReadableValue(profile?.age, 'chưa cập nhật');
  const gender = asReadableValue(profile?.gender, 'chưa cập nhật');
  const height = asReadableValue(profile?.height, 'chưa cập nhật');
  const weight = asReadableValue(profile?.weight, 'chưa cập nhật');
  const goal = asReadableValue(profile?.goal, 'chưa cập nhật');
  const monthlyBudget = Number(profile?.monthlyBudget || 0);
  const budgetText = formatMoney(monthlyBudget);
  const spentText = formatMoney(monthlySpent);
  const remainingText = formatMoney(Math.max(0, monthlyBudget - monthlySpent));

  const todayDate = diary?.date || getVietnamDateString();
  const waterIntake = Number(diary?.waterIntake || 0);
  const todayCalo = sumFoodCalories([
    ...(Array.isArray(diary?.breakfast) ? diary.breakfast : []),
    ...(Array.isArray(diary?.lunch) ? diary.lunch : []),
    ...(Array.isArray(diary?.snack) ? diary.snack : []),
    ...(Array.isArray(diary?.dinner) ? diary.dinner : []),
  ]);
  const todayBurned = sumBurnedCalories(diary?.exercise);
  const targetCalo = Number(diary?.targetCalo || profile?.targetCalo || 0);

  const productHighlights = Array.isArray(products)
    ? products.map((product) => ({
      n: asReadableValue(product?.name, 'Sản phẩm'),
      p: Number(product?.priceVND || 0),
      kcal: Number(product?.calories || product?.priceCalo || 0),
      c: asReadableValue(product?.category, 'food'),
    }))
    : [];

  const compactContext = {
    profile: {
      name,
      age,
      gender,
      heightCm: height,
      weightKg: weight,
      goal,
      monthlyBudgetVnd: Number(monthlyBudget || 0),
      monthlyBudgetText: budgetText,
    },
    today: {
      date: todayDate,
      waterMl: Number.isFinite(waterIntake) ? waterIntake : 0,
      intakeKcal: todayCalo,
      burnedKcal: todayBurned,
      targetKcal: targetCalo > 0 ? targetCalo : null,
    },
    finance: {
      spentThisMonthVnd: Number(monthlySpent || 0),
      remainingBudgetVnd: Math.max(0, Number(monthlyBudget || 0) - Number(monthlySpent || 0)),
      spentText,
      remainingText,
    },
    shopHighlights: productHighlights,
  };

  return JSON.stringify(compactContext);
}

function buildSystemPrompt(contextString) {
  return [
    'Bạn là chuyên gia sức khỏe cá nhân của người dùng.',
    'Dữ liệu người dùng hiện tại ở định dạng JSON (ngắn gọn):',
    contextString,
    '',
    'Quy tắc bắt buộc:',
    '- Luôn trả lời thân thiện, ngắn gọn, cá nhân hóa và gọi tên người dùng khi phù hợp.',
    '- Nếu người dùng hỏi về ăn uống, hãy đối chiếu với số calo và nước họ đã dùng hôm nay.',
    '- Nếu họ hỏi về mua sắm, hãy gợi ý sản phẩm phù hợp với mục tiêu sức khỏe và túi tiền, dựa trên tổng chi tiêu tháng này so với ngân sách.',
    '- Nếu câu hỏi ngoài sức khỏe, y tế, dinh dưỡng hoặc tập luyện, BẮT BUỘC từ chối cực kỳ ngắn gọn trong tối đa 1-2 câu, dưới 40 chữ. Không giải thích dài. Chỉ xin lỗi vì ngoài chuyên môn và hỏi họ có cần tư vấn sức khỏe không.',
    '- Không tự bịa số liệu. Nếu một trường dữ liệu còn trống, hãy suy luận thận trọng từ ngữ cảnh hoặc nói rằng dữ liệu chưa được cập nhật.',
  ].join('\n');
}

function buildConversationContents({ historyMessages, currentMessage, resolvedImagePart }) {
  const sanitizedHistory = normalizeHistoryMessages(historyMessages);
  const maxHistoryBeforeCurrent = Math.max(0, MAX_HISTORY_MESSAGES - 1);
  const recentHistory = sanitizedHistory.slice(-maxHistoryBeforeCurrent);

  const historyContents = recentHistory.map((message) => ({
    role: message.role,
    parts: [{ text: message.text }],
  }));

  const currentParts = [
    {
      text: currentMessage || 'Please analyze the attached image and provide personalized health advice based on the current user context.',
    },
    ...(resolvedImagePart ? [resolvedImagePart] : []),
  ];

  historyContents.push({
    role: 'user',
    parts: currentParts,
  });

  return historyContents;
}

function buildImagePart(imagePart) {
  if (!imagePart || typeof imagePart !== 'object') {
    return null;
  }

  const inlineData = imagePart.inlineData;
  if (!inlineData || typeof inlineData !== 'object') {
    return null;
  }

  const mimeType = String(inlineData.mimeType || '').trim();
  const data = String(inlineData.data || '').trim();

  if (!mimeType || !data) {
    return null;
  }

  return {
    inlineData: {
      mimeType,
      data,
    },
  };
}

async function appendChatMessage(userId, role, text) {
  const trimmedUserId = String(userId || '').trim();
  const trimmedText = String(text || '').trim();

  if (!trimmedUserId || !trimmedText) {
    return;
  }

  if (!['user', 'model'].includes(role)) {
    return;
  }

  await Chat.findOneAndUpdate(
    { userId: trimmedUserId },
    {
      $push: {
        messages: {
          role,
          text: trimmedText,
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
}

function buildErrorMessage(statusCode, bodyText) {
  if ([429, 500, 502, 503, 504].includes(statusCode)) {
    return 'The AI service is currently busy. Please try again in a moment.';
  }

  if (statusCode === 401 || statusCode === 403) {
    return 'Authentication error. Please check API configuration.';
  }

  if (statusCode === 400) {
    return 'Invalid request sent to AI service.';
  }

  const trimmedBody = String(bodyText || '').trim();
  return trimmedBody || 'Sorry, I am unable to respond right now. Please try again in a moment.';
}

function extractGeminiText(data) {
  const candidates = data?.candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) {
    return '';
  }

  const parts = candidates[0]?.content?.parts;
  if (!Array.isArray(parts) || parts.length === 0) {
    return '';
  }

  return parts
    .map((part) => String(part?.text || '').trim())
    .filter((value) => value.length > 0)
    .join(' ')
    .trim();
}

async function fetchPersonalizedContext(userId) {
  if (!mongoose.Types.ObjectId.isValid(userId)) {
    const error = new Error('userId is not valid');
    error.statusCode = 400;
    throw error;
  }

  const objectId = new mongoose.Types.ObjectId(userId);
  const today = getVietnamDateString();
  const { start: monthStart, end: monthEnd } = getMonthRange(new Date());

  // Fetch all personalization sources in parallel to keep response time low.
  const [profile, diary, expenseResult, products] = await Promise.all([
    User.findById(objectId)
      .select('name age gender height weight goal monthlyBudget targetCalo')
      .lean(),
    Diary.findOne({ userId: objectId, date: today }).lean(),
    Expense.aggregate([
      {
        $match: {
          userId: objectId,
          date: { $gte: monthStart, $lt: monthEnd },
        },
      },
      {
        $group: {
          _id: null,
          totalAmount: { $sum: '$amount' },
        },
      },
    ]),
    Product.find({})
      .select('name priceVND priceCalo calories category description')
      .sort({ _id: -1 })
      .limit(5)
      .lean(),
  ]);

  return {
    profile,
    diary,
    monthlySpent: Number(expenseResult?.[0]?.totalAmount || 0),
    products,
  };
}

async function generatePersonalizedReply({ userId, message, imagePart }) {
  const trimmedUserId = String(userId || '').trim();
  const trimmedMessage = String(message || '').trim();

  if (!trimmedUserId) {
    const error = new Error('userId is required');
    error.statusCode = 400;
    throw error;
  }

  if (!trimmedMessage && !imagePart) {
    const error = new Error('message or image is required');
    error.statusCode = 400;
    throw error;
  }

  if (!GEMINI_API_KEY) {
    const error = new Error('GEMINI_API_KEY is not configured');
    error.statusCode = 500;
    throw error;
  }

  const { profile, diary, monthlySpent, products } = await fetchPersonalizedContext(trimmedUserId);
  const existingChat = await Chat.findOne({ userId: trimmedUserId }).select('messages').lean();
  const historyMessages = Array.isArray(existingChat?.messages) ? existingChat.messages : [];
  const contextString = buildContextString({ profile, diary, monthlySpent, products });
  const systemPrompt = buildSystemPrompt(contextString);
  const resolvedImagePart = buildImagePart(imagePart);

  // Persist the user message first so chat history stays consistent even if the AI call fails.
  await appendChatMessage(trimmedUserId, 'user', trimmedMessage || '[Attached image]');

  const payload = {
    systemInstruction: {
      parts: [
        {
          text: systemPrompt,
        },
      ],
    },
    contents: buildConversationContents({
      historyMessages,
      currentMessage: trimmedMessage,
      resolvedImagePart,
    }),
  };

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    }
  );

  if (!response.ok) {
    const bodyText = await response.text();
    const error = new Error(buildErrorMessage(response.status, bodyText));
    error.statusCode = response.status;
    throw error;
  }

  const data = await response.json();
  const reply = extractGeminiText(data);

  if (!reply) {
    const error = new Error('Sorry, I am unable to respond right now. Please try again in a moment.');
    error.statusCode = 502;
    throw error;
  }

  await appendChatMessage(trimmedUserId, 'model', reply);

  return {
    reply,
    contextString,
    profile,
    diary,
    monthlySpent,
    products,
  };
}

module.exports = {
  generatePersonalizedReply,
};