import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/data/repositories/habit_repository.dart';

enum StatsFilter { weekly, monthly, yearly, allTime, custom }

class StatisticsController extends GetxController {
  final HabitRepository _habitRepository = HabitRepository();
  StreamSubscription? _subscription;

  var habits = <Habit>[].obs;
  var allLogs = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;

  // Filter State
  var selectedFilter = StatsFilter.weekly.obs;
  var customRange = Rx<DateTimeRange?>(null);

  // Global Stats (Filtered)
  var globalCompletionCount = 0.obs;
  var globalCompletionRate = 0.0.obs;

  // Map of habitId -> its specific logs (Filtered)
  var habitLogsMap = <String, List<Map<String, dynamic>>>{}.obs;

  // Displayed Range
  var displayedStart = DateTime.now().obs;
  var displayedEnd = DateTime.now().obs;

  // Heatmap Data: DateTime -> Intensity level (0-4) or count (Filtered)
  var overallHeatmap = <DateTime, int>{}.obs;

  // Chart Data: X (index) -> Value
  // We need metadata for labels (e.g., 'Mon', 'Jan').
  var chartData = <ChartDataPoint>[].obs;
  var topStreaks = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchData();
    _subscribeToRealtimeUpdates();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void _subscribeToRealtimeUpdates() {
    _subscription = _habitRepository.subscribeToHabitLogs().listen(
      (event) {
        fetchData();
      },
      onError: (e) {
        // print('Stream error: $e');
      },
    );
  }

  void setFilter(StatsFilter filter) {
    selectedFilter.value = filter;
    _processData();
  }

  void setCustomRange(DateTimeRange range) {
    customRange.value = range;
    selectedFilter.value = StatsFilter.custom;
    _processData();
  }

  Future<void> fetchData() async {
    try {
      if (habits.isEmpty) isLoading.value = true;

      final results = await Future.wait([
        _habitRepository.getHabits(),
        _habitRepository.getAllLogs(),
      ]);

      habits.value = results[0] as List<Habit>;
      allLogs.value = results[1] as List<Map<String, dynamic>>;

      _processData();
    } catch (e) {
      Get.snackbar('Error', 'Gagal ambil data statistik: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _processData() {
    // 1. Determine Date Range based on Filter
    DateTime start;
    DateTime end = DateTime.now();
    // Normalize end to end of day
    end = DateTime(end.year, end.month, end.day, 23, 59, 59);

    switch (selectedFilter.value) {
      case StatsFilter.weekly:
        // Current Week (Mon-Sun)
        start = end.subtract(Duration(days: end.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case StatsFilter.monthly:
        // Current Month (1st - End)
        start = DateTime(end.year, end.month, 1);
        break;
      case StatsFilter.yearly:
        // Current Year (Jan 1st - End)
        start = DateTime(end.year, 1, 1);
        break;
      case StatsFilter.allTime:
        // Find earliest log date or default to a safe past date
        if (allLogs.isNotEmpty) {
          DateTime minDate = end;
          for (var l in allLogs) {
            final d = DateTime.parse(l['target_date']);
            if (d.isBefore(minDate)) minDate = d;
          }
          start = DateTime(minDate.year, minDate.month, minDate.day);
        } else {
          start = DateTime(2024); // Fallback
        }
        break;
      case StatsFilter.custom:
        if (customRange.value != null) {
          start = customRange.value!.start;
          end = customRange.value!.end.add(
            const Duration(hours: 23, minutes: 59, seconds: 59),
          );
        } else {
          // Fallback to weekly if null
          start = end.subtract(Duration(days: end.weekday - 1));
          start = DateTime(start.year, start.month, start.day);
        }
        break;
    }

    displayedStart.value = start;
    displayedEnd.value = end;

    // 2. Filter Logs
    final filteredLogs = allLogs.where((log) {
      final date = DateTime.parse(log['target_date'] as String);
      return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          date.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    // 3. Partition filtered logs by habit
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (var habit in habits) {
      map[habit.id!] = [];
    }

    final Map<DateTime, int> heatMapCounts = {};

    for (var log in filteredLogs) {
      final habitId = log['habit_id'];
      if (map.containsKey(habitId)) {
        map[habitId]!.add(log);
      }

      // Heatmap Data Processing
      if (log['status'] == 'completed') {
        final date = DateTime.parse(log['target_date'] as String);
        final normalizedDate = DateTime(date.year, date.month, date.day);
        heatMapCounts[normalizedDate] =
            (heatMapCounts[normalizedDate] ?? 0) + 1;
      }
    }
    habitLogsMap.value = map;

    // 4. Global Stats
    final completedLogs = filteredLogs
        .where((l) => l['status'] == 'completed')
        .toList();
    globalCompletionCount.value = completedLogs.length;

    final skippedLogs = filteredLogs
        .where((l) => l['status'] == 'skipped')
        .toList();
    final totalActioned = completedLogs.length + skippedLogs.length;

    if (totalActioned > 0) {
      globalCompletionRate.value = (completedLogs.length / totalActioned) * 100;
    } else {
      globalCompletionRate.value = 0.0;
    }

    // 5. Heatmap (Use filtered counts? Or Keep Heatmap 90 days fixed?
    // Usually Heatmap is fixed history. But "Keaktifan" could reflect filter.
    // Let's make heatmap reflect filter if possible, OR just keep it fixed 90 days for "GitHub style".
    // User asked for "statistik filter", implying filtering everything.
    // But Heatmap usually shows long term context.
    // Let's Update Heatmap to show the filtered range if it's longer than default,
    // or just show the filtered data points.
    overallHeatmap.value = heatMapCounts;

    // 6. Chart Data Generation
    _generateChartData(start, end, completedLogs);

    // 7. Top 3 Best Streaks Ranking (All-time context)
    _updateTopStreaks();
  }

  void _updateTopStreaks() {
    List<Map<String, dynamic>> rankings = [];

    for (var habit in habits) {
      final habitLogs = allLogs
          .where((l) => l['habit_id'] == habit.id && l['status'] == 'completed')
          .toList();

      final bestStreak = _calculateBestStreak(habitLogs);
      if (bestStreak > 0) {
        rankings.add({'habit': habit, 'streak': bestStreak});
      }
    }

    rankings.sort((a, b) => (b['streak'] as int).compareTo(a['streak'] as int));
    topStreaks.value = rankings.take(3).toList();
  }

  int _calculateBestStreak(List<Map<String, dynamic>> completedLogs) {
    if (completedLogs.isEmpty) return 0;

    final dates =
        completedLogs
            .map((l) => DateTime.parse(l['target_date']))
            .map((d) => DateTime(d.year, d.month, d.day))
            .toSet()
            .toList()
          ..sort((a, b) => a.compareTo(b));

    int maxStreak = 0;
    int currentStreak = 0;

    for (int i = 0; i < dates.length; i++) {
      if (i == 0) {
        currentStreak = 1;
      } else {
        if (dates[i].difference(dates[i - 1]).inDays == 1) {
          currentStreak++;
        } else {
          if (currentStreak > maxStreak) maxStreak = currentStreak;
          currentStreak = 1;
        }
      }
    }
    if (currentStreak > maxStreak) maxStreak = currentStreak;

    return maxStreak;
  }

  void _generateChartData(
    DateTime start,
    DateTime end,
    List<Map<String, dynamic>> logs,
  ) {
    List<ChartDataPoint> points = [];

    // For 'All Time' with range > 1 year or 'Yearly', use Monthly Aggregation
    // Check if range > 365 days for All Time/Custom
    final rangeDays = end.difference(start).inDays;

    if (selectedFilter.value == StatsFilter.yearly ||
        ((selectedFilter.value == StatsFilter.allTime ||
                selectedFilter.value == StatsFilter.custom) &&
            rangeDays > 90)) {
      // Aggregate by Month (Year-Month)
      // Map "YYYY-MM" -> count
      Map<String, int> monthlyCounts = {};

      // Generate all months in range first
      DateTime current = DateTime(start.year, start.month);
      List<DateTime> monthsList = [];
      while (current.isBefore(end) ||
          (current.year == end.year && current.month == end.month)) {
        monthsList.add(current);
        // next month
        if (current.month == 12) {
          current = DateTime(current.year + 1, 1);
        } else {
          current = DateTime(current.year, current.month + 1);
        }
      }
      monthsList.sort((a, b) => a.compareTo(b)); // Ensure sorted

      for (var log in logs) {
        final d = DateTime.parse(log['target_date']);
        final key = "${d.year}-${d.month}";
        monthlyCounts[key] = (monthlyCounts[key] ?? 0) + 1;
      }

      List<String> monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];

      for (int i = 0; i < monthsList.length; i++) {
        final m = monthsList[i];
        final key = "${m.year}-${m.month}";

        // Label: if multiple years, show 'Jan 24'. If single year view (yearly filter), show 'Jan'.
        String label;
        if (selectedFilter.value == StatsFilter.yearly &&
            start.year == end.year) {
          label = monthNames[m.month - 1]; // Just month
        } else {
          // For all time, 'Jan', 'Feb' might be ambiguous if 2023 and 2024 exist.
          // Let's shorten year: 'Jan 24'
          final y = m.year.toString().substring(2);
          label = "${monthNames[m.month - 1]} $y";
        }

        points.add(
          ChartDataPoint(
            x: i.toDouble(),
            y: (monthlyCounts[key] ?? 0).toDouble(),
            label: label,
          ),
        );
      }
    } else {
      // Daily Aggregation (Weekly, Monthly, Custom/AllTime < 90 days)
      final dayCount = end.difference(start).inDays + 1;

      // Map Date -> Count
      Map<DateTime, int> dailyCounts = {};
      for (var log in logs) {
        final d = DateTime.parse(log['target_date']);
        final normalized = DateTime(d.year, d.month, d.day);
        dailyCounts[normalized] = (dailyCounts[normalized] ?? 0) + 1;
      }

      for (int i = 0; i < dayCount; i++) {
        final date = start.add(Duration(days: i));
        final normalized = DateTime(date.year, date.month, date.day);

        String label = '';
        if (selectedFilter.value == StatsFilter.weekly) {
          const days = ['Sn', 'Sl', 'Rb', 'Km', 'Jm', 'Sb', 'Mn']; // Mon-Sun
          // weekday 1=Mon -> index 0 for array
          label = days[(date.weekday - 1) % 7];
        } else {
          // Include date for monthly/custom
          if (i % 5 == 0 || dayCount <= 7) {
            label = '${date.day}';
          }
        }

        points.add(
          ChartDataPoint(
            x: i.toDouble(),
            y: (dailyCounts[normalized] ?? 0).toDouble(),
            label: label,
          ),
        );
      }
    }

    chartData.value = points;
  }

  Map<String, dynamic> getStatsForHabit(String habitId) {
    // 1. Total for filtered period
    final filteredLogs = habitLogsMap[habitId] ?? [];
    final filteredCompleted = filteredLogs
        .where((l) => l['status'] == 'completed')
        .toList();

    // 2. Streaks (from all logs, unfiltered)
    final habitAllLogs = allLogs
        .where((l) => l['habit_id'] == habitId && l['status'] == 'completed')
        .toList();

    final currentStreak = _calculateStreak(habitAllLogs);
    final bestStreak = _calculateBestStreak(habitAllLogs);

    return {
      'total': filteredCompleted.length,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
    };
  }

  Map<DateTime, int> getHeatmapForHabit(String habitId) {
    if (!habitLogsMap.containsKey(habitId)) return {};
    final logs = habitLogsMap[habitId]!;
    final Map<DateTime, int> heat = {};
    for (var log in logs) {
      if (log['status'] == 'completed') {
        final date = DateTime.parse(log['target_date']);
        final normalized = DateTime(date.year, date.month, date.day);
        heat[normalized] = 1;
      }
    }
    return heat;
  }

  int _calculateStreak(List<Map<String, dynamic>> completedLogs) {
    if (completedLogs.isEmpty) return 0;

    final dates =
        completedLogs
            .map((l) => DateTime.parse(l['target_date']))
            .map((d) => DateTime(d.year, d.month, d.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    if (dates.isEmpty) return 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (dates.first.isBefore(todayDate.subtract(const Duration(days: 1)))) {
      return 0;
    }

    int streak = 1;
    for (int i = 0; i < dates.length - 1; i++) {
      if (dates[i].difference(dates[i + 1]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}

class ChartDataPoint {
  final double x;
  final double y;
  final String label;

  ChartDataPoint({required this.x, required this.y, required this.label});
}
