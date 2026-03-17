import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  static Future<String> getDietaryAdvice({
    required double currentWeight,
    required double targetWeight,
    required int targetCalo,
    required List<dynamic> foodDatabase, // THÊM BIẾN NÀY ĐỂ NHẬN DATA TỪ DB
  }) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return "Lỗi: Chưa cấu hình API Key cho Gemini.";
      }

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );

      // Ép kiểu mảng thức ăn thành chuỗi String (JSON Format) để AI có thể đọc hiểu
      String foodListString = jsonEncode(foodDatabase);

      // KỸ THUẬT RAG: NHÚNG DỮ LIỆU VÀ ÉP BUỘC AI
      final prompt = '''
Bạn là một chuyên gia dinh dưỡng thực tế tại Việt Nam.
Thông tin cơ thể khách hàng: 
- Cân nặng hiện tại: $currentWeight kg
- Cân nặng mục tiêu: $targetWeight kg
- Lượng Calo yêu cầu một ngày: $targetCalo kcal.

RÀNG BUỘC TỐI CAO (BẮT BUỘC TUÂN THỦ 100%):
1. Bạn CHỈ ĐƯỢC PHÉP chọn các nguyên liệu nấu ăn từ "Danh sách Cơ sở dữ liệu" (JSON) tôi cung cấp bên dưới để thiết kế thực đơn 3 bữa (Sáng, Trưa, Tối). TUYỆT ĐỐI KHÔNG tự phát minh hoặc thêm bất kỳ nguyên liệu nào nằm ngoài danh sách này.
2. Dựa vào trường 'pricePer100g' trong JSON, hãy tính toán và ghi rõ tổng số tiền dự kiến cho cả ngày. Đảm bảo giá tiền là thực tế nhất.
3. Dựa vào trường 'calories' trong JSON, hãy đảm bảo tổng lượng calo 3 bữa bám sát mốc $targetCalo kcal.
4. Trình bày bằng Tiếng Việt, định dạng Markdown đẹp mắt, phân cấp rõ ràng (dùng in đậm, gạch đầu dòng). Mỗi món ăn phải ghi rõ số lượng gam (g).

DANH SÁCH CƠ SỞ DỮ LIỆU MÓN ĂN (JSON):
$foodListString
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      return response.text ?? "Không thể tạo thực đơn lúc này. Vui lòng thử lại.";
    } catch (e) {
      return "Hệ thống AI đang bận hoặc có lỗi mạng: $e";
    }
  }
}