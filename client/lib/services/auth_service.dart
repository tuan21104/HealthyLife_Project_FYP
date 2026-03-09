import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
// Cập nhật IP này mỗi khi đổi mạng Wi-Fi
  static const String myWifiIp = '10.22.49.212';

  // - Đặt là TRUE: Dùng được cho CẢ MÁY THẬT VÀ MÁY ẢO (Yêu cầu máy tính có kết nối Wi-Fi)
  // - Đặt là FALSE: Chỉ dùng cho máy ảo
  static const bool isOnlineMode = true;

  static const String baseUrl = isOnlineMode
      ? 'http://$myWifiIp:3000/api/auth'
      : 'http://10.0.2.2:3000/api/auth';

  static Future<Map<String, dynamic>> register(String email, String password) async {
    final url = Uri.parse('$baseUrl/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'name': 'New User'}),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'message': responseData['message']};
      } else {
        return {'success': false, 'message': responseData['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', responseData['token']);

        await prefs.setString('userId', responseData['user']['id']);

        return {'success': true, 'message': 'Đăng nhập thành công!'};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Lỗi đăng nhập'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<bool> updateProfile(String email, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/update-profile');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          ...data,
        }),
      );

      final responseData = jsonDecode(response.body);
      return response.statusCode == 200 && responseData['success'] == true;
    } catch (e) {
      print("Lỗi update: $e");
      return false;
    }
  }
}
