import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // NHỚ ĐỔI LẠI IP NÀY THEO IP MÁY TÍNH CỦA BẠN NHÉ (nếu test máy thật)
  static const String myWifiIp = '192.18.23.104'; 
  static const bool isOnlineMode = true;

  static const String baseUrl = isOnlineMode 
      ? 'http://$myWifiIp:3000/api/auth' 
      : 'http://10.0.2.2:3000/api/auth'; //đổi thành 127.0.0.1 nếu test với máy ảo ios

  // --- HÀM 1: ĐĂNG KÝ ---
  static Future<Map<String, dynamic>> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Đăng ký thành công'};
      } else {
        return {'success': false, 'message': jsonDecode(response.body)['message'] ?? 'Lỗi đăng ký'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối tới Server'};
    }
  }

  // --- HÀM 2: ĐĂNG NHẬP (LƯU TOKEN VÀO ĐIỆN THOẠI) ---
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10)
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // CỰC KỲ QUAN TRỌNG: Cất Token vào ví (SharedPreferences)
        if (data['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', data['token']);
          print("Đã lưu Token thành công: ${data['token']}"); // In ra để check
        }
        
        // ĐÃ SỬA: Bổ sung thêm hasProfile vào dữ liệu trả về cho giao diện
        return {
          'success': true, 
          'message': 'Đăng nhập thành công',
          'hasProfile': data['hasProfile'] ?? false 
        };
      } else {
        return {'success': false, 'message': jsonDecode(response.body)['message'] ?? 'Lỗi đăng nhập'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối tới Server'};
    }
  }

  // --- HÀM 3: CẬP NHẬT THÔNG TIN (GẮN TOKEN VÀO ĐỂ XIN PHÉP SERVER) ---
  static Future<bool> updateProfile(String email, Map<String, dynamic> profileData) async {
    try {
      // 1. Mở ví lấy Token ra
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        print("Lỗi: Không tìm thấy Token, người dùng chưa đăng nhập hợp lệ.");
        return false;
      }

      // 2. Gộp email vào chung cục dữ liệu để gửi lên
      profileData['email'] = email;

      // 3. Gửi lên Server kèm Token ở phần Headers
      final response = await http.post(
        Uri.parse('$baseUrl/update-profile'),
        headers: {
          'Content-Type': 'application/json',
          // Trình thẻ bảo vệ (JWT) ra ở đây:
          'Authorization': 'Bearer $token', 
        },
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 200) {
        print("Lưu Database thành công!");
        return true;
      } else {
        print("Server từ chối lưu DB. Mã lỗi: ${response.statusCode}");
        print("Chi tiết lỗi: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Lỗi kết nối khi updateProfile: $e");
      return false;
    }
  }

  // --- HÀM LẤY THÔNG TIN PROFILE ---
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      // 1. Mở ví lấy Token ra
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        return {'success': false, 'message': 'Chưa đăng nhập'};
      }

      // 2. Gọi API kèm theo Token trong Header
      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Trình thẻ bài ra
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'user': data['user']}; // Trả về cục dữ liệu User
      } else {
        return {'success': false, 'message': 'Lỗi xác thực'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối Server'};
    }
  }
}