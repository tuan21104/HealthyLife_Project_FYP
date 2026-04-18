import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'user_preferences_service.dart';

class AuthService {
  static const String myWifiIp = '172.20.10.11';
  static const bool enableLogs = false;
  static const String _pendingOnboardingEmailKey = 'pending_onboarding_email';

  // SỬA LỖI 1: Đổi thành false để máy ảo Android dùng IP 10.0.2.2 cho ổn định
  static const bool isOnlineMode = false;

  // SỬA LỖI 2: Cắt bỏ chữ 'auth' ở đuôi, chỉ giữ lại '/api' làm thư mục gốc
  static const String baseUrl = isOnlineMode
      ? 'http://$myWifiIp:3000'
      : 'http://10.0.2.2:3000';

  static void _log(String message) {
    if (enableLogs) {
      debugPrint(message);
    }
  }

  static String _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Ignore JSON parse errors and fallback to HTTP message.
    }

    return 'Yeu cau that bai (HTTP ${response.statusCode}).';
  }

  static Exception _mapRequestException(Object error) {
    if (error is SocketException) {
      return Exception('Khong the ket noi toi server. Vui long kiem tra mang.');
    }
    if (error is TimeoutException) {
      return Exception(
        'Het thoi gian cho phan hoi tu server. Vui long thu lai.',
      );
    }
    if (error is FormatException) {
      return Exception('Du lieu tra ve khong hop le.');
    }
    if (error is Exception) {
      return error;
    }
    return Exception('Da xay ra loi khong xac dinh.');
  }

  static Map<String, dynamic>? _extractUserFromPayload(dynamic payload) {
    if (payload == null) return null;

    if (payload is Map<String, dynamic>) {
      final directUser = payload['user'];
      if (directUser is Map) {
        return Map<String, dynamic>.from(directUser);
      }

      final directData = payload['data'];
      if (directData is Map<String, dynamic>) {
        final nestedUser = directData['user'];
        if (nestedUser is Map) {
          return Map<String, dynamic>.from(nestedUser);
        }

        final nestedProfile = directData['profile'];
        if (nestedProfile is Map) {
          return Map<String, dynamic>.from(nestedProfile);
        }

        final nestedData = directData['data'];
        if (nestedData is Map) {
          return Map<String, dynamic>.from(nestedData);
        }

        if (directData.containsKey('_id') || directData.containsKey('id')) {
          return Map<String, dynamic>.from(directData);
        }
      }

      final result = payload['result'];
      if (result is Map<String, dynamic>) {
        final resultUser = result['user'];
        if (resultUser is Map) {
          return Map<String, dynamic>.from(resultUser);
        }
      }

      if (payload.containsKey('_id') || payload.containsKey('id')) {
        return Map<String, dynamic>.from(payload);
      }
    }

    return null;
  }

  static String _extractUserIdFromResponse(Map<String, dynamic> data) {
    final user = data['user'];
    if (user is Map) {
      final userMap = Map<String, dynamic>.from(user);
      final candidate = userMap['id']?.toString() ?? userMap['_id']?.toString();
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }

    final directUserId = data['userId']?.toString();
    if (directUserId != null && directUserId.isNotEmpty) {
      return directUserId;
    }

    final directId = data['id']?.toString() ?? data['_id']?.toString();
    if (directId != null && directId.isNotEmpty) {
      return directId;
    }

    return '';
  }

  static String _extractUserNameFromResponse(Map<String, dynamic> data) {
    final user = data['user'];
    if (user is Map) {
      final userMap = Map<String, dynamic>.from(user);
      final candidate =
          userMap['name']?.toString() ?? userMap['username']?.toString();
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }
    return data['name']?.toString() ?? data['username']?.toString() ?? '';
  }

  static String _extractUserEmailFromResponse(
    Map<String, dynamic> data,
    String fallbackEmail,
  ) {
    final user = data['user'];
    if (user is Map) {
      final userMap = Map<String, dynamic>.from(user);
      final candidate = userMap['email']?.toString();
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }
    final directEmail = data['email']?.toString();
    if (directEmail != null && directEmail.isNotEmpty) {
      return directEmail;
    }
    return fallbackEmail;
  }

  static Future<void> _syncStoredFcmTokenToBackend(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString('fcm_token')?.trim();

      if (fcmToken == null || fcmToken.isEmpty) {
        _log('FCM token chua co san, bo qua dong bo voi backend');
        return;
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl/api/users/fcm-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'fcmToken': fcmToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _log('Da cap nhat fcmToken len backend thanh cong');
      } else {
        _log(
          'Cap nhat fcmToken that bai: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      _log('Khong the dong bo fcmToken sau khi login: $e');
    }
  }

  // --- HÀM 1: ĐĂNG KÝ ---
  static Future<Map<String, dynamic>> register(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/api/auth/register',
        ), // Thêm /auth/ vào từng endpoint
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Đăng ký thành công'};
      } else {
        return {
          'success': false,
          'message': jsonDecode(response.body)['message'] ?? 'Lỗi đăng ký',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối tới Server'};
    }
  }

  // --- HÀM 2: ĐĂNG NHẬP (LƯU TOKEN VÀ USER ID VÀO ĐIỆN THOẠI) ---
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          final userId = _extractUserIdFromResponse(
            Map<String, dynamic>.from(data),
          );
          final userName = _extractUserNameFromResponse(
            Map<String, dynamic>.from(data),
          );
          final userEmail = _extractUserEmailFromResponse(
            Map<String, dynamic>.from(data),
            email,
          );

          // 1. Lưu Token
          await prefs.setString('jwt_token', data['token']);
          await prefs.setString('token', data['token']);

          if (userId.isNotEmpty) {
            await prefs.setString('userId', userId);
            await prefs.setString('user_id', userId);
            await UserPreferencesService.saveUserInfo(
              userId: userId,
              userName: userName,
              userEmail: userEmail,
              authToken: data['token'].toString(),
            );

            // Cố gắng đồng bộ token FCM, nhưng không được chặn đăng nhập nếu lỗi
            unawaited(_syncStoredFcmTokenToBackend(userId));
          }
        }

        return {
          'success': true,
          'message': 'Đăng nhập thành công',
          'hasProfile': data['hasProfile'] ?? false,
        };
      } else {
        return {
          'success': false,
          'message': jsonDecode(response.body)['message'] ?? 'Lỗi đăng nhập',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối tới Server'};
    }
  }

  // --- HÀM MỚI: QUÊN MẬT KHẨU ---
  static Future<bool> forgotPassword(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      }

      throw Exception(_extractErrorMessage(response));
    } catch (e) {
      throw _mapRequestException(e);
    }
  }

  // --- HÀM MỚI: XÁC THỰC OTP (VERIFY EMAIL) ---
  static Future<bool> verifyOtp(String email, String otp) async {
    return verifySignupOtp(email, otp);
  }

  static Future<bool> verifySignupOtp(String email, String otp) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/verify-email'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'otpCode': otp.trim()}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      }

      throw Exception(_extractErrorMessage(response));
    } catch (e) {
      throw _mapRequestException(e);
    }
  }

  static Future<bool> verifyForgotPasswordOtp(String email, String otp) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/verify-reset-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'otpCode': otp.trim()}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      }

      throw Exception(_extractErrorMessage(response));
    } catch (e) {
      throw _mapRequestException(e);
    }
  }

  static Future<bool> resendSignupOtp(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/resend-signup-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      }

      throw Exception(_extractErrorMessage(response));
    } catch (e) {
      throw _mapRequestException(e);
    }
  }

  // --- HÀM MỚI: ĐẶT LẠI MẬT KHẨU ---
  static Future<bool> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'otpCode': otp.trim(),
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      }

      throw Exception(_extractErrorMessage(response));
    } catch (e) {
      throw _mapRequestException(e);
    }
  }

  static Future<void> markPendingOnboarding(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingOnboardingEmailKey,
      email.trim().toLowerCase(),
    );
  }

  static Future<bool> shouldForceOnboarding(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingEmail = prefs.getString(_pendingOnboardingEmailKey);
    if (pendingEmail == null || pendingEmail.isEmpty) {
      return false;
    }
    return pendingEmail == email.trim().toLowerCase();
  }

  static Future<void> clearPendingOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingOnboardingEmailKey);
  }

  // --- HÀM 3: CẬP NHẬT THÔNG TIN
  static Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localUserId = prefs.getString('userId');
      final bodyUserId =
          profileData['userId']?.toString() ??
          profileData['_id']?.toString() ??
          profileData['id']?.toString();
      final userId = (bodyUserId != null && bodyUserId.isNotEmpty)
          ? bodyUserId
          : localUserId;
      final token = prefs.getString('jwt_token');

      if (userId == null || userId.isEmpty) return false;

      final requestBody = Map<String, dynamic>.from(profileData);
      requestBody['userId'] = userId;

      final response = await http.put(
        Uri.parse('$baseUrl/api/users/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      return response.statusCode == 200;
    } catch (e) {
      _log("Lỗi updateProfile: $e");
      return false;
    }
  }

  // Bản đầy đủ: trả về cả dữ liệu user mới sau khi server cập nhật
  static Future<Map<String, dynamic>> updateProfileWithResponse(
    Map<String, dynamic> profileData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localUserId = prefs.getString('userId');
      final bodyUserId =
          profileData['userId']?.toString() ??
          profileData['_id']?.toString() ??
          profileData['id']?.toString();
      final userId = (bodyUserId != null && bodyUserId.isNotEmpty)
          ? bodyUserId
          : localUserId;
      final token = prefs.getString('jwt_token') ?? prefs.getString('token');

      if (userId == null || userId.isEmpty) {
        return {'success': false, 'message': 'Thiếu userId local'};
      }

      final requestBody = Map<String, dynamic>.from(profileData);
      requestBody['userId'] = userId;

      final response = await http.put(
        Uri.parse('$baseUrl/api/users/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode == 200) {
        final user = _extractUserFromPayload(decoded);

        if (user == null) {
          return {
            'success': false,
            'message':
                'Update thành công nhưng không tìm thấy user trong payload.',
            'raw': decoded,
          };
        }

        return {'success': true, 'user': user, 'raw': decoded};
      }

      String message = 'Server từ chối cập nhật';
      if (decoded is Map<String, dynamic>) {
        message = decoded['message']?.toString() ?? message;
      }

      return {'success': false, 'message': message};
    } catch (e) {
      _log('Lỗi updateProfileWithResponse: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // --- HÀM LẤY THÔNG TIN PROFILE CÓ GẮN TOKEN ---
  static Future<dynamic> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Lấy vé VIP (Token) và ID từ kho lưu trữ Local
      // (Dự phòng cả 2 tên biến phổ biến là 'jwt_token' và 'token')
      final token = prefs.getString('jwt_token') ?? prefs.getString('token');
      final userId = prefs.getString('userId');

      if (token == null) {
        return {'success': false, 'message': 'Chưa đăng nhập'};
      }

      // 2. Gọi API kèm theo Vé VIP trong Header
      // Lưu ý: Thay đổi URL '/api/users/$userId' cho đúng với API Node.js của bạn
      // (Một số backend dùng '/api/users/profile' hoặc '/api/auth/me')
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // <--- ĐÂY LÀ DÒNG QUAN TRỌNG NHẤT
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Lỗi xác thực: ${response.statusCode}',
        };
      }
    } catch (e) {
      _log("==== 🚨 LỖI GỌI API PROFILE: $e ====");
      return {'success': false, 'message': e.toString()};
    }
  }

  // --- HÀM TẢI KHO DATA MÓN ĂN GỐC ---
  static Future<Map<String, dynamic>> getAllFoods() async {
    try {
      _log("==== 🔄 ĐANG TẢI DATABASE MÓN ĂN TỪ: $baseUrl/api/foods ====");
      final response = await http.get(Uri.parse('$baseUrl/api/foods'));

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);

        // TRƯỜNG HỢP 1: Backend trả về một Danh sách (Array) trực tiếp
        if (decodedData is List) {
          _log(
            "==== ✅ TẢI THÀNH CÔNG: ${decodedData.length} món ăn gốc (Dạng List) ====",
          );
          return {'success': true, 'foods': decodedData};
        }

        // TRƯỜNG HỢP 2: Backend trả về đúng chuẩn Object { success: true, foods: [...] }
        _log("==== ✅ TẢI THÀNH CÔNG (Dạng Object) ====");
        return decodedData;
      } else {
        _log("==== ⚠️ LỖI SERVER KHI TẢI DATA: Mã ${response.statusCode} ====");
        return {'success': false, 'foods': []};
      }
    } catch (e) {
      _log("==== 🚨 LỖI GỌI API ALL FOODS: $e ====");
      return {'success': false, 'foods': []};
    }
  }

  // Hàm lấy dữ liệu nhật ký từ Server
  static Future<Map<String, dynamic>?> getDiaryFromCloud(
    String userId,
    String date,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/diary/$userId/$date'),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final diary = decoded is Map<String, dynamic> ? decoded['diary'] : null;
        if (diary is Map) {
          return Map<String, dynamic>.from(diary);
        }
        return null;
      }
    } catch (e) {
      _log("Lỗi tải Cloud: $e");
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
      _log("☁️ Đã đồng bộ ngầm lên Cloud thành công!");
    } catch (e) {
      _log("Lỗi đồng bộ Cloud: $e");
    }
  }

  static String _todayVnDateKey() {
    final now = DateTime.now();
    final localDate = DateTime(now.year, now.month, now.day);
    final year = localDate.year.toString().padLeft(4, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static Future<bool> syncWaterIntakeForToday({
    required String userId,
    required num waterIntake,
  }) async {
    try {
      final date = _todayVnDateKey();
      final currentDiary = await getDiaryFromCloud(userId, date);

      final safeWater = waterIntake.isFinite && waterIntake >= 0
          ? waterIntake.toDouble()
          : 0.0;

      final payload = <String, dynamic>{
        'userId': userId,
        'date': date,
        'targetCalo': currentDiary?['targetCalo'] ?? 1200,
        'targetCarb': currentDiary?['targetCarb'] ?? 150,
        'targetProtein': currentDiary?['targetProtein'] ?? 60,
        'targetFat': currentDiary?['targetFat'] ?? 40,
        'waterIntake': safeWater,
        'breakfast': currentDiary?['breakfast'] ?? <dynamic>[],
        'lunch': currentDiary?['lunch'] ?? <dynamic>[],
        'snack': currentDiary?['snack'] ?? <dynamic>[],
        'dinner': currentDiary?['dinner'] ?? <dynamic>[],
        'exercise': currentDiary?['exercise'] ?? <dynamic>[],
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/diary/sync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _log('Dong bo waterIntake thanh cong');
        return true;
      }

      _log(
        'Dong bo waterIntake that bai: ${response.statusCode} ${response.body}',
      );
      return false;
    } catch (e) {
      _log('Loi syncWaterIntakeForToday: $e');
      return false;
    }
  }

  // Hàm kéo danh sách My Foods
  static Future<List<dynamic>> getMyFoods(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user-foods/$userId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['foods'];
      }
    } catch (e) {
      _log("Lỗi tải My Foods: $e");
    }
    return [];
  }

  // Hàm kéo danh sách Recipes
  static Future<List<dynamic>> getRecipes(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/recipes/$userId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['recipes'];
      }
    } catch (e) {
      _log("Lỗi tải Recipes: $e");
    }
    return [];
  }

  // Hàm đẩy món ăn mới do User tự tạo lên Server
  static Future<bool> createMyFood(
    Map<String, dynamic> foodData,
    File? imageToUpload,
  ) async {
    try {
      // BƯỚC A: NẾU CÓ ẢNH, NÉM ẢNH LÊN CLOUDINARY TRƯỚC
      String imageUrlOnCloud = ""; // Biến chứa link ảnh trên cloud

      if (imageToUpload != null) {
        _log("==== 🔄 BẮT ĐẦU UPLOAD ẢNH LÊN MÂY... ====");
        String? link = await uploadImage(imageToUpload);
        if (link != null) {
          imageUrlOnCloud = link; // Gán link ảnh lấy về vào đây
        }
      }

      // BƯỚC B: NỐI LINK ẢNH VÀO HỒ SƠ MÓN ĂN
      foodData['imageUrl'] = imageUrlOnCloud; // Nối link ảnh vào object JSON

      // BƯỚC C: GỬI HỒ SƠ MÓN ĂN LÊN CLOBAL DATABASE (MONGODB)
      _log("==== 🔄 ĐANG GỬI HỒ SƠ MÓN ĂN LÊN: $baseUrl/api/user-foods ====");
      final response = await http.post(
        Uri.parse('$baseUrl/api/user-foods'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(foodData),
      );

      _log("==== KẾT QUẢ SERVER TRẢ VỀ: Mã ${response.statusCode} ====");
      _log("==== NỘI DUNG TRẢ VỀ: ${response.body} ====");

      return response.statusCode == 201;
    } catch (e) {
      _log("==== 🚨 LỖI KẾT NỐI MẠNG CHÍ MẠNG: $e ====");
      return false;
    }
  }

  // Hàm đẩy Công thức (Recipe) mới lên Server
  static Future<bool> createRecipe(Map<String, dynamic> recipeData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/recipes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(recipeData),
      );
      return response.statusCode == 201;
    } catch (e) {
      _log("Lỗi tạo Công thức: $e");
      return false;
    }
  }

  //  HÀM UPLOAD ẢNH LÊN CLOUDINARY (GỌI API NODE.JS)
  static Future<String?> uploadImage(File imageFile) async {
    try {
      final String uploadUrl = '$baseUrl/api/upload'; // Đường link kho bãi

      // 1. Ép file ảnh thành một request 'multpart'
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.files.add(
        await http.MultipartFile.fromPath(
          'image', // Tên field bên BackendNode.js (upload.js) nhận
          imageFile.path,
        ),
      );

      // 2. Ném request lên và chờ Node.js xử lý
      var response = await request.send();

      // 3. Xử lý kết quả trả về
      if (response.statusCode == 200) {
        // Lấy dữ liệu và ép kiểu về JSON
        String responseData = await response.stream.bytesToString();
        var data = jsonDecode(responseData);

        // Trả về cái Link ảnh quý giá cho Flutter
        if (data['success'] == true && data['imageUrl'] != null) {
          _log("==== ✅ UPLOAD ẢNH THÀNH CÔNG: ${data['imageUrl']} ====");
          return data['imageUrl']; // Trả về link ảnh https
        }
      }
      return null;
    } catch (e) {
      _log("==== 🚨 LỖI UPLOAD ẢNH: $e ====");
      return null;
    }
  }

  // HÀM SỬA MÓN ĂN MY FOOD (PUT)
  static Future<bool> updateMyFood(
    String foodId,
    Map<String, dynamic> foodData,
    File? imageToUpload,
  ) async {
    try {
      // BƯỚC A: NẾU CÓ ẢNH MỚI, UPLOAD LÊN MÂY LẤY LINK MỚI
      String finalImageUrl = foodData['imageUrl'] ?? ""; // Link ảnh cũ (nếu có)

      if (imageToUpload != null) {
        _log("==== 🔄 BẮT ĐẦU UPLOAD ẢNH MỚI LÊN MÂY... ====");
        String? link = await uploadImage(imageToUpload);
        if (link != null) {
          finalImageUrl = link; // Gán link ảnh mới
        }
      }

      // BƯỚC B: CẬP NHẬT LINK ẢNH VÀO HỒ SƠ
      foodData['imageUrl'] = finalImageUrl;

      // BƯỚC C: GỬI REQUEST PUT LÊN SERVER NODE.JS
      _log(
        "==== 🔄 ĐANG CẬP NHẬT MÓN ĂN LÊN: $baseUrl/api/user-foods/$foodId ====",
      );
      final response = await http.put(
        Uri.parse('$baseUrl/api/user-foods/$foodId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(foodData),
      );

      _log("==== KẾT QUẢ SERVER TRẢ VỀ: Mã ${response.statusCode} ====");
      _log("==== NỘI DUNG TRẢ VỀ: ${response.body} ====");

      return response.statusCode == 200;
    } catch (e) {
      _log("==== 🚨 LỖI CẬP NHẬT MÓN ĂN: $e ====");
      return false;
    }
  }

  // [NEW] 4. HÀM XÓA MÓN ĂN MY FOOD (DELETE)
  static Future<bool> deleteMyFood(String foodId, String userId) async {
    try {
      _log("==== 🔄 ĐANG XÓA MÓN ĂN: $baseUrl/api/user-foods/$foodId ====");
      final response = await http.delete(
        Uri.parse('$baseUrl/api/user-foods/$foodId'),
        headers: {'Content-Type': 'application/json'},
        // Ta không cần body để verify ownership bên Node.js, frontend sẽ lo
      );

      _log("==== KẾT QUẢ SERVER TRẢ VỀ: Mã ${response.statusCode} ====");
      _log("==== NỘI DUNG TRẢ VỀ: ${response.body} ====");

      return response.statusCode == 200;
    } catch (e) {
      _log("==== 🚨 LỖI XÓA MÓN ĂN: $e ====");
      return false;
    }
  }

  // --- HÀM 4: LẤY THỐNG KÊ HOME TỪ SERVER NODE.JS (Cần viết API bên Node.js nhé) ---
  static Future<Map<String, dynamic>?> getHomeStatistics(String userId) async {
    try {
      _log("==== 🌐 GỌI API ĐẾN: $baseUrl/api/statistics/home/$userId ====");
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/api/statistics/home/$userId',
            ), // Đường dẫn API này cần viết ở Node.js
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'];
      }
    } catch (e) {
      _log("Lỗi gọi API Home Statistics: $e");
    }
    return null; // Trả về null nếu lỗi để Flutter dùng data mặc định
  }

  // --- HÀM REDEEM MỚI: Nhận đầy đủ Bill và Địa chỉ ---
  static Future<Map<String, dynamic>?> redeemProduct({
    String productId = '',
    List<Map<String, dynamic>> items = const [],
    String billUrl = '',
    required String address,
    double lat = 0.0,
    double lng = 0.0,
    required int shippingFee,
    required double distanceKm,
    int quantity = 1,
    String phoneNumber = '',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = prefs.getString('jwt_token');

      if (userId == null) {
        return {'success': false, 'message': 'Lỗi ID người dùng'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/shop/redeem'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': userId,
          'productId': productId,
          'items': items,
          'quantity': quantity,
          'billUrl': billUrl,
          'address': address,
          'lat': lat,
          'lng': lng,
          'shippingFee': shippingFee,
          'distanceKm': distanceKm,
          'phoneNumber': phoneNumber,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      _log("Lỗi gọi API Redeem: $e");
      return {'success': false, 'message': 'Không thể kết nối Server'};
    }
  }

  static Future<Map<String, dynamic>> getAllProducts() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/shop/all'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'products': []};
    } catch (e) {
      return {'success': false, 'products': []};
    }
  }

  static Future<Map<String, dynamic>> getOrderHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null || userId.isEmpty) {
        return {'success': false, 'orders': []};
      }

      final response = await http
          .get(Uri.parse('$baseUrl/api/shop/history/$userId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return {'success': false, 'orders': []};
    } catch (e) {
      return {'success': false, 'orders': []};
    }
  }
}
