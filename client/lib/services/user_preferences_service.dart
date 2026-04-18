import 'package:shared_preferences/shared_preferences.dart';

/// Service quản lý dữ liệu người dùng cục bộ
class UserPreferencesService {
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _userTokenKey = 'auth_token';

  /// Lưu thông tin người dùng sau khi đăng nhập
  static Future<void> saveUserInfo({
    required String userId,
    required String userName,
    required String userEmail,
    required String authToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
      await prefs.setString(_userNameKey, userName);
      await prefs.setString(_userEmailKey, userEmail);
      await prefs.setString(_userTokenKey, authToken);
      print('[UserPreferences] ✓ Đã lưu thông tin người dùng');
    } catch (e) {
      print('[UserPreferences] ✗ Lỗi lưu thông tin: $e');
    }
  }

  /// Lấy user_id từ SharedPreferences
  static Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userIdKey);
    } catch (e) {
      print('[UserPreferences] ✗ Lỗi lấy user_id: $e');
      return null;
    }
  }

  /// Lấy user email từ SharedPreferences
  static Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userEmailKey);
    } catch (e) {
      print('[UserPreferences] ✗ Lỗi lấy email: $e');
      return null;
    }
  }

  /// Lấy auth token từ SharedPreferences
  static Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userTokenKey);
    } catch (e) {
      print('[UserPreferences] ✗ Lỗi lấy token: $e');
      return null;
    }
  }

  /// Xóa tất cả thông tin người dùng (logout)
  static Future<void> clearUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      await prefs.remove(_userNameKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userTokenKey);
      print('[UserPreferences] ✓ Đã xóa thông tin người dùng');
    } catch (e) {
      print('[UserPreferences] ✗ Lỗi xóa thông tin: $e');
    }
  }
}
