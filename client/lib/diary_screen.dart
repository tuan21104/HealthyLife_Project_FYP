import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'food_search_screen.dart';
import 'services/auth_service.dart';
import 'services/diary_service.dart';
import 'modal_effects.dart';
import 'animation_presets.dart';
import 'core/theme/app_theme.dart';

class DiaryScreen extends StatefulWidget {
  final double initialCalo;
  final int refreshSignal;

  const DiaryScreen({
    super.key,
    this.initialCalo = 1200,
    this.refreshSignal = 0,
  });

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
  Map<String, dynamic>? _profileUser;
  double _waterIntake = 0;
  double _waterAnimatedFrom = 0;
  double _waterTargetMl = 2000;
  bool _isWaterSyncing = false;

  List<Map<String, dynamic>> _breakfastFoods = [];
  List<Map<String, dynamic>> _lunchFoods = [];
  List<Map<String, dynamic>> _snackFoods = [];
  List<Map<String, dynamic>> _dinnerFoods = [];
  final Set<String> _processingDiaryItemKeys = <String>{};

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

  @override
  void didUpdateWidget(covariant DiaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _syncTargetFromProfile();
    }
  }

  Future<void> _syncTargetFromProfile() async {
    await _loadPersonalizedTargetCalo();
    await _loadDailyData();
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

      final profileTarget = _resolveProfileDailyTarget(user);

      if (profileTarget > 0 && mounted) {
        setState(() {
          _profileUser = user is Map ? Map<String, dynamic>.from(user) : null;
          _defaultTargetCalo = profileTarget;
          _targetCalo = profileTarget;
          _applyGoalBasedMacroTargets(_targetCalo, _profileUser);
          final weight = (user?['weight'] as num?)?.toDouble();
          if (weight != null && weight > 0) {
            _waterTargetMl = weight * 35;
          }
        });
      }
    } catch (_) {}
  }

  double _normalizeDailyTarget(dynamic value) {
    if (value is! num) return 0;
    final target = value.toDouble();

    if (!target.isFinite || target <= 0) return 0;

    // Daily calorie target that is too low/high is considered invalid.
    if (target < 500 || target > 6000) return 0;

    return target;
  }

  double _normalizeWeight(dynamic value) {
    if (value is! num) return 0;
    final weight = value.toDouble();
    if (!weight.isFinite || weight <= 0) return 0;
    if (weight < 25 || weight > 300) return 0;
    return weight;
  }

  ({double carb, double protein, double fat}) _macroRatiosForGoal(
    dynamic user,
  ) {
    final goal =
        (user is Map ? user['goal'] : null)?.toString().toLowerCase() ?? '';

    final weight = user is Map ? _normalizeWeight(user['weight']) : 0;

    if (weight >= 90) {
      if (goal.contains('losing')) {
        return (carb: 0.37, protein: 0.38, fat: 0.25);
      }
      if (goal.contains('gaining')) {
        return (carb: 0.48, protein: 0.27, fat: 0.25);
      }
      if (goal.contains('keeping') || goal.contains('fit')) {
        return (carb: 0.43, protein: 0.27, fat: 0.30);
      }
    }

    if (goal.contains('losing')) {
      return (carb: 0.40, protein: 0.35, fat: 0.25);
    }
    if (goal.contains('gaining')) {
      return (carb: 0.50, protein: 0.25, fat: 0.25);
    }
    if (goal.contains('keeping') || goal.contains('fit')) {
      return (carb: 0.45, protein: 0.25, fat: 0.30);
    }

    return (carb: 0.45, protein: 0.25, fat: 0.30);
  }

  bool _looksLikeLegacyMacroSplit(
    double carb,
    double protein,
    double fat,
    double targetCalo,
  ) {
    if (targetCalo <= 0) return false;

    final carbRatio = (carb * 4) / targetCalo;
    final proteinRatio = (protein * 4) / targetCalo;
    final fatRatio = (fat * 9) / targetCalo;

    return (carbRatio - 0.50).abs() <= 0.06 &&
        (proteinRatio - 0.20).abs() <= 0.05 &&
        (fatRatio - 0.30).abs() <= 0.06;
  }

  void _applyGoalBasedMacroTargets(
    double calories,
    Map<String, dynamic>? user,
  ) {
    final ratios = _macroRatiosForGoal(user);
    final normalizedCalories = calories > 0 ? calories : _defaultTargetCalo;

    _targetCarb = (normalizedCalories * ratios.carb) / 4;
    _targetProtein = (normalizedCalories * ratios.protein) / 4;
    _targetFat = (normalizedCalories * ratios.fat) / 9;
  }

  double _resolveProfileDailyTarget(dynamic user) {
    if (user is! Map) {
      return _defaultTargetCalo > 0 ? _defaultTargetCalo : 1200;
    }

    final safeUser = Map<String, dynamic>.from(user);

    // Source of truth: calories recommended by onboarding goal calculation.
    final target = _normalizeDailyTarget(safeUser['targetCalo']);
    final maintenance = _normalizeDailyTarget(safeUser['maintenanceCalo']);
    final tdee = _normalizeDailyTarget(safeUser['tdee']);

    if (target > 0) return target;
    if (maintenance > 0) return maintenance;
    if (tdee > 0) return tdee;

    return _defaultTargetCalo > 0 ? _defaultTargetCalo : 1200;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  // --- HÀM 1: CẬP NHẬT GIAO DIỆN (HÀM PHỤ TRỢ) ---
  bool _updateStateWithData(Map<String, dynamic> data) {
    if (!mounted) return false;

    bool migratedLegacyTarget = false;

    setState(() {
      final savedTargetCalo = _normalizeDailyTarget(data['targetCalo']);
      final savedTargetCarb = (data['targetCarb'] as num?)?.toDouble() ?? 0;
      final savedTargetProtein =
          (data['targetProtein'] as num?)?.toDouble() ?? 0;
      final savedTargetFat = (data['targetFat'] as num?)?.toDouble() ?? 0;

      // Migrate dữ liệu cũ: trước đây target mặc định luôn bị lưu là 1200.
      final isLegacyDefault =
          savedTargetCalo > 0 &&
          savedTargetCalo == widget.initialCalo &&
          _defaultTargetCalo != widget.initialCalo;

      if (isLegacyDefault) {
        migratedLegacyTarget = true;
      }

      // Profile-calculated target is the source of truth for daily calories.
      _targetCalo = _defaultTargetCalo > 0
          ? _defaultTargetCalo
          : ((savedTargetCalo > 0 && !isLegacyDefault)
                ? savedTargetCalo
                : widget.initialCalo);

      final shouldRecalculateMacros =
          savedTargetCarb <= 0 ||
          savedTargetProtein <= 0 ||
          savedTargetFat <= 0 ||
          _looksLikeLegacyMacroSplit(
            savedTargetCarb,
            savedTargetProtein,
            savedTargetFat,
            _targetCalo,
          );

      if (shouldRecalculateMacros) {
        _applyGoalBasedMacroTargets(_targetCalo, _profileUser);
      } else {
        _targetCarb = savedTargetCarb;
        _targetProtein = savedTargetProtein;
        _targetFat = savedTargetFat;
      }
      _waterAnimatedFrom = _waterIntake;
      _waterIntake = (data['waterIntake'] as num?)?.toDouble() ?? 0;

      _breakfastFoods = _asMapList(data['breakfast']);
      _lunchFoods = _asMapList(data['lunch']);
      _snackFoods = _asMapList(data['snack']);
      _dinnerFoods = _asMapList(data['dinner']);
      _exerciseList = _asMapList(data['exercise']);
    });

    return migratedLegacyTarget;
  }

  // --- HÀM 2: TẢI DỮ LIỆU THÔNG MINH (LOCAL + CLOUD) ---
  Future<void> _loadDailyData() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');

    // Luôn ưu tiên nguồn cloud cho ngày hôm nay để tránh lệch state với Home.
    if (userId != null && userId.isNotEmpty) {
      final latest = await DiaryService.loadLatestDiary(
        userId: userId,
        date: _selectedDate,
        preferCloudForToday: true,
      );

      if (latest != null) {
        final migrated = _updateStateWithData(latest);
        if (migrated) {
          await _saveDailyData();
        }
        return;
      }
    }

    // BƯỚC 3: NẾU MÂY CŨNG TRỐNG NỐT -> TẠO NGÀY MỚI TRẮNG TINH
    if (!mounted) return;

    setState(() {
      _targetCalo = _defaultTargetCalo;
      _applyGoalBasedMacroTargets(_targetCalo, _profileUser);
      _waterIntake = 0;

      _breakfastFoods = [];
      _lunchFoods = [];
      _snackFoods = [];
      _dinnerFoods = [];
      _exerciseList = [];
    });
  }

  Map<String, dynamic> _buildDiarySnapshot({double? waterOverride}) {
    return {
      'targetCalo': _targetCalo,
      'targetCarb': _targetCarb,
      'targetProtein': _targetProtein,
      'targetFat': _targetFat,
      'waterIntake': waterOverride ?? _waterIntake,
      'breakfast': _breakfastFoods,
      'lunch': _lunchFoods,
      'snack': _snackFoods,
      'dinner': _dinnerFoods,
      'exercise': _exerciseList,
    };
  }

  Future<bool> _saveDailyData({bool syncToCloud = true}) async {
    final snapshot = _buildDiarySnapshot();
    final prefs = await SharedPreferences.getInstance();
    final realUserId = prefs.getString('userId');
    if (realUserId == null || realUserId.isEmpty) {
      return false;
    }

    await DiaryService.saveLocalDiary(
      userId: realUserId,
      date: _selectedDate,
      diaryData: snapshot,
    );

    if (!syncToCloud) return true;

    return DiaryService.syncDiaryPayload(
      userId: realUserId,
      date: _selectedDate,
      payload: snapshot,
    );
  }

  String _mealLabel(String key) {
    switch (key) {
      case 'Breakfast':
        return 'diary.breakfast'.tr();
      case 'Lunch':
        return 'diary.lunch'.tr();
      case 'Dinner':
        return 'diary.dinner'.tr();
      case 'Snack':
        return 'diary.snack'.tr();
      case 'Exercise':
        return 'diary.exercise'.tr();
      default:
        return key;
    }
  }

  String _trSafe(
    String key,
    String fallback, {
    Map<String, String>? namedArgs,
  }) {
    final translated = key.tr(namedArgs: namedArgs ?? <String, String>{});
    if (translated != key) return translated;

    String resolvedFallback = fallback;
    if (namedArgs != null) {
      namedArgs.forEach((String name, String value) {
        resolvedFallback = resolvedFallback.replaceAll('{$name}', value);
      });
    }
    return resolvedFallback;
  }

  String _diaryItemKey(String mealType, int index, Map<String, dynamic> food) {
    final String name = (food['name'] ?? '').toString();
    final String amount = (food['amount'] ?? '').toString();
    return '$mealType::$index::$name::$amount';
  }

  bool _isDiaryItemProcessing(String key) {
    return _processingDiaryItemKeys.contains(key);
  }

  void _setDiaryItemProcessing(String key, bool isProcessing) {
    if (!mounted) return;

    setState(() {
      if (isProcessing) {
        _processingDiaryItemKeys.add(key);
      } else {
        _processingDiaryItemKeys.remove(key);
      }
    });
  }

  Future<bool> _deleteFood(String mealType, int index) async {
    bool deleted = false;
    setState(() {
      if (mealType == "Breakfast" && index < _breakfastFoods.length) {
        _breakfastFoods.removeAt(index);
        deleted = true;
      } else if (mealType == "Lunch" && index < _lunchFoods.length) {
        _lunchFoods.removeAt(index);
        deleted = true;
      } else if (mealType == "Snack" && index < _snackFoods.length) {
        _snackFoods.removeAt(index);
        deleted = true;
      } else if (mealType == "Dinner" && index < _dinnerFoods.length) {
        _dinnerFoods.removeAt(index);
        deleted = true;
      } else if (mealType == "Exercise" && index < _exerciseList.length) {
        _exerciseList.removeAt(index);
        deleted = true;
      }
    });

    if (!deleted) {
      return false;
    }

    return _saveDailyData();
  }

  Future<bool> _confirmDeleteFood(String mealType, String foodName) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(_trSafe('diary.delete_item_title', 'Xóa bản ghi')),
          content: Text(
            _trSafe(
              'diary.delete_item_confirm',
              'Bạn có chắc chắn muốn xóa {name} khỏi mục {meal}?',
              namedArgs: <String, String>{
                'name': foodName,
                'meal': _mealLabel(mealType),
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_trSafe('common.cancel', 'Hủy')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                _trSafe('common.delete', 'Xóa'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _showFoodActions(
    String mealType,
    int index,
    Map<String, dynamic> food,
  ) async {
    final String itemKey = _diaryItemKey(mealType, index, food);

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext bottomSheetContext) {
        final bool isProcessing = _isDiaryItemProcessing(itemKey);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text(_trSafe('common.edit', 'Sửa')),
                enabled: !isProcessing,
                onTap: isProcessing
                    ? null
                    : () {
                        Navigator.of(bottomSheetContext).pop();
                        _showEditFoodDialog(
                          mealType,
                          index,
                          food,
                          itemKey: itemKey,
                        );
                      },
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: Text(
                  _trSafe('common.delete', 'Xóa'),
                  style: const TextStyle(color: Colors.red),
                ),
                enabled: !isProcessing,
                onTap: isProcessing
                    ? null
                    : () async {
                        Navigator.of(bottomSheetContext).pop();
                        final bool confirmed = await _confirmDeleteFood(
                          mealType,
                          food['name']?.toString() ?? '-',
                        );
                        if (!confirmed) return;

                        _setDiaryItemProcessing(itemKey, true);
                        try {
                          final bool synced = await _deleteFood(
                            mealType,
                            index,
                          );

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                synced
                                    ? _trSafe(
                                        'diary.delete_success',
                                        'Đã xóa bản ghi.',
                                      )
                                    : _trSafe(
                                        'diary.delete_failed',
                                        'Xóa bản ghi thất bại.',
                                      ),
                              ),
                            ),
                          );
                        } finally {
                          _setDiaryItemProcessing(itemKey, false);
                        }
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditFoodDialog(
    String mealType,
    int index,
    Map<String, dynamic> food, {
    required String itemKey,
  }) {
    List<String> amountParts = food['amount'].toString().split(" ");
    String oldAmountStr = amountParts.isNotEmpty ? amountParts[0] : "100";
    String unit = amountParts.length > 1 ? amountParts[1] : "Gr";

    TextEditingController controller = TextEditingController(
      text: oldAmountStr,
    );

    ModalEffects.showScaleFadeDialog(
      context: context,
      builder: (dialogContext) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                _trSafe(
                  'diary.edit_item_title',
                  'Sửa: {name}',
                  namedArgs: <String, String>{
                    'name': food['name']?.toString() ?? '-',
                  },
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _trSafe(
                    'diary.edit_amount_label',
                    'Nhập định lượng mới',
                  ),
                  suffixText: unit,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(
                    _trSafe('common.cancel', 'Hủy'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _greenColor,
                    elevation: 0,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          double oldVal = double.tryParse(oldAmountStr) ?? 1.0;
                          double newVal =
                              double.tryParse(controller.text) ?? oldVal;

                          if (!(newVal > 0 && oldVal > 0)) {
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                          });
                          _setDiaryItemProcessing(itemKey, true);

                          try {
                            double ratio = newVal / oldVal;
                            setState(() {
                              food['amount'] =
                                  "${newVal.toStringAsFixed(0)} $unit";
                              if (mealType == "Exercise") {
                                food['burnedCalories'] =
                                    (food['burnedCalories'] ?? 0) * ratio;
                              } else {
                                food['kcal'] = (food['kcal'] ?? 0) * ratio;
                                food['carb'] = (food['carb'] ?? 0) * ratio;
                                food['protein'] =
                                    (food['protein'] ?? 0) * ratio;
                                food['fat'] = (food['fat'] ?? 0) * ratio;
                                food['fiber'] = (food['fiber'] ?? 0) * ratio;
                              }
                            });

                            final bool synced = await _saveDailyData();
                            if (!mounted) return;

                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  synced
                                      ? _trSafe(
                                          'diary.edit_save_success',
                                          'Đã cập nhật bản ghi.',
                                        )
                                      : _trSafe(
                                          'diary.edit_save_failed',
                                          'Cập nhật bản ghi thất bại.',
                                        ),
                                ),
                              ),
                            );
                          } finally {
                            _setDiaryItemProcessing(itemKey, false);
                          }
                        },
                  child: Text(
                    _trSafe('common.save', 'Lưu'),
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
          {'key': 'Breakfast', 'icon': Icons.free_breakfast_rounded},
          {'key': 'Lunch', 'icon': Icons.lunch_dining_rounded},
          {'key': 'Dinner', 'icon': Icons.dinner_dining_rounded},
          {'key': 'Snack', 'icon': Icons.icecream_rounded},
          {'key': 'Exercise', 'icon': Icons.fitness_center_rounded},
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
                        _mealLabel(item['key'] as String),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _handleAddFood(item['key'] as String);
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
            'diary.edit_target_title'.tr(namedArgs: {'title': title}),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              suffixText: title.contains('Calo')
                  ? 'diary.kcal_unit'.tr()
                  : 'diary.gram_unit'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'common.cancel'.tr(),
                style: const TextStyle(color: Colors.grey),
              ),
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
        automaticallyImplyLeading: false,
        title: Text('diary.title'.tr(), style: AppTypography.pageTitle),
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
                _buildWaterTrackerCard(),
                const SizedBox(height: 20),
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
    final requiredIntake = (_targetCalo + burnt).clamp(0.0, double.infinity);
    final remaining = (requiredIntake - taken).clamp(0.0, double.infinity);
    final progress = requiredIntake > 0
        ? (taken / requiredIntake).clamp(0.0, 1.0)
        : 0.0;

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
                      Text(
                        'diary.taken'.tr(),
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
                      Text(
                        'diary.burnt'.tr(),
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
              'diary.calorie_target'.tr(),
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
                              'diary.remaining'.tr(),
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

  Future<void> _quickAddWater(double amountMl) async {
    if (_isWaterSyncing) return;

    HapticFeedback.lightImpact();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('auth.relogin_required'.tr())));
      return;
    }

    final previousValue = _waterIntake;
    final nextValue = (previousValue + amountMl).clamp(0, 10000).toDouble();

    setState(() {
      _isWaterSyncing = true;
      _waterAnimatedFrom = previousValue;
      _waterIntake = nextValue;
    });

    try {
      final payload = _buildDiarySnapshot(waterOverride: nextValue);
      final synced = await DiaryService.syncDiaryPayload(
        userId: userId,
        date: _selectedDate,
        payload: payload,
      );

      if (!mounted) return;

      if (!synced) {
        setState(() {
          _waterAnimatedFrom = _waterIntake;
          _waterIntake = previousValue;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('common.retry'.tr())));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _waterAnimatedFrom = _waterIntake;
        _waterIntake = previousValue;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('common.retry'.tr())));
    } finally {
      if (mounted) {
        setState(() {
          _isWaterSyncing = false;
        });
      }
    }
  }

  Widget _buildWaterTrackerCard() {
    final target = _waterTargetMl <= 0 ? 2000 : _waterTargetMl;
    final rawProgress = target > 0 ? _waterIntake / target : 0.0;
    final progress = rawProgress.clamp(0.0, 1.0);
    final isOverTarget = rawProgress > 1.0;
    final progressColor = isOverTarget
        ? const Color(0xFFFF7043)
        : const Color(0xFF29B6F6);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_rounded, color: Color(0xFF4FC3F7)),
              const SizedBox(width: 8),
              Text(
                'home.water_tracker'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_isWaterSyncing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: _waterAnimatedFrom, end: _waterIntake),
            duration: const Duration(milliseconds: 350),
            builder: (context, animatedValue, _) {
              return Text(
                '${animatedValue.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} ml',
                style: const TextStyle(fontWeight: FontWeight.w600),
              );
            },
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE3F2FD),
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(rawProgress * 100).toStringAsFixed(0)}% ${'home.goal'.tr()}',
            style: TextStyle(
              fontSize: 12,
              color: isOverTarget ? const Color(0xFFBF360C) : Colors.grey[600],
            ),
          ),
          if (isOverTarget) ...[
            const SizedBox(height: 4),
            Text(
              'home.over_target'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFBF360C),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isWaterSyncing ? null : () => _quickAddWater(250),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE3F2FD),
                    foregroundColor: const Color(0xFF0277BD),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '+ 250ml',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isWaterSyncing ? null : () => _quickAddWater(500),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE3F2FD),
                    foregroundColor: const Color(0xFF0277BD),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '+ 500ml',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
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
        leading: const SizedBox(width: 24),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        collapsedBackgroundColor: bgColor,
        backgroundColor: _macroBgColor.withOpacity(0.35),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: SizedBox(
          width: double.infinity,
          child: Text(
            _mealLabel(title),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
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
                    "${_trSafe('diary.total_energy', 'Tổng năng lượng')}: ${mealTotalCalo.toStringAsFixed(1)} Kcal",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _trSafe('diary.table_name', 'Tên'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _trSafe('diary.table_gram', 'Gram'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _trSafe('diary.table_kcal', 'Kcal'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _trSafe('diary.table_carb', 'Carb'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _trSafe('diary.table_protein', 'Protein'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _trSafe('diary.table_fat', 'Fat'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),
                  ],
                ),
                const SizedBox(height: 12),
                if (foods.isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _trSafe('diary.no_data', 'Chưa có dữ liệu'),
                      style: const TextStyle(color: Colors.black45),
                    ),
                  )
                else
                  ...foods.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> food = entry.value;
                    final String itemKey = _diaryItemKey(title, index, food);
                    final bool isItemProcessing = _isDiaryItemProcessing(
                      itemKey,
                    );

                    return Container(
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
                              (food['fat'] ?? 0.0).toDouble().toStringAsFixed(
                                1,
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          SizedBox(
                            width: 28,
                            child: IconButton(
                              onPressed: isItemProcessing
                                  ? null
                                  : () => _showFoodActions(title, index, food),
                              icon: isItemProcessing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.more_vert_rounded,
                                      size: 18,
                                    ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              splashRadius: 18,
                            ),
                          ),
                        ],
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
