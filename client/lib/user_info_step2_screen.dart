import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'bmi_calculation_screen.dart';
import 'modal_effects.dart';

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
  DateTime? _selectedDate;

  // --- BIẾN QUẢN LÝ AVATAR ---
  int? _selectedAvatarIndex; // Dành cho ảnh có sẵn (asset)
  File? _profileImageFile; // Dành cho ảnh thật chụp/chọn từ máy
  final ImagePicker _picker = ImagePicker();
  int _selectedPicOption = 0; // Lưu lựa chọn Radio Button

  final List<String> _activities = [
    "Sedentary",
    "Lightly Active",
    "Moderately Active",
    "Very Active",
  ];

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

  void _handleCalculate() async {
    if (_heightController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _selectedDate == null ||
        _selectedActivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Vui lòng điền đủ thông tin *",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double height = double.parse(_heightController.text);
    if (!_isCm) height = height * 30.48; // Chuyển ft sang cm

    double weight = double.parse(_weightController.text);
    if (!_isKg) weight = weight * 0.453592; // Chuyển lbs sang kg

    bool success = await AuthService.updateProfile({
      'height': height,
      'weight': weight,
      'activityLevel': _selectedActivity,
      // ĐÃ XÓA GENDER Ở ĐÂY VÌ ĐÃ LƯU Ở STEP 1
      'birthDate':
          "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}",
      'avatarIndex': _selectedAvatarIndex,
    });

    if (success) {
      await AuthService.clearPendingOnboarding();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Hoàn tất hồ sơ!"),
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
              const Text(
                "Your Info",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Step 2/2",
                style: TextStyle(fontSize: 16, color: Colors.grey),
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
                    const Text(
                      "Add Profile Picture",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              _buildInputWithToggle(
                controller: _heightController,
                label: "Height*",
                isMetric: _isCm,
                unit1: "ft",
                unit2: "cm",
                onToggle: () => setState(() => _isCm = !_isCm),
              ),
              const SizedBox(height: 20),

              _buildInputWithToggle(
                controller: _weightController,
                label: "Weight*",
                isMetric: _isKg,
                unit1: "lbs",
                unit2: "kg",
                onToggle: () => setState(() => _isKg = !_isKg),
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: _showActivityDialog,
                child: _buildDropdownField(
                  "Week Movement",
                  _selectedActivity ?? "",
                ),
              ),
              const SizedBox(height: 20),

              // ĐÃ XÓA KHỐI UI CHỌN GENDER Ở ĐÂY
              GestureDetector(
                onTap: () => _selectDate(context),
                child: _buildDropdownField(
                  "Birth Date",
                  _selectedDate != null
                      ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
                      : "",
                ),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _handleCalculate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Calculate BMI and Weight",
                    style: TextStyle(
                      fontSize: 16,
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

  Widget _buildInputWithToggle({
    required TextEditingController controller,
    required String label,
    required bool isMetric,
    required String unit1,
    required String unit2,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500]),
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
          onTap: onToggle,
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
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              if (value.isNotEmpty) const SizedBox(height: 4),
              if (value.isNotEmpty)
                Text(
                  value,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                ),
            ],
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  void _showProfilePictureDialog() {
    _selectedPicOption = 0;

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
              const Text(
                "Profile Picture",
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
            children: [
              _buildRadioOption("Choose from available avatars", 0),
              _buildRadioOption("Choose from library", 1),
              _buildRadioOption("Take photo", 2),
              _buildRadioOption("Remove current picture", 3),
            ],
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
                onPressed: () {
                  Navigator.pop(context);

                  if (_selectedPicOption == 0) {
                    _showAvatarGridDialog();
                  } else if (_selectedPicOption == 1) {
                    _pickImage(ImageSource.gallery);
                  } else if (_selectedPicOption == 2) {
                    _pickImage(ImageSource.camera);
                  } else if (_selectedPicOption == 3) {
                    setState(() {
                      _profileImageFile = null;
                      _selectedAvatarIndex = null;
                    });
                  }
                },
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRadioOption(String title, int value) {
    return StatefulBuilder(
      builder: (context, setStateSB) {
        return RadioListTile<int>(
          title: Text(title, style: const TextStyle(fontSize: 14)),
          value: value,
          groupValue: _selectedPicOption,
          activeColor: const Color(0xFF4CAF50),
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            setStateSB(() => _selectedPicOption = val!);
          },
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
              const Text(
                "Profile Picture",
                style: TextStyle(fontWeight: FontWeight.bold),
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
                child: const Text("OK", style: TextStyle(color: Colors.white)),
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
          title: const Text(
            "Activity Level",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _activities
                .map(
                  (act) => ListTile(
                    title: Text(act),
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
