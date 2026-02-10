import 'package:get/get.dart';

import 'package:strik_app/data/repositories/habit_repository.dart';
import 'package:strik_app/controllers/gamification_controller.dart';

class HabitDetailController extends GetxController {
  final HabitRepository _habitRepository = HabitRepository();
  final String habitId;

  var logs = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;

  // Stats
  var totalCompletions = 0.obs;
  var currentStreak = 0.obs;
  var bestStreak = 0.obs;

  // Calendar Navigation
  var focusedMonth = DateTime.now().obs;

  HabitDetailController(this.habitId);

  @override
  void onInit() {
    super.onInit();
    fetchLogs();
  }

  Future<void> fetchLogs() async {
    try {
      isLoading.value = true;
      final fetchedLogs = await _habitRepository.getLogsForHabit(habitId);
      logs.value = fetchedLogs;
      calculateStats();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load history: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void changeMonth(int offset) {
    var newMonth = DateTime(
      focusedMonth.value.year,
      focusedMonth.value.month + offset,
    );
    focusedMonth.value = newMonth;
  }

  Future<void> toggleLog(DateTime date) async {
    final today = DateTime.now();
    final targetDate = DateTime(date.year, date.month, date.day);
    if (targetDate.isAfter(DateTime(today.year, today.month, today.day))) {
      return; // Can't log future
    }

    final dateStr = targetDate.toIso8601String().split('T')[0];

    // Check current status
    final existingIndex = logs.indexWhere((l) => l['target_date'] == dateStr);
    String? newStatus;

    // Check 7-day restriction
    final sevenDaysAgo = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 7));
    final isTooOldForXP = targetDate.isBefore(sevenDaysAgo);

    if (existingIndex != -1) {
      // Exists, toggle off (delete)
      final currentStatus = logs[existingIndex]['status'];

      // XP Logic
      try {
        if (!isTooOldForXP && Get.isRegistered<GamificationController>()) {
          final gamification = Get.find<GamificationController>();
          if (currentStatus == 'completed') {
            // Undo completion: Deduct XP
            final xp = gamification.getXPReward('complete_habit');
            gamification.awardXP(-xp, reason: 'Undo Completion');
          } else if (currentStatus == 'skipped') {
            // Undo skip: Refund penalty (add positive of negative value)
            final xp = gamification.getXPReward('skip_habit');
            gamification.awardXP(-xp, reason: 'Undo Skip');
          }
        }
      } catch (_) {}

      logs.removeAt(existingIndex);
      newStatus = null;
    } else {
      // Doesn't exist, Create 'completed'
      newStatus = 'completed';

      // XP Logic
      try {
        if (!isTooOldForXP && Get.isRegistered<GamificationController>()) {
          final gamification = Get.find<GamificationController>();
          final xp = gamification.getXPReward('complete_habit');
          gamification.awardXP(xp, reason: 'Completed Habit');
        }
      } catch (_) {}

      // Add locally
      logs.add({
        'target_date': dateStr,
        'status': 'completed',
        'habit_id': habitId,
      });
      // Sort desc
      logs.sort(
        (a, b) =>
            (b['target_date'] as String).compareTo(a['target_date'] as String),
      );
    }

    logs.refresh();
    calculateStats();

    // Persist
    try {
      if (newStatus == null) {
        await _habitRepository.deleteLog(habitId, targetDate);
      } else {
        await _habitRepository.logHabit(habitId, targetDate, newStatus);
      }
    } catch (e) {
      // Revert (simplified)
      fetchLogs();
      Get.snackbar('Error', 'Failed to update: $e');
    }
  }

  void calculateStats() {
    if (logs.isEmpty) {
      totalCompletions.value = 0;
      currentStreak.value = 0;
      bestStreak.value = 0;
      return;
    }

    // Filter only completed logs
    final completedDates = logs
        .where((l) => l['status'] == 'completed')
        .map((l) => DateTime.parse(l['target_date']))
        .toList(); // Already sorted desc from repo OR local insert

    totalCompletions.value = completedDates.length;

    if (completedDates.isEmpty) {
      currentStreak.value = 0;
      bestStreak.value = 0;
      return;
    }

    // Calculate streaks
    int current = 0;
    int best = 0;
    int tempStreak = 0;

    // Check strict consecutive days
    // Since list is descending (newest first)
    final today = DateTime.now();
    final uniqueDates =
        completedDates
            .map((d) => DateTime(d.year, d.month, d.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a)); // Descending unique

    if (uniqueDates.isEmpty) return;

    // Current Streak
    // If the most recent completion is today or yesterday, we might have a streak
    final lastCompletion = uniqueDates.first;
    final diffDays = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(lastCompletion).inDays;

    if (diffDays <= 1) {
      current = 1;
      for (int i = 0; i < uniqueDates.length - 1; i++) {
        final d1 = uniqueDates[i];
        final d2 = uniqueDates[i + 1];
        if (d1.difference(d2).inDays == 1) {
          current++;
        } else {
          break;
        }
      }
    } else {
      current = 0;
    }

    // Best Streak
    tempStreak = 1;
    best = 1;
    for (int i = 0; i < uniqueDates.length - 1; i++) {
      final d1 = uniqueDates[i];
      final d2 = uniqueDates[i + 1];
      if (d1.difference(d2).inDays == 1) {
        tempStreak++;
      } else {
        if (tempStreak > best) best = tempStreak;
        tempStreak = 1;
      }
    }
    if (tempStreak > best) best = tempStreak;

    currentStreak.value = current;
    bestStreak.value = best;
  }
}
