const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const User = require('../models/User');

function resolveServiceAccountPath(configPath) {
  if (!configPath) return null;

  const directPath = path.isAbsolute(configPath)
    ? configPath
    : path.resolve(process.cwd(), configPath);
  if (fs.existsSync(directPath)) return directPath;

  const fromServerRoot = path.resolve(__dirname, '..', configPath);
  if (fs.existsSync(fromServerRoot)) return fromServerRoot;

  return null;
}

function initializeFirebaseAdmin() {
  if (admin.apps.length > 0) {
    console.log('[firebaseService] Firebase Admin đã được khởi tạo trước đó, dùng instance cũ');
    return admin.app();
  }

  const configuredPath =
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
    process.env.FIREBASE_SERVICE_ACCOUNT_KEY_PATH;

  console.log('[firebaseService] Đang tìm kiếm Firebase Service Account...');
  console.log(`  - FIREBASE_SERVICE_ACCOUNT_PATH từ .env: ${configuredPath}`);

  if (!configuredPath) {
    console.error(
      '[firebaseService] ✗ FIREBASE_SERVICE_ACCOUNT_PATH và FIREBASE_SERVICE_ACCOUNT_KEY_PATH đều không được cấu hình trong .env'
    );
    return null;
  }

  const resolvedPath = resolveServiceAccountPath(configuredPath);
  console.log(`  - Đường dẫn tuyệt đối thử #1 (cwd): ${path.resolve(process.cwd(), configuredPath)}`);
  console.log(`  - Đường dẫn tuyệt đối thử #2 (server root): ${path.resolve(__dirname, '..', configuredPath)}`);
  console.log(`  - Đường dẫn cuối cùng được xác định: ${resolvedPath || '(không tìm thấy)'}`);

  if (!resolvedPath) {
    console.error(
      `[firebaseService] ✗ Không tìm thấy file serviceAccountKey.json tại: "${configuredPath}"\n` +
      `   Vui lòng đảm bảo file tồn tại tại một trong các vị trí:\n` +
      `   - ${path.resolve(process.cwd(), configuredPath)}\n` +
      `   - ${path.resolve(__dirname, '..', configuredPath)}`
    );
    return null;
  }

  try {
    console.log(`  - Đang đọc file: ${resolvedPath}`);
    const fileContent = fs.readFileSync(resolvedPath, 'utf8');
    console.log(`  - File đã đọc thành công, chiều dài: ${fileContent.length} bytes`);

    console.log(`  - Đang parse JSON...`);
    const serviceAccount = JSON.parse(fileContent);
    console.log(`  - JSON parse thành công`);

    console.log(`  - Đang khởi tạo Firebase Admin...`);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    console.log('[firebaseService] ✓ Firebase Admin khởi tạo thành công!');
    return admin.app();
  } catch (error) {
    console.error('[firebaseService] ✗ Lỗi khởi tạo Firebase Admin:');
    console.error(`  - Message: ${error.message}`);
    console.error(`  - Stack: ${error.stack}`);
    console.error(`  - Code: ${error.code}`);
    return null;
  }
}

function normalizeDataPayload(data = {}) {
  const normalized = {};
  Object.entries(data || {}).forEach(([key, value]) => {
    if (value === undefined || value === null) return;
    normalized[String(key)] = String(value);
  });
  return normalized;
}

async function cleanupInvalidToken(fcmToken) {
  try {
    await User.updateMany(
      { fcmToken },
      { $set: { fcmToken: null } }
    );
  } catch (cleanupError) {
    console.error('[firebaseService] Dọn token lỗi thất bại:', cleanupError.message);
  }
}

async function sendPushNotification(fcmToken, title, body, data = {}) {
  if (!fcmToken || typeof fcmToken !== 'string') {
    return { success: false, skipped: true, message: 'Thiếu fcmToken' };
  }

  const firebaseApp = initializeFirebaseAdmin();
  if (!firebaseApp) {
    return { success: false, skipped: true, message: 'Firebase Admin chưa sẵn sàng' };
  }

  const message = {
    token: fcmToken,
    notification: {
      title: String(title || ''),
      body: String(body || ''),
    },
    data: normalizeDataPayload(data),
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        channelId: 'high_importance_channel_v2',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  };

  try {
    const messageId = await admin.messaging().send(message);
    return { success: true, messageId };
  } catch (error) {
    const errorCode = error?.code || 'unknown';

    if (
      errorCode === 'messaging/invalid-registration-token' ||
      errorCode === 'messaging/registration-token-not-registered'
    ) {
      await cleanupInvalidToken(fcmToken);
    }

    console.error('[firebaseService] Gửi push thất bại:', errorCode, error.message);
    return { success: false, error: error.message, errorCode };
  }
}

module.exports = {
  initializeFirebaseAdmin,
  sendPushNotification,
};
