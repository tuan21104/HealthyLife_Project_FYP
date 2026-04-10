import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'user_info_step1_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'modal_effects.dart';
import 'animation_presets.dart';

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

  Future<void> _fetchUserData() async {
    print("==== 🔄 ĐANG GỌI API LẤY PROFILE... ====");
    try {
      final result = await AuthService.getUserProfile();
      print("==== 📥 KẾT QUẢ API PROFILE TRẢ VỀ: $result ====");

      if (mounted) {
        setState(() {
          if (result != null &&
              (result['success'] == true || result['user'] != null)) {
            _userData = result['user'] ?? result['data'];
          } else {
            print("⚠️ CẢNH BÁO: Dữ liệu trả về bị rỗng hoặc success = false");
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print("==== 🚨 LỖI CRASH KHI GỌI API PROFILE: $e ====");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

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
            )
          : _userData == null
          ? const Center(child: Text("Lỗi tải dữ liệu. Vui lòng thử lại!"))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // --- PHẦN AVATAR: ĐÃ SỬA LỖI UNDEFINED 'USER' ---
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      child: ClipOval(
                        child:
                            (_userData?['avatarUrl'] != null &&
                                _userData!['avatarUrl'].toString().isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: _userData!['avatarUrl'],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                errorWidget: (context, url, error) =>
                                    _buildPlaceholderIcon(),
                              )
                            : _buildPlaceholderIcon(),
                      ),
                    ),
                    const SizedBox(height: 40),

                    _buildProfileRow(
                      "Name:",
                      _userData?['name'] ?? "Chưa cập nhật",
                    ).withStagger(0),
                    _buildProfileRow(
                      "ID:",
                      _userData?['_id']?.toString().substring(0, 8) ??
                          "Chưa cập nhật",
                    ).withStagger(1),
                    _buildProfileRow(
                      "Email:",
                      _userData?['email'] ?? "Chưa cập nhật",
                    ).withStagger(2),
                    _buildProfileRow(
                      "Gender:",
                      _userData?['gender'] ?? "Chưa cập nhật",
                    ).withStagger(3),
                    _buildProfileRow(
                      "Weight:",
                      _userData?['weight'] != null
                          ? "${_userData!['weight']} Kg"
                          : "Chưa cập nhật",
                    ).withStagger(4),
                    _buildProfileRow(
                      "Height:",
                      _userData?['height'] != null
                          ? "${_userData!['height']} Cm"
                          : "Chưa cập nhật",
                    ).withStagger(5),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditProfileScreen(userData: _userData!),
                            ),
                          );

                          if (result == true) {
                            setState(() {
                              _isLoading = true;
                            });
                            _fetchUserData();
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
                    ).withStagger(6),

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
                    ).withStagger(7),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _showChangeGoalConfirmDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Change Goal",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ).withStagger(8),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // --- HÀM PHỤ TRỢ HIỂN THỊ ICON KHI KHÔNG CÓ ẢNH MẠNG ---
  Widget _buildPlaceholderIcon() {
    if (_userData?['avatarIndex'] != null) {
      return Image.asset(
        'assets/images/avatar_${_userData!['avatarIndex'] + 1}.png',
        width: 80,
        height: 80,
        fit: BoxFit.cover,
      );
    }
    return const Icon(Icons.person, size: 40, color: Colors.grey);
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

  void _showChangeGoalConfirmDialog(BuildContext context) {
    ModalEffects.showScaleFadeDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Change Your Goal?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Bạn sẽ được chuyển về trang nhập liệu ban đầu để thiết lập lại các chỉ số cơ thể và mục tiêu mới. Bạn có chắc chắn muốn tiếp tục?",
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 0, 255, 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        UserInfoStep1Screen(email: _userData?['email'] ?? ''),
                  ),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text(
                "Yes",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
