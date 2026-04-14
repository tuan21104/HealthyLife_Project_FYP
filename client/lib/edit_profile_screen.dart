import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'services/auth_service.dart';
import 'modal_effects.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  String? _selectedGender;
  String? _selectedActivity;
  DateTime? _selectedDate;
  bool _isLoading = false;

  // --- BIẾN QUẢN LÝ AVATAR ---
  int? _selectedAvatarIndex;
  String? _currentAvatarUrl; // Lưu URL ảnh cũ từ database
  File? _profileImageFile;
  final ImagePicker _picker = ImagePicker();
  int _selectedPicOption = 0;

  final List<String> _activities = [
    "Sedentary",
    "Lightly Active",
    "Moderately Active",
    "Very Active",
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
        return 'profile.activity_sedentary'.tr();
      case 'Lightly Active':
        return 'profile.activity_lightly_active'.tr();
      case 'Moderately Active':
        return 'profile.activity_moderately_active'.tr();
      case 'Very Active':
        return 'profile.activity_very_active'.tr();
      default:
        return activity;
    }
  }

  String _genderLabel(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return 'onboarding.male'.tr();
      case 'female':
        return 'onboarding.female'.tr();
      case 'other':
        return 'onboarding.other'.tr();
      default:
        return gender;
    }
  }

  dynamic _readUserValue(List<String> keys) {
    for (final key in keys) {
      final value = widget.userData[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String _stringValue(List<String> keys, {String fallback = ''}) {
    final value = _readUserValue(keys);
    return value?.toString() ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    // ĐIỀN SẴN DỮ LIỆU CŨ VÀO FORM
    _nameController.text = _stringValue(['name'], fallback: '');
    _heightController.text = _stringValue(['height'], fallback: '');
    _weightController.text = _stringValue(['weight'], fallback: '');
    _selectedGender = _stringValue(['gender'], fallback: 'Male');
    _selectedActivity = _stringValue([
      'activityLevel',
      'activity',
    ], fallback: 'Sedentary');

    // Load avatar cũ: Có thể là Index hoặc URL
    final avatarIndexValue = _readUserValue(['avatarIndex']);
    if (avatarIndexValue is int) {
      _selectedAvatarIndex = avatarIndexValue;
    } else if (avatarIndexValue is String) {
      _selectedAvatarIndex = int.tryParse(avatarIndexValue);
    }
    _currentAvatarUrl = _stringValue(['avatarUrl'], fallback: '');
    if (_currentAvatarUrl != null && _currentAvatarUrl!.isEmpty) {
      _currentAvatarUrl = null;
    }

    final birthDate = _stringValue(['birthDate', 'dob'], fallback: '');
    if (birthDate.isNotEmpty) {
      _selectedDate = DateTime.tryParse(birthDate);
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
          _currentAvatarUrl = null; // Reset URL cũ khi chọn ảnh mới
        });
      }
    } catch (e) {
      print("Lỗi chọn ảnh: $e");
    }
  }

  // --- HÀM LƯU DỮ LIỆU (ĐÃ SỬA DỨT ĐIỂM) ---
  void _handleSave() async {
    if (_nameController.text.isEmpty ||
        _heightController.text.isEmpty ||
        _weightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('onboarding.fill_all_fields'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? finalAvatarUrl = _currentAvatarUrl;
      int? finalAvatarIndex = _selectedAvatarIndex;

      // 1. NẾU CÓ CHỌN FILE ẢNH MỚI -> UPLOAD LÊN MÂY TRƯỚC
      if (_profileImageFile != null) {
        print("==== 🔄 ĐANG UPLOAD ẢNH LÊN CLOUDINARY... ====");
        String? uploadedLink = await AuthService.uploadImage(
          _profileImageFile!,
        );
        if (uploadedLink != null) {
          finalAvatarUrl = uploadedLink;
          finalAvatarIndex = null; // Có ảnh thật thì bỏ qua avatar index
        } else {
          throw Exception("Không thể upload ảnh lên máy chủ.");
        }
      }

      // 2. CHUẨN BỊ DATA GỬI LÊN SERVER
      double height = double.tryParse(_heightController.text) ?? 0;
      double weight = double.tryParse(_weightController.text) ?? 0;
      String birthDateStr = _selectedDate != null
          ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
          : "";
      final int weeklyMovement =
          _weeklyMovementByLevel[_selectedActivity] ??
          (widget.userData['weeklyMovement'] as num?)?.toInt() ??
          60;

      Map<String, dynamic> updateData = {
        'userId': widget.userData['_id'] ?? widget.userData['id'],
        'name': _nameController.text,
        'height': height,
        'weight': weight,
        'gender': _selectedGender,
        'activityLevel': _selectedActivity,
        'weeklyMovement': weeklyMovement,
        'birthDate': birthDateStr,
        'avatarIndex': finalAvatarIndex,
        'avatarUrl': finalAvatarUrl,
      };

      // 3. GỌI API UPDATE
      final updateResult = await AuthService.updateProfileWithResponse(
        updateData,
      );
      final bool success = updateResult['success'] == true;

      setState(() => _isLoading = false);

      if (success) {
        final latestUser = updateResult['user'];

        if (latestUser == null) {
          throw Exception('Đã update nhưng server không trả dữ liệu user mới.');
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('onboarding.profile_updated'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, {'updated': true, 'user': latestUser});
      } else {
        throw Exception(updateResult['message'] ?? "Server từ chối cập nhật.");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'common.error'.tr()}: ${e.toString()}'),
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'profile.edit_profile'.tr(),
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                title: 'profile.profile_photo'.tr(),
                subtitle: 'profile.profile_photo_subtitle'.tr(),
              ),
              const SizedBox(height: 14),
              _buildAvatarCard(),

              const SizedBox(height: 22),

              _buildSectionHeader(
                title: 'profile.your_info'.tr(),
                subtitle: 'profile.info_subtitle'.tr(),
              ),
              const SizedBox(height: 14),
              _buildFormCard(),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'common.save'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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

  // --- UI HELPER WIDGETS ---
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

  Widget _buildAvatarCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E9E2)),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 52,
              backgroundColor: Colors.grey[200],
              backgroundImage: _profileImageFile != null
                  ? FileImage(_profileImageFile!) as ImageProvider
                  : (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty
                        ? NetworkImage(_currentAvatarUrl!)
                        : (_selectedAvatarIndex != null
                              ? AssetImage(
                                  'assets/images/avatar_${_selectedAvatarIndex! + 1}.png',
                                )
                              : null)),
              child:
                  _profileImageFile == null &&
                      _currentAvatarUrl == null &&
                      _selectedAvatarIndex == null
                  ? Icon(Icons.person, size: 52, color: Colors.grey[400])
                  : null,
            ),
            GestureDetector(
              onTap: _showProfilePictureDialog,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E9E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('onboarding.name'.tr()),
          _buildTextField(
            controller: _nameController,
            hint: 'profile.enter_name'.tr(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('onboarding.height'.tr()),
                    _buildTextField(
                      controller: _heightController,
                      hint: 'profile.height_example'.tr(),
                      isNumber: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('onboarding.weight'.tr()),
                    _buildTextField(
                      controller: _weightController,
                      hint: 'profile.weight_example'.tr(),
                      isNumber: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabel('profile.gender'.tr()),
          GestureDetector(
            onTap: _showGenderDialog,
            child: _buildDropdownField(
              _selectedGender == null ? '' : _genderLabel(_selectedGender!),
            ),
          ),
          const SizedBox(height: 16),
          _buildLabel('profile.activity_level'.tr()),
          GestureDetector(
            onTap: _showActivityDialog,
            child: _buildDropdownField(
              _selectedActivity == null
                  ? ''
                  : _activityLabel(_selectedActivity!),
            ),
          ),
          const SizedBox(height: 16),
          _buildLabel('profile.birth_date'.tr()),
          GestureDetector(
            onTap: () => _selectDate(context),
            child: _buildDropdownField(
              _selectedDate != null
                  ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
                  : 'profile.select_birth_date'.tr(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

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
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF4CAF50), width: 1.4),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.grey[300]!),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.black87, fontSize: 16),
        ),
        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ],
    ),
  );

  // --- DIALOGS ---
  void _showProfilePictureDialog() {
    ModalEffects.showScaleFadeDialog(
      context: context,
      builder: (context) {
        int selectedOption = _selectedPicOption;

        return StatefulBuilder(
          builder: (context, setStateSB) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'profile.profile_photo'.tr(),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRadioOption(
                  'profile.avatar_choose_available'.tr(),
                  0,
                  selectedOption,
                  (val) => setStateSB(() => selectedOption = val),
                ),
                _buildRadioOption(
                  'profile.choose_from_library'.tr(),
                  1,
                  selectedOption,
                  (val) => setStateSB(() => selectedOption = val),
                ),
                _buildRadioOption(
                  'profile.take_photo'.tr(),
                  2,
                  selectedOption,
                  (val) => setStateSB(() => selectedOption = val),
                ),
                _buildRadioOption(
                  'profile.remove_current_picture'.tr(),
                  3,
                  selectedOption,
                  (val) => setStateSB(() => selectedOption = val),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _selectedPicOption = selectedOption;
                  Navigator.pop(context);
                  if (_selectedPicOption == 0)
                    _showAvatarGridDialog();
                  else if (_selectedPicOption == 1)
                    _pickImage(ImageSource.gallery);
                  else if (_selectedPicOption == 2)
                    _pickImage(ImageSource.camera);
                  else if (_selectedPicOption == 3)
                    setState(() {
                      _profileImageFile = null;
                      _selectedAvatarIndex = null;
                      _currentAvatarUrl = null;
                    });
                },
                child: Text(
                  'common.ok'.tr(),
                  style: TextStyle(color: Color(0xFF4CAF50)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRadioOption(
    String title,
    int value,
    int selectedOption,
    ValueChanged<int> onChanged,
  ) {
    return RadioListTile<int>(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: value,
      groupValue: selectedOption,
      activeColor: const Color(0xFF4CAF50),
      onChanged: (val) => onChanged(val!),
    );
  }

  void _showAvatarGridDialog() {
    ModalEffects.showScaleFadeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('profile.choose_avatar'.tr()),
        content: Wrap(
          spacing: 10,
          children: List.generate(
            6,
            (index) => GestureDetector(
              onTap: () {
                setState(() {
                  _selectedAvatarIndex = index;
                  _profileImageFile = null;
                  _currentAvatarUrl = null;
                });
                Navigator.pop(context);
              },
              child: CircleAvatar(
                backgroundImage: AssetImage(
                  'assets/images/avatar_${index + 1}.png',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showActivityDialog() {
    ModalEffects.showScaleFadeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('profile.activity_level'.tr()),
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
      ),
    );
  }

  void _showGenderDialog() {
    ModalEffects.showScaleFadeDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('profile.gender'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ["Male", "Female", "Other"]
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
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }
}
