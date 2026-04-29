import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'add_expense_screen.dart';
import 'services/expense_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final Color _primaryGreen = const Color(0xFF65B362);
  final Color _bgColor = const Color(0xFFF4F8F4);

  final NumberFormat _currencyFormat = NumberFormat('#,###', 'en_US');

  final Map<String, _ExpenseCategoryMeta> _categoryMeta = const {
    'Food & Drink': _ExpenseCategoryMeta(
      icon: Icons.restaurant_rounded,
      color: Color(0xFFEF8A5B),
    ),
    'Shopping': _ExpenseCategoryMeta(
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFF6C8CFF),
    ),
    'Transport': _ExpenseCategoryMeta(
      icon: Icons.directions_car_rounded,
      color: Color(0xFF4DA3FF),
    ),
    'Bills': _ExpenseCategoryMeta(
      icon: Icons.receipt_long_rounded,
      color: Color(0xFF9C6BFF),
    ),
    'Health': _ExpenseCategoryMeta(
      icon: Icons.favorite_rounded,
      color: Color(0xFFFF6B8B),
    ),
    'Entertainment': _ExpenseCategoryMeta(
      icon: Icons.movie_rounded,
      color: Color(0xFFFFB84D),
    ),
    'Education': _ExpenseCategoryMeta(
      icon: Icons.school_rounded,
      color: Color(0xFF4BBE9A),
    ),
    'Others': _ExpenseCategoryMeta(
      icon: Icons.grid_view_rounded,
      color: Color(0xFF8A98A8),
    ),
  };

  bool _isLoading = true;
  int _monthlyBudget = 10000000;
  String _currentUserId = '';
  List<ExpenseModel> _expenses = [];
  final Set<String> _processingExpenseIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final userId = (prefs.getString('userId') ?? '').trim();

    if (!mounted) return;

    if (userId.isEmpty) {
      setState(() {
        _expenses = [];
        _monthlyBudget = 10000000;
        _isLoading = false;
      });
      return;
    }

    final results = await Future.wait([
      ExpenseService.fetchExpenses(userId),
      ExpenseService.fetchMonthlyBudget(userId),
    ]);

    final expenses = results[0] as List<ExpenseModel>;
    final monthlyBudget = results[1] as int;

    if (!mounted) return;

    setState(() {
      _currentUserId = userId;
      _expenses = expenses;
      _monthlyBudget = monthlyBudget;
      _isLoading = false;
    });
  }

  String _formatCurrency(num value) {
    return '${_currencyFormat.format(value)} VNĐ';
  }

  String _expenseUiKey(ExpenseModel expense) {
    final String id = expense.id?.trim() ?? '';
    if (id.isNotEmpty) return id;
    return '${expense.userId}_${expense.date.millisecondsSinceEpoch}_${expense.category}_${expense.amount}';
  }

  bool _isExpenseProcessing(ExpenseModel expense) {
    return _processingExpenseIds.contains(_expenseUiKey(expense));
  }

  void _setExpenseProcessing(ExpenseModel expense, bool isProcessing) {
    if (!mounted) return;

    final String key = _expenseUiKey(expense);
    setState(() {
      if (isProcessing) {
        _processingExpenseIds.add(key);
      } else {
        _processingExpenseIds.remove(key);
      }
    });
  }

  String _trWithFallback(
    String key,
    String fallback, {
    Map<String, String>? namedArgs,
  }) {
    final String translated = key.tr(
      namedArgs: namedArgs ?? <String, String>{},
    );
    if (translated != key) {
      return translated;
    }

    String resolvedFallback = fallback;
    if (namedArgs != null) {
      namedArgs.forEach((String name, String value) {
        resolvedFallback = resolvedFallback.replaceAll('{$name}', value);
      });
    }
    return resolvedFallback;
  }

  String formatCompactCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)} Tr';
    }

    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)} K';
    }

    return amount.toStringAsFixed(0);
  }

  double get _totalExpense =>
      _expenses.fold<double>(0, (sum, expense) => sum + expense.amount);

  double get _remainingBudget =>
      (_monthlyBudget - _totalExpense).clamp(0, _monthlyBudget.toDouble());

  Future<Map<String, dynamic>> _saveMonthlyBudget(int newBudget) async {
    final result = await ExpenseService.updateMonthlyBudget(
      _currentUserId,
      newBudget,
    );

    if (!mounted) return {'success': false, 'message': 'Màn hình đã đóng'};

    if (result['success'] == true) {
      setState(() {
        _monthlyBudget = newBudget;
      });
      return {'success': true, 'message': 'Cập nhật ngân sách thành công!'};
    }

    return {
      'success': false,
      'message': result['message']?.toString() ?? 'Vui lòng thử lại!',
    };
  }

  Future<void> _showEditBudgetDialog() async {
    if (_currentUserId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('auth.relogin_required'.tr())));
      return;
    }

    final controller = TextEditingController(
      text: _currencyFormat.format(_monthlyBudget),
    );
    bool isFormatting = false;

    void formatBudgetInput() {
      if (isFormatting) return;

      final rawDigits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (rawDigits.isEmpty) return;

      final parsed = int.tryParse(rawDigits);
      if (parsed == null) return;

      final formatted = _currencyFormat.format(parsed);
      if (controller.text == formatted) return;

      isFormatting = true;
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      isFormatting = false;
    }

    controller.addListener(formatBudgetInput);

    int? newBudget;

    newBudget = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('expense.update_budget_title'.tr()),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'expense.update_budget_hint'.tr(),
              suffixText: 'VND',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = int.tryParse(
                  controller.text.replaceAll(RegExp(r'[^0-9]'), ''),
                );

                if (parsed == null || parsed < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('expense.budget_invalid'.tr())),
                  );
                  return;
                }

                Navigator.pop(dialogContext, parsed);
              },
              child: Text('common.save'.tr()),
            ),
          ],
        );
      },
    );

    if (newBudget == null) return;

    final result = await _saveMonthlyBudget(newBudget);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ??
              (result['success'] == true
                  ? 'Cập nhật ngân sách thành công!'
                  : 'Vui lòng thử lại!'),
        ),
      ),
    );
  }

  Map<String, double> get _expensesByCategory {
    final Map<String, double> grouped = {};
    for (final expense in _expenses) {
      grouped[expense.category] =
          (grouped[expense.category] ?? 0) + expense.amount;
    }
    return grouped;
  }

  List<MapEntry<String, double>> get _categoryEntries {
    final entries = _expensesByCategory.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  _ExpenseCategoryMeta _metaForCategory(String category) {
    return _categoryMeta[category] ??
        const _ExpenseCategoryMeta(
          icon: Icons.grid_view_rounded,
          color: Color(0xFF8A98A8),
        );
  }

  String _translateCategory(String category) {
    switch (category) {
      case 'Food & Drink':
        return 'expense.food_drink'.tr();
      case 'Transport':
        return 'expense.transport'.tr();
      case 'Shopping':
        return 'expense.shopping'.tr();
      case 'Bills':
        return 'expense.bills'.tr();
      case 'Health':
        return 'expense.health'.tr();
      case 'Entertainment':
        return 'expense.entertainment'.tr();
      case 'Education':
        return 'expense.education'.tr();
      case 'Others':
        return 'expense.others'.tr();
      default:
        return category;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  double _percentageForCategory(double value) {
    if (_totalExpense <= 0) return 0;
    return (value / _totalExpense) * 100;
  }

  List<PieChartSectionData> _buildPieSections() {
    final entries = _categoryEntries;
    if (entries.isEmpty) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 1,
          title: '',
          radius: 46,
        ),
      ];
    }

    return List.generate(entries.length, (index) {
      final entry = entries[index];
      final percent = _percentageForCategory(entry.value);
      final meta = _metaForCategory(entry.key);

      return PieChartSectionData(
        color: meta.color,
        value: entry.value,
        title: percent >= 8 ? '${percent.toStringAsFixed(0)}%' : '',
        radius: 48,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    });
  }

  Future<void> _openAddExpense() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
    );

    if (result == true && mounted) {
      await _loadExpenses();
    }
  }

  Future<bool> _confirmDeleteExpense(ExpenseModel expense) async {
    if (expense.id == null || expense.id!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _trWithFallback(
              'expense.delete_invalid',
              'Không thể xóa bản ghi này.',
            ),
          ),
        ),
      );
      return false;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(_trWithFallback('expense.delete_title', 'Xóa chi tiêu')),
          content: Text(
            _trWithFallback(
              'expense.delete_confirm',
              'Bạn có chắc chắn muốn xóa giao dịch {category}?',
              namedArgs: <String, String>{
                'category': _translateCategory(expense.category),
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_trWithFallback('common.cancel', 'Hủy')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_trWithFallback('common.delete', 'Xóa')),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    if (_currentUserId.trim().isEmpty || expense.id == null) {
      return;
    }

    if (_isExpenseProcessing(expense)) {
      return;
    }

    final bool confirmed = await _confirmDeleteExpense(expense);
    if (!confirmed || !mounted) {
      return;
    }

    _setExpenseProcessing(expense, true);
    try {
      final Map<String, dynamic> result = await ExpenseService.deleteExpense(
        expense.id!,
        _currentUserId,
      );

      if (!mounted) {
        return;
      }

      if (result['success'] == true) {
        await _loadExpenses();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _trWithFallback('expense.delete_success', 'Đã xóa chi tiêu.'),
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _trWithFallback('expense.delete_failed', 'Xóa chi tiêu thất bại.'),
          ),
        ),
      );
    } finally {
      _setExpenseProcessing(expense, false);
    }
  }

  Future<void> _showEditExpenseDialog(ExpenseModel expense) async {
    if (expense.id == null || expense.id!.trim().isEmpty) {
      return;
    }

    final TextEditingController amountController = TextEditingController(
      text: expense.amount.toStringAsFixed(0),
    );
    final TextEditingController noteController = TextEditingController(
      text: expense.note,
    );

    String selectedCategory = expense.category;
    DateTime selectedDate = expense.date;
    bool isSubmitting = false;
    final String processingKey = _expenseUiKey(expense);

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                _trWithFallback('expense.edit_title', 'Sửa chi tiêu'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _trWithFallback(
                          'expense.amount_label',
                          'Số tiền',
                        ),
                        hintText: _trWithFallback(
                          'expense.amount_hint',
                          'Nhập số tiền',
                        ),
                        suffixText: 'VNĐ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _categoryMeta.containsKey(selectedCategory)
                          ? selectedCategory
                          : 'Others',
                      items: _categoryMeta.keys
                          .map(
                            (String key) => DropdownMenuItem<String>(
                              value: key,
                              child: Text(_translateCategory(key)),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedCategory = value;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: _trWithFallback(
                          'expense.category',
                          'Danh mục',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _trWithFallback('expense.note', 'Ghi chú'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final DateTime now = DateTime.now();
                        final DateTime firstDate = DateTime(now.year - 5);
                        final DateTime lastDate = DateTime(now.year + 1);
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: firstDate,
                          lastDate: lastDate,
                        );

                        if (pickedDate == null) return;

                        setDialogState(() {
                          selectedDate = pickedDate;
                        });
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: _trWithFallback('expense.date', 'Ngày'),
                          border: const OutlineInputBorder(),
                        ),
                        child: Text(_formatDate(selectedDate)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(_trWithFallback('common.cancel', 'Hủy')),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final double? parsedAmount = double.tryParse(
                            amountController.text.trim().replaceAll(
                              RegExp(r'[^0-9.]'),
                              '',
                            ),
                          );

                          if (parsedAmount == null || parsedAmount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _trWithFallback(
                                    'expense.invalid_amount',
                                    'Số tiền không hợp lệ',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                          });

                          if (mounted) {
                            setState(() {
                              _processingExpenseIds.add(processingKey);
                            });
                          }

                          try {
                            final Map<String, dynamic> result =
                                await ExpenseService.updateExpense(
                                  expenseId: expense.id!,
                                  userId: _currentUserId,
                                  amount: parsedAmount,
                                  category: selectedCategory,
                                  note: noteController.text,
                                  date: selectedDate,
                                );

                            if (!mounted) {
                              return;
                            }

                            if (result['success'] == true) {
                              Navigator.of(dialogContext).pop();
                              await _loadExpenses();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _trWithFallback(
                                      'expense.update_success',
                                      'Cập nhật chi tiêu thành công!',
                                    ),
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              isSubmitting = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result['message']?.toString() ??
                                      _trWithFallback(
                                        'expense.update_failed',
                                        'Cập nhật chi tiêu thất bại.',
                                      ),
                                ),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                _processingExpenseIds.remove(processingKey);
                              });
                            }
                          }
                        },
                  child: Text(_trWithFallback('common.save', 'Lưu')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showExpenseActions(ExpenseModel expense) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext bottomSheetContext) {
        final bool isProcessing = _isExpenseProcessing(expense);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text(_trWithFallback('common.edit', 'Sửa')),
                enabled: !isProcessing,
                onTap: isProcessing
                    ? null
                    : () {
                        Navigator.of(bottomSheetContext).pop();
                        _showEditExpenseDialog(expense);
                      },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_rounded,
                  color: Color(0xFFE53935),
                ),
                title: Text(
                  _trWithFallback('common.delete', 'Xóa'),
                  style: const TextStyle(color: Color(0xFFE53935)),
                ),
                enabled: !isProcessing,
                onTap: isProcessing
                    ? null
                    : () {
                        Navigator.of(bottomSheetContext).pop();
                        _deleteExpense(expense);
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _expenses.isNotEmpty;
    final sections = _buildPieSections();

    return Scaffold(
      backgroundColor: _bgColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpense,
        backgroundColor: _primaryGreen,
        elevation: 0,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'expense.add_transaction'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _primaryGreen,
          onRefresh: _loadExpenses,
          child: _isLoading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.75,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF65B362),
                        ),
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 18),
                      _buildSummaryCards(),
                      const SizedBox(height: 18),
                      _buildChartCard(sections, hasData),
                      const SizedBox(height: 18),
                      _buildListCard(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryGreen, _primaryGreen.withOpacity(0.82)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primaryGreen.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'expense.title'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'expense.total_expense'.tr(),
            value: _formatCurrency(_totalExpense),
            icon: Icons.payments_rounded,
            color: const Color(0xFFEF8A5B),
            backgroundColor: const Color(0xFFFFF3EC),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'expense.remaining_budget'.tr(),
            value: _formatCurrency(_remainingBudget),
            icon: Icons.savings_rounded,
            color: const Color(0xFF4BBE9A),
            backgroundColor: const Color(0xFFEAF9F4),
            isClickable: true,
            showEditHint: true,
            onTap: _showEditBudgetDialog,
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard(List<PieChartSectionData> sections, bool hasData) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Text(
            'expense.chart_by_category'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: hasData
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 52,
                          sections: sections,
                          pieTouchData: PieTouchData(enabled: true),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 112,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formatCompactCurrency(_totalExpense),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'expense.total'.tr(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : _buildEmptyChartState(),
          ),
          const SizedBox(height: 24),
          if (hasData) _buildChartLegend(),
        ],
      ),
    );
  }

  Widget _buildEmptyChartState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Text(
          'expense.no_data'.tr(),
          style: const TextStyle(
            color: Colors.black45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildChartLegend() {
    final entries = _categoryEntries.take(4).toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: entries.map((entry) {
        final meta = _metaForCategory(entry.key);
        return _LegendChip(
          label: _translateCategory(entry.key),
          value: _formatCurrency(entry.value),
          color: meta.color,
          percent: _percentageForCategory(entry.value),
        );
      }).toList(),
    );
  }

  Widget _buildListCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'expense.expense_list'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'expense.item_count'.tr(
                  namedArgs: {'count': _expenses.length.toString()},
                ),
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_expenses.isEmpty)
            _buildEmptyListState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _expenses.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final expense = _expenses[index];
                final meta = _metaForCategory(expense.category);
                final bool isItemProcessing = _isExpenseProcessing(expense);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E9E2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: meta.color.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(meta.icon, color: meta.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _translateCategory(expense.category),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              expense.note.isNotEmpty
                                  ? expense.note
                                  : _trWithFallback(
                                      'expense.no_note',
                                      'Không có ghi chú',
                                    ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDate(expense.date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(expense.amount),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          IconButton(
                            onPressed: isItemProcessing
                                ? null
                                : () => _showExpenseActions(expense),
                            icon: isItemProcessing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.more_vert_rounded),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            visualDensity: VisualDensity.compact,
                            splashRadius: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyListState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E9E2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            size: 42,
            color: Colors.black38,
          ),
          const SizedBox(height: 10),
          Text(
            _trWithFallback(
              'expense.empty_title',
              'Chưa có khoản chi tiêu nào',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            _trWithFallback(
              'expense.empty_subtitle',
              'Bấm nút thêm chi tiêu để tạo dữ liệu đầu tiên.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCategoryMeta {
  final IconData icon;
  final Color color;

  const _ExpenseCategoryMeta({required this.icon, required this.color});
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final bool isClickable;
  final bool showEditHint;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.onTap,
    this.isClickable = false,
    this.showEditHint = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: isClickable ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (showEditHint)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.edit, size: 16, color: Color(0xFFBDBDBD)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final String value;
  final double percent;
  final Color color;

  const _LegendChip({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E9E2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Text(
                '$value • ${percent.toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.black54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
