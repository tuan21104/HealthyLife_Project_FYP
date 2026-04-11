import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/expense_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final Color _primaryGreen = const Color(0xFF65B362);
  final Color _softGreen = const Color(0xFFEAF6E7);
  final Color _cardColor = const Color(0xFFF7FAF8);

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isFormattingAmount = false;
  bool _isSaving = false;
  bool _isLocaleReady = false;

  int _amountValue = 0;
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  String _currentUserId = '';

  final List<_ExpenseCategoryItem> _categories = const [
    _ExpenseCategoryItem(
      title: 'Food & Drink',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFEF8A5B),
    ),
    _ExpenseCategoryItem(
      title: 'Shopping',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFF6C8CFF),
    ),
    _ExpenseCategoryItem(
      title: 'Transport',
      icon: Icons.directions_car_rounded,
      color: Color(0xFF4DA3FF),
    ),
    _ExpenseCategoryItem(
      title: 'Bills',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFF9C6BFF),
    ),
    _ExpenseCategoryItem(
      title: 'Health',
      icon: Icons.favorite_rounded,
      color: Color(0xFFFF6B8B),
    ),
    _ExpenseCategoryItem(
      title: 'Entertainment',
      icon: Icons.movie_rounded,
      color: Color(0xFFFFB84D),
    ),
    _ExpenseCategoryItem(
      title: 'Education',
      icon: Icons.school_rounded,
      color: Color(0xFF4BBE9A),
    ),
    _ExpenseCategoryItem(
      title: 'Others',
      icon: Icons.grid_view_rounded,
      color: Color(0xFF8A98A8),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = null;
    _selectedDate = DateTime.now();
    _amountController.addListener(_handleAmountChanged);
    _initializeLocale();
    _loadUserId();
  }

  @override
  void dispose() {
    _amountController.removeListener(_handleAmountChanged);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocale() async {
    try {
      await initializeDateFormatting('vi_VN', null);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLocaleReady = true;
      });
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentUserId = (prefs.getString('userId') ?? '').trim();
    });
  }

  void _handleAmountChanged() {
    if (_isFormattingAmount) return;

    final rawDigits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final parsedValue = rawDigits.isEmpty ? 0 : int.tryParse(rawDigits) ?? 0;
    final formattedText = rawDigits.isEmpty
        ? ''
        : NumberFormat('#,###', 'vi_VN').format(parsedValue);

    _amountValue = parsedValue;

    if (_amountController.text == formattedText) {
      if (mounted) setState(() {});
      return;
    }

    _isFormattingAmount = true;
    _amountController.value = TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
    _isFormattingAmount = false;

    if (mounted) setState(() {});
  }

  String _formatSelectedDate(DateTime date) {
    try {
      if (_isLocaleReady) {
        return DateFormat('d MMMM', 'vi_VN').format(date);
      }
    } catch (_) {}
    return DateFormat('d MMMM').format(date);
  }

  String _formatAmountDisplay(int value) {
    if (value <= 0) return '0';
    return NumberFormat('#,###', 'vi_VN').format(value);
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày chi tiêu',
      confirmText: 'Chọn',
      cancelText: 'Hủy',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryGreen,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (pickedDate != null && mounted) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _openCategorySheet() async {
    final chosenCategory = await ModalBottomSheetHelper.showCategoryPicker(
      context: context,
      categories: _categories,
      selectedCategory: _selectedCategory,
    );

    if (chosenCategory != null && mounted) {
      setState(() {
        _selectedCategory = chosenCategory;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (_isSaving) return;

    print('==== [AddExpense] Save pressed ====');
    print(
      '==== [AddExpense] userId=$_currentUserId, amount=$_amountValue, category=$_selectedCategory, date=$_selectedDate ====',
    );

    if (_currentUserId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập lại!')));
      return;
    }

    if (_amountValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ!')),
      );
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn danh mục!')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final expense = ExpenseModel(
      userId: _currentUserId,
      amount: _amountValue.toDouble(),
      category: _selectedCategory!,
      note: _noteController.text.trim(),
      date: _selectedDate,
    );

    final result = await ExpenseService.addExpense(expense);
    final bool success = result['success'] == true;
    final String message = (result['message']?.toString() ?? '').trim();

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã thêm thành công!')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isNotEmpty ? message : 'Vui lòng thử lại!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseDateLabel = _formatSelectedDate(_selectedDate);
    final amountText = _amountValue > 0
        ? '${_formatAmountDisplay(_amountValue)}đ'
        : '0đ';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: false,
        title: const Text(
          'Add Expense',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF4F8F4), Color(0xFFEAF6E7)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _softGreen,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.payments_rounded,
                                color: _primaryGreen,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Thêm chi tiêu mới',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Nhập số tiền, chọn danh mục và lưu lại nhanh chóng.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Số tiền',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E9E2)),
                          ),
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 8,
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: _primaryGreen,
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 0,
                                minHeight: 0,
                              ),
                              suffixText: 'đ',
                              suffixStyle: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Hiển thị: $amountText',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _ActionRow(
                          icon: Icons.calendar_month_rounded,
                          iconColor: const Color(0xFF4DA3FF),
                          title: 'Ngày tháng',
                          value: expenseDateLabel,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 14),
                        _ActionRow(
                          icon: Icons.category_rounded,
                          iconColor: const Color(0xFFEF8A5B),
                          title: 'Danh mục',
                          value: _selectedCategory ?? 'Chọn danh mục',
                          isPlaceholder: _selectedCategory == null,
                          onTap: _openCategorySheet,
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E9E2)),
                          ),
                          child: TextField(
                            controller: _noteController,
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              hintText: 'Ghi chú',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(18),
                              prefixIcon: Icon(Icons.edit_note_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        disabledBackgroundColor: _primaryGreen.withOpacity(
                          0.65,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Lưu',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isSaving)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: Colors.black.withOpacity(0.06)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpenseCategoryItem {
  final String title;
  final IconData icon;
  final Color color;

  const _ExpenseCategoryItem({
    required this.title,
    required this.icon,
    required this.color,
  });
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onTap,
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7FAF8),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E9E2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isPlaceholder ? Colors.grey : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class ModalBottomSheetHelper {
  static Future<String?> showCategoryPicker({
    required BuildContext context,
    required List<_ExpenseCategoryItem> categories,
    required String? selectedCategory,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Chọn danh mục',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Chọn một nhóm phù hợp cho khoản chi tiêu này.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categories.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.65,
                        ),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = category.title == selectedCategory;

                      return Material(
                        color: isSelected
                            ? category.color.withOpacity(0.14)
                            : const Color(0xFFF7FAF8),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.pop(context, category.title),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? category.color
                                    : const Color(0xFFE2E9E2),
                                width: isSelected ? 1.6 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: category.color.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    category.icon,
                                    color: category.color,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        category.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isSelected
                                            ? 'Đang chọn'
                                            : 'Chạm để chọn',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? category.color
                                              : Colors.black45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
