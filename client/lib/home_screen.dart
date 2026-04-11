import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'ask_me_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'shop_screen.dart';
import 'custom_page_route.dart';
import 'expense_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color _greenColor = const Color(0xFF4CAF50);
  final Color _lightGreenColor = const Color(0xFFE8F5E9);
  final Color _bgColor = const Color(0xFFF8F9FA);

  bool _isLoading = true;
  bool _isFetched = false;
  String _userName = "User";
  double targetCalo = 1800;
  double currentCaloTaken = 0;
  double currentBurned = 0;
  double currentExpense = 0;
  String? _userAvatarUrl;
  int? _avatarIndex;
  List<double> weeklyCalo = [0, 0, 0, 0, 0, 0, 0];
  List<double> weeklyExpense = [0, 0, 0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _fetchRealData();
  }

  Future<void> _fetchRealData() async {
    if (_isFetched && !_isLoading) return;
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');

    if (userId != null && userId.isNotEmpty) {
      print("==== 🔄 REFRESHING DATA FOR: $userId ====");

      // Gọi song song cả Profile và Statistics để tối ưu tốc độ
      final results = await Future.wait([
        AuthService.getUserProfile(),
        AuthService.getHomeStatistics(userId),
      ]).timeout(const Duration(seconds: 10));

      final userProfile = results[0];
      final statsData = results[1];

      if (mounted) {
        setState(() {
          // 1. Cập nhật tên từ Profile
          if (userProfile != null && userProfile['user'] != null) {
            _userName = userProfile['user']['name'] ?? "User";
          }

          // 2. Cập nhật thông số từ Statistics
          if (statsData != null) {
            targetCalo = (statsData['targetCalo'] ?? 1800).toDouble();
            currentCaloTaken = (statsData['todayCalo'] ?? 0).toDouble();
            currentBurned = (statsData['todayBurned'] ?? 0).toDouble();
            currentExpense = (statsData['todayExpense'] ?? 0).toDouble();
            _userAvatarUrl = statsData['avatarUrl'];
            _avatarIndex = statsData['avatarIndex'] != null
                ? (statsData['avatarIndex'] as num).toInt()
                : null;

            weeklyCalo = (statsData['weeklyCalo'] as List)
                .map((e) => (e as num).toDouble())
                .toList();
            weeklyExpense = (statsData['weeklyExpense'] as List)
                .map((e) => (e as num).toDouble())
                .toList();
          }
          _isLoading = false;
          _isFetched = true;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: Center(child: CircularProgressIndicator(color: _greenColor)),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _isFetched = false;
            await _fetchRealData();
          },
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
                _buildHeader(),
                const SizedBox(height: 24),
                _buildSummaryCard(),
                const SizedBox(height: 32),
                const Text(
                  "Weekly Health Overview",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildCalorieChart(),
                const SizedBox(height: 32),
                const Text(
                  "Weekly Expense Trend",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildExpenseChart(),
                const SizedBox(height: 32),
                _buildActionButtons(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String todayStr = DateFormat('EEEE, dd MMMM').format(DateTime.now());
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _greenColor, width: 2),
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: ClipOval(
              child: (_userAvatarUrl != null && _userAvatarUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: _userAvatarUrl!,
                      width: 48,
                      height: 48,
                      memCacheWidth: 100,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(strokeWidth: 2),
                      errorWidget: (context, url, error) =>
                          _buildPlaceholderIcon(),
                    )
                  : _buildPlaceholderIcon(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hello, $_userName!",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                todayStr,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.smart_toy, color: _greenColor, size: 32),
        ),
      ],
    );
  }

  Widget _buildPlaceholderIcon() {
    if (_avatarIndex != null) {
      return Image.asset(
        'assets/images/avatar_${_avatarIndex! + 1}.png',
        width: 48,
        height: 48,
        fit: BoxFit.cover,
      );
    }
    return const Icon(Icons.person, color: Colors.grey, size: 30);
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatColumn(
            "EXPENSE",
            "₫${(currentExpense / 1000).toStringAsFixed(0)}k",
          ),
          _buildProgressCircle(),
          _buildStatColumn("BURNED", currentBurned.toStringAsFixed(0)),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildProgressCircle() {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: targetCalo > 0
                ? (currentCaloTaken / targetCalo).clamp(0.0, 1.0)
                : 0,
            strokeWidth: 10,
            backgroundColor: _lightGreenColor,
            valueColor: AlwaysStoppedAnimation<Color>(_greenColor),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currentCaloTaken.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "kcal taken",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieChart() {
    double maxCalo = weeklyCalo.reduce((a, b) => a > b ? a : b);
    if (maxCalo < 2500) maxCalo = 2500;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxCalo,
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  DateTime targetDate = DateTime.now().subtract(
                    Duration(days: 6 - value.toInt()),
                  );
                  List<String> days = [
                    'CN',
                    'T2',
                    'T3',
                    'T4',
                    'T5',
                    'T6',
                    'T7',
                  ];
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      days[targetDate.weekday % 7],
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            7,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: weeklyCalo[i],
                  color: i == 6 ? _greenColor : _lightGreenColor,
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseChart() {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) => val % 3 == 0
                    ? Text(
                        ['Mon', 'Thu', 'Sun'][(val / 3).toInt()],
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                7,
                (i) => FlSpot(i.toDouble(), weeklyExpense[i] / 1000),
              ),
              isCurved: true,
              color: _greenColor,
              barWidth: 4,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: _greenColor.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. ACTION BUTTONS (Đã đổi Log Meal -> Shopping)
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildQuickButton(
          Icons.shopping_bag_outlined,
          "Shopping",
          onTap: () {
            // Chuyển sang trang Shop
            Navigator.push(context, CustomPageRoute(page: const ShopScreen()));
          },
        ),
        _buildQuickButton(
          Icons.account_balance_wallet_outlined,
          "Add Expense",
          onTap: () {
            Navigator.push(
              context,
              CustomPageRoute(page: const ExpenseScreen()),
            );
          },
        ),
        _buildQuickButton(
          Icons.auto_awesome_outlined,
          "AI Chat",
          onTap: () {
            Navigator.push(context, CustomPageRoute(page: const AskMeScreen()));
          },
        ),
      ],
    );
  }

  // Cập nhật hàm helper để nhận sự kiện GestureDetector
  Widget _buildQuickButton(
    IconData icon,
    String label, {
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _greenColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _greenColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
