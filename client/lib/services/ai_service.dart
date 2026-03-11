import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  // Hàm gọi AI để lấy tư vấn thực đơn
  static Future<String> getDietaryAdvice({
    required double currentWeight,
    required double targetWeight,
    required int targetCalo,
    required String gender,
    required String activityLevel,
    required int dailyBudget, // ĐÃ BỔ SUNG: Tham số ngân sách
  }) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return "Lỗi bảo mật: Không tìm thấy API Key. Vui lòng kiểm tra lại file .env";
      }

      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      String goal = currentWeight > targetWeight ? "Giảm cân" : "Tăng cân";

      // PROMPT ĐÃ NÂNG CẤP: Ép AI phải tối ưu chi phí
      final String prompt =
          '''
      Bạn là một chuyên gia dinh dưỡng thực tế và am hiểu giá cả thị trường Việt Nam.
      Dưới đây là thông tin của tôi:
      - Giới tính: $gender
      - Cân nặng hiện tại: ${currentWeight}kg
      - Mục tiêu: $goal để đạt ${targetWeight}kg
      - Lượng Calo nạp vào mục tiêu: $targetCalo kcal/ngày.
      - NGÂN SÁCH ĂN UỐNG TỐI ĐA: $dailyBudget VNĐ/ngày.

      Nhiệm vụ của bạn:
      Hãy thiết kế một thực đơn 1 ngày (Sáng, Trưa, Tối, Phụ) đáp ứng ĐỒNG THỜI 2 tiêu chí:
      1. Tổng lượng calo bám sát mức $targetCalo kcal.
      2. Tổng chi phí mua nguyên liệu KHÔNG ĐƯỢC VƯỢ QUÁ $dailyBudget VNĐ.

      Yêu cầu trình bày:
      - Gạch đầu dòng rõ ràng từng bữa.
      - Ước tính lượng Calo VÀ Giá tiền (VNĐ) bên cạnh mỗi món ăn.
      - Nếu ngân sách hẹp, hãy ưu tiên các thực phẩm bình dân, sinh viên dễ tìm (như trứng, đậu phụ, ức gà, rau theo mùa...).
      - Cuối cùng, có 1 dòng "Tổng kết: Tổng Calo | Tổng Chi phí" để chứng minh bạn không vượt ngân sách.
      
      Trả lời bằng tiếng Việt, thân thiện và súc tích.
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      return response.text ?? "AI hiện đang bận, vui lòng thử lại sau nhé.";
    } catch (e) {
      print("Lỗi hệ thống AI: $e");
      return "CHI TIẾT LỖI TỪ GOOGLE:\n$e";
    }
  }
}
