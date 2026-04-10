import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'diary_screen.dart';
import 'home_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Biến lưu trữ tab đang được chọn (Mặc định là 0 - Home)
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 3);
  }

  final List<Widget> _pages = [
    const HomeScreen(),
    const DiaryScreen(),
    const Center(
      child: Text(
        "⚙️ Trang Settings (Sắp ra mắt)",
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    ),
    const ProfileScreen(),
  ];

  // Hàm xử lý khi người dùng bấm vào một tab
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Phần thân trên sẽ hiển thị màn hình tương ứng với tab được chọn
      body: IndexedStack(index: _selectedIndex, children: _pages),
      // Thanh điều hướng bên dưới
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(
                0,
                -5,
              ), // Đổ bóng nhẹ lên trên cho viền thanh tab
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType
              .fixed, // Giữ các icon đứng im không bị phóng to
          backgroundColor: Colors.white,
          elevation: 0,
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(
            0xFF4CAF50,
          ), // Màu xanh lá khi được chọn
          unselectedItemColor: Colors.grey[400], // Màu xám khi không được chọn
          selectedFontSize: 12,
          unselectedFontSize: 12,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home_filled),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.pie_chart),
              ),
              label: 'Diaries',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.settings),
              ),
              label: 'Settings',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.person),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
