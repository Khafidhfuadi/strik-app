import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/data/models/user_model.dart';

class GamificationRepository {
  final SupabaseClient _supabase;

  GamificationRepository(this._supabase);

  Future<UserModel?> getCurrentUserGamificationData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    return UserModel.fromJson(response);
  }

  Future<void> updateXPAndLevel(double newXP, int newLevel) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('profiles')
        .update({'xp': newXP, 'level': newLevel})
        .eq('id', user.id);
  }

  Future<int> getTotalCompletedHabitsCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    // 1. Get habit IDs for current user
    final habitsResponse = await _supabase
        .from('habits')
        .select('id')
        .eq('user_id', user.id);

    if (habitsResponse.isEmpty) return 0;

    final habitIds = (habitsResponse as List<dynamic>)
        .map((h) => h['id'])
        .toList();

    // 2. Count completed logs for those habits
    final count = await _supabase
        .from('habit_logs')
        .count(CountOption.exact)
        .filter('habit_id', 'in', habitIds)
        .eq('status', 'completed');

    return count;
  }

  Future<void> logXP(double amount, String reason) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('xp_logs').insert({
      'user_id': user.id,
      'amount': amount,
      'reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> getXPHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('xp_logs')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }
}
