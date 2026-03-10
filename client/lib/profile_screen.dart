import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Hàm tự động chạy để kéo dữ liệu từ DB về
  Future<void> _fetchUserData() async {
    final result = await AuthService.getUserProfile();
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _userData = result['user'];
        }
        _isLoading = false;
      });
    }
  }

  // --- LOGIC ĐĂNG XUẤT ---
  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.normal,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            ) // Hiện vòng xoay lúc đang tải
          : _userData == null
          ? const Center(child: Text("Lỗi tải dữ liệu. Vui lòng thử lại!"))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFE8F5E9),
                      backgroundImage: _userData?['avatarIndex'] != null
                          ? AssetImage(
                              'assets/images/avatar_${_userData!['avatarIndex'] + 1}.png',
                            )
                          : null,
                      child: _userData?['avatarIndex'] == null
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: Color(0xFF4CAF50),
                            )
                          : null,
                    ),
                    const SizedBox(height: 40),

                    // ĐỔ DỮ LIỆU THẬT VÀO ĐÂY (Nếu null thì hiện 'Chưa cập nhật')
                    _buildProfileRow(
                      "Name:",
                      _userData?['name'] ?? "Chưa cập nhật",
                    ),
                    _buildProfileRow(
                      "ID:",
                      _userData?['_id']?.toString().substring(0, 8) ??
                          "Chưa cập nhật",
                    ),
                    _buildProfileRow(
                      "Email:",
                      _userData?['email'] ?? "Chưa cập nhật",
                    ),
                    _buildProfileRow(
                      "Gender:",
                      _userData?['gender'] ?? "Chưa cập nhật",
                    ),
                    _buildProfileRow(
                      "Weight:",
                      _userData?['weight'] != null
                          ? "${_userData!['weight']} Kg"
                          : "Chưa cập nhật",
                    ),
                    _buildProfileRow(
                      "Height:",
                      _userData?['height'] != null
                          ? "${_userData!['height']} Cm"
                          : "Chưa cập nhật",
                    ),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Chuyển sang trang Edit và chờ kết quả trả về
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditProfileScreen(userData: _userData!),
                            ),
                          );

                          // Nếu result == true (người dùng bấm Save thành công), tự động tải lại dữ liệu mới
                          if (result == true) {
                            setState(() {
                              _isLoading = true; // Hiện vòng quay loading
                            });
                            _fetchUserData(); // Gọi lại API để cập nhật UI
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Edit",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _handleLogout(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Log out",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
