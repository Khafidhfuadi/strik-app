import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:strik_app/controllers/statistics_controller.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/widgets/heatmap_grid.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late StatisticsController _controller;
  late PageController _pageController;
  final RxInt _currentIndex = 0.obs;

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
          return const Center(child: CircularProgressIndicator());
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
              'Gacor Abis 🔥',
              AppTheme.secondary,
              description:
                  'Tingkat kedisiplinan lo. Kalo 100% berarti lo ga pernah skip, Gacor Abis!',
            ),
            const SizedBox(height: 32),

            _buildRankingSection(),
            const SizedBox(height: 32),

            Text(
              'Jejak Keaktifan',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
            Text(
              _getChartTitle(filter),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
                    child: Container(
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
                    '',
                    AppTheme.primary,
                    description:
                        'Berapa kali lo lakuin habit ini di periode ini.',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Streak Aktif',
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
            Text(
              'Jejak Keaktifan',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
                  'Grafik coming soon',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54),
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
          Row(
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
              const Icon(
                Icons.emoji_events_rounded,
                color: Colors.amber,
                size: 20,
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
              if (top3.length >= 1)
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
          return 'Statistik Mingguan (${start.day}-${end.day} ${shortMonths[start.month - 1]})';
        } else {
          return 'Statistik Mingguan (${start.day} ${shortMonths[start.month - 1]} - ${end.day} ${shortMonths[end.month - 1]})';
        }
      case StatsFilter.monthly:
        return 'Statistik Bulan ${months[start.month - 1]} (1-${end.day})';
      case StatsFilter.yearly:
        return 'Statistik Tahun ${start.year} (1 ${shortMonths[0]}-hari ini)';
      case StatsFilter.allTime:
        return 'Statistik Sepanjang Masaa~';
      case StatsFilter.custom:
        return 'Statistik ${start.day} ${shortMonths[start.month - 1]} - ${end.day} ${shortMonths[end.month - 1]}';
    }
  }
}
