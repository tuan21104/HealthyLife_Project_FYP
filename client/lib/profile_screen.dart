import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
  Locale? _currentLocale;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
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
      _currentLocale = newLocale;
      setState(() {});
    }
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
        title: Text(
          'profile.title'.tr(),
          style: const TextStyle(
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
          ? Center(
              child: Text('${'common.error'.tr()}. ${'common.retry'.tr()}'),
            )
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

                    _buildSectionHeader(
                      title: 'profile.your_info'.tr(),
                      subtitle: 'profile.info_subtitle'.tr(),
                    ).withStagger(0),
                    const SizedBox(height: 14),
                    _buildPersonalInfoCard().withStagger(1),

                    const SizedBox(height: 18),
                    _buildSectionHeader(
                      title: 'profile.goal_overview'.tr(),
                      subtitle: 'profile.goal_subtitle'.tr(),
                    ).withStagger(2),
                    const SizedBox(height: 14),
                    _buildGoalOverviewCard().withStagger(3),

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

                          if (!mounted || result == null) return;

                          if (result == true) {
                            setState(() => _isLoading = true);
                            _fetchUserData();
                            return;
                          }

                          if (result is Map && result['updated'] == true) {
                            final updatedUser = result['user'];
                            if (updatedUser is Map) {
                              setState(() {
                                _userData = Map<String, dynamic>.from(
                                  updatedUser,
                                );
                                _isLoading = false;
                              });
                            } else {
                              setState(() => _isLoading = true);
                              _fetchUserData();
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'profile.edit_profile'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ).withStagger(4),

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
                        child: Text(
                          'profile.logout'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ).withStagger(5),

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
                        child: Text(
                          'profile.change_goal'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ).withStagger(6),

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

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoCard() {
    final items = <_ProfileInfoItem>[
      _ProfileInfoItem(
        label: 'profile.name'.tr(),
        value: _userData?['name'] ?? 'profile.not_updated'.tr(),
        icon: Icons.person_outline_rounded,
        color: const Color(0xFF4CAF50),
      ),
      _ProfileInfoItem(
        label: 'profile.id'.tr(),
        value:
            _userData?['_id']?.toString().substring(0, 8) ??
            'profile.not_updated'.tr(),
        icon: Icons.badge_outlined,
        color: const Color(0xFF78909C),
      ),
      _ProfileInfoItem(
        label: 'profile.email'.tr(),
        value: _userData?['email'] ?? 'profile.not_updated'.tr(),
        icon: Icons.email_outlined,
        color: const Color(0xFF1976D2),
      ),
      _ProfileInfoItem(
        label: 'profile.phone_number'.tr(),
        value:
            (_userData?['phoneNumber']?.toString().trim().isNotEmpty ?? false)
            ? _userData!['phoneNumber']
            : 'profile.not_updated'.tr(),
        icon: Icons.phone_outlined,
        color: const Color(0xFF00897B),
      ),
      _ProfileInfoItem(
        label: 'profile.gender'.tr(),
        value: _formatGenderLabel(_userData?['gender']),
        icon: Icons.wc_outlined,
        color: const Color(0xFFFF8F00),
      ),
      _ProfileInfoItem(
        label: 'profile.weight'.tr(),
        value: _userData?['weight'] != null
            ? '${_userData!['weight']} Kg'
            : 'profile.not_updated'.tr(),
        icon: Icons.monitor_weight_outlined,
        color: const Color(0xFF8D6E63),
      ),
      _ProfileInfoItem(
        label: 'profile.height'.tr(),
        value: _userData?['height'] != null
            ? '${_userData!['height']} Cm'
            : 'profile.not_updated'.tr(),
        icon: Icons.height_outlined,
        color: const Color(0xFF26A69A),
      ),
      _ProfileInfoItem(
        label: 'profile.activity_level'.tr(),
        value: _formatActivityLevelLabel(_userData?['activityLevel']),
        icon: Icons.directions_run_outlined,
        color: const Color(0xFF5C6BC0),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E9E2)),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.85,
        children: items
            .map(
              (item) => _buildInfoTile(
                label: item.label,
                value: item.value,
                icon: item.icon,
                color: item.color,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECE6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatGoalLabel(String? goal) {
    switch (goal) {
      case 'Losing Weight':
      case 'onboarding.losing_weight':
        return 'onboarding.losing_weight'.tr();
      case 'Gaining Weight':
      case 'onboarding.gaining_weight':
        return 'onboarding.gaining_weight'.tr();
      case 'Keeping Weight':
      case 'onboarding.keeping_weight':
        return 'onboarding.keeping_weight'.tr();
      case 'Being Fit':
      case 'onboarding.being_fit':
        return 'onboarding.being_fit'.tr();
      default:
        return 'profile.not_updated'.tr();
    }
  }

  String _formatGenderLabel(dynamic gender) {
    final g = gender?.toString().toLowerCase();
    switch (g) {
      case 'male':
        return 'onboarding.male'.tr();
      case 'female':
        return 'onboarding.female'.tr();
      case 'other':
        return 'onboarding.other'.tr();
      default:
        return 'profile.not_updated'.tr();
    }
  }

  String _formatActivityLevelLabel(dynamic activityLevel) {
    final level = activityLevel?.toString();
    switch (level) {
      case 'Sedentary':
        return 'profile.activity_sedentary'.tr();
      case 'Lightly Active':
        return 'profile.activity_lightly_active'.tr();
      case 'Moderately Active':
        return 'profile.activity_moderately_active'.tr();
      case 'Very Active':
        return 'profile.activity_very_active'.tr();
      default:
        return 'profile.not_updated'.tr();
    }
  }

  String _formatNullableNum(dynamic value, {String suffix = ''}) {
    if (value == null) return 'profile.not_updated'.tr();
    if (value is num)
      return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}$suffix';
    return '$value$suffix';
  }

  Widget _buildGoalOverviewCard() {
    final goal = _userData?['goal']?.toString();
    final dailyBudget = _userData?['dailyBudget'];
    final targetWeight = _userData?['targetWeight'];
    final targetWeightLoss = _userData?['targetWeightLoss'];
    final durationDays = _userData?['durationDays'];
    final maintenanceCalo = _userData?['maintenanceCalo'];
    final targetCalo = _userData?['targetCalo'];
    final isLosing = goal == 'Losing Weight';
    final isGaining = goal == 'Gaining Weight';

    String planLabel;
    if (targetWeightLoss != null && durationDays != null) {
      planLabel =
          '${isLosing
              ? 'onboarding.losing_weight'.tr()
              : isGaining
              ? 'onboarding.gaining_weight'.tr()
              : 'profile.adjusting'.tr()} '
          '${_formatNullableNum(targetWeightLoss, suffix: ' Kg')} '
          '${'profile.duration'.tr()}: ${_formatNullableNum(durationDays, suffix: ' ${'profile.day_unit'.tr()}')}';
    } else if (goal == 'Being Fit' || goal == 'Keeping Weight') {
      planLabel = 'profile.maintain_current'.tr();
    } else {
      planLabel = 'profile.not_updated'.tr();
    }

    final calorieLabel = maintenanceCalo != null && targetCalo != null
        ? '${_formatNullableNum(maintenanceCalo)} → ${_formatNullableNum(targetCalo)} ${'profile.kcal_per_day'.tr()}'
        : 'profile.not_updated'.tr();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFF7FAF8), const Color(0xFFEFF8F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E9E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatGoalLabel(goal),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  planLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _buildGoalInfoCard(
                icon: Icons.account_balance_wallet_rounded,
                title: 'profile.daily_budget'.tr(),
                value: _formatNullableNum(dailyBudget, suffix: ' VNĐ'),
                color: const Color(0xFF4CAF50),
              ),
              _buildGoalInfoCard(
                icon: Icons.monitor_weight_rounded,
                title: 'profile.target_weight'.tr(),
                value: _formatNullableNum(targetWeight, suffix: ' Kg'),
                color: const Color(0xFF8D6E63),
              ),
              _buildGoalInfoCard(
                icon: Icons.schedule_rounded,
                title: 'profile.duration'.tr(),
                value: durationDays != null
                    ? _formatNullableNum(
                        durationDays,
                        suffix: ' ${'profile.day_unit'.tr()}',
                      )
                    : 'profile.not_updated'.tr(),
                color: const Color(0xFF1976D2),
              ),
              _buildGoalInfoCard(
                icon: Icons.local_fire_department_rounded,
                title: 'profile.calories'.tr(),
                value: calorieLabel,
                color: const Color(0xFFFF8F00),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${'profile.goal_subtitle'.tr()}. ${'profile.change_goal'.tr()}.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey[700],
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E9E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              height: 1.2,
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
          title: Text(
            '${'profile.change_goal'.tr()}?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            '${'profile.goal_subtitle'.tr()}. ${'common.confirm'.tr()}?',
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'common.cancel'.tr(),
                style: const TextStyle(color: Colors.grey, fontSize: 16),
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
              child: Text(
                'common.yes'.tr(),
                style: const TextStyle(
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

class _ProfileInfoItem {
  const _ProfileInfoItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}
