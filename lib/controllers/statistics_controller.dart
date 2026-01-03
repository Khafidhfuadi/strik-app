import 'dart:async';
import 'package:get/get.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/data/repositories/habit_repository.dart';

class StatisticsController extends GetxController {
  final HabitRepository _habitRepository = HabitRepository();
  StreamSubscription? _subscription;

  var habits = <Habit>[].obs;
  var allLogs = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;

  // Global Stats
  var globalCompletionCount = 0.obs;
  var globalCompletionRate = 0.0.obs;

  // Map of habitId -> its specific logs
  var habitLogsMap = <String, List<Map<String, dynamic>>>{}.obs;

  // Heatmap Data: DateTime -> Intensity level (0-4) or count
  var overallHeatmap = <DateTime, int>{}.obs;

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
        // Simple strategy: Re-fetch everything on any change for consistency
        // Ideally we merge, but re-fetching ensures we get complete updated state including deletions etc.
        fetchData();
      },
      onError: (e) {
        // print('Stream error: $e');
      },
    );
  }

  Future<void> fetchData() async {
    try {
      // Only show loading if we have no data yet
      if (habits.isEmpty) isLoading.value = true;

      // Fetch habits and all logs in parallel
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
    // 1. Partition logs by habit
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (var habit in habits) {
      map[habit.id!] = [];
    }

    final Map<DateTime, int> heatMapCounts = {};

    for (var log in allLogs) {
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

    // 2. Global Stats
    final completedLogs = allLogs
        .where((l) => l['status'] == 'completed')
        .toList();
    globalCompletionCount.value = completedLogs.length;

    final skippedLogs = allLogs.where((l) => l['status'] == 'skipped').toList();
    final totalActioned = completedLogs.length + skippedLogs.length;

    if (totalActioned > 0) {
      globalCompletionRate.value = (completedLogs.length / totalActioned) * 100;
    } else {
      globalCompletionRate.value = 0.0;
    }

    // 3. Process Heatmap Data
    overallHeatmap.value = heatMapCounts;
  }

  Map<String, int> getStatsForHabit(String habitId) {
    if (!habitLogsMap.containsKey(habitId)) return {'total': 0, 'streak': 0};

    final logs = habitLogsMap[habitId]!;
    final completed = logs.where((l) => l['status'] == 'completed').toList();

    int streak = _calculateStreak(completed);

    return {'total': completed.length, 'streak': streak};
  }

  Map<DateTime, int> getHeatmapForHabit(String habitId) {
    if (!habitLogsMap.containsKey(habitId)) return {};
    final logs = habitLogsMap[habitId]!;
    final Map<DateTime, int> heat = {};
    for (var log in logs) {
      if (log['status'] == 'completed') {
        final date = DateTime.parse(log['target_date']);
        final normalized = DateTime(date.year, date.month, date.day);
        heat[normalized] = 1; // Binary for single habit
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

    // Check start. Streak is valid if last completion is Today or Yesterday
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
