import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'food_detail_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'services/ai_service.dart';
import 'modal_effects.dart';

class FoodSearchScreen extends StatefulWidget {
  final String mealType;

  const FoodSearchScreen({super.key, required this.mealType});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final Color _greenColor = const Color(0xFF65B362);
  final Color _lightBlueColor = const Color(0xFFD3E7F0);
  final Color _textGreenColor = const Color(0xFF5A9B58);

  int _selectedTabIndex = 0; // 0: Search, 1: My Foods, 2: Exercises, 3: Recipes
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allFoods = [];
  List<dynamic> _searchResults = [];

  // --- [FIX LỖI 1: TÁCH RIÊNG LIST STATE CHO TỪNG TAB] ---
  // Giải quyết Vấn đề Lỗi 1&2: Flow tạo My Food mượt mà, hỗ trợ State refresh tab
  List<dynamic> _myFoodsList = [];
  List<dynamic> _recipesList = [];

  bool _isLoading = true;
  String _currentUserId = "";

  // 1. KHAI BÁO CÔNG CỤ CHỤP ẢNH TẠI ĐÂY
  final ImagePicker _picker = ImagePicker();

  // 2. BIẾN CHỨA FILE ẢNH ĐANG ĐƯỢC CHỌN/CHỤP
  File? _selectedImageFile;

  // --- HÀM XỬ LÝ ẢNH AI ĐƯỢC ĐẶT VÀO TRONG STATE ---
  Future<void> _processImageWithAI(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
      );
      if (pickedFile == null) return;

      // --- [LƯU LẠI FILE ẢNH VÀO BIẾN TRẠNG THÁI] ---
      _selectedImageFile = File(pickedFile.path);
      // --------------------

      // 1. Hiện vòng xoay chờ đợi AI phân tích
      ModalEffects.showScaleFadeDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF65B362)),
        ),
      );

      // 2. Gửi ảnh lên cho AI
      final aiResult = await AIService.analyzeFoodImage(File(pickedFile.path));

      // 3. Đóng vòng xoay
      if (mounted) Navigator.pop(context);

      if (aiResult != null && mounted) {
        // --- [FIX FLOW LỖI 1&2 & DAILY LOG vs MY FOOD SEPARATION] ---
        // 4. Nếu AI thành công, mở Form MyFood để user SAVE trước vào My Foods (Lỗi 1)
        _showAddMyFoodModal(prefillData: aiResult);
      } else {
        // Nếu AI thất bại, vẫn mở Form MyFood để họ tự điền vào My Foods
        _showAddMyFoodModal();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Đóng vòng xoay nếu lỗi
      print("Lỗi chụp ảnh: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.mealType == 'Exercise') {
      _selectedTabIndex = 2;
    }
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('userId') ?? "";

    await Future.wait([
      _fetchFoodDatabase(),
      if (_currentUserId.isNotEmpty) _loadPersonalData(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchFoodDatabase() async {
    final result = await AuthService.getAllFoods();
    if (result['success'] == true && result['foods'] != null) {
      _allFoods = result['foods'];
    }
  }

  Future<void> _loadPersonalData() async {
    final myFoods = await AuthService.getMyFoods(_currentUserId);
    final recipes = await AuthService.getRecipes(_currentUserId);

    if (mounted) {
      setState(() {
        _myFoodsList = myFoods;
        _recipesList = recipes;
      });
    }
  }

  String removeVietnameseAccents(String str) {
    const withDia =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const withoutDia =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    String result = str;
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    String normalizedQuery = removeVietnameseAccents(query.toLowerCase());
    final results = _allFoods.where((food) {
      final foodName = food['name'].toString().toLowerCase();
      final normalizedFoodName = removeVietnameseAccents(foodName);
      return normalizedFoodName.contains(normalizedQuery);
    }).toList();
    setState(() => _searchResults = results);
  }

  // ==========================================================
  // --- [YÊU CẦU] 1. FORM SỬA/XÓA MÓN ĂN CỦA BẠN (MY FOOD) ---
  // ==========================================================
  void _showEditMyFoodModal(dynamic existingFood) {
    _selectedImageFile = null; // Reset image flow

    final foodId = existingFood['_id'];
    final nameCtrl = TextEditingController(text: existingFood['name']);
    final amountCtrl = TextEditingController(
      text: existingFood['amount'] ?? "100g",
    );
    final caloCtrl = TextEditingController(
      text: (existingFood['totalCalories'] ?? existingFood['calories'] ?? 0)
          .toString(),
    );
    final proteinCtrl = TextEditingController(
      text: (existingFood['totalProtein'] ?? existingFood['protein'] ?? 0)
          .toString(),
    );
    final fatCtrl = TextEditingController(
      text: (existingFood['totalFat'] ?? existingFood['fat'] ?? 0).toString(),
    );
    final carbCtrl = TextEditingController(
      text: (existingFood['totalCarbs'] ?? existingFood['carbs'] ?? 0)
          .toString(),
    );
    String currentImageUrl = existingFood['imageUrl'] ?? "";

    ModalEffects.showAppBottomSheet(
      context: context,
      topRadius: 28,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Sửa Món Ăn Của Bạn",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Nút đóng Form
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            _selectedImageFile = null;
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- KHU VỰC HIỂN THỊ ẢNH PREVIEW KHI SỬA ---
                    _buildImagePreview(
                      setModalState,
                      initialImageUrl: currentImageUrl,
                    ),
                    const SizedBox(height: 20),

                    // ==========================================================
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Tên món ăn (*)",
                      ),
                    ),
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(
                        labelText: "Định lượng (vd: 100g, 1 bát)",
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: caloCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Calories (*)",
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: proteinCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Protein (g)",
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: fatCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Fat (g)",
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: carbCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Carbs (g)",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _greenColor,
                        ),
                        onPressed: () async {
                          if (nameCtrl.text.isEmpty || caloCtrl.text.isEmpty)
                            return;

                          final updatedFoodData = {
                            "name": nameCtrl.text,
                            "amount": amountCtrl.text,
                            "calories": double.tryParse(caloCtrl.text) ?? 0,
                            "protein": double.tryParse(proteinCtrl.text) ?? 0,
                            "fat": double.tryParse(fatCtrl.text) ?? 0,
                            "carbs": double.tryParse(carbCtrl.text) ?? 0,
                            // Link ảnh cũ để backend dùng nếu user không upload ảnh mới
                            "imageUrl": currentImageUrl,
                          };

                          final messenger = ScaffoldMessenger.of(context);

                          Navigator.pop(
                            context,
                          ); // Close modal flow back to My Foods tab context

                          setState(() => _isLoading = true);

                          // GỌI HÀM SỬA MÓN ĂN
                          bool success = await AuthService.updateMyFood(
                            foodId,
                            updatedFoodData,
                            _selectedImageFile,
                          );

                          // Giải phóng bộ nhớ, xóa ảnh khỏi biến trạng thái
                          _selectedImageFile = null;

                          if (success) {
                            await _loadPersonalData(); // REFRESH MY FOODS LIST IN TAB
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text("Đã sửa món ăn thành công!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Sửa thất bại! Hãy kiểm tra Server.",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }

                          setState(() => _isLoading = false);
                        },
                        child: const Text(
                          "Cập nhật",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _selectedImageFile = null; // Clean up flow
    });
  }

  // --- [FIX LỖI 1: FLOW ADD MY FOOD] ---
  // Giải quyết Vấn đề Lỗi 1&2: Flow tạo My Food mượt mà, hỗ trợ State refresh tab
  void _showAddMyFoodModal({Map<String, dynamic>? prefillData}) {
    final nameCtrl = TextEditingController(text: prefillData?['name'] ?? "");
    final amountCtrl = TextEditingController(text: "100g");
    final caloCtrl = TextEditingController(
      text: prefillData?['calories']?.toString() ?? "",
    );
    final proteinCtrl = TextEditingController(
      text: prefillData?['protein']?.toString() ?? "",
    );
    final fatCtrl = TextEditingController(
      text: prefillData?['fat']?.toString() ?? "",
    );
    final carbCtrl = TextEditingController(
      text: prefillData?['carbs']?.toString() ?? "",
    );

    ModalEffects.showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Tạo Món Ăn Của Bạn",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Nút đóng Form
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            // XÓA ẢNH ĐÃ CHỌN KHI ĐÓNG FORM BẰNG NÚT
                            _selectedImageFile = null;
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- [FIX FLOW LỖI 1: PHOTO PREVIEW] ---
                    // Giải quyết Vấn đề Lỗi 1&2: Flow tạo My Food mượt mà, hỗ trợ State refresh tab
                    _buildImagePreview(setModalState),
                    const SizedBox(height: 20),

                    // ==========================================================
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Tên món ăn (*)",
                      ),
                    ),
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(
                        labelText: "Định lượng (vd: 100g, 1 bát)",
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: caloCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Calories (*)",
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: proteinCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Protein (g)",
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: fatCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Fat (g)",
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: carbCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Carbs (g)",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _greenColor,
                        ),
                        onPressed: () async {
                          if (nameCtrl.text.isEmpty || caloCtrl.text.isEmpty)
                            return;

                          final newFood = {
                            "userId": _currentUserId,
                            "name": nameCtrl.text,
                            "amount": amountCtrl.text,
                            "calories": double.tryParse(caloCtrl.text) ?? 0,
                            "protein": double.tryParse(proteinCtrl.text) ?? 0,
                            "fat": double.tryParse(fatCtrl.text) ?? 0,
                            "carbs": double.tryParse(carbCtrl.text) ?? 0,
                            "category": "My Foods",
                          };

                          final messenger = ScaffoldMessenger.of(context);

                          Navigator.pop(
                            context,
                          ); // Close modal flow back to Search screen context

                          // --- [FIX LỖI 1: STATE MANAGEMENT & Separation] ---
                          setState(() => _isLoading = true);

                          // Giải quyết Vấn đề Lỗi 1&2: Flow tạo My Food mượt mà, hỗ trợ State refresh tab
                          bool success = await AuthService.createMyFood(
                            newFood,
                            _selectedImageFile,
                          );

                          // Giải phóng bộ nhớ, xóa ảnh khỏi biến trạng thái
                          _selectedImageFile = null;

                          if (success) {
                            await _loadPersonalData(); // REFRESH MY FOODS LIST IN TAB
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text("Đã lưu món ăn thành công!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                            // --- [FIX SEPARATION]: We do NOT pop back data to diary log flow here.
                            // User must explicitly add it from My Foods or Search tabs. ---
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Lưu thất bại! Hãy kiểm tra Server.",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }

                          setState(() => _isLoading = false);
                        },
                        child: const Text(
                          "Lưu Món Ăn",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Giải phóng bộ nhớ, xóa ảnh khỏi biến trạng thái khi đóng BottomSheet bằng cách bấm ra ngoài
      _selectedImageFile = null;
    });
  }

  // --- WIDGET HIỂN THỊ ẢNH PREVIEW & SUPPORT SỬA MÓN ---
  // Ta thêm biến `initialImageUrl` để hỗ trợ hiển thị ảnh cũ khi sửa món.
  Widget _buildImagePreview(
    StateSetter setModalState, {
    String? initialImageUrl,
  }) {
    if (_selectedImageFile == null) {
      // Ta kiểm tra nếu initialImageUrl tồn tại (khi sửa món), hiển thị ảnh cloud
      if (initialImageUrl != null && initialImageUrl.isNotEmpty) {
        return Align(
          alignment: Alignment.center,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  initialImageUrl,
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                  // Hiển thị loading/lỗi khi tải ảnh mạng
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 150,
                      height: 150,
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _greenColor,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 150,
                    height: 150,
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey[500],
                      size: 50,
                    ),
                  ),
                ),
              ),
              // Nút đổi ảnh mới
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () async {
                    // Menu đổi ảnh mới
                    ModalEffects.showAppBottomSheet(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.camera_alt,
                                color: Colors.green,
                              ),
                              title: const Text('Chụp ảnh mới'),
                              onTap: () async {
                                Navigator.pop(context);
                                final pickedFile = await _picker.pickImage(
                                  source: ImageSource.camera,
                                  maxWidth: 800,
                                );
                                if (pickedFile != null) {
                                  setModalState(() {
                                    _selectedImageFile = File(pickedFile.path);
                                  });
                                }
                              },
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.photo_library,
                                color: Colors.blue,
                              ),
                              title: const Text('Chọn ảnh từ Thư viện'),
                              onTap: () async {
                                Navigator.pop(context);
                                final pickedFile = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 800,
                                );
                                if (pickedFile != null) {
                                  setModalState(() {
                                    _selectedImageFile = File(pickedFile.path);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.change_circle,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Nếu không có ảnh cũ, không có ảnh mới, hiển thị nút add.
      return Align(
        alignment: Alignment.center,
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                // Menu chọn ảnh
                ModalEffects.showAppBottomSheet(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.camera_alt,
                            color: Colors.green,
                          ),
                          title: const Text('Chụp ảnh mới'),
                          onTap: () async {
                            Navigator.pop(context);
                            final pickedFile = await _picker.pickImage(
                              source: ImageSource.camera,
                              maxWidth: 800,
                            );
                            if (pickedFile != null) {
                              setModalState(() {
                                _selectedImageFile = File(pickedFile.path);
                              });
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.photo_library,
                            color: Colors.blue,
                          ),
                          title: const Text('Chọn ảnh từ Thư viện'),
                          onTap: () async {
                            Navigator.pop(context);
                            final pickedFile = await _picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 800,
                            );
                            if (pickedFile != null) {
                              setModalState(() {
                                _selectedImageFile = File(pickedFile.path);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_a_photo,
                  color: Colors.grey[400],
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Đính kèm ảnh",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Nếu có ảnh mới vừa chụp/chọn, hiển thị ảnh local
    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _selectedImageFile!,
              width: 150,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Nút xóa ảnh local
        Positioned(
          top: 0,
          right: (MediaQuery.of(context).size.width / 2) - (150 / 2) - 16,
          child: GestureDetector(
            onTap: () {
              setModalState(() {
                _selectedImageFile = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  // --- FORM TẠO CÔNG THỨC NẤU ĂN (RECIPE) ---
  void _showAddRecipeModal() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final caloCtrl = TextEditingController();

    ModalEffects.showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Tạo Công Thức Mới",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Tên công thức (*)",
                  ),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: "Mô tả ngắn"),
                ),
                TextField(
                  controller: caloCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Tổng Calories (*)",
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _greenColor,
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty || caloCtrl.text.isEmpty)
                        return;

                      final newRecipe = {
                        "userId": _currentUserId,
                        "name": nameCtrl.text,
                        "description": descCtrl.text,
                        "totalCalories": double.tryParse(caloCtrl.text) ?? 0,
                        "totalProtein": 0,
                        "totalFat": 0,
                        "totalCarbs": 0,
                      };

                      final messenger = ScaffoldMessenger.of(context);

                      Navigator.pop(context);
                      setState(() => _isLoading = true);

                      bool success = await AuthService.createRecipe(newRecipe);
                      if (success) {
                        await _loadPersonalData();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("Đã lưu công thức thành công!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("Lưu thất bại! Hãy kiểm tra Server."),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }

                      setState(() => _isLoading = false);
                    },
                    child: const Text(
                      "Lưu Công Thức",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- [YÊU CẦU]: HÀM XÓA MÓN ĂN MY FOOD ---
  void _deleteMyFood(dynamic item) {
    if (item['userId'] != _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lỗi: Bạn chỉ được xóa món ăn của riêng mình."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final foodId = item['_id'];
    final foodName = item['name'];

    // 1. CHỐT REFERENCE CỦA MESSENGER TỪ MÀN HÌNH GỐC (TRƯỚC KHI MỞ DIALOG)
    final messenger = ScaffoldMessenger.of(context);

    ModalEffects.showScaleFadeDialog(
      context: context,
      // 2. Đổi tên biến này thành dialogContext để không bị nhầm lẫn với context của màn hình
      builder: (dialogContext) => AlertDialog(
        title: const Text("Xóa Món Ăn"),
        content: Text(
          "Bạn có chắc chắn muốn xóa '$foodName' khỏi 'Món Ăn Của Bạn'? Hành động này không thể hoàn tác.",
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext), // Đóng dialog không xóa
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Đóng dialog trước khi gọi API

              setState(() => _isLoading = true);

              // Gọi hàm xóa
              bool success = await AuthService.deleteMyFood(
                foodId,
                _currentUserId,
              );

              if (success) {
                await _loadPersonalData(); // REFRESH MY FOODS LIST IN TAB
                // 3. DÙNG BIẾN MESSENGER ĐÃ CHỐT ĐỂ HIỆN THÔNG BÁO
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text("Đã xóa món ăn thành công!"),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text("Xóa thất bại! Hãy kiểm tra Server."),
                    backgroundColor: Colors.red,
                  ),
                );
              }

              setState(() => _isLoading = false);
            },
            child: const Text(
              "Xóa",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.mealType,
          style: const TextStyle(color: Colors.black54, fontSize: 28),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildTabs(),
              const SizedBox(height: 24),

              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: _greenColor),
                      )
                    : _buildContentByTab(),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    // Menu chọn ảnh mớm data cho AI
                    ModalEffects.showAppBottomSheet(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.camera_alt,
                                color: Colors.green,
                              ),
                              title: const Text('Chụp ảnh mới'),
                              onTap: () {
                                Navigator.pop(context);
                                _processImageWithAI(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.photo_library,
                                color: Colors.blue,
                              ),
                              title: const Text('Chọn ảnh từ Thư viện'),
                              onTap: () {
                                Navigator.pop(context);
                                _processImageWithAI(ImageSource.gallery);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _greenColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Add image",
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

  Widget _buildContentByTab() {
    switch (_selectedTabIndex) {
      case 0:
        return Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 24),
            Expanded(
              child: _searchController.text.isNotEmpty
                  ? _buildSearchResults()
                  : const SizedBox.shrink(),
            ),
          ],
        );
      case 1:
        // --- [FIX LỖI 1]: DÙNG GIAO DIỆN TÁCH STATE CHO MY FOOD ---
        return _buildMyFoodsListState(); // Giao diện Món Ăn Của Bạn với Sửa/Xóa
      case 2:
        return _buildExerciseEntry();
      case 3:
        // --- [FIX LỖI 1]: Giữ giao diện cũ cho Recipes (tạm thời) ---
        return _buildPersonalList(
          _recipesList,
          "Chưa có công thức nào được lưu.",
          false,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // --- GIAO DIỆN NHẬP CALO TIÊU HAO (BÀI TẬP) ---
  Widget _buildExerciseEntry() {
    final nameCtrl = TextEditingController(text: "Đạp xe");
    final caloCtrl = TextEditingController();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Nhập Calo Tiêu Hao",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Nhập lượng calo bạn đã đốt cháy từ thiết bị đo lường (Smartwatch...) để hệ thống ghi nhận.",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              labelText: "Tên bài tập (vd: Đạp xe, Tập tạ...)",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: caloCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Lượng Calories đốt cháy (Kcal) *",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(
                Icons.directions_run,
                color: Colors.orange,
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _greenColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (caloCtrl.text.isEmpty) return;

                final exerciseData = {
                  "_id": "exercise_${DateTime.now().millisecondsSinceEpoch}",
                  "name": nameCtrl.text.isEmpty ? "Bài tập" : nameCtrl.text,
                  "burnedCalories": double.tryParse(caloCtrl.text) ?? 0.0,
                  "isExercise": true,
                };

                Navigator.pop(context, exerciseData);
              },
              child: const Text(
                "Ghi nhận bài tập",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // --- [FIX LỖI 1: GIAO DIỆN MY FOOD TAB VỚI SỬA/XÓA] ---
  // ==========================================================
  // Giải quyết Vấn đề Lỗi 1&2: Tách Local State tab, hỗ trợ ảnh và edit/delete
  Widget _buildMyFoodsListState() {
    final emptyMessage = "Chưa có món ăn nào của riêng bạn.";

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _showAddMyFoodModal,
            icon: const Icon(Icons.add_circle, color: Color(0xFF65B362)),
            label: const Text(
              "Tạo món mới",
              style: TextStyle(
                color: Color(0xFF65B362),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        Expanded(
          child: _myFoodsList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fastfood_outlined,
                        size: 60,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        emptyMessage,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _myFoodsList.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final item = _myFoodsList[index];
                    final cals = item['totalCalories'] ?? item['calories'] ?? 0;
                    final amountText = item['amount'] ?? "1 phần";
                    String imageUrl = item['imageUrl'] ?? "";

                    // Kiểm tra ownership để hiện nút Sửa/Xóa
                    bool isOwner = (item['userId'] == _currentUserId);

                    return InkWell(
                      onTap: () async {
                        // FLOW QUEN THUỘC: Bấm vào để thêm vào Diary ngày
                        Map<String, dynamic> normalizedFood = {
                          '_id': item['_id'],
                          'name': item['name'],
                          'calories': cals,
                          'protein':
                              item['totalProtein'] ?? item['protein'] ?? 0,
                          'fat': item['totalFat'] ?? item['fat'] ?? 0,
                          'carbs': item['totalCarbs'] ?? item['carbs'] ?? 0,
                          'imageUrl': imageUrl,
                        };
                        final addedFood = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FoodDetailScreen(
                              mealType: widget.mealType,
                              foodData: normalizedFood,
                            ),
                          ),
                        );
                        if (addedFood != null && mounted) {
                          Navigator.pop(context, addedFood);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            // 1. Hiển thị ảnh (nếu có link cloud)
                            if (imageUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imageUrl,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Container(
                                            width: 50,
                                            height: 50,
                                            color: Colors.grey[100],
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                color: _greenColor,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          );
                                        },
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              width: 50,
                                              height: 50,
                                              color: Colors.grey[200],
                                              child: Icon(
                                                Icons.broken_image,
                                                color: Colors.grey[400],
                                              ),
                                            ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.no_photography,
                                  color: Colors.grey[300],
                                ),
                              ),
                            const SizedBox(width: 12),

                            // 2. Thông tin món ăn
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$cals Kcal / $amountText",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 3. Actions: Icon Add + Nút Sửa/Xóa (chỉ cho owner)
                            const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFF65B362),
                            ),
                            if (isOwner)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Nút sửa món
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                                    onPressed: () => _showEditMyFoodModal(item),
                                  ),
                                  // Nút xóa món
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    onPressed: () => _deleteMyFood(item),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- HÀM BUILD LIST CŨ (DÙNG CHO RECIPES) ---
  Widget _buildPersonalList(
    List<dynamic> listData,
    String emptyMessage,
    bool isMyFood,
  ) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: isMyFood ? _showAddMyFoodModal : _showAddRecipeModal,
            icon: const Icon(Icons.add_circle, color: Color(0xFF65B362)),
            label: Text(
              isMyFood ? "Tạo món mới" : "Tạo công thức",
              style: const TextStyle(
                color: Color(0xFF65B362),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        Expanded(
          child: listData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fastfood_outlined,
                        size: 60,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        emptyMessage,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: listData.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final item = listData[index];
                    final cals = item['totalCalories'] ?? item['calories'] ?? 0;
                    final amountText = item['amount'] ?? "1 phần";

                    return InkWell(
                      onTap: () async {
                        Map<String, dynamic> normalizedFood = {
                          '_id': item['_id'],
                          'name': item['name'],
                          'calories': cals,
                          'protein':
                              item['totalProtein'] ?? item['protein'] ?? 0,
                          'fat': item['totalFat'] ?? item['fat'] ?? 0,
                          'carbs': item['totalCarbs'] ?? item['carbs'] ?? 0,
                        };
                        final addedFood = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FoodDetailScreen(
                              mealType: widget.mealType,
                              foodData: normalizedFood,
                            ),
                          ),
                        );
                        if (addedFood != null && mounted) {
                          Navigator.pop(context, addedFood);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "$cals Kcal / $amountText",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFF65B362),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    final tabs = ["Search", "My Foods", "Exercises", "Recipes"];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          bool isSelected = _selectedTabIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                  if (index != 0) _searchController.clear();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? _greenColor : _lightBlueColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : _textGreenColor,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _searchController.text.isNotEmpty
              ? _greenColor
              : Colors.grey[300]!,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: "Search (vd: Ức gà, cơm...)",
          hintStyle: TextStyle(color: Colors.grey[400]),
          suffixIcon: Icon(Icons.search, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _greenColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _searchController.text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _onSearchChanged("");
                  },
                  child: Icon(
                    Icons.cancel_outlined,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: _lightBlueColor, thickness: 1),
          Expanded(
            child: _searchResults.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Không tìm thấy món ăn nào",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) =>
                        _buildFoodItemRow(_searchResults[index]),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFoodItemRow(dynamic item) {
    return InkWell(
      onTap: () async {
        final addedFood = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FoodDetailScreen(mealType: widget.mealType, foodData: item),
          ),
        );
        if (addedFood != null && mounted) Navigator.pop(context, addedFood);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['name'],
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${item['calories']} Kcal / 100g",
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
