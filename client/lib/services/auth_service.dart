import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class AuthService {
  static const String myWifiIp = '172.20.10.11';

  // SỬA LỖI 1: Đổi thành false để máy ảo Android dùng IP 10.0.2.2 cho ổn định
  static const bool isOnlineMode = false;

  // SỬA LỖI 2: Cắt bỏ chữ 'auth' ở đuôi, chỉ giữ lại '/api' làm thư mục gốc
  static const String baseUrl = isOnlineMode
      ? 'http://$myWifiIp:3000'
      : 'http://10.0.2.2:3000';

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
        print("==== 🕵️‍♂️ DỮ LIỆU LOGIN BACKEND GỬI VỀ LÀ: $data ====");

        if (data['token'] != null) {
          final prefs = await SharedPreferences.getInstance();

          // 1. Lưu Token
          await prefs.setString('jwt_token', data['token']);

          // 2. LƯU USER ID (ĐÃ SỬA CHUẨN XÁC 100%)
          String userId = "";

          if (data['user'] != null) {
            // Chỉ cần data['user'] tồn tại, ta sẽ vét cạn tìm 'id' hoặc '_id'
            userId =
                data['user']['id']?.toString() ??
                data['user']['_id']?.toString() ??
                "";
          } else if (data['userId'] != null) {
            userId = data['userId']?.toString() ?? "";
          }

          if (userId.isNotEmpty) {
            await prefs.setString('userId', userId);
            print("==== ✅ Đã lưu Token và UserId: $userId ====");
          } else {
            print(
              "==== ⚠️ CẢNH BÁO: Đăng nhập thành công nhưng Backend không trả về UserId! ====",
            );
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

  // --- HÀM 3: CẬP NHẬT THÔNG TIN (BẢN FIX TRIỆT ĐỂ LỖI OBJECTID) ---// Trong file lib/services/auth_service.dart
  static Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(
        'userId',
      ); // Tự lấy ID từ máy, không bắt truyền vào nữa
      final token = prefs.getString('jwt_token');

      if (userId == null) return false;

      profileData['userId'] = userId; // Gán ID vào body

      final response = await http.put(
        Uri.parse('$baseUrl/api/users/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(profileData),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Lỗi updateProfile: $e");
      return false;
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
        print("==== ⚠️ KHÔNG CÓ TOKEN, APP SẼ BỊ SERVER TỪ CHỐI ====");
        return {'success': false, 'message': 'Chưa đăng nhập'};
      }

      print(
        "==== 🔄 ĐANG LẤY PROFILE VỚI TOKEN: ${token.substring(0, 10)}... ====",
      );

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
        print("==== 🚨 SERVER TỪ CHỐI: ${response.body} ====");
        return {
          'success': false,
          'message': 'Lỗi xác thực: ${response.statusCode}',
        };
      }
    } catch (e) {
      print("==== 🚨 LỖI GỌI API PROFILE: $e ====");
      return {'success': false, 'message': e.toString()};
    }
  }

  // --- HÀM TẢI KHO DATA MÓN ĂN GỐC ---
  static Future<Map<String, dynamic>> getAllFoods() async {
    try {
      print("==== 🔄 ĐANG TẢI DATABASE MÓN ĂN TỪ: $baseUrl/api/foods ====");
      final response = await http.get(Uri.parse('$baseUrl/api/foods'));

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);

        // TRƯỜNG HỢP 1: Backend trả về một Danh sách (Array) trực tiếp
        if (decodedData is List) {
          print(
            "==== ✅ TẢI THÀNH CÔNG: ${decodedData.length} món ăn gốc (Dạng List) ====",
          );
          return {'success': true, 'foods': decodedData};
        }

        // TRƯỜNG HỢP 2: Backend trả về đúng chuẩn Object { success: true, foods: [...] }
        print("==== ✅ TẢI THÀNH CÔNG (Dạng Object) ====");
        return decodedData;
      } else {
        print(
          "==== ⚠️ LỖI SERVER KHI TẢI DATA: Mã ${response.statusCode} ====",
        );
        return {'success': false, 'foods': []};
      }
    } catch (e) {
      print("==== 🚨 LỖI GỌI API ALL FOODS: $e ====");
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
      print("Lỗi tải My Foods: $e");
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
      print("Lỗi tải Recipes: $e");
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
        print("==== 🔄 BẮT ĐẦU UPLOAD ẢNH LÊN MÂY... ====");
        String? link = await uploadImage(imageToUpload);
        if (link != null) {
          imageUrlOnCloud = link; // Gán link ảnh lấy về vào đây
        }
      }

      // BƯỚC B: NỐI LINK ẢNH VÀO HỒ SƠ MÓN ĂN
      foodData['imageUrl'] = imageUrlOnCloud; // Nối link ảnh vào object JSON

      // BƯỚC C: GỬI HỒ SƠ MÓN ĂN LÊN CLOBAL DATABASE (MONGODB)
      print("==== 🔄 ĐANG GỬI HỒ SƠ MÓN ĂN LÊN: $baseUrl/api/user-foods ====");
      final response = await http.post(
        Uri.parse('$baseUrl/api/user-foods'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(foodData),
      );

      print("==== KẾT QUẢ SERVER TRẢ VỀ: Mã ${response.statusCode} ====");
      print("==== NỘI DUNG TRẢ VỀ: ${response.body} ====");

      return response.statusCode == 201;
    } catch (e) {
      print("==== 🚨 LỖI KẾT NỐI MẠNG CHÍ MẠNG: $e ====");
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
      print("Lỗi tạo Công thức: $e");
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
          print("==== ✅ UPLOAD ẢNH THÀNH CÔNG: ${data['imageUrl']} ====");
          return data['imageUrl']; // Trả về link ảnh https
        }
      }
      return null;
    } catch (e) {
      print("==== 🚨 LỖI UPLOAD ẢNH: $e ====");
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
        print("==== 🔄 BẮT ĐẦU UPLOAD ẢNH MỚI LÊN MÂY... ====");
        String? link = await uploadImage(imageToUpload);
        if (link != null) {
          finalImageUrl = link; // Gán link ảnh mới
        }
      }

      // BƯỚC B: CẬP NHẬT LINK ẢNH VÀO HỒ SƠ
      foodData['imageUrl'] = finalImageUrl;

      // BƯỚC C: GỬI REQUEST PUT LÊN SERVER NODE.JS
      print(
        "==== 🔄 ĐANG CẬP NHẬT MÓN ĂN LÊN: $baseUrl/api/user-foods/$foodId ====",
      );
      final response = await http.put(
        Uri.parse('$baseUrl/api/user-foods/$foodId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(foodData),
      );

      print("==== KẾT QUẢ SERVER TRẢ VỀ: Mã ${response.statusCode} ====");
      print("==== NỘI DUNG TRẢ VỀ: ${response.body} ====");

      return response.statusCode == 200;
    } catch (e) {
      print("==== 🚨 LỖI CẬP NHẬT MÓN ĂN: $e ====");
      return false;
    }
  }

  // [NEW] 4. HÀM XÓA MÓN ĂN MY FOOD (DELETE)
  static Future<bool> deleteMyFood(String foodId, String userId) async {
    try {
      print("==== 🔄 ĐANG XÓA MÓN ĂN: $baseUrl/api/user-foods/$foodId ====");
      final response = await http.delete(
        Uri.parse('$baseUrl/api/user-foods/$foodId'),
        headers: {'Content-Type': 'application/json'},
        // Ta không cần body để verify ownership bên Node.js, frontend sẽ lo
      );

      print("==== KẾT QUẢ SERVER TRẢ VỀ: Mã ${response.statusCode} ====");
      print("==== NỘI DUNG TRẢ VỀ: ${response.body} ====");

      return response.statusCode == 200;
    } catch (e) {
      print("==== 🚨 LỖI XÓA MÓN ĂN: $e ====");
      return false;
    }
  }

  // --- HÀM 4: LẤY THỐNG KÊ HOME TỪ SERVER NODE.JS (Cần viết API bên Node.js nhé) ---
  static Future<Map<String, dynamic>?> getHomeStatistics(String userId) async {
    try {
      print("==== 🌐 GỌI API ĐẾN: $baseUrl/api/statistics/home/$userId ====");
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
      print("Lỗi gọi API Home Statistics: $e");
    }
    return null; // Trả về null nếu lỗi để Flutter dùng data mặc định
  }

  // --- HÀM REDEEM MỚI: Nhận đầy đủ Bill và Địa chỉ ---
  static Future<Map<String, dynamic>?> redeemProduct({
    required String productId,
    String billUrl = '',
    required String address,
    double lat = 0.0,
    double lng = 0.0,
    required int shippingFee,
    required double distanceKm,
    int quantity = 1,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = prefs.getString('jwt_token');

      if (userId == null)
        return {'success': false, 'message': 'Lỗi ID người dùng'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/shop/redeem'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': userId,
          'productId': productId,
          'quantity': quantity,
          'billUrl': billUrl,
          'address': address,
          'lat': lat,
          'lng': lng,
          'shippingFee': shippingFee,
          'distanceKm': distanceKm,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print("Lỗi gọi API Redeem: $e");
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
