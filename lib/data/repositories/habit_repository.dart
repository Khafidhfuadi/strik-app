import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/main.dart';

class HabitRepository {
  Future<void> createHabit(Habit habit) async {
    try {
      await supabase.from('habits').insert(habit.toJson());
    } catch (e) {
      throw Exception('Failed to create habit: $e');
    }
  }

  Future<List<Habit>> getHabits() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await supabase
          .from('habits')
          .select()
          .eq('user_id', userId) // Only fetch current user's habits
          .order('created_at', ascending: false);

      return (response as List).map((data) => Habit.fromJson(data)).toList();
    } catch (e) {
      throw Exception('Failed to fetch habits: $e');
    }
  }

  Future<Map<String, String>> getHabitLogsForDate(DateTime date) async {
    try {
      final formattedDate = date.toIso8601String().split('T')[0];
      final response = await supabase
          .from('habit_logs')
          .select('habit_id, status')
          .eq('target_date', formattedDate);

      final Map<String, String> logs = {};
      for (var log in (response as List)) {
        logs[log['habit_id']] = log['status'];
      }
      return logs;
    } catch (e) {
      throw Exception('Failed to fetch habit logs: $e');
    }
  }

  Future<void> logHabit(String habitId, DateTime date, String status) async {
    try {
      final formattedDate = date.toIso8601String().split('T')[0];

      // Upsert with conflict handling to avoid duplicate key errors on (habit_id, target_date)
      await supabase.from('habit_logs').upsert({
        'habit_id': habitId,
        'target_date': formattedDate,
        'status': status,
        'completed_at': DateTime.now().toIso8601String(),
      }, onConflict: 'habit_id,target_date');
    } catch (e) {
      throw Exception('Failed to log habit: $e');
    }
  }

  Future<void> deleteLog(String habitId, DateTime date) async {
    try {
      final formattedDate = date.toIso8601String().split('T')[0];
      await supabase
          .from('habit_logs')
          .delete()
          .eq('habit_id', habitId)
          .eq('target_date', formattedDate);
    } catch (e) {
      throw Exception('Failed to delete log: $e');
    }
  }

  /// Returns a map: habit_id -> (date_string -> status)
  Future<Map<String, Map<String, String>>> getHabitLogsForRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final startFormatted = start.toIso8601String().split('T')[0];
      final endFormatted = end.toIso8601String().split('T')[0];

      final response = await supabase
          .from('habit_logs')
          .select('habit_id, target_date, status')
          .gte('target_date', startFormatted)
          .lte('target_date', endFormatted);

      final Map<String, Map<String, String>> logs = {};

      for (var log in (response as List)) {
        final habitId = log['habit_id'] as String;
        final date = log['target_date'] as String; // YYYY-MM-DD
        final status = log['status'] as String;

        if (!logs.containsKey(habitId)) {
          logs[habitId] = {};
        }
        logs[habitId]![date] = status;
      }
      return logs;
    } catch (e) {
      throw Exception('Failed to fetch range logs: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLogsForHabit(String habitId) async {
    try {
      final response = await supabase
          .from('habit_logs')
          .select('target_date, status')
          .eq('habit_id', habitId)
          .order('target_date', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw Exception('Failed to fetch habit logs: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllLogs() async {
    try {
      final response = await supabase
          .from('habit_logs')
          .select('habit_id, target_date, status, completed_at')
          .order('target_date', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw Exception('Failed to fetch all logs: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> subscribeToHabitLogs() {
    return supabase
        .from('habit_logs')
        .stream(
          primaryKey: ['id'],
        ) // Assuming 'id' is PK, or use logical key if supported by stream
        .order('target_date', ascending: false);
  }
}
