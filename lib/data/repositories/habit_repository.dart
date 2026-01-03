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
      final response = await supabase
          .from('habits')
          .select()
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

      // Upsert: valid status are 'completed', 'skipped', 'failed' based on DB check
      await supabase.from('habit_logs').upsert({
        'habit_id': habitId,
        'target_date': formattedDate,
        'status': status,
        'completed_at': DateTime.now().toIso8601String(),
      });
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
}
