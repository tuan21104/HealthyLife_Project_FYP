import 'package:flutter/material.dart';
import 'main_screen.dart';
import 'ai_menu_screen.dart';

class CongratulationsScreen extends StatefulWidget {
  // Các thông số này sau này sẽ được truyền từ màn hình Target Weight sang
  final double targetWeightLoss;
  final int durationDays;
  final int maintenanceCalo;
  final int targetCalo;
  final bool isLosing;

  const CongratulationsScreen({
    super.key,
    this.targetWeightLoss = 12.5, // Dữ liệu mẫu theo thiết kế
    this.durationDays = 135,
    this.maintenanceCalo = 2500,
    this.targetCalo = 1870,
    this.isLosing = true,
  });

  @override
  State<CongratulationsScreen> createState() => _CongratulationsScreenState();
}

class _CongratulationsScreenState extends State<CongratulationsScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [_buildPage1(), _buildPage2(), _buildPage3()],
              ),
            ),

            // Phần hiển thị chấm tròn (Dot Indicators) và nút Start
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Căn lề ảo để chấm tròn luôn ở giữa màn hình
                  const SizedBox(width: 48),

                  // Các chấm tròn
                  Row(
                    children: List.generate(
                      3,
                      (index) => _buildDot(index: index),
                    ),
                  ),

                  // Nút Start chỉ hiện ở trang cuối cùng
                  _currentPage == 2
                      ? GestureDetector(
                          onTap: () {
                            print("Chuyển vào màn hình chính Home Screen!");
                            // Dùng pushAndRemoveUntil để xóa sạch lịch sử màn hình Onboarding (người dùng bấm Back trên đt không bị quay lại màn hình đăng ký)
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MainScreen(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                          },
                          child: const Row(
                            children: [
                              Text(
                                "Start",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        )
                      : const SizedBox(
                          width: 48,
                        ), // Căn lề ảo nếu không phải trang cuối
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TRANG 1 ---
  Widget _buildPage1() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Congratulations!",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 40),
          // Thay ảnh thật từ Figma vào đây
          Image.asset(
            'assets/images/congrats_1.png',
            height: 250,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.image, size: 150, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          Text(
            "You finished\nthe registration process\nsuccessfully!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // --- TRANG 2 ---
  Widget _buildPage2() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "You should take",
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          Text(
            "${widget.maintenanceCalo} Kcal",
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "per day to stay in your\npresent weight.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 50),
          Image.asset(
            'assets/images/congrats_2.png',
            height: 250,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.fitness_center, size: 150, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // --- TRANG 3 ---
  Widget _buildPage3() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/congrats_3.png',
            height: 250,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.restaurant_menu,
              size: 150,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 50),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text:
                      "As you are going to ${widget.isLosing ? 'lose' : 'gain'}\n",
                ),
                TextSpan(
                  text: "${widget.targetWeightLoss}kg ",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                const TextSpan(text: "in "),
                TextSpan(
                  text: "${widget.durationDays} days, ",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const TextSpan(text: "you should\ntake "),
                TextSpan(
                  text: "${widget.targetCalo} kcal ",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const TextSpan(text: "per day!"),
              ],
            ),
          ),

          const SizedBox(height: 40), // Khoảng cách từ chữ xuống nút
          // NÚT 1: GỌI CHUYÊN GIA AI
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AIMenuScreen(
                      targetWeight:
                          0, // Placeholder, AI sẽ dùng currentWeight và calo để tính toán
                      targetCalo: widget.targetCalo,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              label: const Text(
                "Generate AI Menu",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // Màu cam cho AI nổi bật
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // NÚT 2: VỀ TRANG CHỦ HOÀN TẤT
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
              // Chuyển thẳng đến MainScreen bằng MaterialPageRoute
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScreen()), 
                  (Route<dynamic> route) => false, // Xoá sạch lịch sử trang cũ
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Go to Dashboard",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET CHẤM TRÒN ---
  Widget _buildDot({required int index}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 8),
      height: 10,
      width: 10,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? const Color(0xFF80CBC4)
            : Colors.grey[300], // Màu xanh lơ khi được chọn
        shape: BoxShape.circle,
      ),
    );
  }
}
