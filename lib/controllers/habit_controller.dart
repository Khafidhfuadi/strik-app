import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/data/repositories/habit_repository.dart';
import 'package:strik_app/data/repositories/friend_repository.dart';
import 'package:strik_app/services/alarm_manager_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/controllers/gamification_controller.dart';
import 'package:strik_app/controllers/habit_challenge_controller.dart';

class HabitController extends GetxController {
  final HabitRepository _habitRepository = HabitRepository();

  var habits = <Habit>[].obs;
  var archivedHabits = <Habit>[].obs; // New list for archives
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

      // Partition habits into active and archived
      final activeList = <Habit>[];
      final archivedList = <Habit>[];

      for (var habit in fetchedHabits) {
        if (!habit.isArchived) {
          activeList.add(habit);
        } else {
          archivedList.add(habit);
        }
      }

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

      habits.value = activeList;
      archivedHabits.value = archivedList; // Update archived list
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
      // It's a new day! Refresh habits and logs.
      // Note: Missed habit penalties are handled server-side via pg_cron.
      await fetchHabitsAndLogs(isRefresh: true);
    }
  }

  // Note: Missed habit penalties are now handled server-side
  // via process_missed_habits() PostgreSQL cron job.
  // See: supabase/process_missed_habits.sql

  Future<void> checkAlarmConsistency() async {
    if (habits.isNotEmpty) {
      await AlarmManagerService.instance.ensureAlarmsAreScheduled(habits);
    }
  }

  Future<void> toggleHabitStatus(
    Habit habit,
    String? currentStatus,
    DismissDirection direction, {
    bool skipJournalCheck = false,
  }) async {
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

    // Challenge habit: require journal before completion (only for today)
    if (habit.isChallenge && newStatus == 'completed' && !skipJournalCheck) {
      try {
        final localStart = DateTime(today.year, today.month, today.day);
        final localEnd = localStart
            .add(const Duration(days: 1))
            .subtract(const Duration(seconds: 1));
        final journal = await Supabase.instance.client
            .from('habit_journals')
            .select('id')
            .eq('habit_id', habit.id!)
            .gte('created_at', localStart.toUtc().toIso8601String())
            .lte('created_at', localEnd.toUtc().toIso8601String())
            .maybeSingle();

        if (journal == null) {
          Get.snackbar(
            'Jurnal Dulu!',
            'Tulis jurnal dulu sebelum menyelesaikan challenge habit ini 1',
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
      } catch (e) {
        print('Error checking journal for challenge: $e');
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

        // Handle Alarm: If today (or relevant), cancel and schedule next
        // Since toggleHabitStatus is usually for "today" (swipe action)
        if (habit.id != null) {
          await AlarmManagerService.instance.completeHabit(habit.id!);
        }
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

        // Handle Alarm: Restore alarm if undone
        if (habit.id != null) {
          await AlarmManagerService.instance.ensureAlarmsAreScheduled([habit]);
        }
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

        // Only create post if completing a public habit AND NOT A CHALLENGE (Challenges use Momentz)
        if (newStatus == 'completed' && habit.isPublic && !habit.isChallenge) {
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
              String postContent = 'abis bantai "${habit.title}", nih!';

              // Create post and get its ID
              final createdPost = await Supabase.instance.client
                  .from('posts')
                  .insert({
                    'user_id': Supabase.instance.client.auth.currentUser!.id,
                    'content': postContent,
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

        // Update challenge leaderboard if this is a challenge habit
        if (newStatus == 'completed' && habit.isChallenge) {
          try {
            if (Get.isRegistered<HabitChallengeController>()) {
              Get.find<HabitChallengeController>().fetchChallengeLeaderboard(
                habit.challengeId!,
              );
            }
          } catch (_) {}
        }
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

    // Challenge habit: require journal before completion (only for today)
    if (habit.isChallenge &&
        newStatus == 'completed' &&
        targetDate.isAtSameMomentAs(today)) {
      try {
        final jLocalStart = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        );
        final jLocalEnd = jLocalStart
            .add(const Duration(days: 1))
            .subtract(const Duration(seconds: 1));
        final journal = await Supabase.instance.client
            .from('habit_journals')
            .select('id')
            .eq('habit_id', habit.id!)
            .gte('created_at', jLocalStart.toUtc().toIso8601String())
            .lte('created_at', jLocalEnd.toUtc().toIso8601String())
            .maybeSingle();

        if (journal == null) {
          Get.snackbar(
            'Jurnal Dulu!',
            'Tulis jurnal dulu sebelum menyelesaikan challenge habit ini 2',
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
      } catch (e) {
        print('Error checking journal for challenge: $e');
      }
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
      // Check 7-day restriction for XP
      final sevenDaysAgo = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 7));
      final isTooOldForXP = targetDate.isBefore(sevenDaysAgo);

      if (!isTooOldForXP) {
        final gamification = Get.find<GamificationController>();
        if (newStatus == 'completed') {
          final xp = gamification.getXPReward('complete_habit');
          gamification.awardXP(xp, reason: 'Completed Habit');

          // Alarm Logic
          if (habit.id != null) {
            await AlarmManagerService.instance.completeHabit(habit.id!);
          }
        } else if (newStatus == 'skipped') {
          final xp = gamification.getXPReward('skip_habit'); // Returns negative
          gamification.awardXP(xp, reason: 'Skipped Habit');
        } else if (currentStatus == 'completed' && newStatus == null) {
          // Undo completed
          final xp = gamification.getXPReward('complete_habit');
          gamification.awardXP(-xp, reason: 'Undo Completion');

          // Alarm Logic: Restore
          if (habit.id != null) {
            await AlarmManagerService.instance.ensureAlarmsAreScheduled([
              habit,
            ]);
          }
        } else if (currentStatus == 'skipped' && newStatus == null) {
          // Undo skipped
          final xp = gamification.getXPReward('skip_habit'); // is negative
          gamification.awardXP(-xp, reason: 'Undo Skip'); // -(-5) = +5
        }
      }

      if (newStatus == null) {
        await _habitRepository.deleteLog(habit.id!, targetDate);
      } else {
        await _habitRepository.logHabit(habit.id!, targetDate, newStatus);
      }

      // Update challenge leaderboard if this is a challenge habit
      if (newStatus == 'completed' && habit.isChallenge) {
        try {
          if (Get.isRegistered<HabitChallengeController>()) {
            Get.find<HabitChallengeController>().fetchChallengeLeaderboard(
              habit.challengeId!,
            );
          }
        } catch (_) {}
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

  // Helper to mark habit as completed (called by HabitJournalController)
  Future<void> markHabitAsCompleted(Habit habit) async {
    // Check current status
    final status = todayLogs[habit.id];
    if (status == 'completed') return; // Already completed

    // Toggle to completed
    // We use DismissDirection.startToEnd as proxy for "Complete"
    await toggleHabitStatus(
      habit,
      status,
      DismissDirection.startToEnd,
      skipJournalCheck: true,
    );
  }
}
