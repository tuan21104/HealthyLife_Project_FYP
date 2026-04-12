import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'food_search_screen.dart';
import 'services/auth_service.dart';
import 'modal_effects.dart';
import 'animation_presets.dart';

class DiaryScreen extends StatefulWidget {
  final double initialCalo;

  const DiaryScreen({super.key, this.initialCalo = 1200});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  List<Map<String, dynamic>> _exerciseList = []; // Mảng lưu bài tập

  DateTime _selectedDate = DateTime.now();

  final Color _greenColor = const Color(0xFF65B362);
  final Color _blueGreyColor = const Color(0xFF9CB8C6);
  final Color _macroBgColor = const Color(0xFFD3E7F0);

  double _targetCalo = 1200;
  double _defaultTargetCalo = 1200;
  double _targetCarb = 150;
  double _targetProtein = 60;
  double _targetFat = 40;

  List<Map<String, dynamic>> _breakfastFoods = [];
  List<Map<String, dynamic>> _lunchFoods = [];
  List<Map<String, dynamic>> _snackFoods = [];
  List<Map<String, dynamic>> _dinnerFoods = [];

  @override
  void initState() {
    super.initState();
    _defaultTargetCalo = widget.initialCalo;
    _targetCalo = _defaultTargetCalo;
    _targetCarb = (_targetCalo * 0.5) / 4;
    _targetProtein = (_targetCalo * 0.2) / 4;
    _targetFat = (_targetCalo * 0.3) / 9;

    _bootstrapDiaryData();
  }

  Future<void> _bootstrapDiaryData() async {
    await _loadPersonalizedTargetCalo();
    await _loadDailyData();
  }

  Future<void> _refreshDiaryPage() async {
    await _bootstrapDiaryData();
  }

  Future<void> _loadPersonalizedTargetCalo() async {
    try {
      final profile = await AuthService.getUserProfile();
      final user = profile is Map<String, dynamic>
          ? (profile['user'] ?? profile['data'])
          : null;

      final profileTarget = user is Map
          ? (user['targetCalo'] as num?)?.toDouble()
          : null;

      if (profileTarget != null && profileTarget > 0 && mounted) {
        setState(() {
          _defaultTargetCalo = profileTarget;
          _targetCalo = profileTarget;
          _targetCarb = (_targetCalo * 0.5) / 4;
          _targetProtein = (_targetCalo * 0.2) / 4;
          _targetFat = (_targetCalo * 0.3) / 9;
        });
      }
    } catch (_) {}
  }

  // --- HÀM 1: CẬP NHẬT GIAO DIỆN (HÀM PHỤ TRỢ) ---
  bool _updateStateWithData(Map<String, dynamic> data) {
    bool migratedLegacyTarget = false;

    setState(() {
      final savedTargetCalo = (data['targetCalo'] as num?)?.toDouble();

      // Migrate dữ liệu cũ: trước đây target mặc định luôn bị lưu là 1200.
      final isLegacyDefault =
          savedTargetCalo != null &&
          savedTargetCalo == widget.initialCalo &&
          _defaultTargetCalo != widget.initialCalo;

      if (isLegacyDefault) {
        migratedLegacyTarget = true;
      }

      _targetCalo =
          (savedTargetCalo != null && savedTargetCalo > 0 && !isLegacyDefault)
          ? savedTargetCalo
          : _defaultTargetCalo;
      _targetCarb =
          (data['targetCarb'] as num?)?.toDouble() ?? (_targetCalo * 0.5) / 4;
      _targetProtein =
          (data['targetProtein'] as num?)?.toDouble() ??
          (_targetCalo * 0.2) / 4;
      _targetFat =
          (data['targetFat'] as num?)?.toDouble() ?? (_targetCalo * 0.3) / 9;

      _breakfastFoods = List<Map<String, dynamic>>.from(
        data['breakfast'] ?? [],
      );
      _lunchFoods = List<Map<String, dynamic>>.from(data['lunch'] ?? []);
      _snackFoods = List<Map<String, dynamic>>.from(data['snack'] ?? []);
      _dinnerFoods = List<Map<String, dynamic>>.from(data['dinner'] ?? []);
      _exerciseList = List<Map<String, dynamic>>.from(data['exercise'] ?? []);
    });

    return migratedLegacyTarget;
  }

  // --- HÀM 2: TẢI DỮ LIỆU THÔNG MINH (LOCAL + CLOUD) ---
  Future<void> _loadDailyData() async {
    final prefs = await SharedPreferences.getInstance();
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    String dateKey = 'diary_$formattedDate';
    String? savedData = prefs.getString(dateKey);

    // BƯỚC 1: KIỂM TRA BỘ NHỚ TRONG MÁY TRƯỚC (Rất nhanh, dùng khi offline)
    if (savedData != null) {
      try {
        Map<String, dynamic> data = jsonDecode(savedData);
        final migrated = _updateStateWithData(data);
        if (migrated) {
          await _saveDailyData();
        }
        return; // Có data trong máy rồi thì dừng luôn
      } catch (e) {
        print("Lỗi parse JSON Local: $e");
      }
    }

    // BƯỚC 2: NẾU MÁY TRỐNG (Vừa Log out xong) -> GỌI LÊN MÂY TẢI VỀ
    String? userId = prefs.getString('userId');
    if (userId != null && userId.isNotEmpty) {
      print("==== ☁️ ĐANG LẤY NHẬT KÝ TỪ CLOUD: Ngày $formattedDate ====");
      Map<String, dynamic>? cloudData = await AuthService.getDiaryFromCloud(
        userId,
        formattedDate,
      );

      if (cloudData != null) {
        print("==== ✅ ĐÃ TẢI THÀNH CÔNG TỪ CLOUD VỀ MÁY ====");
        final migrated = _updateStateWithData(cloudData);

        // Tiện tay lưu luôn vào điện thoại để lần sau mở App không cần đợi tải mạng
        if (migrated) {
          await _saveDailyData();
        } else {
          await prefs.setString(dateKey, jsonEncode(cloudData));
        }
        return;
      }
    }

    // BƯỚC 3: NẾU MÂY CŨNG TRỐNG NỐT -> TẠO NGÀY MỚI TRẮNG TINH
    setState(() {
      _targetCalo = _defaultTargetCalo;
      _targetCarb = (_targetCalo * 0.5) / 4;
      _targetProtein = (_targetCalo * 0.2) / 4;
      _targetFat = (_targetCalo * 0.3) / 9;

      _breakfastFoods = [];
      _lunchFoods = [];
      _snackFoods = [];
      _dinnerFoods = [];
      _exerciseList = [];
    });
  }

  Future<void> _saveDailyData() async {
    final prefs = await SharedPreferences.getInstance();
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    String dateKey = 'diary_$formattedDate';

    // Đóng gói dữ liệu để lưu
    Map<String, dynamic> dataToSave = {
      'targetCalo': _targetCalo,
      'targetCarb': _targetCarb,
      'targetProtein': _targetProtein,
      'targetFat': _targetFat,
      'breakfast': _breakfastFoods,
      'lunch': _lunchFoods,
      'snack': _snackFoods,
      'dinner': _dinnerFoods,
      'exercise': _exerciseList, // Lưu bài tập
    };

    // 1. LƯU LOCAL
    await prefs.setString(dateKey, jsonEncode(dataToSave));

    // 2. ĐỒNG BỘ LÊN CLOUD
    String? realUserId = prefs.getString('userId');

    if (realUserId != null && realUserId.isNotEmpty) {
      Map<String, dynamic> cloudData = {
        'userId': realUserId,
        'date': formattedDate,
        ...dataToSave,
      };

      AuthService.syncDiaryToCloud(cloudData);
    }
  }

  void _deleteFood(String mealType, int index) {
    setState(() {
      if (mealType == "Breakfast")
        _breakfastFoods.removeAt(index);
      else if (mealType == "Lunch")
        _lunchFoods.removeAt(index);
      else if (mealType == "Snack")
        _snackFoods.removeAt(index);
      else if (mealType == "Dinner")
        _dinnerFoods.removeAt(index);
      else if (mealType == "Exercise")
        _exerciseList.removeAt(index);
    });
    _saveDailyData();
  }

  void _showEditFoodDialog(
    String mealType,
    int index,
    Map<String, dynamic> food,
  ) {
    List<String> amountParts = food['amount'].toString().split(" ");
    String oldAmountStr = amountParts.isNotEmpty ? amountParts[0] : "100";
    String unit = amountParts.length > 1 ? amountParts[1] : "Gr";

    TextEditingController controller = TextEditingController(
      text: oldAmountStr,
    );

    ModalEffects.showScaleFadeDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Sửa: ${food['name']}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Nhập định lượng mới",
              suffixText: unit,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                _deleteFood(mealType, index);
              },
              child: const Text("Xóa", style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _greenColor,
                elevation: 0,
              ),
              onPressed: () {
                double oldVal = double.tryParse(oldAmountStr) ?? 1.0;
                double newVal = double.tryParse(controller.text) ?? oldVal;

                if (newVal > 0 && oldVal > 0) {
                  double ratio = newVal / oldVal;
                  setState(() {
                    food['amount'] = "${newVal.toStringAsFixed(0)} $unit";
                    if (mealType == "Exercise") {
                      food['burnedCalories'] =
                          (food['burnedCalories'] ?? 0) * ratio;
                    } else {
                      food['kcal'] = (food['kcal'] ?? 0) * ratio;
                      food['carb'] = (food['carb'] ?? 0) * ratio;
                      food['protein'] = (food['protein'] ?? 0) * ratio;
                      food['fat'] = (food['fat'] ?? 0) * ratio;
                      food['fiber'] = (food['fiber'] ?? 0) * ratio;
                    }
                  });
                  _saveDailyData();
                }
                Navigator.pop(context);
              },
              child: const Text(
                "Lưu",
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

  // CỖ MÁY TÍNH TOÁN AN TOÀN
  Map<String, double> _calculateTotals() {
    double totalTaken = 0,
        totalCarb = 0,
        totalProtein = 0,
        totalFat = 0,
        totalBurnt = 0;

    List<Map<String, dynamic>> allFoods = [
      ..._breakfastFoods,
      ..._lunchFoods,
      ..._snackFoods,
      ..._dinnerFoods,
    ];

    for (var food in allFoods) {
      totalTaken += (food['kcal'] ?? food['calories'] ?? 0.0).toDouble();
      totalCarb += (food['carb'] ?? food['carbs'] ?? 0.0).toDouble();
      totalProtein += (food['protein'] ?? 0.0).toDouble();
      totalFat += (food['fat'] ?? 0.0).toDouble();
    }

    for (var item in _exerciseList) {
      totalBurnt += (item['burnedCalories'] ?? 0.0).toDouble();
    }

    return {
      'taken': totalTaken,
      'carb': totalCarb,
      'protein': totalProtein,
      'fat': totalFat,
      'burnt': totalBurnt,
    };
  }

  Map<String, dynamic> _calculateHealthStatus(double taken, double burnt) {
    if (taken <= 0) {
      return {'icon': Icons.sentiment_very_dissatisfied, 'color': Colors.red};
    }

    final target = _targetCalo <= 0 ? 1.0 : _targetCalo;
    final netCalorie = taken - burnt;
    final deviationRatio = ((netCalorie - target).abs()) / target;

    if (deviationRatio <= 0.10) {
      return {'icon': Icons.sentiment_satisfied_alt, 'color': _greenColor};
    }

    if (deviationRatio <= 0.30) {
      return {'icon': Icons.sentiment_neutral, 'color': Colors.orange};
    }

    return {'icon': Icons.sentiment_very_dissatisfied, 'color': Colors.red};
  }

  Future<void> _handleAddFood(String mealType) async {
    final addedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodSearchScreen(mealType: mealType),
      ),
    );

    if (addedData != null) {
      bool isExercise = addedData['isExercise'] == true;

      // KHÓA BẢO VỆ
      if (mealType == 'Exercise' && !isExercise) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mục này chỉ dành cho Bài Tập!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (mealType != 'Exercise' && isExercise) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Không thể thêm Bài Tập vào bữa ăn!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        if (mealType == 'Breakfast')
          _breakfastFoods.add(addedData);
        else if (mealType == 'Lunch')
          _lunchFoods.add(addedData);
        else if (mealType == 'Snack')
          _snackFoods.add(addedData);
        else if (mealType == 'Dinner')
          _dinnerFoods.add(addedData);
        else if (mealType == 'Exercise')
          _exerciseList.add(addedData);
      });

      _saveDailyData();
    }
  }

  void _showAddActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final actions = [
          {'title': 'Breakfast', 'icon': Icons.free_breakfast_rounded},
          {'title': 'Lunch', 'icon': Icons.lunch_dining_rounded},
          {'title': 'Dinner', 'icon': Icons.dinner_dining_rounded},
          {'title': 'Snack', 'icon': Icons.icecream_rounded},
          {'title': 'Exercise', 'icon': Icons.fitness_center_rounded},
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: actions
                  .map(
                    (item) => ListTile(
                      leading: Icon(
                        item['icon'] as IconData,
                        color: _greenColor,
                      ),
                      title: Text(
                        item['title'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _handleAddFood(item['title'] as String);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  void _showEditTargetDialog(
    String title,
    double currentValue,
    Function(double) onSaved,
  ) {
    TextEditingController controller = TextEditingController(
      text: currentValue.toInt().toString(),
    );
    ModalEffects.showScaleFadeDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Chỉnh sửa $title",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              suffixText: title.contains("Calo") ? "Kcal" : "g",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _greenColor,
                elevation: 0,
              ),
              onPressed: () {
                double newValue =
                    double.tryParse(controller.text) ?? currentValue;
                if (newValue > 0) {
                  onSaved(newValue);
                  _saveDailyData();
                }
                Navigator.pop(context);
              },
              child: const Text(
                "Lưu",
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

  @override
  Widget build(BuildContext context) {
    final totals =
        _calculateTotals(); // Tính toán tươi mới mỗi khi vẽ giao diện
    final healthStatus = _calculateHealthStatus(
      totals['taken']!,
      totals['burnt']!,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Diary",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.normal,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle, color: _greenColor, size: 36),
            onPressed: _showAddActionSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDiaryPage,
          color: _greenColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCalorieTracker(totals['taken']!, totals['burnt']!),
                const SizedBox(height: 24),
                _buildMacrosTracker(
                  totals['carb']!,
                  totals['protein']!,
                  totals['fat']!,
                ),
                const SizedBox(height: 20),
                _buildDateSelector(
                  moodIcon: healthStatus['icon'] as IconData,
                  moodColor: healthStatus['color'] as Color,
                ),
                const SizedBox(height: 20),

                _buildMealSection(
                  "Breakfast",
                  _breakfastFoods,
                  _greenColor,
                ).withStagger(0),
                const SizedBox(height: 12),
                _buildMealSection(
                  "Lunch",
                  _lunchFoods,
                  _greenColor,
                ).withStagger(1),
                const SizedBox(height: 12),
                _buildMealSection(
                  "Exercise",
                  _exerciseList,
                  _blueGreyColor,
                ).withStagger(2), // Đã truyền list bài tập
                const SizedBox(height: 12),
                _buildMealSection(
                  "Snack",
                  _snackFoods,
                  _greenColor,
                ).withStagger(3),
                const SizedBox(height: 12),
                _buildMealSection(
                  "Dinner",
                  _dinnerFoods,
                  _greenColor,
                ).withStagger(4),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalorieTracker(double taken, double burnt) {
    double remaining = _targetCalo - taken + burnt;
    double progress = _targetCalo > 0 ? (taken / _targetCalo) : 0.0;
    if (progress > 1.0) progress = 1.0;

    return SizedBox(
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: _greenColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(35),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${taken.toStringAsFixed(1)} Kcal",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(
                        "Taken",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: _blueGreyColor,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(35),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${burnt.toStringAsFixed(0)} Kcal",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(
                        "Burnt",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => _showEditTargetDialog(
              "Mục tiêu Calo",
              _targetCalo,
              (newValue) => setState(() => _targetCalo = newValue),
            ),
            child: Container(
              width: 95,
              height: 95,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5,
                    backgroundColor: Colors.grey[400],
                    valueColor: AlwaysStoppedAnimation<Color>(_greenColor),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          remaining.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Còn lại",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.edit, size: 10, color: Colors.grey[500]),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosTracker(double carb, double protein, double fat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: _macroBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMacroItem(
              "Carbs",
              carb,
              _targetCarb,
              _greenColor,
              () => _showEditTargetDialog(
                "Mục tiêu Carbs",
                _targetCarb,
                (val) => setState(() => _targetCarb = val),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildMacroItem(
              "Protein",
              protein,
              _targetProtein,
              Colors.white,
              () => _showEditTargetDialog(
                "Mục tiêu Protein",
                _targetProtein,
                (val) => setState(() => _targetProtein = val),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildMacroItem(
              "Fat",
              fat,
              _targetFat,
              Colors.grey[700]!,
              () => _showEditTargetDialog(
                "Mục tiêu Fat",
                _targetFat,
                (val) => setState(() => _targetFat = val),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(
    String label,
    double current,
    double max,
    Color progressColor,
    VoidCallback onEdit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: max > 0 ? (current / max) : 0,
            minHeight: 8,
            backgroundColor: Colors.white54,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
            GestureDetector(
              onTap: onEdit,
              child: Row(
                children: [
                  Text(
                    "${current.toInt()}/${max.toInt()}g",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.edit, size: 10, color: Colors.black54),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMealSection(
    String title,
    List<Map<String, dynamic>> foods,
    Color bgColor,
  ) {
    // Lấy đúng số Calo tùy thuộc vào Bữa Ăn hay Bài Tập
    double mealTotalCalo = foods.fold(
      0,
      (sum, item) =>
          sum +
          ((item['kcal'] ?? item['burnedCalories'] ?? item['calories'] ?? 0.0)
              .toDouble()),
    );

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        collapsedBackgroundColor: bgColor,
        backgroundColor: _macroBgColor.withOpacity(0.35),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Total Energy: ${mealTotalCalo.toStringAsFixed(1)} Kcal",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        "Name",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        "Gram",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        "Kcal",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        "Carb",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        "Protein",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        "Fat",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (foods.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Chưa có dữ liệu',
                      style: TextStyle(color: Colors.black45),
                    ),
                  )
                else
                  ...foods.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> food = entry.value;

                    return Dismissible(
                      key: UniqueKey(),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) => _deleteFood(title, index),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Colors.red[400],
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      child: GestureDetector(
                        onTap: () => _showEditFoodDialog(title, index, food),
                        child: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  food['name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF5A9B58),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  food['amount']?.toString() ?? '-',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  (food['kcal'] ??
                                          food['burnedCalories'] ??
                                          food['calories'] ??
                                          0.0)
                                      .toDouble()
                                      .toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  (food['carb'] ?? food['carbs'] ?? 0.0)
                                      .toDouble()
                                      .toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  (food['protein'] ?? 0.0)
                                      .toDouble()
                                      .toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  (food['fat'] ?? 0.0)
                                      .toDouble()
                                      .toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).withStagger(index, beginY: 0.12);
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector({
    required IconData moodIcon,
    required Color moodColor,
  }) {
    DateTime today = DateTime.now();
    DateTime todayOnly = DateTime(today.year, today.month, today.day);
    DateTime minDate = todayOnly.subtract(const Duration(days: 6));
    DateTime selectedOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    bool canGoBack = selectedOnly.isAfter(minDate);
    bool canGoForward = selectedOnly.isBefore(todayOnly);
    final sideWidth = MediaQuery.of(context).size.width * 0.38;

    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: sideWidth,
              child: GestureDetector(
                onTap: canGoBack
                    ? () {
                        setState(
                          () => _selectedDate = _selectedDate.subtract(
                            const Duration(days: 1),
                          ),
                        );
                        _loadDailyData();
                      }
                    : null,
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_back_ios,
                      size: 16,
                      color: canGoBack ? Colors.black87 : Colors.grey[300],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE').format(_selectedDate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          color: canGoBack ? Colors.black54 : Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(child: Icon(moodIcon, size: 40, color: moodColor)),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: sideWidth,
              child: GestureDetector(
                onTap: canGoForward
                    ? () {
                        setState(
                          () => _selectedDate = _selectedDate.add(
                            const Duration(days: 1),
                          ),
                        );
                        _loadDailyData();
                      }
                    : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          color: canGoForward
                              ? Colors.black54
                              : Colors.grey[300],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: canGoForward ? Colors.black87 : Colors.grey[300],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
