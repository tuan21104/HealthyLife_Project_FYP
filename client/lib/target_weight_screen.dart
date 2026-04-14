import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math';
import 'congratulations_screen.dart';
import 'services/auth_service.dart';
import 'modal_effects.dart';

class TargetWeightScreen extends StatefulWidget {
  final double currentHeight;
  final double currentWeight;

  const TargetWeightScreen({
    super.key,
    required this.currentHeight,
    required this.currentWeight,
  });

  @override
  State<TargetWeightScreen> createState() => _TargetWeightScreenState();
}

class _TargetWeightScreenState extends State<TargetWeightScreen> {
  final TextEditingController _targetWeightController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();

  late double _minHealthyWeight;
  late double _maxHealthyWeight;
  late double _suggestedWeightLoss;
  late int _suggestedDays;
  late bool _isLosing;

  // Lưu trữ dữ liệu tải về từ DB
  Map<String, dynamic>? _userData;
  bool _isLoadingData = true;

  String _trSafe(String key, {required String vi, required String en}) {
    final translated = key.tr();
    if (translated != key) return translated;
    return context.locale.languageCode == 'vi' ? vi : en;
  }

  String _trSafeNamed(
    String key, {
    required Map<String, String> namedArgs,
    required String vi,
    required String en,
  }) {
    final translated = key.tr(namedArgs: namedArgs);
    if (translated != key) return translated;
    final template = context.locale.languageCode == 'vi' ? vi : en;
    var resolved = template;
    namedArgs.forEach((k, v) {
      resolved = resolved.replaceAll('{$k}', v);
    });
    return resolved;
  }

  @override
  void initState() {
    super.initState();
    _calculateSuggestions();
    _fetchMedicalData();
  }

  // HÀM KÉO DỮ LIỆU TỪ MONGODB
  Future<void> _fetchMedicalData() async {
    final result = await AuthService.getUserProfile();
    if (mounted && result['success'] == true) {
      setState(() {
        _userData = result['user'];
        _isLoadingData = false;
      });
    }
  }

  // HÀM TÍNH TOÁN DẢI CÂN NẶNG & GỢI Ý (Chuẩn WHO)
  void _calculateSuggestions() {
    double heightM = widget.currentHeight / 100;

    _minHealthyWeight = 18.5 * pow(heightM, 2);
    _maxHealthyWeight = 24.9 * pow(heightM, 2);

    if (widget.currentWeight > _maxHealthyWeight) {
      _isLosing = true;
      _suggestedWeightLoss = widget.currentWeight - _maxHealthyWeight;
    } else if (widget.currentWeight < _minHealthyWeight) {
      _isLosing = false;
      _suggestedWeightLoss = _minHealthyWeight - widget.currentWeight;
    } else {
      _isLosing = true;
      _suggestedWeightLoss = 0;
    }

    // Tốc độ chuẩn y khoa: ~0.5kg/tuần (1kg = 14 ngày)
    _suggestedDays = (_suggestedWeightLoss * 14).round();
  }

  // --- BƯỚC 1: KIỂM TRA RÀO CHẮN Y KHOA TRƯỚC ---
  void _checkHealthWarningAndProceed() {
    if (_isLoadingData || _userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _trSafe(
              'onboarding.syncing_medical_data',
              vi: 'Đang đồng bộ dữ liệu y khoa, vui lòng chờ...',
              en: 'Syncing your medical data, please wait...',
            ),
          ),
        ),
      );
      return;
    }

    // Lấy thông số người dùng nhập (Nếu trống thì lấy gợi ý mặc định)
    double defaultTarget =
        widget.currentWeight +
        (_isLosing ? -_suggestedWeightLoss : _suggestedWeightLoss);
    double targetInputWeight =
        double.tryParse(_targetWeightController.text) ?? defaultTarget;
    int days = int.tryParse(_daysController.text) ?? _suggestedDays;

    if (days <= 0) return; // Tránh lỗi chia cho 0

    // Tính tốc độ thay đổi cân nặng (kg/tuần)
    double weightDifference = widget.currentWeight - targetInputWeight;
    double kgPerWeek = (weightDifference.abs() / days) * 7;

    // Nếu ép cân/tăng cân quá nhanh (> 1.0 kg/tuần) -> Bật Pop-up Cảnh báo
    if (kgPerWeek > 1.0) {
      _showWarningDialog(kgPerWeek, () {
        _finalizeAndNavigate(targetInputWeight, days, weightDifference);
      });
    } else {
      // Nếu an toàn -> Đi thẳng đến tính toán Calo và Chuyển trang
      _finalizeAndNavigate(targetInputWeight, days, weightDifference);
    }
  }

  // --- HÀM POP-UP CẢNH BÁO ---
  void _showWarningDialog(double kgPerWeek, VoidCallback onContinue) {
    ModalEffects.showScaleFadeDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              _trSafe(
                'onboarding.medical_warning_title',
                vi: 'Cảnh báo y khoa',
                en: 'Medical Warning',
              ),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          _trSafeNamed(
            'onboarding.medical_warning_message',
            namedArgs: {'kgPerWeek': kgPerWeek.toStringAsFixed(1)},
            vi: 'Mục tiêu của bạn tương đương việc thay đổi {kgPerWeek} kg/tuần.\n\nTheo chuẩn y tế, tốc độ an toàn tối đa là 1.0 kg/tuần để tránh suy nhược cơ thể hoặc mất cơ. Chuyên gia khuyến nghị bạn nên tăng số ngày hoặc giảm bớt số cân mục tiêu.',
            en: 'Your goal equals a change of {kgPerWeek} kg/week.\n\nAccording to medical standards, the maximum safe rate is 1.0 kg/week to avoid weakness or muscle loss. Experts recommend increasing the number of days or reducing your target weight change.',
          ),
          style: const TextStyle(height: 1.5, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Đóng hộp thoại để sửa số
            child: Text(
              _trSafe(
                'onboarding.edit_goal',
                vi: 'Sửa lại mục tiêu',
                en: 'Edit goal',
              ),
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context); // Đóng hộp thoại
              onContinue(); // Vẫn cho phép đi tiếp nếu người dùng khăng khăng muốn
            },
            child: Text(
              _trSafe(
                'onboarding.continue_anyway',
                vi: 'Vẫn tiếp tục',
                en: 'Continue anyway',
              ),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- BƯỚC 2: TÍNH TOÁN CALO & CHUYỂN TRANG ---
  Future<void> _finalizeAndNavigate(
    double targetInputWeight,
    int days,
    double weightDifference,
  ) async {
    // 1. Tính Tuổi từ BirthDate
    DateTime dob =
        DateTime.tryParse(_userData!['birthDate'] ?? "") ??
        DateTime(2000, 1, 1);
    int age = DateTime.now().year - dob.year;

    // 2. Lấy Giới tính và Mức vận động
    String gender = _userData!['gender'] ?? 'Male';
    String activity = _userData!['activityLevel'] ?? 'Sedentary';

    // 3. Tính BMR
    double bmr =
        (10 * widget.currentWeight) + (6.25 * widget.currentHeight) - (5 * age);
    bmr += (gender == 'Male') ? 5 : -161;

    // 4. Tính TDEE (Calo duy trì)
    double multiplier = 1.2;
    if (activity.contains("Lightly"))
      multiplier = 1.375;
    else if (activity.contains("Moderately"))
      multiplier = 1.55;
    else if (activity.contains("Very"))
      multiplier = 1.725;

    int maintenanceCalo = (bmr * multiplier).round();

    // 5. Tính Calo mục tiêu
    int targetCalo = maintenanceCalo;
    if (days > 0 && weightDifference != 0) {
      double dailyDeficitOrSurplus =
          (weightDifference * 7700) / days; // 1kg mỡ ~ 7700 calo
      targetCalo = maintenanceCalo - dailyDeficitOrSurplus.round();
    }

    // 6. Giới hạn an toàn y khoa về lượng Calo tối thiểu/tối đa
    if (targetCalo < 1200) targetCalo = 1200;
    if (targetCalo > maintenanceCalo + 1000)
      targetCalo = maintenanceCalo + 1000;

    // 7. Lưu mục tiêu lên profile để có thể hiển thị lại ở Profile screen
    await AuthService.updateProfile({
      'targetWeight': targetInputWeight,
      'targetWeightLoss': weightDifference.abs(),
      'durationDays': days,
      'maintenanceCalo': maintenanceCalo,
      'targetCalo': targetCalo,
    });

    // 8. Chuyển trang
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CongratulationsScreen(
          targetWeightLoss: weightDifference.abs(),
          durationDays: days,
          maintenanceCalo: maintenanceCalo,
          targetCalo: targetCalo,
          isLosing: weightDifference >= 0,
          targetWeight: targetInputWeight,
        ),
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _trSafe(
            'onboarding.target_weight_title',
            vi: 'Cân nặng mục tiêu của bạn',
            en: 'Your Target Weight',
          ),
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              Text(
                _trSafe(
                  'onboarding.healthy_weight_range',
                  vi: 'Khoảng cân nặng khỏe mạnh của bạn:',
                  en: 'Your healthy weight range:',
                ),
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              Text(
                "${_minHealthyWeight.toStringAsFixed(1)} - ${_maxHealthyWeight.toStringAsFixed(1)}",
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 40),

              Text(
                _trSafe(
                  'onboarding.our_suggestion',
                  vi: 'Đề xuất của chúng tôi:',
                  en: 'Our Suggestion:',
                ),
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text:
                          '${_trSafe('onboarding.to', vi: 'Để', en: 'To')} ${_isLosing ? _trSafe('onboarding.lose_verb', vi: 'giảm', en: 'lose') : _trSafe('onboarding.gain_verb', vi: 'tăng', en: 'gain')} ',
                    ),
                    TextSpan(
                      text: "${_suggestedWeightLoss.toStringAsFixed(1)} kg ",
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          '${_trSafe('onboarding.in', vi: 'trong', en: 'in')} ',
                    ),
                    TextSpan(
                      text:
                          '$_suggestedDays ${_trSafe('onboarding.days_suffix', vi: 'ngày', en: 'days')}.',
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              Text(
                _trSafe(
                  'onboarding.choose_logical_weight_duration',
                  vi: 'Chọn mức cân nặng và thời gian hợp lý',
                  en: 'Choose a logical weight and duration',
                ),
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),

              _buildInputWithSuffix(
                _trSafe(
                  'onboarding.target_weight_input',
                  vi: 'Cân nặng mục tiêu',
                  en: 'Target Weight',
                ),
                _targetWeightController,
                _trSafe('onboarding.weight_suffix', vi: 'kg', en: 'kg'),
              ),
              const SizedBox(height: 20),
              _buildInputWithSuffix(
                _trSafe(
                  'onboarding.duration_input',
                  vi: 'Trong (ngày)',
                  en: 'During (days)',
                ),
                _daysController,
                _trSafe('onboarding.days_suffix', vi: 'ngày', en: 'days'),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  // ĐÃ SỬA: Gọi hàm kiểm tra Y khoa trước thay vì chuyển trang thẳng
                  onPressed: _checkHealthWarningAndProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoadingData
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _trSafe(
                            'onboarding.lets_see',
                            vi: 'Xem kết quả!',
                            en: "Let's see!",
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

  Widget _buildInputWithSuffix(
    String hint,
    TextEditingController controller,
    String suffix,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
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
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                suffix,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
