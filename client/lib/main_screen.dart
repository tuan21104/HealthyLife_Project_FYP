import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'profile_screen.dart';
import 'diary_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Biến lưu trữ tab đang được chọn (Mặc định là 0 - Home)
  late int _selectedIndex;
  int _homeRefreshSignal = 0;
  int _diaryRefreshSignal = 0;
  Locale? _currentLocale;
  int _localeVersion = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 3);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLocale = context.locale;

    if (_currentLocale == null) {
      _currentLocale = newLocale;
      return;
    }

    if (_currentLocale != newLocale && mounted) {
      setState(() {
        _currentLocale = newLocale;
        _localeVersion++;
      });
    }
  }

  List<Widget> _buildPages() {
    return [
      KeyedSubtree(
        key: ValueKey('home_${_currentLocale?.languageCode}_$_localeVersion'),
        child: HomeScreen(refreshSignal: _homeRefreshSignal),
      ),
      KeyedSubtree(
        key: ValueKey('diary_${_currentLocale?.languageCode}_$_localeVersion'),
        child: DiaryScreen(refreshSignal: _diaryRefreshSignal),
      ),
      KeyedSubtree(
        key: ValueKey(
          'settings_${_currentLocale?.languageCode}_$_localeVersion',
        ),
        child: const SettingsScreen(),
      ),
      KeyedSubtree(
        key: ValueKey(
          'profile_${_currentLocale?.languageCode}_$_localeVersion',
        ),
        child: const ProfileScreen(),
      ),
    ];
  }

  // Hàm xử lý khi người dùng bấm vào một tab
  void _onItemTapped(int index) {
    setState(() {
      if (index == 0) {
        _homeRefreshSignal++;
      }
      if (index == 1) {
        _diaryRefreshSignal++;
      }
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    return Scaffold(
      backgroundColor: Colors.white,
      // Phần thân trên sẽ hiển thị màn hình tương ứng với tab được chọn
      body: IndexedStack(index: _selectedIndex, children: pages),
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
          items: [
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.home_filled),
              ),
              label: 'nav.home'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.pie_chart),
              ),
              label: 'nav.diaries'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.settings),
              ),
              label: 'nav.settings'.tr(),
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.person),
              ),
              label: 'nav.profile'.tr(),
            ),
          ],
        ),
      ),
    );
  }
}
