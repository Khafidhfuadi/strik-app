import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/data/repositories/habit_repository.dart';
import 'package:strik_app/data/repositories/friend_repository.dart';
import 'package:strik_app/services/alarm_manager_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/controllers/gamification_controller.dart';

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

  DateTime? _lastFetchTime;
  bool _hasRunMigration = false;

  Future<void> fetchHabitsAndLogs({bool isRefresh = false}) async {
    try {
      if (!isRefresh) {
        isLoading.value = true;
      }
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
      _lastFetchTime = DateTime.now();

      // Run migration once on first fetch
      if (!_hasRunMigration && !isRefresh) {
        _hasRunMigration = true;
        // Pass Habit objects directly (not JSON) since toJson() doesn't include id
        await AlarmManagerService.instance.migrateExistingHabits(fetchedHabits);
      }

      // Ensure alarms are consistent (run every fetch to be safe, or just occasionally)
      // Since this is lightweight (just checks memory/prefs), it's fine here.
      checkAlarmConsistency();
    } catch (e) {
      if (!isRefresh) {
        // Only show snackbar if not pull-to-refresh to avoid spamming
        Get.snackbar(
          'Error',
          'Failed to load habits: $e',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        print('Error refreshing habits: $e');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> checkDailyRefresh() async {
    if (_lastFetchTime == null) return;

    final now = DateTime.now();
    final lastFetchDate = DateTime(
      _lastFetchTime!.year,
      _lastFetchTime!.month,
      _lastFetchTime!.day,
    );
    final todayDate = DateTime(now.year, now.month, now.day);

    if (todayDate.isAfter(lastFetchDate)) {
      // It's a new day!
      // Check for missed habits on the previous active day (Yesterday)
      // We only check yesterday to avoid massive penalties if user returns after a long time.
      final yesterday = todayDate.subtract(const Duration(days: 1));

      // Ensure we don't double process if last fetch was already today (unlikely given the if)
      // But if lastFetch was yesterday, we process yesterday.
      // If lastFetch was 3 days ago, we process yesterday?
      // User requirement: "tidak melakukan aksi apapun... -5xp"
      // Simplest interpretation: Penalize for Yesterday if it was missed.
      if (yesterday.isAfter(lastFetchDate) ||
          yesterday.isAtSameMomentAs(lastFetchDate)) {
        await _processMissedHabits(yesterday);
      }

      await fetchHabitsAndLogs(isRefresh: true);
    }
  }

  Future<void> _processMissedHabits(DateTime date) async {
    try {
      // Get logs for that date
      final logs = await _habitRepository.getHabitLogsForDate(date);

      // Get active habits for that date
      final activeHabits = habits.where((habit) {
        // 1. Must be created before or on that date
        if (habit.createdAt != null &&
            habit.createdAt!.isAfter(date.add(const Duration(days: 1)))) {
          return false;
        }

        // 2. Must match frequency
        final dayIndex = date.weekday - 1; // 0-6
        if (habit.frequency == 'daily') {
          if (habit.daysOfWeek != null && habit.daysOfWeek!.isNotEmpty) {
            return habit.daysOfWeek!.contains(dayIndex);
          }
          return true;
        } else if (habit.frequency == 'weekly') {
          // Weekly is tricky to detect "missed" on a specific day without complex logic
          // Assuming weekly means "any day in week", so hard to penalize on a specific day unless end of week.
          // Skip weekly for daily penalty for now to avoid unfairness.
          return false;
        } else if (habit.frequency == 'monthly') {
          if (habit.daysOfWeek != null) {
            return habit.daysOfWeek!.contains(date.day);
          }
          return false;
        }
        return true;
      }).toList();

      for (var habit in activeHabits) {
        if (!logs.containsKey(habit.id)) {
          // No log found (neither completed nor skipped)
          // "tidak melakukan aksi apapun" -> Penalty
          try {
            final gamification = Get.find<GamificationController>();
            final xp = gamification.getXPReward('skip_habit');
            gamification.awardXP(xp, reason: 'Missed Habit');
            print('Penalized $xp XP for missed habit: ${habit.title} on $date');
          } catch (_) {}
        }
      }
    } catch (e) {
      print('Error processing missed habits: $e');
    }
  }

  Future<void> checkAlarmConsistency() async {
    if (habits.isNotEmpty) {
      await AlarmManagerService.instance.ensureAlarmsAreScheduled(habits);
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
      if (newStatus == 'completed') {
        // Award XP
        try {
          final gamification = Get.find<GamificationController>();
          final xp = gamification.getXPReward('complete_habit');
          gamification.awardXP(xp, reason: 'Completed Habit');
        } catch (_) {}
      } else if (newStatus == 'skipped') {
        // Deduct XP for skipping
        try {
          final gamification = Get.find<GamificationController>();
          final xp = gamification.getXPReward('skip_habit');
          gamification.awardXP(xp, reason: 'Skipped Habit');
        } catch (_) {}
      } else if (oldStatus == 'completed' && newStatus == null) {
        // Undo completed -> Deduct XP
        try {
          final gamification = Get.find<GamificationController>();
          final xp = gamification.getXPReward('complete_habit');
          gamification.awardXP(-xp, reason: 'Undo Completion');
        } catch (_) {}
      } else if (oldStatus == 'skipped' && newStatus == null) {
        // Undo skipped -> Return XP
        try {
          final gamification = Get.find<GamificationController>();
          final xp = gamification.getXPReward('skip_habit');
          gamification.awardXP(-xp, reason: 'Undo Skip');
        } catch (_) {}
      }

      if (newStatus == null) {
        // User is uncompleting/unskipping - check if there's an associated post to delete
        final formattedDate = today.toIso8601String().split('T')[0];
        final existingLog = await Supabase.instance.client
            .from('habit_logs')
            .select('post_id')
            .eq('habit_id', habit.id!)
            .eq('target_date', formattedDate)
            .maybeSingle();

        final postIdToDelete = existingLog?['post_id'] as String?;

        // Delete the log
        await _habitRepository.deleteLog(habit.id!, today);

        // Delete associated post if exists
        if (postIdToDelete != null) {
          try {
            final friendRepo = FriendRepository(Supabase.instance.client);
            await friendRepo.deletePost(postIdToDelete);
          } catch (e) {
            print('Failed to delete associated post: $e');
          }
        }
      } else {
        // User is completing/skipping
        String? postId;

        // Only create post if completing a public habit
        if (newStatus == 'completed' && habit.isPublic) {
          // Check if log already exists with a post_id
          final formattedDate = today.toIso8601String().split('T')[0];
          final existingLog = await Supabase.instance.client
              .from('habit_logs')
              .select('post_id')
              .eq('habit_id', habit.id!)
              .eq('target_date', formattedDate)
              .maybeSingle();

          final existingPostId = existingLog?['post_id'] as String?;

          // Only create post if one doesn't exist yet
          if (existingPostId == null) {
            try {
              // Create post and get its ID
              final createdPost = await Supabase.instance.client
                  .from('posts')
                  .insert({
                    'user_id': Supabase.instance.client.auth.currentUser!.id,
                    'content': 'abis bantai "${habit.title}", nih! 💪',
                  })
                  .select('id')
                  .single();

              postId = createdPost['id'] as String;
            } catch (e) {
              print('Failed to create auto-post: $e');
            }
          }
        }

        // Log habit with post_id (if created)
        await _habitRepository.logHabit(
          habit.id!,
          today,
          newStatus,
          postId: postId,
        );
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
    }
  }

  var showCompleted = false.obs;
  var showSkipped = false.obs;

  List<Habit> get habitsForToday {
    final today = DateTime.now();
    final currentDayIndex = today.weekday - 1; // 0 (Mon) - 6 (Sun)

    return habits.where((habit) {
      if (habit.frequency == 'daily') {
        if (habit.daysOfWeek != null && habit.daysOfWeek!.isNotEmpty) {
          return habit.daysOfWeek!.contains(currentDayIndex);
        }
        return true;
      } else if (habit.frequency == 'weekly') {
        return true;
      } else if (habit.frequency == 'monthly') {
        if (habit.daysOfWeek != null && habit.daysOfWeek!.isNotEmpty) {
          return habit.daysOfWeek!.contains(today.day);
        }
        return false;
      }
      return true;
    }).toList();
  }

  bool get isAllHabitsCompletedForToday {
    final todaysHabits = habitsForToday;
    if (todaysHabits.isEmpty) return false;

    return todaysHabits.every((habit) => todayLogs[habit.id] == 'completed');
  }

  List<Habit> get sortedHabits {
    // Apply status filters
    final filtered = habitsForToday.where((habit) {
      final status = todayLogs[habit.id];
      if (status == 'completed' && !showCompleted.value) return false;
      if (status == 'skipped' && !showSkipped.value) return false;
      return true;
    }).toList();

    final sorted = List<Habit>.from(filtered);
    sorted.sort((a, b) {
      final aStatus = todayLogs[a.id];
      final bStatus = todayLogs[b.id];
      if (aStatus == null && bStatus != null) return -1;
      if (aStatus != null && bStatus == null) return 1;
      return 0;
    });
    return sorted;
  }

  Future<void> toggleHabitCompletion(Habit habit, DateTime date) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate.isAfter(today)) {
      // Cannot check future dates
      return;
    }

    final dateStr = targetDate.toIso8601String().split('T')[0];
    final currentStatus = weeklyLogs[habit.id]?[dateStr];

    // Toggle logic
    String? newStatus;
    if (currentStatus == 'completed') {
      newStatus = null;
    } else {
      newStatus = 'completed';
    }

    // Optimistic UI updates
    final currentMap = Map<String, String>.from(weeklyLogs[habit.id] ?? {});
    if (newStatus == null) {
      currentMap.remove(dateStr);
    } else {
      currentMap[dateStr] = newStatus;
    }
    weeklyLogs[habit.id!] = currentMap;

    // Sync specific logs if needed (e.g. todayLogs)
    if (targetDate.isAtSameMomentAs(today)) {
      if (newStatus == null) {
        todayLogs.remove(habit.id);
      } else {
        todayLogs[habit.id!] = newStatus;
      }
    }

    try {
      final gamification = Get.find<GamificationController>();
      if (newStatus == 'completed') {
        final xp = gamification.getXPReward('complete_habit');
        gamification.awardXP(xp, reason: 'Completed Habit');
      } else if (newStatus == 'skipped') {
        final xp = gamification.getXPReward('skip_habit'); // Returns negative
        gamification.awardXP(xp, reason: 'Skipped Habit');
      } else if (currentStatus == 'completed' && newStatus == null) {
        // Undo completed
        final xp = gamification.getXPReward('complete_habit');
        gamification.awardXP(-xp, reason: 'Undo Completion');
      } else if (currentStatus == 'skipped' && newStatus == null) {
        // Undo skipped
        final xp = gamification.getXPReward('skip_habit'); // is negative
        gamification.awardXP(-xp, reason: 'Undo Skip'); // -(-5) = +5
      }

      if (newStatus == null) {
        await _habitRepository.deleteLog(habit.id!, targetDate);
      } else {
        await _habitRepository.logHabit(habit.id!, targetDate, newStatus);
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update status: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  double get todayProgress {
    int completedCount = todayLogs.values.where((s) => s == 'completed').length;
    int totalCount = habits.length;
    return totalCount == 0 ? 0 : completedCount / totalCount;
  }

  Future<void> deleteHabit(String id) async {
    try {
      // Cancel alarm and remove metadata
      await AlarmManagerService.instance.cancelHabitAlarm(id);

      await _habitRepository.deleteHabit(id);
      habits.removeWhere((h) => h.id == id);
      todayLogs.remove(id);
      weeklyLogs.remove(id);
      Get.back(); // Back from Detail screen
    } catch (e) {
      Get.snackbar('Error', 'Gagal hapus habit: $e');
    }
  }
}
