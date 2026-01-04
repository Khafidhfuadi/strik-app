import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:strik_app/controllers/statistics_controller.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/widgets/custom_loading_indicator.dart';
import 'package:strik_app/widgets/heatmap_grid.dart';
import 'package:strik_app/screens/habit_detail_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late StatisticsController _controller;
  late PageController _pageController;
  final RxInt _currentIndex = 0.obs;
  bool _isAiCardVisible = true;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(StatisticsController());
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    _currentIndex.value = index;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    _currentIndex.value = index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getDynamicTitle(),
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [_buildFilterButton(), const SizedBox(width: 16)],
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(child: CustomLoadingIndicator());
        }

        final habits = _controller.habits;

        return Column(
          children: [
            // Custom Tab Bar (Home Style)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: 1 + habits.length,
                itemBuilder: (context, index) {
                  return Obx(() {
                    final isSelected = _currentIndex.value == index;
                    String label;
                    if (index == 0) {
                      label = 'Semua';
                    } else {
                      label = habits[index - 1].title;
                    }
                    return GestureDetector(
                      onTap: () => _onTabTapped(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.grey[900]
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? null
                              : Border.all(color: Colors.white12),
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[600],
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  });
                },
              ),
            ),

            const SizedBox(height: 10),

            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _buildOverallTab(),
                  ...habits.map((h) => _buildHabitTab(h)),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildFilterButton() {
    return PopupMenuButton<StatsFilter>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: const Icon(
          Icons.filter_list_rounded,
          size: 20,
          color: Colors.white,
        ),
      ),
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (filter) async {
        if (filter == StatsFilter.custom) {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            builder: (context, child) {
              return Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppTheme.primary,
                    surface: AppTheme.surface,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            _controller.setCustomRange(picked);
          }
        } else {
          _controller.setFilter(filter);
        }
      },
      itemBuilder: (context) => [
        _buildPopupItem(StatsFilter.weekly, 'Mingguan'),
        _buildPopupItem(StatsFilter.monthly, 'Bulanan'),
        _buildPopupItem(StatsFilter.yearly, 'Tahunan'),
        _buildPopupItem(StatsFilter.allTime, 'Sepanjang Masa'),
        _buildPopupItem(StatsFilter.custom, 'Custom Range'),
      ],
    );
  }

  PopupMenuItem<StatsFilter> _buildPopupItem(StatsFilter value, String text) {
    return PopupMenuItem(
      value: value,
      child: Obx(
        () => Row(
          children: [
            Text(text, style: GoogleFonts.plusJakartaSans(color: Colors.white)),
            const Spacer(),
            if (_controller.selectedFilter.value == value)
              const Icon(Icons.check, color: AppTheme.primary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallTab() {
    return Obx(() {
      final completionCount = _controller.globalCompletionCount.value;
      final completionRate = _controller.globalCompletionRate.value;
      final heatmapData = _controller.overallHeatmap;

      final filter = _controller.selectedFilter.value;
      DateTime end = DateTime.now();
      DateTime start;
      switch (filter) {
        case StatsFilter.weekly:
          start = end.subtract(Duration(days: end.weekday - 1));
          break;
        case StatsFilter.monthly:
          start = DateTime(end.year, end.month, 1);
          break;
        case StatsFilter.yearly:
          start = DateTime(end.year, 1, 1);
          break;
        case StatsFilter.custom:
          start =
              _controller.customRange.value?.start ??
              end.subtract(const Duration(days: 7));
          end = _controller.customRange.value?.end ?? end;
          break;
        case StatsFilter.allTime:
          // Show last 1 year for Heatmap View:
          start = end.subtract(const Duration(days: 365));
          break;
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Advisor Section Header & Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Coach Strik AI",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isAiCardVisible = !_isAiCardVisible;
                    });
                  },
                  icon: Icon(
                    _isAiCardVisible
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                  ),
                  tooltip: _isAiCardVisible ? "Sembunyikan" : "Tampilkan",
                ),
              ],
            ),
            const SizedBox(height: 12),

            // AI Advisor Card (Animated Visibility)
            AnimatedSize(
              duration: const Duration(milliseconds: 500),
              curve: Curves.fastOutSlowIn,
              child: _isAiCardVisible
                  ? Column(
                      children: [
                        AIAdvisorCard(controller: _controller),
                        const SizedBox(height: 8), // Extra spacing when visible
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            _buildStatCard(
              'Totalan Kelar',
              '$completionCount',
              'Kali',
              AppTheme.primary,
              description:
                  'Jumlah total kebiasaan yang udah lo kelarin di periode ini. Makin banyak makin GG!',
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              'Persentase',
              '${completionRate.toStringAsFixed(1)}%',
              _getPercentageLabel(completionRate),
              AppTheme.secondary,
              description:
                  'Tingkat kedisiplinan lo. Kalo 100% berarti lo ga pernah skip, Gacor Abis!',
            ),
            const SizedBox(height: 16),

            // Global Insights
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Jam Emas',
                      _controller.goldenHour.value,
                      '',
                      Colors.purpleAccent,
                      description:
                          'Jam dimana lo paling sering nyelesain habit. Waktu produktif lo banget nih!',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Hari Gacor',
                      _controller.bestDay.value,
                      '',
                      Colors.blueAccent,
                      description:
                          'Hari dimana lo paling rajin sikat habis semua habit.',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            _buildRankingSection(),
            const SizedBox(height: 32),

            _buildSectionTitleWithHelp(
              'Jejak Keaktifan',
              'Visualisasi seberapa rajin lo setiap harinya. Kotak yang berwarna nunjukin kalo lo ada progress di hari itu. Makin terang warnanya, makin rajin lo! 🔥',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: HeatmapGrid(
                datasets: heatmapData,
                startDate: start,
                endDate: end,
              ),
            ),

            const SizedBox(height: 32),
            _buildSectionTitleWithHelp(
              _getChartTitle(filter),
              'Grafik batang ini nunjukin performa lo dari waktu ke waktu. Lo bisa liat tren naik turun produktivitas lo disini. 📊',
            ),
            const SizedBox(height: 16),
            Container(
              height: 250,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dataCount = _controller.chartData.length;
                  final chartWidth = _calculateChartWidth(
                    dataCount,
                    constraints.maxWidth,
                  );

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: chartWidth,
                      child: BarChart(
                        BarChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) => _bottomTitles(
                                  val,
                                  meta,
                                  _controller.chartData,
                                ),
                                reservedSize: 30,
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: _generateChartGroups(
                            _controller.chartData,
                          ),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => Colors.transparent,
                              tooltipPadding: EdgeInsets.zero,
                              tooltipMargin: 4,
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      rod.toY.toInt().toString(),
                                      GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildHabitTab(Habit habit) {
    return Obx(() {
      final stats = _controller.getStatsForHabit(habit.id!);
      final heatmapData = _controller.getHeatmapForHabit(habit.id!);

      final filter = _controller.selectedFilter.value;
      DateTime end = DateTime.now();
      DateTime start;
      switch (filter) {
        case StatsFilter.weekly:
          start = end.subtract(Duration(days: end.weekday - 1));
          break;
        case StatsFilter.monthly:
          start = DateTime(end.year, end.month, 1);
          break;
        case StatsFilter.yearly:
          start = DateTime(end.year, 1, 1);
          break;
        case StatsFilter.custom:
          start =
              _controller.customRange.value?.start ??
              end.subtract(const Duration(days: 7));
          end = _controller.customRange.value?.end ?? end;
          break;
        case StatsFilter.allTime:
          start = end.subtract(const Duration(days: 365));
          break;
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Totalan',
                    '${stats['total']}',
                    'Kali',
                    AppTheme.primary,
                    description:
                        'Berapa kali lo lakuin habit ini di periode ini.',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Streak Aktif ',
                    '${stats['currentStreak']}',
                    'Hari',
                    const Color(0xFFFF5757),
                    description:
                        'Streak lo yang lagi jalan sekarang. Gas terooos! 🔥',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              'Rekor Terpanjang',
              '${stats['bestStreak']}',
              'Hari',
              Colors.amber,
              description: 'Streak paling lama yang pernah lo capai. Legend!',
            ),

            const SizedBox(height: 32),
            _buildSectionTitleWithHelp(
              'Jejak Keaktifan',
              'Rekam jejak konsistensi lo buat habit ini. Liat seberapa sering lo lakuin habit ini dalam rentang waktu tertentu. 📅',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: HeatmapGrid(
                datasets: heatmapData,
                startDate: start,
                endDate: end,
                baseColor: Color(
                  int.parse(habit.color.replaceAll('#', '0xFF')),
                ),
              ),
            ),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  'grafik lain coming soon...',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surface,
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Get.to(() => HabitDetailScreen(habit: habit)),
                child: Text(
                  'Lihat Detail Kebiasaan',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatCard(
    String label,
    String value,
    String sub,
    Color color, {
    String? description,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (description != null)
                GestureDetector(
                  onTap: () {
                    Get.dialog(
                      Dialog(
                        backgroundColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                description,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  onPressed: () => Get.back(),
                                  child: Text(
                                    'Paham!',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.question_mark_rounded,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: GoogleFonts.spaceGrotesk(
                    color: color,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  sub,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getChartTitle(StatsFilter filter) {
    switch (filter) {
      case StatsFilter.weekly:
        return 'Performa Minggu Ini';
      case StatsFilter.monthly:
        return 'Performa Bulan Ini';
      case StatsFilter.yearly:
        return 'Performa Tahun Ini';
      case StatsFilter.allTime:
        return 'Performa Sepanjang Masa';
      case StatsFilter.custom:
        return 'Performa Periode Ini';
    }
  }

  double _calculateChartWidth(int dataCount, double maxWidth) {
    if (dataCount <= 7) return maxWidth;
    return (dataCount * 45.0).clamp(maxWidth, 2000.0);
  }

  List<BarChartGroupData> _generateChartGroups(List<ChartDataPoint> data) {
    if (data.isEmpty) return [];

    final maxVal = data
        .map((e) => e.y)
        .reduce((curr, next) => curr > next ? curr : next);
    final isAllZero = maxVal == 0;

    return data.asMap().entries.map((entry) {
      final i = entry.key;
      final point = entry.value;
      final val = point.y;
      final isMax = !isAllZero && val == maxVal;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: val,
            color: isMax
                ? AppTheme.primary
                : AppTheme.primary.withValues(alpha: 0.3),
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: (maxVal == 0 ? 5 : maxVal * 1.2),
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ],
        showingTooltipIndicators: val > 0 ? [0] : [],
      );
    }).toList();
  }

  Widget _bottomTitles(
    double value,
    TitleMeta meta,
    List<ChartDataPoint> data,
  ) {
    const style = TextStyle(
      color: Colors.grey,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    final index = value.toInt();
    if (index < 0 || index >= data.length) return const SizedBox();

    // Safety check mostly for hot reload

    return SideTitleWidget(
      meta: meta,
      space: 4,
      child: Text(data[index].label, style: style),
    );
  }

  Widget _buildRankingSection() {
    return Obx(() {
      final top3 = _controller.topStreaks;
      if (top3.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Jawara Strik',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Lottie.asset(
                'assets/src/strik-logo.json',
                width: 20,
                height: 20,
                repeat: false,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Rank 2
              if (top3.length >= 2)
                Expanded(child: _buildRankCard(top3[1], 2, Colors.grey[400]!)),
              const SizedBox(width: 12),
              // Rank 1
              if (top3.isNotEmpty)
                Expanded(child: _buildRankCard(top3[0], 1, Colors.amber)),
              const SizedBox(width: 12),
              // Rank 3
              if (top3.length >= 3)
                Expanded(
                  child: _buildRankCard(top3[2], 3, Colors.orange[800]!),
                ),
              if (top3.length < 3) const Expanded(child: SizedBox()),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildRankCard(Map<String, dynamic> data, int rank, Color rankColor) {
    final Habit habit = data['habit'];
    final int streak = data['streak'];
    final bool isFirst = rank == 1;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFirst
              ? rankColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
          width: isFirst ? 2 : 1,
        ),
        boxShadow: isFirst
            ? [
                BoxShadow(
                  color: rankColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              '#$rank',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.bold,
                color: rankColor,
                fontSize: isFirst ? 16 : 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            habit.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$streak',
                style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.primary,
                  fontSize: isFirst ? 24 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.local_fire_department_rounded,
                color: AppTheme.primary,
                size: isFirst ? 20 : 16,
              ),
            ],
          ),
          Text(
            'Hari',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white30,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitleWithHelp(String title, String description) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            Get.dialog(
              Dialog(
                backgroundColor: AppTheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Get.back(),
                          child: Text(
                            'Paham!',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: const Icon(
              Icons.question_mark_rounded,
              size: 12,
              color: Colors.white54,
            ),
          ),
        ),
      ],
    );
  }

  String _getDynamicTitle() {
    final filter = _controller.selectedFilter.value;
    final start = _controller.displayedStart.value;
    final end = _controller.displayedEnd.value;

    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final shortMonths = [
      'jan',
      'feb',
      'mar',
      'apr',
      'mei',
      'jun',
      'jul',
      'agu',
      'sep',
      'okt',
      'nov',
      'des',
    ];

    switch (filter) {
      case StatsFilter.weekly:
        if (start.month == end.month) {
          return 'WRAPPED Mingguan (${start.day}-${end.day} ${shortMonths[start.month - 1]})';
        } else {
          return 'WRAPPED Mingguan (${start.day} ${shortMonths[start.month - 1]} - ${end.day} ${shortMonths[end.month - 1]})';
        }
      case StatsFilter.monthly:
        return 'WRAPPED ${months[start.month - 1]} (1-${end.day})';
      case StatsFilter.yearly:
        return 'WRAPPED ${start.year} (1 ${shortMonths[0]}-hari ini)';
      case StatsFilter.allTime:
        return 'WRAPPED Sepanjang Masaa~';
      case StatsFilter.custom:
        return 'WRAPPED ${start.day} ${shortMonths[start.month - 1]} - ${end.day} ${shortMonths[end.month - 1]}';
    }
  }

  String _getPercentageLabel(double rate) {
    if (rate >= 100) return 'Perfectoo! 💯';
    if (rate >= 80) return 'Gacor Abiss! 🔥';
    if (rate >= 60) return 'Mantapp! 👍';
    if (rate >= 40) return 'Gas Teruss! 🚀';
    if (rate > 0) return 'Yuu Bisa Yukk! 💪';
    return 'Mulai Aja Dulu 🌱';
  }
}

class AIAdvisorCard extends StatefulWidget {
  final StatisticsController controller;

  const AIAdvisorCard({super.key, required this.controller});

  @override
  State<AIAdvisorCard> createState() => _AIAdvisorCardState();
}

class _AIAdvisorCardState extends State<AIAdvisorCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rainbowController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rainbowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rainbowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isGenerating = widget.controller.isGeneratingAI.value;
      final insight = widget.controller.aiInsight.value;

      return AnimatedBuilder(
        animation: Listenable.merge([_rainbowController, _pulseController]),
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.black, // Dark base
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // LIQUID GRADIENT BACKGROUND (Custom Painter)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: LiquidGradientPainter(
                        animationValue: _rainbowController.value,
                      ),
                    ),
                  ),

                  // Inner Container handling Content & Padding
                  Padding(
                    padding: const EdgeInsets.all(2), // Border width
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(
                          alpha: 0.9,
                        ), // Inner card color
                        borderRadius: BorderRadius.circular(
                          22,
                        ), // slightly smaller radius
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          children: [
                            // Subtle Moving Gradient Background OVERLAY (Inner)
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.3, // Visible but subtle
                                child: CustomPaint(
                                  painter: LiquidGradientPainter(
                                    animationValue:
                                        _rainbowController.value +
                                        0.5, // Offset animation
                                  ),
                                ),
                              ),
                            ),
                            // Existing Content Logic...
                            child!,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Animated Icon
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isGenerating ? _pulseAnimation.value : 1.0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            boxShadow: isGenerating
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primary.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            isGenerating
                                ? Icons.hourglass_top_rounded
                                : Icons.auto_awesome_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Coach Strik AI',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (isGenerating) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (!isGenerating && insight.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      tooltip: "Tanya lagi",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        widget.controller.generateManualInsight();
                      },
                    ),
                ],
              ),

              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: isGenerating
                    ? Row(
                        key: const ValueKey('loading'),
                        children: [
                          Text(
                            "Lagi meracik strategi... 🧠⚡",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      )
                    : insight.isEmpty
                    ? _buildAskButton()
                    : _buildStyledText(insight),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStyledText(String text) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<TextSpan> spans = [];
    // Regex to match **bold** or *bold*
    final RegExp exp = RegExp(r'(\*{1,2})(.*?)(\1)');
    final matches = exp.allMatches(text);

    int lastIndex = 0;
    for (final match in matches) {
      // Add text before the match
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        );
      }

      // Add the bold text (without asterisks)
      spans.add(
        TextSpan(
          text: match.group(2), // The content inside the asterisks
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white, // Pure white for bold
            fontSize: 15,
            fontWeight: FontWeight.bold, // BOLD
            height: 1.6,
          ),
        ),
      );

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 15,
            height: 1.6,
          ),
        ),
      );
    }

    return RichText(
      key: const ValueKey('content'),
      text: TextSpan(children: spans),
    );
  }

  Widget _buildAskButton() {
    return Center(
      child: GestureDetector(
        onTap: () {
          widget.controller.generateManualInsight();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.primary, Colors.purple]),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Tanya Coach Strik",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
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

class LiquidGradientPainter extends CustomPainter {
  final double animationValue;

  LiquidGradientPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()..blendMode = BlendMode.srcOver;

    void drawBlob(
      Color color,
      double offsetX,
      double offsetY,
      double radiusScale,
    ) {
      // Calculate animated position based on Lissajous-like curves
      // Using prime number multipliers for frequencies to avoid repetition
      double x =
          size.width *
          (0.5 +
              0.4 * offsetX * math.cos(animationValue * 2 * math.pi + offsetX));
      double y =
          size.height *
          (0.5 +
              0.4 *
                  offsetY *
                  math.sin(animationValue * 2 * math.pi * 0.7 + offsetY));

      paint.shader =
          RadialGradient(
            colors: [
              color.withValues(alpha: 0.8),
              color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(x, y),
              radius: size.width * radiusScale,
            ),
          );

      canvas.drawRect(rect, paint);
    }

    // Draw 4 moving blobs
    drawBlob(const Color(0xFF4285F4), 1.0, 0.5, 0.8); // Blue
    drawBlob(const Color(0xFFDB4437), -0.8, -0.6, 0.9); // Red
    drawBlob(const Color(0xFFF4B400), 0.7, -0.9, 0.7); // Yellow
    drawBlob(const Color(0xFF0F9D58), -0.6, 0.8, 1.0); // Green
  }

  @override
  bool shouldRepaint(covariant LiquidGradientPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
