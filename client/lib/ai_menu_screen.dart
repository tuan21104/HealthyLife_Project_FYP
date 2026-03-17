import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'services/auth_service.dart';
import 'services/ai_service.dart';

class AIMenuScreen extends StatefulWidget {
  final double targetWeight;
  final int targetCalo;

  const AIMenuScreen({
    super.key,
    required this.targetWeight,
    required this.targetCalo,
  });

  @override
  State<AIMenuScreen> createState() => _AIMenuScreenState();
}

class _AIMenuScreenState extends State<AIMenuScreen> {
  String _aiResponse = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndGenerateMenu();
  }

  Future<void> _fetchAndGenerateMenu() async {
    try {
      // 1. Kéo thông tin user và danh sách món ăn (Database) cùng một lúc
      final userResult = await AuthService.getUserProfile();
      final foodResult =
          await AuthService.getAllFoods(); // Lệnh gọi RAG mới thêm

      if (userResult['success'] == true && userResult['user'] != null) {
        final user = userResult['user'];

        // Trích xuất mảng thức ăn từ Backend (Nếu lỗi mạng đoạn này thì truyền mảng rỗng)
        final List<dynamic> foodDatabase =
            (foodResult['success'] == true && foodResult['foods'] != null)
            ? foodResult['foods']
            : [];

        // Kiểm tra xem DB có trống không
        if (foodDatabase.isEmpty) {
          if (mounted) {
            setState(() {
              _aiResponse =
                  "Cảnh báo: Không tìm thấy dữ liệu món ăn trong Database. Vui lòng kiểm tra lại Backend (chạy hàm /seed).";
              _isLoading = false;
            });
          }
          return;
        }

        // PARSE DỮ LIỆU AN TOÀN TUYỆT ĐỐI
        double currentWeight =
            double.tryParse(user['weight'].toString()) ?? 60.0;

        // 2. Gửi thông tin cho Gemini qua AIService (KÈM THEO DATABASE MÓN ĂN)
        final menu = await AIService.getDietaryAdvice(
          currentWeight: currentWeight,
          targetWeight: widget.targetWeight,
          targetCalo: widget.targetCalo,
          foodDatabase: foodDatabase, // ĐÂY LÀ CHÌA KHÓA CỦA RAG
        );

        // 3. Cập nhật giao diện khi có kết quả từ AI
        if (mounted) {
          setState(() {
            _aiResponse = menu;
            _isLoading = false;
          });
        }
      } else {
        // NẾU BACKEND TỪ CHỐI TRẢ DỮ LIỆU USER
        if (mounted) {
          setState(() {
            _aiResponse =
                "Lỗi Backend: ${userResult['message'] ?? 'Không rõ lỗi'}";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // NẾU CÓ LỖI XẢY RA TRONG LÚC CHẠY (Bắt sống Bug)
      if (mounted) {
        setState(() {
          _aiResponse = "Lỗi hệ thống App: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Your AI Nutritionist",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading ? _buildLoadingState() : _buildMenuContent(),
      ),
    );
  }

  // --- GIAO DIỆN LÚC ĐANG CHỜ AI ---
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/logo_green.png',
            height: 80,
            color: const Color(0xFF4CAF50).withOpacity(0.5),
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.restaurant,
              size: 80,
              color: Color(0xFF4CAF50),
            ), // Fallback nếu lỗi đường dẫn ảnh
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Color(0xFF4CAF50)),
          const SizedBox(height: 24),
          const Text(
            "AI đang thiết kế thực đơn từ DB chuẩn Viện Dinh Dưỡng...\nVui lòng chờ trong giây lát!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }

  // --- GIAO DIỆN KHI CÓ KẾT QUẢ ---
  Widget _buildMenuContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant_menu, color: Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                Text(
                  "Thực đơn ${widget.targetCalo} Kcal",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const Divider(height: 30, thickness: 1),
            // ĐÃ NÂNG CẤP: Dùng MarkdownBody để render các thẻ in đậm, in nghiêng
            MarkdownBody(
              data: _aiResponse,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.6,
                ),
                strong: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                listBullet: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.6,
                ),
                h1: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50),
                ),
                h2: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
