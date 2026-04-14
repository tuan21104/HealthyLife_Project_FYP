import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'bmi_calculation_screen.dart';
import 'modal_effects.dart';
import 'core/utils/i18n_fallback.dart';

class UserInfoStep2Screen extends StatefulWidget {
  final String email;
  const UserInfoStep2Screen({super.key, required this.email});

  @override
  State<UserInfoStep2Screen> createState() => _UserInfoStep2ScreenState();
}

class _UserInfoStep2ScreenState extends State<UserInfoStep2Screen> {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // Trạng thái đơn vị đo
  bool _isCm = true;
  bool _isKg = true;

  String? _selectedActivity;
  String? _selectedGoal;
  DateTime? _selectedDate;

  // --- BIẾN QUẢN LÝ AVATAR ---
  int? _selectedAvatarIndex; // Dành cho ảnh có sẵn (asset)
  File? _profileImageFile; // Dành cho ảnh thật chụp/chọn từ máy
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  static const TextStyle _titleStyle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: Colors.black,
  );
  static const TextStyle _subtitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Colors.grey,
  );
  static const TextStyle _buttonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  static const TextStyle _fieldValueStyle = TextStyle(
    color: Colors.black,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  final List<String> _activities = [
    "Sedentary",
    "Lightly Active",
    "Moderately Active",
    "Very Active",
  ];

  final List<String> _goals = [
    'Losing Weight',
    'Gaining Weight',
    'Keeping Weight',
    'Being Fit',
  ];

  final Map<String, int> _weeklyMovementByLevel = {
    'Sedentary': 60,
    'Lightly Active': 150,
    'Moderately Active': 300,
    'Very Active': 450,
  };

  String _activityLabel(String activity) {
    switch (activity) {
      case 'Sedentary':
        return trSafe(
          context,
          'profile.activity_sedentary',
          vi: 'Ít vận động',
          en: 'Sedentary',
        );
      case 'Lightly Active':
        return trSafe(
          context,
          'profile.activity_lightly_active',
          vi: 'Vận động nhẹ',
          en: 'Lightly Active',
        );
      case 'Moderately Active':
        return trSafe(
          context,
          'profile.activity_moderately_active',
          vi: 'Vận động vừa',
          en: 'Moderately Active',
        );
      case 'Very Active':
        return trSafe(
          context,
          'profile.activity_very_active',
          vi: 'Vận động cao',
          en: 'Very Active',
        );
      default:
        return activity;
    }
  }

  String _goalLabel(String goal) {
    switch (goal) {
      case 'Losing Weight':
        return trSafe(
          context,
          'onboarding.losing_weight',
          vi: 'Giảm cân',
          en: 'Losing Weight',
        );
      case 'Gaining Weight':
        return trSafe(
          context,
          'onboarding.gaining_weight',
          vi: 'Tăng cân',
          en: 'Gaining Weight',
        );
      case 'Keeping Weight':
        return trSafe(
          context,
          'onboarding.keeping_weight',
          vi: 'Giữ cân',
          en: 'Keeping Weight',
        );
      case 'Being Fit':
        return trSafe(
          context,
          'onboarding.being_fit',
          vi: 'Giữ dáng',
          en: 'Being Fit',
        );
      default:
        return goal;
    }
  }

  // --- HÀM MỞ CAMERA/GALLERY ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImageFile = File(pickedFile.path);
          _selectedAvatarIndex = null;
        });
      }
    } catch (e) {
      debugPrint('Lỗi chọn ảnh: $e');
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _handleCalculate() async {
    if (_heightController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _selectedGoal == null ||
        _selectedDate == null ||
        _selectedActivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trSafe(
              context,
              'onboarding.fill_all_fields',
              vi: 'Vui lòng điền đầy đủ tất cả các trường',
              en: 'Please fill all fields',
            ),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final weeklyMovement = _weeklyMovementByLevel[_selectedActivity] ?? 0;

    setState(() => _isSaving = true);

    double height = double.parse(_heightController.text);
    if (!_isCm) height = height * 30.48; // Chuyển ft sang cm

    double weight = double.parse(_weightController.text);
    if (!_isKg) weight = weight * 0.453592; // Chuyển lbs sang kg

    String? uploadedAvatarUrl;
    int? finalAvatarIndex = _selectedAvatarIndex;

    if (_profileImageFile != null) {
      uploadedAvatarUrl = await AuthService.uploadImage(_profileImageFile!);
      if (uploadedAvatarUrl == null || uploadedAvatarUrl.isEmpty) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trSafe(
                context,
                'onboarding.avatar_upload_failed',
                vi: 'Không thể tải ảnh avatar lên máy chủ.',
                en: 'Unable to upload avatar to server.',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      finalAvatarIndex = null;
    }

    bool success = await AuthService.updateProfile({
      'height': height,
      'weight': weight,
      'weeklyMovement': weeklyMovement,
      'goal': _selectedGoal,
      'activityLevel': _selectedActivity,
      // ĐÃ XÓA GENDER Ở ĐÂY VÌ ĐÃ LƯU Ở STEP 1
      'birthDate':
          "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}",
      'avatarIndex': finalAvatarIndex,
      'avatarUrl': uploadedAvatarUrl,
    });

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      await AuthService.clearPendingOnboarding();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trSafe(
              context,
              'onboarding.profile_updated',
              vi: 'Hồ sơ được cập nhật thành công',
              en: 'Profile updated successfully',
            ),
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              BmiCalculationScreen(heightCm: height, weightKg: weight),
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
          onPressed: () => Navigator.pop(context),
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
                style: _titleStyle,
              ),
              const SizedBox(height: 8),
              Text(
                trSafe(
                  context,
                  'onboarding.step_2_of_2',
                  vi: 'Bước 2/2',
                  en: 'Step 2 of 2',
                ),
                style: _subtitleStyle,
              ),
              const SizedBox(height: 30),

              // --- UI HIỂN THỊ AVATAR ---
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showProfilePictureDialog,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey[100],
                        backgroundImage: _profileImageFile != null
                            ? FileImage(_profileImageFile!) as ImageProvider
                            : (_selectedAvatarIndex != null
                                  ? AssetImage(
                                      'assets/images/avatar_${_selectedAvatarIndex! + 1}.png',
                                    )
                                  : null),
                        child:
                            _profileImageFile == null &&
                                _selectedAvatarIndex == null
                            ? Icon(
                                Icons.person_outline,
                                size: 40,
                                color: Colors.grey[400],
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trSafe(
                        context,
                        'profile.edit_profile',
                        vi: 'Chỉnh sửa hồ sơ',
                        en: 'Edit Profile',
                      ),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              _buildInputWithToggle(
                controller: _heightController,
                label: trSafe(
                  context,
                  'onboarding.height',
                  vi: 'Chiều cao (cm)',
                  en: 'Height (cm)',
                ),
                isMetric: _isCm,
                unit1: "ft",
                unit2: "cm",
                onToggle: () => setState(() => _isCm = !_isCm),
              ),
              const SizedBox(height: 20),

              _buildInputWithToggle(
                controller: _weightController,
                label: trSafe(
                  context,
                  'onboarding.weight',
                  vi: 'Cân nặng (kg)',
                  en: 'Weight (kg)',
                ),
                isMetric: _isKg,
                unit1: "lbs",
                unit2: "kg",
                onToggle: () => setState(() => _isKg = !_isKg),
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: _showGoalDialog,
                child: _buildDropdownField(
                  trSafe(
                    context,
                    'onboarding.you_are_here_for',
                    vi: 'Mục tiêu của bạn',
                    en: "You're here for",
                  ),
                  _selectedGoal != null ? _goalLabel(_selectedGoal!) : '',
                ),
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: _showActivityDialog,
                child: _buildDropdownField(
                  trSafe(
                    context,
                    'profile.activity_level',
                    vi: 'Mức độ vận động',
                    en: 'Activity Level',
                  ),
                  _selectedActivity != null
                      ? _activityLabel(_selectedActivity!)
                      : '',
                ),
              ),
              const SizedBox(height: 20),

              // ĐÃ XÓA KHỐI UI CHỌN GENDER Ở ĐÂY
              GestureDetector(
                onTap: () => _selectDate(context),
                child: _buildDropdownField(
                  trSafe(context, 'onboarding.age', vi: 'Tuổi', en: 'Age'),
                  _selectedDate != null
                      ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
                      : '',
                ),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleCalculate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          trSafe(
                            context,
                            'onboarding.finish',
                            vi: 'Hoàn thành',
                            en: 'Finish',
                          ),
                          style: _buttonTextStyle,
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputWithToggle({
    required TextEditingController controller,
    required String label,
    required bool isMetric,
    required String unit1,
    required String unit2,
    required VoidCallback onToggle,
    bool isReadOnlyToggle = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[500],
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
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
        suffixIcon: GestureDetector(
          onTap: isReadOnlyToggle ? null : onToggle,
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildUnitButton(unit1, !isMetric),
                _buildUnitButton(unit2, isMetric),
              ],
            ),
          ),
        ),
      ),
      style: _fieldValueStyle,
    );
  }

  Widget _buildUnitButton(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[600],
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (value.isNotEmpty) const SizedBox(height: 4),
              if (value.isNotEmpty) Text(value, style: _fieldValueStyle),
            ],
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  void _showProfilePictureDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.face_retouching_natural),
                  title: Text(
                    trSafe(
                      context,
                      'profile.avatar_choose_available',
                      vi: 'Chọn avatar có sẵn',
                      en: 'Choose default avatar',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAvatarGridDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(
                    trSafe(
                      context,
                      'profile.choose_from_library',
                      vi: 'Chọn từ thư viện',
                      en: 'Choose from library',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text(
                    trSafe(
                      context,
                      'profile.take_photo',
                      vi: 'Chụp ảnh',
                      en: 'Take photo',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    trSafe(
                      context,
                      'profile.remove_current_picture',
                      vi: 'Xóa ảnh hiện tại',
                      en: 'Remove current picture',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _profileImageFile = null;
                      _selectedAvatarIndex = null;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAvatarGridDialog() {
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
                trSafe(context, 'profile.title', vi: 'Hồ sơ', en: 'Profile'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: List.generate(
              6,
              (index) => GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAvatarIndex = index;
                    _profileImageFile = null;
                  });
                  Navigator.pop(context);
                },
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.transparent,
                  backgroundImage: AssetImage(
                    'assets/images/avatar_${index + 1}.png',
                  ),
                ),
              ),
            ),
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
                  trSafe(context, 'common.ok', vi: 'OK', en: 'OK'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showActivityDialog() {
    ModalEffects.showScaleFadeDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            trSafe(
              context,
              'profile.activity_level',
              vi: 'Mức độ vận động',
              en: 'Activity Level',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _activities
                .map(
                  (act) => ListTile(
                    title: Text(_activityLabel(act)),
                    onTap: () {
                      setState(() => _selectedActivity = act);
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

  void _showGoalDialog() {
    ModalEffects.showScaleFadeDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            trSafe(
              context,
              'onboarding.you_are_here_for',
              vi: 'Mục tiêu của bạn',
              en: "You're here for",
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _goals
                .map(
                  (goal) => ListTile(
                    title: Text(_goalLabel(goal)),
                    trailing: _selectedGoal == goal
                        ? const Icon(Icons.check, color: Color(0xFF4CAF50))
                        : null,
                    onTap: () {
                      setState(() => _selectedGoal = goal);
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4CAF50),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }
}
