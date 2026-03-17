import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static const String myWifiIp = '192.18.23.106'; 
  
  // SỬA LỖI 1: Đổi thành false để máy ảo Android dùng IP 10.0.2.2 cho ổn định
  static const bool isOnlineMode = false;

  // SỬA LỖI 2: Cắt bỏ chữ 'auth' ở đuôi, chỉ giữ lại '/api' làm thư mục gốc
  static const String baseUrl = isOnlineMode 
      ? 'http://$myWifiIp:3000/api' 
      : 'http://10.0.2.2:3000/api'; 

  // --- HÀM 1: ĐĂNG KÝ ---
  static Future<Map<String, dynamic>> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'), // Thêm /auth/ vào từng endpoint
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
        Uri.parse('$baseUrl/auth/login'), // Thêm /auth/
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', data['token']);
          print("Đã lưu Token thành công: ${data['token']}"); 
        }
        
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

  // --- HÀM 3: CẬP NHẬT THÔNG TIN ---
  static Future<bool> updateProfile(String email, Map<String, dynamic> profileData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        print("Lỗi: Không tìm thấy Token.");
        return false;
      }

      profileData['email'] = email;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/update-profile'), // Thêm /auth/
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', 
        },
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Server từ chối lưu DB. Mã lỗi: ${response.statusCode}");
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        return {'success': false, 'message': 'Chưa đăng nhập'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'), // Thêm /auth/
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', 
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'user': data['user']}; 
      } else {
        return {'success': false, 'message': 'Lỗi xác thực'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối Server'};
    }
  }

  // --- HÀM LẤY DANH SÁCH MÓN ĂN TỪ DATABASE ---
  static Future<Map<String, dynamic>> getAllFoods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      
      // ĐÃ CHUẨN XÁC: Gọi thẳng $baseUrl/foods -> 'http://10.0.2.2:3000/api/foods'
      final response = await http.get(
        Uri.parse('$baseUrl/foods'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', 
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body); 
      } else {
        return {'success': false, 'message': 'Lỗi tải danh sách món ăn: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối server: $e'};
    }
  }
  // Hàm lấy dữ liệu nhật ký từ Server
  static Future<Map<String, dynamic>?> getDiaryFromCloud(String userId, String date) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/diary/$userId/$date'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['diary'];
      }
    } catch (e) {
      print("Lỗi tải Cloud: $e");
    }
    return null;
  }

  // Hàm đẩy dữ liệu nhật ký lên Server
  static Future<void> syncDiaryToCloud(Map<String, dynamic> diaryData) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/diary/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(diaryData),
      );
      print("☁️ Đã đồng bộ ngầm lên Cloud thành công!");
    } catch (e) {
      print("Lỗi đồng bộ Cloud: $e");
    }
  }
}