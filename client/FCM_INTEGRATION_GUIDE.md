# Firebase Cloud Messaging (FCM) Integration Guide

## Các tệp tạo và cập nhật

### 1. **notification_service.dart** (NEW)
- Đường dẫn: `lib/services/notification_service.dart`
- **Chức năng chính:**
  - Khởi tạo Firebase Admin SDK với `Firebase.initializeApp()`
  - Yêu cầu quyền thông báo từ người dùng
  - Lấy FCM token và gửi lên Backend via `PUT /api/users/fcm-token`
  - Xử lý 3 trạng thái thông báo:
    - **Foreground**: Hiển thị local notification popup (heads-up)
    - **Background**: Xử lý khi người dùng bấm vào thông báo
    - **Terminated**: Handler với `@pragma('vm:entry-point')` cho app đã tắt
  - Tự động lắng nghe khi token refresh

### 2. **user_preferences_service.dart** (NEW)
- Đường dẫn: `lib/services/user_preferences_service.dart`
- **Chức năng chính:**
  - Quản lý lưu trữ `user_id` vào SharedPreferences
  - Cung cấp helper functions: `saveUserInfo()`, `getUserId()`, `clearUserInfo()`
  - Sử dụng để notification_service lấy user_id khi gửi token lên Backend

### 3. **main.dart** (UPDATED)
- **Thay đổi:**
  - Thêm import: `firebase_core`, `notification_service`
  - Gọi `await NotificationService.initializeFirebaseMessaging()` trong `main()`
  - FCM được khởi tạo trước `runApp()`

### 4. **pubspec.yaml** (UPDATED)
- **Thêm dependency:** `firebase_core: ^4.10.0`

---

## Cách tích hợp vào Login Flow

### Step 1: Cập nhật Login Screen
Khi người dùng đăng nhập thành công, lưu `user_id` vào SharedPreferences:

```dart
import 'package:client/services/user_preferences_service.dart';

// Trong login logic, sau khi nhận response từ Backend:
if (loginResponse.statusCode == 200) {
  final data = jsonDecode(loginResponse.body);
  final userId = data['user']["_id"]; // hoặc data['userId']
  final userName = data['user']['name'];
  final userEmail = data['user']['email'];
  final authToken = data['token'];

  // Lưu user info vào SharedPreferences
  await UserPreferencesService.saveUserInfo(
    userId: userId,
    userName: userName,
    userEmail: userEmail,
    authToken: authToken,
  );

  // FCM token sẽ tự động được gửi lên Backend ngay sau
  print('✓ User info lưu thành công, FCM token đang được gửi...');
}
```

### Step 2: Cập nhật Logout
Khi user logout, xóa thông tin:

```dart
await UserPreferencesService.clearUserInfo();
```

---

## Cách xử lý điều hướng từ thông báo

### Update file: `notification_service.dart`
Trong hàm `_handleNotificationNavigation()`, thêm navigator:

```dart
static void _handleNotificationNavigation(
  Map<String, dynamic> data,
  BuildContext? context,
) {
  final type = data['type'] as String?;

  if (context == null) {
    print('[Navigation] Context không có sẵn, bỏ qua điều hướng');
    return;
  }

  switch (type) {
    case 'expense_alert':
      print('[Navigation] Điều hướng đến Expense Screen');
      Navigator.of(context).pushNamed('/expense');
      break;

    case 'water_reminder':
      print('[Navigation] Điều hướng đến Diary Screen');
      Navigator.of(context).pushNamed('/diary');
      break;

    default:
      print('[Navigation] Loại thông báo không xác định: $type');
  }
}
```

---

## Cách test Push Notifications

### Method 1: Postman + Test Endpoint (RECOMMENDED)
1. Backend đã chuẩn bị endpoint: `POST /api/test/push`
2. Mở Postman, gửi request:
```json
{
  "fcmToken": "YOUR_DEVICE_FCM_TOKEN",
  "title": "Test Notification",
  "body": "This is a test notification"
}
```
3. Nhận thông báo trên thiết bị trong 3 trạng thái:
   - **Foreground**: Popup hiện lên ngay
   - **Background**: Bấm vào thông báo để mở app
   - **Terminated**: Bấm vào thông báo để launch app

### Method 2: Firebase Console
1. Vào [Firebase Console](https://console.firebase.google.com/)
2. Chọn project → Messaging → Create your first campaign
3. Gửi thông báo test đến FCM token

### Method 3: Lấy FCM Token từ App
Để lấy FCM token của thiết bị:
1. Chạy app: `flutter run`
2. Mở DevTools: `flutter emulator --launch <device_id>` (nếu cần)
3. Check console logs cho dòng: `[FCM Token] Lấy được token: ...`
4. Copy token đó vào Postman

---

## Cấu hình Environment Variables

### File: `.env`
Đảm bảo `.env` chứa:
```
BACKEND_URL=http://localhost:3000
```
hoặc cho production:
```
BACKEND_URL=https://api.healthy-life.com
```

---

## Cấu hình Android

### File: `android/app/build.gradle.kts`
Đảm bảo có:
```kts
android {
    compileSdk = 35  // hoặc version tương tự
    ...
    defaultConfig {
        minSdk = 21
        targetSdk = 35
        ...
    }
}
```

### File: `android/app/AndroidManifest.xml`
Kiểm tra có permissions:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

---

## Cấu hình iOS

### File: `ios/Podfile`
Cần có platform minimium:
```ruby
platform :ios, '11.0'  # hoặc cao hơn
```

### File: `ios/Runner.xcodeproj`
1. Mở Xcode: `open ios/Runner.xcworkspace`
2. Chọn Runner target
3. Tab "Signing & Capabilities"
4. Click "+ Capability" → Tìm "Push Notifications"
5. Thêm "Background Modes" → Chọn "Remote notifications"

---

## Logs & Debugging

### Check logs khi app chạy
```bash
flutter run
```

Tìm các dòng như:
```
[FCM] Khởi tạo Firebase...
[FCM] ✓ Firebase đã khởi tạo
[Permissions] ✓ Người dùng đã cấp quyền thông báo
[FCM Token] Lấy được token: xxx...
[Backend Token] ✓ Token đã gửi thành công
```

### Nếu có lỗi
1. **Token không được gửi**: Kiểm tra `user_id` có trong SharedPreferences không
2. **Thông báo không hiển thị**: Kiểm tra quyền notification trên thiết bị
3. **Firebase init fail**: Kiểm tra `google-services.json` có đúng không

---

## Checklist Tích hợp

- [ ] File `notification_service.dart` tạo thành công
- [ ] File `user_preferences_service.dart` tạo thành công
- [ ] `main.dart` import `firebase_core` và `notification_service`
- [ ] `main.dart` gọi `NotificationService.initializeFirebaseMessaging()`
- [ ] `firebase_core` thêm vào `pubspec.yaml`
- [ ] Chạy `flutter pub get`
- [ ] Cập nhật login screen gọi `UserPreferencesService.saveUserInfo()`
- [ ] Cập nhật logout gọi `UserPreferencesService.clearUserInfo()`
- [ ] Test notification qua Postman `/api/test/push`
- [ ] Kiểm tra logs có token được gửi lên Backend không

---

## Thao tác Tiếp Theo

1. **Cập nhật Login/Signup Screens** để lưu user_id vào SharedPreferences
2. **Cập nhật Water Intake UI** để gửi `waterIntake` lên Backend via `POST /api/diary/sync`
3. **Test push notifications** với Postman trước khi deploy
4. **Monitor server logs** để xem token có được lưu vào DB không

Trong Backend đã có:
- ✓ Firebase Admin service
- ✓ Auto-cleanup invalid tokens
- ✓ Test endpoint `/api/test/push`
- ✓ Expense alert logic
- ✓ Water reminder cronjob
