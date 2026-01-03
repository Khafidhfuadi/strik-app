import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/data/repositories/habit_repository.dart';

class HabitController extends GetxController {
  final HabitRepository _habitRepository = HabitRepository();

  var habits = <Habit>[].obs;
  var todayLogs = <String, String>{}.obs;
  var weeklyLogs = <String, Map<String, String>>{}.obs;
  var isLoading = true.obs;

  // Sorting preference? For now we just sort in the getter or method
  // But let's keep a computed listed for sorted habits if needed

  @override
  void onInit() {
    super.onInit();
    fetchHabitsAndLogs();
  }

  Future<void> fetchHabitsAndLogs() async {
    try {
      isLoading.value = true;
      final fetchedHabits = await _habitRepository.getHabits();
      final today = DateTime.now();

      // Fetch today's logs
      final logs = await _habitRepository.getHabitLogsForDate(today);

      // Fetch weekly logs (current week Mon-Sun)
      final now = DateTime.now();
      final currentWeekday = now.weekday; // 1 (Mon) to 7 (Sun)
      final weekStart = now.subtract(Duration(days: currentWeekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      final rangeLogs = await _habitRepository.getHabitLogsForRange(
        weekStart,
        weekEnd,
      );

      habits.value = fetchedHabits;
      todayLogs.value = logs;
      weeklyLogs.value = rangeLogs;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load habits: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleHabitStatus(
    Habit habit,
    String? currentStatus,
    DismissDirection direction,
  ) async {
    final today = DateTime.now();
    String? newStatus;

    if (direction == DismissDirection.startToEnd) {
      if (currentStatus == 'completed') {
        newStatus = null;
      } else {
        newStatus = 'completed';
      }
    } else if (direction == DismissDirection.endToStart) {
      if (currentStatus == 'skipped') {
        newStatus = null;
      } else {
        newStatus = 'skipped';
      }
    }

    // Optimistic update
    final String? oldStatus = todayLogs[habit.id];
    if (newStatus == null) {
      todayLogs.remove(habit.id);
    } else {
      todayLogs[habit.id!] = newStatus;
    }

    try {
      if (newStatus == null) {
        await _habitRepository.deleteLog(habit.id!, today);
      } else {
        await _habitRepository.logHabit(habit.id!, today, newStatus);
      }
      // Also update weekly logs locally to reflect the change immediately in weekly view if visible
      // Only simpler way is to re-fetch or manuall update the map.
      // Re-fetching might be overkill. Let's update map manually for consistency.
      final todayStr = today.toIso8601String().split('T')[0];
      final currentMap = weeklyLogs[habit.id!] ?? {};
      if (newStatus == null) {
        currentMap.remove(todayStr);
      } else {
        currentMap[todayStr] = newStatus;
      }
      // Assignment to trigger obs update if map ref changed, or use .refresh()
      weeklyLogs[habit.id!] = currentMap;
      weeklyLogs.refresh();
    } catch (e) {
      // Revert on error
      if (oldStatus == null) {
        todayLogs.remove(habit.id);
      } else {
        todayLogs[habit.id!] = oldStatus;
      }
      Get.snackbar(
        'Error',
        'Failed to update status: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      print(e);
    }
  }

  List<Habit> get sortedHabits {
    final sorted = List<Habit>.from(habits);
    sorted.sort((a, b) {
      final aStatus = todayLogs[a.id];
      final bStatus = todayLogs[b.id];
      if (aStatus == null && bStatus != null) return -1;
      if (aStatus != null && bStatus == null) return 1;
      return 0;
    });
    return sorted;
  }

  double get todayProgress {
    int completedCount = todayLogs.values.where((s) => s == 'completed').length;
    int totalCount = habits.length;
    return totalCount == 0 ? 0 : completedCount / totalCount;
  }
}
