import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'services/auth_service.dart';
import 'user_info_step2_screen.dart';
import 'landing_screen.dart';
import 'modal_effects.dart';

class UserInfoStep1Screen extends StatefulWidget {
  final String email;
  const UserInfoStep1Screen({super.key, required this.email});

  @override
  State<UserInfoStep1Screen> createState() => _UserInfoStep1ScreenState();
}

class _UserInfoStep1ScreenState extends State<UserInfoStep1Screen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  String? _selectedGender;
  String? _selectedGoal;

  final List<String> _goals = [
    'onboarding.losing_weight',
    'onboarding.gaining_weight',
    'onboarding.keeping_weight',
    'onboarding.being_fit',
  ];

  void _handleNext() async {
    if (_nameController.text.isEmpty ||
        _selectedGender == null ||
        _budgetController.text.isEmpty ||
        _selectedGoal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('onboarding.fill_all_fields'.tr())),
      );
      return;
    }

    bool success = await AuthService.updateProfile({
      'name': _nameController.text,
      'gender': _selectedGender,
      'dailyBudget': int.tryParse(_budgetController.text) ?? 0,
      'goal': _selectedGoal,
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
          content: Text('common.error'.tr()),
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
                'profile.your_info'.tr(),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'onboarding.step_1_of_2'.tr(),
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              _buildTextField(
                controller: _nameController,
                hint: 'onboarding.name'.tr(),
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: () => _showGenderDialog(),
                child: _buildFakeDropdown(
                  text: _selectedGender?.tr() ?? 'onboarding.gender'.tr(),
                  isPlaceholder: _selectedGender == null,
                ),
              ),
              const SizedBox(height: 20),

              _buildTextField(
                controller: _budgetController,
                hint: 'onboarding.daily_budget'.tr(),
                isNumber: true,
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: () => _showGoalDialog(),
                child: _buildFakeDropdown(
                  text: _selectedGoal?.tr() ?? 'onboarding.goal'.tr(),
                  isPlaceholder: _selectedGoal == null,
                  isGoal: true,
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
                    'onboarding.next'.tr(),
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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

  void _showGoalDialog() {
    ModalEffects.showScaleFadeDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'onboarding.goal'.tr(),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _goals
                .map(
                  (goal) => RadioListTile<String>(
                    title: Text(goal.tr()),
                    value: goal,
                    groupValue: _selectedGoal,
                    activeColor: const Color(0xFF4CAF50),
                    onChanged: (value) {
                      setState(() => _selectedGoal = value);
                      Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'common.ok'.tr(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
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
          title: Text('onboarding.gender'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                ['onboarding.male', 'onboarding.female', 'onboarding.other']
                    .map(
                      (g) => ListTile(
                        title: Text(g.tr()),
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
