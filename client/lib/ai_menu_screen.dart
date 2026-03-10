import 'package:flutter/material.dart';
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
    // 1. Kéo thông tin user từ Database (để lấy Giới tính, Cân nặng, Vận động và Budget)
    final result = await AuthService.getUserProfile();
    
    if (result['success'] == true && result['user'] != null) {
      final user = result['user'];
      
      // Lấy thông số (Nếu thiếu thì để mặc định)
      double currentWeight = (user['weight'] ?? 60).toDouble();
      String gender = user['gender'] ?? 'Male';
      String activityLevel = user['activityLevel'] ?? 'Sedentary';
      int dailyBudget = user['dailyBudget'] ?? 100000; // Mặc định 100k nếu chưa nhập

      // 2. Gửi thông tin cho Gemini qua AIService
      final menu = await AIService.getDietaryAdvice(
        currentWeight: currentWeight,
        targetWeight: widget.targetWeight,
        targetCalo: widget.targetCalo,
        gender: gender,
        activityLevel: activityLevel,
        dailyBudget: dailyBudget,
      );

      // 3. Cập nhật giao diện khi có kết quả
      if (mounted) {
        setState(() {
          _aiResponse = menu;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _aiResponse = "Không thể tải thông tin hồ sơ của bạn. Vui lòng thử lại.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA), // Nền xám nhạt cho nổi bật thẻ nội dung
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Your AI Nutritionist", 
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading 
            ? _buildLoadingState() 
            : _buildMenuContent(),
      ),
    );
  }

  // --- GIAO DIỆN LÚC ĐANG CHỜ AI ---
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/logo_green.png', height: 80, color: const Color(0xFF4CAF50).withOpacity(0.5)),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Color(0xFF4CAF50)),
          const SizedBox(height: 24),
          const Text(
            "AI đang thiết kế thực đơn cho bạn...\nVui lòng chờ trong giây lát!",
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                ),
              ],
            ),
            const Divider(height: 30, thickness: 1),
            // Parse và hiển thị Text từ AI trả về
            Text(
              _aiResponse,
              style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}