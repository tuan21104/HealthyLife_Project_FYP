import 'package:flutter/material.dart';
import 'dart:math';
import 'target_weight_screen.dart';

class BmiCalculationScreen extends StatefulWidget {
  final double heightCm;
  final double weightKg;

  const BmiCalculationScreen({
    super.key,
    required this.heightCm,
    required this.weightKg,
  });

  @override
  State<BmiCalculationScreen> createState() => _BmiCalculationScreenState();
}

class _BmiCalculationScreenState extends State<BmiCalculationScreen> {
  late double bmi;
  late String status;
  late double diffWeight;
  late String diffLabel;

  @override
  void initState() {
    super.initState();
    _calculateBMI();
  }

  void _calculateBMI() {
    // Đổi cm sang m
    double heightM = widget.heightCm / 100;

    // Tính BMI: Cân nặng / (Chiều cao bình phương)
    bmi = widget.weightKg / pow(heightM, 2);

    // Mốc tính cân nặng lý tưởng
    double maxNormalWeight = 24.9 * pow(heightM, 2);
    double minNormalWeight = 18.5 * pow(heightM, 2);

    if (bmi < 18.5) {
      status = "Underweight";
      diffWeight = minNormalWeight - widget.weightKg;
      diffLabel = "Your Underweight";
    } else if (bmi <= 24.9) {
      status = "Normal";
      diffWeight = 0;
      diffLabel = "Difference";
    } else if (bmi <= 29.9) {
      status = "Overweight";
      diffWeight = widget.weightKg - maxNormalWeight;
      diffLabel = "Your Overweight";
    } else {
      status = "Obese";
      diffWeight = widget.weightKg - maxNormalWeight;
      diffLabel = "Your Overweight";
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color highlightColor = const Color(0xFF80CBC4);

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TIÊU ĐỀ
              const Text(
                "Your Calculation",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 50),

              // 2. BẢNG KẾT QUẢ
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildTableRow(
                      "Your Height",
                      "${widget.heightCm.toStringAsFixed(0)} cm",
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE0E0E0),
                    ),
                    _buildTableRow(
                      "Your Weight",
                      "${widget.weightKg.toStringAsFixed(0)} kg",
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE0E0E0),
                    ),
                    _buildTableRow(
                      "Your BMI",
                      "${bmi.toStringAsFixed(1)}($status)",
                      isHighlight: true,
                      highlightColor: highlightColor,
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE0E0E0),
                    ),
                    _buildTableRow(
                      diffLabel,
                      diffWeight > 0
                          ? "${diffWeight.toStringAsFixed(1)} kg"
                          : "Perfect",
                      isHighlight: true,
                      highlightColor: highlightColor,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Center(
                child: Text(
                  "We need your target weight and time",
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TargetWeightScreen(
                          // ĐÃ SỬA: Truyền số liệu từ màn hình này sang màn hình Target
                          currentHeight: widget.heightCm,
                          currentWeight: widget.weightKg,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Your Target",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              Center(
                child: Image.asset('assets/images/logo_green.png', height: 60),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow(
    String label,
    String value, {
    bool isHighlight = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: isHighlight ? highlightColor : Colors.grey[600],
              fontWeight: isHighlight ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: isHighlight ? highlightColor : Colors.black87,
              fontWeight: isHighlight ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
