import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'services/diary_service.dart';
import 'ask_me_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'shop_screen.dart';
import 'custom_page_route.dart';
import 'expense_screen.dart';
import 'core/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final int refreshSignal;

  const HomeScreen({super.key, this.refreshSignal = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color _greenColor = const Color(0xFF4CAF50);
  final Color _lightGreenColor = const Color(0xFFE8F5E9);
  final Color _bgColor = const Color(0xFFF8F9FA);
  final NumberFormat _vndFormat = NumberFormat('#,###', 'en_US');
  Locale? _currentLocale;

  bool _isLoading = true;
  bool _isFetched = false;
  String _userName = 'home.user_fallback'.tr();
  double targetCalo = 1800;
  double currentCaloTaken = 0;
  double currentBurned = 0;
  double currentExpense = 0;
  double currentWaterIntake = 0;
  double _waterAnimatedFrom = 0;
  double waterTargetMl = 2000;
  bool _isWaterSyncing = false;
  String? _userAvatarUrl;
  int? _avatarIndex;
  List<double> weeklyCalo = [0, 0, 0, 0, 0, 0, 0];
  List<double> weeklyBurned = [0, 0, 0, 0, 0, 0, 0];
  List<double> weeklyWater = [0, 0, 0, 0, 0, 0, 0];
  List<double> weeklyExpense = [0, 0, 0, 0, 0, 0, 0];

  List<double> _safeWeeklyList(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      final mapped = raw.map((e) => (e is num) ? e.toDouble() : 0.0).toList();
      if (mapped.length == 7) return mapped;
    }
    return List<double>.filled(7, 0);
  }

  @override
  void initState() {
    super.initState();
    _fetchRealData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLocale = context.locale;
    if (_currentLocale == null) {
      _currentLocale = newLocale;
      return;
    }

    if (_currentLocale != newLocale && mounted) {
      _currentLocale = newLocale;
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _isFetched = false;
      _fetchRealData();
    }
  }

  Future<void> _fetchRealData() async {
    if (_isFetched && !_isLoading) return;
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');

    if (userId != null && userId.isNotEmpty) {
      try {
        print("==== 🔄 REFRESHING DATA FOR: $userId ====");

        // Gọi song song Profile + Statistics + Diary để tránh lệch water state.
        final results = await Future.wait([
          AuthService.getUserProfile(),
          AuthService.getHomeStatistics(userId),
          DiaryService.loadLatestDiary(
            userId: userId,
            date: DateTime.now(),
            preferCloudForToday: true,
          ),
        ]).timeout(const Duration(seconds: 10));

        final userProfile = results[0] as Map<String, dynamic>?;
        final statsData = results[1] as Map<String, dynamic>?;
        final latestDiary = results[2] as Map<String, dynamic>?;

        final diaryWater = (latestDiary?['waterIntake'] as num?)?.toDouble();
        final statsWater = ((statsData?['todayWater'] ?? 0) as num).toDouble();
        final resolvedWater = (diaryWater != null && diaryWater >= 0)
            ? diaryWater
            : statsWater;

        if (mounted) {
          setState(() {
            // 1. Cập nhật tên từ Profile
            if (userProfile != null && userProfile['user'] != null) {
              _userName =
                  userProfile['user']['name'] ?? 'home.user_fallback'.tr();

              final weight = (userProfile['user']['weight'] as num?)
                  ?.toDouble();
              if (weight != null && weight > 0) {
                waterTargetMl = weight * 35;
              }
            }

            // 2. Cập nhật thông số từ Statistics
            if (statsData != null) {
              targetCalo = ((statsData['targetCalo'] ?? 1800) as num)
                  .roundToDouble();
              currentCaloTaken = ((statsData['todayCalo'] ?? 0) as num)
                  .roundToDouble();
              currentBurned = ((statsData['todayBurned'] ?? 0) as num)
                  .roundToDouble();
              currentExpense = ((statsData['todayExpense'] ?? 0) as num)
                  .roundToDouble();
              waterTargetMl =
                  ((statsData['waterTargetMl'] ?? waterTargetMl) as num)
                      .roundToDouble();
              _userAvatarUrl = statsData['avatarUrl'];
              _avatarIndex = statsData['avatarIndex'] != null
                  ? (statsData['avatarIndex'] as num).toInt()
                  : null;

              weeklyCalo = _safeWeeklyList(statsData['weeklyCalo']);
              weeklyBurned = _safeWeeklyList(statsData['weeklyBurned']);
              weeklyWater = _safeWeeklyList(statsData['weeklyWater']);
              weeklyExpense = _safeWeeklyList(statsData['weeklyExpense']);
            }

            final nextWater = resolvedWater.roundToDouble();
            _waterAnimatedFrom = currentWaterIntake;
            currentWaterIntake = nextWater;
            if (weeklyWater.isNotEmpty && weeklyWater[6] < nextWater) {
              weeklyWater[6] = nextWater;
            }

            _isLoading = false;
            _isFetched = true;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
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
                const SizedBox(height: 16),
                _buildWaterTrackerCard(),
                const SizedBox(height: 32),
                Text(
                  'home.weekly_health'.tr(),
                  style: AppTypography.sectionTitle,
                ),
                const SizedBox(height: 16),
                _buildCalorieChart(),
                const SizedBox(height: 32),
                Text(
                  'home.weekly_expense'.tr(),
                  style: AppTypography.sectionTitle,
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
    String todayStr = DateFormat(
      'EEEE, dd MMMM',
      context.locale.toLanguageTag(),
    ).format(DateTime.now());
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
                "${'home.hello'.tr()}, $_userName!",
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
      child: SizedBox(
        height: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(child: _buildProgressCircle()),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: _buildStatColumn(
                      'home.expense_short'.tr(),
                      "${_vndFormat.format(currentExpense)} VNĐ",
                    ),
                  ),
                ),
                const SizedBox(width: 120),
                Expanded(
                  child: Center(
                    child: _buildStatColumn(
                      'home.burned_short'.tr(),
                      currentBurned.toStringAsFixed(0),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    String label,
    String value, {
    CrossAxisAlignment align = CrossAxisAlignment.center,
    TextAlign textAlign = TextAlign.center,
  }) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: textAlign,
          maxLines: 2,
          softWrap: true,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                Text(
                  'home.kcal_taken'.tr(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
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
    double maxBurned = weeklyBurned.reduce((a, b) => a > b ? a : b);
    double maxWater = weeklyWater.reduce((a, b) => a > b ? a : b);
    if (maxBurned > maxCalo) maxCalo = maxBurned;
    if (maxWater > maxCalo) maxCalo = maxWater;
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
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final dayIndex = group.x.toInt();
                final dayLabel = _weekdayShortLabel(
                  _chartDateForIndex(dayIndex),
                );
                final isTaken = rodIndex == 0;
                final isBurned = rodIndex == 1;
                final value = isTaken
                    ? weeklyCalo[dayIndex]
                    : isBurned
                    ? weeklyBurned[dayIndex]
                    : weeklyWater[dayIndex];
                final localizedTitle = isTaken
                    ? 'home.intake_short'.tr()
                    : isBurned
                    ? 'home.burned_short'.tr()
                    : 'home.water_short'.tr();
                final unit = isBurned || isTaken ? 'kcal' : 'ml';

                return BarTooltipItem(
                  '$dayLabel\n$localizedTitle: ${value.toStringAsFixed(0)} $unit',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final dayIndex = value.toInt();
                  if (dayIndex < 0 || dayIndex > 6) {
                    return const SizedBox.shrink();
                  }

                  final targetDate = _chartDateForIndex(dayIndex);
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      _weekdayShortLabel(targetDate),
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
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: weeklyCalo[i],
                  color: i == 6 ? _greenColor : _lightGreenColor,
                  width: 8,
                  borderRadius: BorderRadius.circular(6),
                ),
                BarChartRodData(
                  toY: weeklyBurned[i],
                  color: const Color(0xFFFFA726),
                  width: 8,
                  borderRadius: BorderRadius.circular(6),
                ),
                BarChartRodData(
                  toY: weeklyWater[i],
                  color: const Color(0xFF4FC3F7),
                  width: 8,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          ),
        ),
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

    final previousValue = currentWaterIntake;
    final nextValue = (previousValue + amountMl).clamp(0, 10000).toDouble();

    setState(() {
      _isWaterSyncing = true;
      _waterAnimatedFrom = previousValue;
      currentWaterIntake = nextValue;
      if (weeklyWater.isNotEmpty) {
        weeklyWater[6] = nextValue;
      }
    });

    final synced = await AuthService.syncWaterIntakeForToday(
      userId: userId,
      waterIntake: nextValue,
    );

    if (!mounted) return;

    if (!synced) {
      setState(() {
        _waterAnimatedFrom = currentWaterIntake;
        currentWaterIntake = previousValue;
        if (weeklyWater.isNotEmpty) {
          weeklyWater[6] = previousValue;
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('common.retry'.tr())));
    } else {
      await DiaryService.updateLocalWaterIntake(
        userId: userId,
        date: DateTime.now(),
        waterIntake: nextValue,
      );
    }

    setState(() {
      _isWaterSyncing = false;
    });
  }

  Widget _buildWaterTrackerCard() {
    final target = waterTargetMl <= 0 ? 2000 : waterTargetMl;
    final rawProgress = target > 0 ? currentWaterIntake / target : 0.0;
    final progress = rawProgress.clamp(0.0, 1.0);
    final isOverTarget = rawProgress > 1.0;
    final progressColor = isOverTarget
        ? const Color(0xFFFF7043)
        : const Color(0xFF29B6F6);
    final progressTextColor = isOverTarget
        ? const Color(0xFFBF360C)
        : Colors.grey[600];

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_rounded, color: Color(0xFF4FC3F7)),
              const SizedBox(width: 8),
              Text(
                'home.water_tracker'.tr(),
                style: AppTypography.sectionTitle.copyWith(fontSize: 16),
              ),
              const Spacer(),
              if (_isWaterSyncing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: _waterAnimatedFrom, end: currentWaterIntake),
            duration: const Duration(milliseconds: 350),
            builder: (context, animatedValue, child) {
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
            style: TextStyle(fontSize: 12, color: progressTextColor),
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
                child: _buildWaterQuickButton(
                  label: '+ 250ml',
                  onTap: () => _quickAddWater(250),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildWaterQuickButton(
                  label: '+ 500ml',
                  onTap: () => _quickAddWater(500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaterQuickButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: _isWaterSyncing ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE3F2FD),
        foregroundColor: const Color(0xFF0277BD),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildExpenseChart() {
    double maxExpense = weeklyExpense.reduce((a, b) => a > b ? a : b);
    if (maxExpense <= 0) maxExpense = 100000;

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
          minY: 0,
          maxY: maxExpense * 1.2,
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final dayIndex = spot.x.toInt();
                  final dayLabel = (dayIndex >= 0 && dayIndex <= 6)
                      ? _weekdayShortLabel(_chartDateForIndex(dayIndex))
                      : '';

                  return LineTooltipItem(
                    '$dayLabel\n${_formatMoney(spot.y)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (val, meta) {
                  final dayIndex = val.toInt();
                  if (dayIndex < 0 || dayIndex > 6) {
                    return const SizedBox.shrink();
                  }

                  final dayLabel = _weekdayShortLabel(
                    _chartDateForIndex(dayIndex),
                  );

                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      dayLabel,
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
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                7,
                (i) => FlSpot(i.toDouble(), weeklyExpense[i]),
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

  String _formatMoney(num value) {
    return '${_vndFormat.format(value.round())} VNĐ';
  }

  DateTime _chartDateForIndex(int index) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: 6 - index));
  }

  String _weekdayShortLabel(DateTime date) {
    final days = [
      'home.sun_short'.tr(),
      'home.mon_short'.tr(),
      'home.tue_short'.tr(),
      'home.wed_short'.tr(),
      'home.thu_short'.tr(),
      'home.fri_short'.tr(),
      'home.sat_short'.tr(),
    ];
    return days[date.weekday % 7];
  }

  // 5. ACTION BUTTONS (Đã đổi Log Meal -> Shopping)
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildQuickButton(
          Icons.shopping_bag_outlined,
          'shop.title'.tr(),
          onTap: () {
            // Chuyển sang trang Shop
            Navigator.push(context, CustomPageRoute(page: const ShopScreen()));
          },
        ),
        _buildQuickButton(
          Icons.account_balance_wallet_outlined,
          'expense.add_transaction'.tr(),
          onTap: () {
            Navigator.push(
              context,
              CustomPageRoute(page: const ExpenseScreen()),
            ).then((_) async {
              _isFetched = false;
              await _fetchRealData();
            });
          },
        ),
        _buildQuickButton(
          Icons.auto_awesome_outlined,
          'ai_chat.title'.tr(),
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
