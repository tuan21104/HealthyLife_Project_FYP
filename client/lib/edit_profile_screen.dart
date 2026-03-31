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

  @override
  void initState() {
    super.initState();
    // ĐIỀN SẴN DỮ LIỆU CŨ VÀO FORM
    _nameController.text = widget.userData['name'] ?? '';
    _heightController.text = (widget.userData['height'] ?? '').toString();
    _weightController.text = (widget.userData['weight'] ?? '').toString();
    _selectedGender = widget.userData['gender'] ?? 'Male';
    _selectedActivity = widget.userData['activityLevel'] ?? 'Sedentary';

    // Load avatar cũ: Có thể là Index hoặc URL
    _selectedAvatarIndex = widget.userData['avatarIndex'];
    _currentAvatarUrl = widget.userData['avatarUrl'];

    if (widget.userData['birthDate'] != null &&
        widget.userData['birthDate'] != "") {
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
        const SnackBar(
          content: Text("Vui lòng không để trống thông tin!"),
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

      Map<String, dynamic> updateData = {
        'name': _nameController.text,
        'height': height,
        'weight': weight,
        'gender': _selectedGender,
        'activityLevel': _selectedActivity,
        'birthDate': birthDateStr,
        'avatarIndex': finalAvatarIndex,
        'avatarUrl': finalAvatarUrl,
      };

      // 3. GỌI API UPDATE
      bool success = await AuthService.updateProfile(updateData);

      setState(() => _isLoading = false);

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cập nhật thành công!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Trả về true để Home refresh
      } else {
        throw Exception("Server từ chối cập nhật.");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Lỗi: ${e.toString()}"),
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
              // --- HIỂN THỊ AVATAR THÔNG MINH ---
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _profileImageFile != null
                          ? FileImage(_profileImageFile!) as ImageProvider
                          : (_currentAvatarUrl != null &&
                                    _currentAvatarUrl!.isNotEmpty
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

  // --- UI HELPER WIDGETS ---
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

  Widget _buildDropdownField(String value) => Container(
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

  // --- DIALOGS ---
  void _showProfilePictureDialog() {
    _selectedPicOption = 0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Profile Picture",
          style: TextStyle(fontWeight: FontWeight.bold),
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
          TextButton(
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
                  _currentAvatarUrl = null;
                });
            },
            child: const Text("OK", style: TextStyle(color: Color(0xFF4CAF50))),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String title, int value) {
    return StatefulBuilder(
      builder: (context, setStateSB) => RadioListTile<int>(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        value: value,
        groupValue: _selectedPicOption,
        activeColor: const Color(0xFF4CAF50),
        onChanged: (val) => setStateSB(() => _selectedPicOption = val!),
      ),
    );
  }

  void _showAvatarGridDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choose Avatar"),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Activity Level"),
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
        title: const Text("Select Gender"),
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
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }
}
