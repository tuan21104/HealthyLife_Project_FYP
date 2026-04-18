import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_preferences_service.dart' as user_service;

/// Handler cho thông báo khi app đã bị tắt hoàn toàn (Terminated State)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignore if already initialized in this isolate.
  }

  print(
    '[FCM Background] Thông báo nhận được (App Terminated): ${message.messageId}',
  );
  print('[FCM Background] Dữ liệu: ${message.data}');
  await NotificationService.logIncomingDiagnostics(
    source: 'background_handler',
    message: message,
    includePluginChecks: false,
  );
}

/// Hàm hiển thị local notification
Future<void> _showLocalNotification({
  required String title,
  required String body,
}) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'high_importance_channel_v2',
        'Thông báo quan trọng',
        channelDescription: 'Kênh cho thông báo quan trọng từ Healthy Life',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        showWhen: true,
      );

  const DarwinNotificationDetails iosPlatformChannelSpecifics =
      DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iosPlatformChannelSpecifics,
  );

  await NotificationService._flutterLocalNotificationsPlugin.show(
    id: title.hashCode,
    title: title,
    body: body,
    notificationDetails: platformChannelSpecifics,
  );
}

/// Service xử lý Firebase Cloud Messaging và Local Notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _highImportanceChannel =
      AndroidNotificationChannel(
        'high_importance_channel_v2',
        'Thông báo quan trọng',
        description: 'Kênh cho thông báo quan trọng từ Healthy Life',
        importance: Importance.max,
        playSound: true,
      );

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  static Future<void> logIncomingDiagnostics({
    required String source,
    required RemoteMessage message,
    bool includePluginChecks = true,
  }) async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();

      bool? localNotificationsEnabled;
      if (includePluginChecks) {
        final dynamic androidImplementation = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        localNotificationsEnabled = await androidImplementation
            ?.areNotificationsEnabled();
      }

      final payloadChannelId =
          message.data['channelId'] ??
          message.data['android_channel_id'] ??
          message.data['channel_id'];
      final payloadPriority =
          message.data['priority'] ?? message.data['android_priority'];
      final payloadSound =
          message.data['sound'] ?? message.data['android_sound'];

      print('========== [FCM DIAGNOSTIC][$source] ==========');
      print('[Diag] messageId: ${message.messageId}');
      print('[Diag] sentTime: ${message.sentTime?.toIso8601String()}');
      print('[Diag] title: ${message.notification?.title}');
      print('[Diag] body: ${message.notification?.body}');
      print('[Diag] data: ${message.data}');
      print(
        '[Diag] firebase permission.authorizationStatus: ${settings.authorizationStatus}',
      );
      print('[Diag] firebase permission.alert: ${settings.alert}');
      print('[Diag] firebase permission.sound: ${settings.sound}');
      print('[Diag] firebase permission.badge: ${settings.badge}');
      print(
        '[Diag] localNotifications.areEnabled: ${localNotificationsEnabled ?? 'unknown'}',
      );
      print('[Diag] configuredChannel.id: ${_highImportanceChannel.id}');
      print(
        '[Diag] configuredChannel.importance: ${_highImportanceChannel.importance}',
      );
      print(
        '[Diag] configuredChannel.playSound: ${_highImportanceChannel.playSound}',
      );
      print('[Diag] payload.priority: ${payloadPriority ?? 'not_provided'}');
      print('[Diag] payload.channelId: ${payloadChannelId ?? 'not_provided'}');
      print('[Diag] payload.sound: ${payloadSound ?? 'not_provided'}');
      print('========== [FCM DIAGNOSTIC END][$source] ==========');
    } catch (e) {
      print('[FCM DIAGNOSTIC][$source] Lỗi khi ghi log chẩn đoán: $e');
    }
  }

  /// Khởi tạo Firebase và thiết lập handlers
  static Future<void> initializeFirebaseMessaging() async {
    try {
      // 1. Khởi tạo Firebase
      print('[FCM] Khởi tạo Firebase...');
      await Firebase.initializeApp();
      print('[FCM] ✓ Firebase đã khởi tạo');

      // 2. Khởi tạo Local Notifications
      await _initLocalNotifications();

      // 3. Yêu cầu quyền thông báo
      await _requestNotificationPermissions();

      // 4. Lấy FCM token và gửi lên backend
      await _setupFCMToken();

      // 5. Thiết lập handler cho background messages
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // 6. Thiết lập handler cho foreground messages
      _setupForegroundMessageHandler();

      // 7. Thiết lập handler cho khi app mở từ thông báo (background/terminated)
      _setupMessageOpenedAppHandler();

      print('[FCM] ✓ Tất cả handlers đã được thiết lập');
    } catch (e) {
      print('[FCM] ✗ Lỗi khởi tạo FCM: $e');
    }
  }

  /// Khởi tạo Local Notifications
  static Future<void> _initLocalNotifications() async {
    try {
      const AndroidInitializationSettings androidInitializationSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosInitializationSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: androidInitializationSettings,
            iOS: iosInitializationSettings,
          );

      await _flutterLocalNotificationsPlugin.initialize(
            settings: initializationSettings,
            onDidReceiveNotificationResponse: (NotificationResponse response) {
              print(
                '[Local Notification] Người dùng bấm vào: ${response.payload}',
              );
            },
          ) ??
          false;

      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImplementation?.createNotificationChannel(
        _highImportanceChannel,
      );

      print('[Local Notifications] ✓ Đã khởi tạo');
    } catch (e) {
      print('[Local Notifications] ✗ Lỗi khởi tạo: $e');
    }
  }

  /// Yêu cầu quyền thông báo từ người dùng
  static Future<void> _requestNotificationPermissions() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Yêu cầu quyền
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('[Permissions] ✓ Người dùng đã cấp quyền thông báo');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print('[Permissions] ⚠ Quyền tạm thời được cấp');
      } else {
        print('[Permissions] ✗ Người dùng từ chối quyền thông báo');
      }
    } catch (e) {
      print('[Permissions] ✗ Lỗi yêu cầu quyền: $e');
    }
  }

  /// Lấy FCM token và gửi lên Backend
  static Future<void> _setupFCMToken() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Lấy FCM token
      String? token = await messaging.getToken();

      if (token != null) {
        print('[FCM Token] Lấy được token: $token');

        // Lưu token vào SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('fcm_token', token);

        // Gửi token lên Backend nếu user_id có sẵn
        await _sendTokenToBackend(token);
      } else {
        print('[FCM Token] ✗ Không lấy được token');
      }

      // Lắng nghe khi token bị refresh
      messaging.onTokenRefresh.listen((newToken) async {
        print('[FCM Token Refresh] Token mới: $newToken');
        await _sendTokenToBackend(newToken);

        // Cập nhật token mới vào SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('fcm_token', newToken);
      });
    } catch (e) {
      print('[FCM Token] ✗ Lỗi lấy/gửi token: $e');
    }
  }

  /// Gửi FCM token lên Backend
  static Future<void> _sendTokenToBackend(String fcmToken) async {
    try {
      final userId = await user_service.UserPreferencesService.getUserId();

      if (userId == null) {
        print('[Backend Token] ⚠ Chưa lưu user_id, bỏ qua gửi token');
        return;
      }

      final backendUrl = dotenv.get(
        'BACKEND_URL',
        fallback: 'http://localhost:3000',
      );
      final url = Uri.parse('$backendUrl/api/users/fcm-token');

      final response = await http
          .put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'fcmToken': fcmToken}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Timeout gửi token'),
          );

      if (response.statusCode == 200) {
        print('[Backend Token] ✓ Token đã gửi thành công');
      } else {
        print(
          '[Backend Token] ✗ Lỗi: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('[Backend Token] ✗ Lỗi gửi token: $e');
    }
  }

  /// Thiết lập handler cho Foreground Messages (App đang mở)
  static void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('[FCM Foreground] Thông báo nhận được: ${message.messageId}');
      print('[FCM Foreground] Tiêu đề: ${message.notification?.title}');
      print('[FCM Foreground] Nội dung: ${message.notification?.body}');
      print('[FCM Foreground] Dữ liệu: ${message.data}');
      await logIncomingDiagnostics(source: 'foreground', message: message);

      // Hiển thị heads-up notification
      if (message.notification != null) {
        _showLocalNotification(
          title: message.notification?.title ?? 'Thông báo',
          body: message.notification?.body ?? '',
        );
      }
    });
  }

  /// Thiết lập handler cho khi app mở từ thông báo (Background hoặc Terminated)
  static void _setupMessageOpenedAppHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      print('[FCM MessageOpenedApp] Người dùng bấm vào thông báo');
      print('[FCM MessageOpenedApp] Tiêu đề: ${message.notification?.title}');
      print('[FCM MessageOpenedApp] Dữ liệu: ${message.data}');
      await logIncomingDiagnostics(source: 'opened_app', message: message);

      // Xử lý điều hướng dựa trên loại thông báo
      _handleNotificationNavigation(message.data);
    });
  }

  /// Xử lý điều hướng dựa trên dữ liệu thông báo
  static void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'expense_alert':
        print('[Navigation] Điều hướng đến Expense Screen');
        // TODO: Navigating to Expense Screen
        // Navigator.of(GlobalContext).pushNamed('/expense');
        break;

      case 'water_reminder':
        print('[Navigation] Điều hướng đến Diary Screen');
        // TODO: Navigating to Diary Screen
        // Navigator.of(GlobalContext).pushNamed('/diary');
        break;

      default:
        print('[Navigation] Loại thông báo không xác định: $type');
    }
  }
}
