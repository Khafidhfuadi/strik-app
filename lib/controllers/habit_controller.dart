import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/data/repositories/habit_repository.dart';
import 'package:strik_app/data/repositories/friend_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  List<Habit> get sortedHabits {
    final today = DateTime.now();
    final currentDayIndex = today.weekday - 1; // 0 (Mon) - 6 (Sun)

    // Filter habits relevant for today
    final relevantHabits = habits.where((habit) {
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

    // Apply status filters
    final filtered = relevantHabits.where((habit) {
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
