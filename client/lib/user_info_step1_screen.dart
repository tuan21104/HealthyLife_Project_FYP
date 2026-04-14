import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'user_info_step2_screen.dart';
import 'landing_screen.dart';
import 'modal_effects.dart';
import 'core/utils/i18n_fallback.dart';

class UserInfoStep1Screen extends StatefulWidget {
  final String email;
  const UserInfoStep1Screen({super.key, required this.email});

  @override
  State<UserInfoStep1Screen> createState() => _UserInfoStep1ScreenState();
}

class _UserInfoStep1ScreenState extends State<UserInfoStep1Screen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  String? _selectedGender;

  String _genderLabel(String gender) {
    switch (gender) {
      case 'Male':
        return trSafe(context, 'onboarding.male', vi: 'Nam', en: 'Male');
      case 'Female':
        return trSafe(context, 'onboarding.female', vi: 'Nữ', en: 'Female');
      case 'Other':
        return trSafe(context, 'onboarding.other', vi: 'Khác', en: 'Other');
      default:
        return gender;
    }
  }

  void _handleNext() async {
    if (_nameController.text.isEmpty ||
        _selectedGender == null ||
        _budgetController.text.isEmpty ||
        _phoneNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trSafe(
              context,
              'onboarding.fill_all_fields',
              vi: 'Vui lòng điền đầy đủ tất cả các trường',
              en: 'Please fill all fields',
            ),
          ),
        ),
      );
      return;
    }

    bool success = await AuthService.updateProfile({
      'name': _nameController.text,
      'gender': _selectedGender,
      'dailyBudget': int.tryParse(_budgetController.text) ?? 0,
      'phoneNumber': _phoneNumberController.text.trim(),
    });

    if (success) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserInfoStep2Screen(email: widget.email),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trSafe(
              context,
              'common.error',
              vi: 'Đã xảy ra lỗi',
              en: 'An error occurred',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.grey),
          onPressed: () {
            // Dùng pushReplacement để chuyển sang LandingScreen
            // và không cho phép bấm "Back" trên đt quay lại màn hình nhập Info này nữa
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LandingScreen()),
            );
          },
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trSafe(
                  context,
                  'profile.your_info',
                  vi: 'Thông tin của bạn',
                  en: 'Your Info',
                ),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trSafe(
                  context,
                  'onboarding.step_1_of_2',
                  vi: 'Bước 1/2',
                  en: 'Step 1 of 2',
                ),
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              _buildTextField(
                controller: _nameController,
                hint: trSafe(
                  context,
                  'onboarding.name',
                  vi: 'Họ và tên',
                  en: 'Full Name',
                ),
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: () => _showGenderDialog(),
                child: _buildFakeDropdown(
                  text: _selectedGender == null
                      ? trSafe(
                          context,
                          'onboarding.gender',
                          vi: 'Giới tính',
                          en: 'Gender',
                        )
                      : _genderLabel(_selectedGender!),
                  isPlaceholder: _selectedGender == null,
                ),
              ),
              const SizedBox(height: 20),

              _buildTextField(
                controller: _budgetController,
                hint: trSafe(
                  context,
                  'onboarding.daily_budget',
                  vi: 'Ngân sách hàng ngày (VND)',
                  en: 'Daily Budget (VND)',
                ),
                isNumber: true,
              ),
              const SizedBox(height: 20),

              GestureDetector(
                child: _buildTextField(
                  controller: _phoneNumberController,
                  hint: trSafe(
                    context,
                    'onboarding.phone_number',
                    vi: 'Số điện thoại',
                    en: 'Phone Number',
                  ),
                  isPhone: true,
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    trSafe(
                      context,
                      'onboarding.next',
                      vi: 'Tiếp theo',
                      en: 'Next',
                    ),
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
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isNumber = false,
    bool isPhone = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isPhone
          ? TextInputType.phone
          : (isNumber ? TextInputType.number : TextInputType.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }

  Widget _buildFakeDropdown({
    required String text,
    bool isGoal = false,
    bool isPlaceholder = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: TextStyle(
              color: isPlaceholder ? Colors.grey[400] : Colors.black,
              fontSize: 16,
            ),
          ),
          if (isGoal)
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  void _showGenderDialog() {
    ModalEffects.showScaleFadeDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            trSafe(context, 'onboarding.gender', vi: 'Giới tính', en: 'Gender'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['Male', 'Female', 'Other']
                .map(
                  (g) => ListTile(
                    title: Text(_genderLabel(g)),
                    onTap: () {
                      setState(() => _selectedGender = g);
                      Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
