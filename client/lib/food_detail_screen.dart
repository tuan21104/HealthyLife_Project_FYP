import 'package:flutter/material.dart';

class FoodDetailScreen extends StatefulWidget {
  final String mealType;
  final Map<String, dynamic> foodData;

  const FoodDetailScreen({super.key, required this.mealType, required this.foodData});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  final Color _greenColor = const Color(0xFF65B362);
  final Color _borderColor = const Color(0xFFD3E7F0);

  String _selectedUnit = "Gr";
  final TextEditingController _amountController = TextEditingController(text: "195");

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      setState(() {}); // Tính toán realtime khi gõ
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String foodName = widget.foodData['name'] ?? 'Unknown';
    final num baseCal = widget.foodData['calories'] ?? 0;
    final num baseCarb = widget.foodData['carbs'] ?? 0;
    final num baseProtein = widget.foodData['protein'] ?? 0;
    final num baseFat = widget.foodData['fat'] ?? 0;
    // Database hiện tại chưa có Fiber, ta tạm gán bằng 0 hoặc tỷ lệ nhỏ
    final num baseFiber = widget.foodData['fiber'] ?? (baseCarb * 0.1); 

    double inputAmount = double.tryParse(_amountController.text) ?? 0.0;
    
    // TÍNH TOÁN HỆ SỐ NHÂN THEO ĐƠN VỊ
    double multiplier = 1.0;
    if (_selectedUnit == "dl") multiplier = 100.0;
    else if (_selectedUnit == "Tbl Spoon") multiplier = 15.0;
    else if (_selectedUnit == "Serving (130gr)") multiplier = 130.0;

    double totalGrams = inputAmount * multiplier;
    double ratio = totalGrams / 100.0;

    double energy = baseCal * ratio;
    double carb = baseCarb * ratio;
    double protein = baseProtein * ratio;
    double fat = baseFat * ratio;
    double fiber = baseFiber * ratio;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Text("Add ${widget.mealType}", style: const TextStyle(color: Colors.black54, fontSize: 28)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.do_not_disturb_on_outlined, color: Colors.grey[600], size: 24),
                  const SizedBox(width: 12),
                  Expanded(child: Text(foodName, style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w500))),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(border: Border.all(color: _borderColor, width: 1.5), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    _buildAmountRow(),
                    _buildDivider(),
                    _buildNutrientRow("Energy", "${energy.toStringAsFixed(1)} Kcal", isBold: true),
                    _buildDivider(),
                    _buildNutrientRow("Carb", "${carb.toStringAsFixed(1)} gr"),
                    _buildDivider(),
                    _buildNutrientRow("Proteins", "${protein.toStringAsFixed(1)} gr"),
                    _buildDivider(),
                    _buildNutrientRow("Fiber", "${fiber.toStringAsFixed(1)} gr"),
                    _buildDivider(),
                    _buildNutrientRow("Fat", "${fat.toStringAsFixed(1)} gr"),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // NÚT LƯU - ĐÓNG GÓI DỮ LIỆU GỬI VỀ TRANG TRƯỚC
              _buildActionButton("Add to Diary", _greenColor, () {
                Map<String, dynamic> addedItem = {
                  'name': foodName,
                  'amount': '${inputAmount.toStringAsFixed(0)} $_selectedUnit',
                  'kcal': energy,
                  'carb': carb,
                  'protein': protein,
                  'fat': fat,
                  'fiber': fiber,
                };
                Navigator.pop(context, addedItem); // Gửi gói hàng về trang Search
              }),
              const SizedBox(height: 16),
              _buildActionButton("Cancel", _greenColor, () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Giữ nguyên các hàm _buildAmountRow, _buildNutrientRow, _buildDivider, _buildActionButton, _showUnitPickerModal như cũ)
  
  // (Tôi viết lại _buildAmountRow để khớp với logic)
  Widget _buildAmountRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          const SizedBox(width: 80, child: Text("Amount", style: TextStyle(color: Colors.black54, fontSize: 14))),
          Expanded(
            child: TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
              style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
            ),
          ),
          GestureDetector(
            onTap: _showUnitPickerModal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _borderColor.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Text(_selectedUnit, style: const TextStyle(color: Color(0xFF5A9B58), fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF5A9B58)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14))),
          Expanded(child: Text(value, style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }
  Widget _buildDivider() => Divider(color: _borderColor, thickness: 1, height: 1);
  Widget _buildActionButton(String title, Color bgColor, VoidCallback onPressed) {
    return SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: onPressed, style: ElevatedButton.styleFrom(backgroundColor: bgColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))));
  }

  void _showUnitPickerModal() {
    String tempSelectedUnit = _selectedUnit; 
    final units = ["Gr", "dl", "Tbl Spoon", "Serving (130gr)"];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Unit", style: TextStyle(fontSize: 20, color: Colors.black54)),
                      TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey, size: 20), label: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 16))),
                    ],
                  ),
                  const Divider(),
                  ...units.map((unit) => RadioListTile<String>(title: Text(unit, style: const TextStyle(color: Colors.black54)), value: unit, groupValue: tempSelectedUnit, activeColor: _greenColor, onChanged: (String? value) => setModalState(() => tempSelectedUnit = value!))),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: () { setState(() => _selectedUnit = tempSelectedUnit); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: _greenColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text("OK", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)))),
                  const SizedBox(height: 16), 
                ],
              ),
            );
          },
        );
      },
    );
  }
}