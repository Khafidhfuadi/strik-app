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
        title: Text(
          'Statistik',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final habits = _controller.habits;
        // Tabs: 'Semua' + habits

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

  Widget _buildOverallTab() {
    return Obx(() {
      final completionCount = _controller.globalCompletionCount.value;
      final completionRate = _controller.globalCompletionRate.value;
      final heatmapData = _controller.overallHeatmap;

      // Heatmap dates
      // Show last 3 months (approx 12 weeks)
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 90));

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
                  'Jumlah total kebiasaan yang udah lo kelarin selama ini. Makin banyak makin GG!',
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
              'Performa Minggu Ini',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
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
                        getTitlesWidget: _bottomTitles,
                        reservedSize: 30,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _generateWeeklyBarGroups(
                    _controller.weeklyPerformance,
                  ),
                  barTouchData: BarTouchData(
                    enabled:
                        false, // Disable touch interaction if using static tooltips or keep enabled for detail
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.transparent,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 4,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
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
          ],
        ),
      );
    });
  }

  Widget _buildHabitTab(Habit habit) {
    return Obx(() {
      final stats = _controller.getStatsForHabit(habit.id!);
      // Need specific heatmap
      final heatmapData = _controller.getHeatmapForHabit(habit.id!);
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 90));

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
                    description: 'Berapa kali lo lakuin habit ini.',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Streak',
                    '${stats['streak']}',
                    'Hari',
                    const Color(0xFFFF5757),
                    description: 'Berturut-turut tanpa putus. Keep fire! 🔥',
                  ),
                ),
              ],
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
                  'Grafik ${habit.title} Coming Soon',
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

  List<BarChartGroupData> _generateWeeklyBarGroups(List<int> weeklyData) {
    if (weeklyData.isEmpty) return [];

    final maxVal = weeklyData.reduce((curr, next) => curr > next ? curr : next);
    final isAllZero = maxVal == 0;

    return List.generate(7, (i) {
      final val = weeklyData[i];
      final isMax = !isAllZero && val == maxVal;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: val.toDouble(),
            color: isMax
                ? AppTheme.primary
                : AppTheme.primary.withValues(alpha: 0.3),
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: (maxVal == 0
                  ? 5
                  : maxVal * 1.2), // Dynamic subtle background height
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ],
        showingTooltipIndicators: val > 0 ? [0] : [],
      );
    });
  }
}

Widget _bottomTitles(double value, TitleMeta meta) {
  const style = TextStyle(
    color: Colors.grey,
    fontSize: 10,
    fontWeight: FontWeight.bold,
  );
  String text;
  switch (value.toInt()) {
    case 0:
      text = 'Mn';
      break;
    case 1:
      text = 'Sn';
      break;
    case 2:
      text = 'Sl';
      break;
    case 3:
      text = 'Rb';
      break;
    case 4:
      text = 'Km';
      break;
    case 5:
      text = 'Jm';
      break;
    case 6:
      text = 'Sb';
      break;
    default:
      text = '';
  }
  return SideTitleWidget(
    meta: meta,
    space: 4,
    child: Text(text, style: style),
  );
}
