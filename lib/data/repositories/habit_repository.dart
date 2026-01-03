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
}
