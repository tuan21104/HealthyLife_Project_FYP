import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'services/auth_service.dart';

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
  File? _profileImageFile;
  final ImagePicker _picker = ImagePicker();
  int _selectedPicOption = 0;

  final List<String> _activities = [
    "Sedentary",
    "Lightly Active",
    "Moderately Active",
    "Very Active",
  ];

  @override
  void initState() {
    super.initState();
    // ĐIỀN SẴN DỮ LIỆU CŨ VÀO FORM
    _nameController.text = widget.userData['name'] ?? '';
    _heightController.text = (widget.userData['height'] ?? '').toString();
    _weightController.text = (widget.userData['weight'] ?? '').toString();
    _selectedGender = widget.userData['gender'] ?? 'Male';
    _selectedActivity = widget.userData['activityLevel'] ?? 'Sedentary';
    _selectedAvatarIndex = widget.userData['avatarIndex']; // Load avatar cũ

    if (widget.userData['birthDate'] != null) {
      _selectedDate = DateTime.tryParse(widget.userData['birthDate']);
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
      print("Lỗi chọn ảnh: $e");
    }
  }

  void _handleSave() async {
    if (_nameController.text.isEmpty ||
        _heightController.text.isEmpty ||
        _weightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vui lòng không để trống thông tin!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    String email = widget.userData['email'];
    double height = double.tryParse(_heightController.text) ?? 0;
    double weight = double.tryParse(_weightController.text) ?? 0;
    String birthDateStr = _selectedDate != null
        ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
        : "";

    // GỌI API ĐỂ CẬP NHẬT (Kèm theo avatarIndex)
    bool success = await AuthService.updateProfile(email, {
      'name': _nameController.text,
      'height': height,
      'weight': weight,
      'gender': _selectedGender,
      'activityLevel': _selectedActivity,
      'birthDate': birthDateStr,
      'avatarIndex': _selectedAvatarIndex, // Lưu Avatar mới
    });

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cập nhật thành công!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cập nhật thất bại!"),
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
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- KHU VỰC CHỈNH SỬA AVATAR ---
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
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
                              Icons.person,
                              size: 50,
                              color: Colors.grey[400],
                            )
                          : null,
                    ),
                    GestureDetector(
                      onTap: _showProfilePictureDialog,
                      child: Container(
                        padding: const EdgeInsets.all(6),
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
              const SizedBox(height: 30),

              // --- FORM NHẬP LIỆU (Giữ nguyên) ---
              _buildLabel("Full Name"),
              _buildTextField(
                controller: _nameController,
                hint: "Enter your name",
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Height (cm)"),
                        _buildTextField(
                          controller: _heightController,
                          hint: "e.g. 170",
                          isNumber: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Weight (kg)"),
                        _buildTextField(
                          controller: _weightController,
                          hint: "e.g. 65",
                          isNumber: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildLabel("Gender"),
              GestureDetector(
                onTap: _showGenderDialog,
                child: _buildDropdownField(_selectedGender ?? ""),
              ),
              const SizedBox(height: 20),

              _buildLabel("Activity Level"),
              GestureDetector(
                onTap: _showActivityDialog,
                child: _buildDropdownField(_selectedActivity ?? ""),
              ),
              const SizedBox(height: 20),

              _buildLabel("Birth Date"),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: _buildDropdownField(
                  _selectedDate != null
                      ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
                      : "Select your birth date",
                ),
              ),

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
                      : const Text(
                          "Save Changes",
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

  Widget _buildLabel(String text) {
    return Padding(
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

  Widget _buildDropdownField(String value) {
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
            value,
            style: const TextStyle(color: Colors.black87, fontSize: 16),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  // --- LOGIC POPUP CHỌN ẢNH TỪ STEP 2 ---
  void _showProfilePictureDialog() {
    _selectedPicOption = 0;
    showDialog(
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
                    });
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
          onChanged: (val) => setStateSB(() => _selectedPicOption = val!),
        );
      },
    );
  }

  void _showAvatarGridDialog() {
    showDialog(
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      ),
    );
  }

  void _showGenderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Select Gender",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ["Male", "Female", "Other"]
              .map(
                (g) => ListTile(
                  title: Text(g),
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF4CAF50)),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate)
      setState(() => _selectedDate = picked);
  }
}
