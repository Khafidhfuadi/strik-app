import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
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

  Future<Map<String, dynamic>> incrementUserXP({
    required String userId,
    required double amount,
    required String reason,
    required String referenceId,
  }) async {
    final response = await _supabase.rpc(
      'increment_user_xp',
      params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_reason': reason,
        'p_reference_id': referenceId,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<UserModel?> getUserGamificationData(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return UserModel.fromJson(response);
  }

  Future<void> updateXPAndLevelForUser(
    String userId,
    double newXP,
    int newLevel,
  ) async {
    await _supabase
        .from('profiles')
        .update({'xp': newXP, 'level': newLevel})
        .eq('id', userId);
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

  Future<void> logXP(
    double amount,
    String reason, {
    String? referenceId,
    String? userId,
  }) async {
    final targetUserId = userId ?? _supabase.auth.currentUser?.id;
    if (targetUserId == null) return;

    final data = <String, dynamic>{
      'user_id': targetUserId,
      'amount': amount,
      'reason': reason,
    };
    if (referenceId != null) {
      data['reference_id'] = referenceId;
    }

    await _supabase.from('xp_logs').insert(data);
  }

  /// Check if XP has already been awarded for a specific reference.
  Future<bool> hasXPBeenAwarded(String referenceId, {String? userId}) async {
    final targetUserId = userId ?? _supabase.auth.currentUser?.id;
    if (targetUserId == null) return false;

    final response = await _supabase
        .from('xp_logs')
        .select('id')
        .eq('user_id', targetUserId)
        .eq('reference_id', referenceId)
        .maybeSingle();

    return response != null;
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

    final logs = List<Map<String, dynamic>>.from(response);
    final enrichedLogs = <Map<String, dynamic>>[];

    // Collect habit IDs to fetch names
    final habitIds = <String>{};
    for (var log in logs) {
      final reason = log['reason'] as String?;
      final referenceId = log['reference_id'] as String?;

      // Validate if it's a UUID v4 loosely
      bool isUuid = false;
      if (referenceId != null) {
        final uuidRegExp = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          caseSensitive: false,
        );
        isUuid = uuidRegExp.hasMatch(referenceId);
      }

      if (isUuid &&
          (reason == 'Completed Habit' ||
              reason == 'Skipped Habit' ||
              reason == 'New Habit')) {
        habitIds.add(referenceId!);
      }
    }

    // Fetch habit names
    Map<String, String> habitNames = {};
    if (habitIds.isNotEmpty) {
      try {
        final habitsResponse = await _supabase
            .from('habits')
            .select('id, title')
            .filter('id', 'in', habitIds.toList());
        for (var h in habitsResponse) {
          habitNames[h['id'] as String] = h['title'] as String;
        }
      } catch (e) {
        debugPrint('Error fetching habit names: $e');
      }
    }

    // Merge names into logs
    for (var log in logs) {
      final newLog = Map<String, dynamic>.from(log);
      final referenceId = log['reference_id'] as String?;
      if (referenceId != null && habitNames.containsKey(referenceId)) {
        newLog['habit_title'] = habitNames[referenceId];
      }
      enrichedLogs.add(newLog);
    }

    return enrichedLogs;
  }
}
