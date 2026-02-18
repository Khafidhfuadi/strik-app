import 'dart:math';
import 'package:strik_app/data/models/habit_challenge.dart';
import 'package:strik_app/main.dart';

class HabitChallengeRepository {
  /// Generate a unique 8-character invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create a new challenge + creator's habit + participant entry
  Future<HabitChallenge> createChallenge({
    required String habitTitle,
    String? habitDescription,
    required String habitColor,
    required String habitFrequency,
    List<int>? habitDaysOfWeek,
    int? habitFrequencyCount,
    required DateTime endDate,
    required String creatorHabitId,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final inviteCode = _generateInviteCode();

      // 1. Create the challenge
      final challengeRes = await supabase
          .from('habit_challenges')
          .insert({
            'creator_id': userId,
            'habit_title': habitTitle,
            'habit_description': habitDescription,
            'habit_color': habitColor,
            'habit_frequency': habitFrequency,
            'habit_days_of_week': habitDaysOfWeek,
            'habit_frequency_count': habitFrequencyCount,
            'end_date': endDate.toUtc().toIso8601String(),
            'invite_code': inviteCode,
          })
          .select()
          .single();

      final challengeId = challengeRes['id'] as String;

      // 2. Link creator's habit to the challenge
      await supabase
          .from('habits')
          .update({'challenge_id': challengeId})
          .eq('id', creatorHabitId);

      // 3. Add creator as participant
      await supabase.from('habit_challenge_participants').insert({
        'challenge_id': challengeId,
        'user_id': userId,
        'habit_id': creatorHabitId,
      });

      // 4. Initialize leaderboard entry for creator
      await supabase.from('habit_challenge_leaderboard').upsert({
        'challenge_id': challengeId,
        'user_id': userId,
        'total_completed': 0,
        'total_expected': 0,
        'completion_rate': 0.0,
        'current_streak': 0,
        'score': 0.0,
        'rank': 1,
      }, onConflict: 'challenge_id,user_id');

      return HabitChallenge.fromJson(challengeRes);
    } catch (e) {
      throw Exception('Failed to create challenge: $e');
    }
  }

  /// Look up a challenge by invite code
  Future<HabitChallenge?> getChallengeByInviteCode(String inviteCode) async {
    try {
      final res = await supabase
          .from('habit_challenges')
          .select('*, creator:profiles!creator_id(*)')
          .eq('invite_code', inviteCode.toUpperCase())
          .maybeSingle();

      if (res == null) return null;
      return HabitChallenge.fromJson(res);
    } catch (e) {
      throw Exception('Failed to find challenge: $e');
    }
  }

  /// Join a challenge: create a copy of the habit + participant entry
  Future<void> joinChallenge(HabitChallenge challenge) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Check if already joined
      final existing = await supabase
          .from('habit_challenge_participants')
          .select('id')
          .eq('challenge_id', challenge.id!)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        throw Exception('Kamu sudah bergabung challenge ini');
      }

      // 1. Create a copy of the habit for the joining user
      final habitRes = await supabase
          .from('habits')
          .insert({
            'user_id': userId,
            'title': challenge.habitTitle,
            'description': challenge.habitDescription,
            'color': challenge.habitColor,
            'frequency': challenge.habitFrequency,
            'days_of_week': challenge.habitDaysOfWeek,
            'frequency_count': challenge.habitFrequencyCount,
            'is_public': true,
            'challenge_id': challenge.id,
            'end_date': challenge.endDate.toUtc().toIso8601String(),
          })
          .select()
          .single();

      final habitId = habitRes['id'] as String;

      // 2. Add as participant
      await supabase.from('habit_challenge_participants').insert({
        'challenge_id': challenge.id,
        'user_id': userId,
        'habit_id': habitId,
      });

      // 3. Initialize leaderboard entry
      await supabase.from('habit_challenge_leaderboard').upsert({
        'challenge_id': challenge.id,
        'user_id': userId,
        'total_completed': 0,
        'total_expected': 0,
        'completion_rate': 0.0,
        'current_streak': 0,
        'score': 0.0,
        'rank': 0,
      }, onConflict: 'challenge_id,user_id');
    } catch (e) {
      throw Exception('Failed to join challenge: $e');
    }
  }

  /// Get all active challenges for the current user
  Future<List<HabitChallenge>> getActiveChallenges() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final participantRes = await supabase
          .from('habit_challenge_participants')
          .select('challenge_id')
          .eq('user_id', userId)
          .eq('status', 'active');

      final challengeIds = (participantRes as List)
          .map((e) => e['challenge_id'] as String)
          .toList();

      if (challengeIds.isEmpty) return [];

      final res = await supabase
          .from('habit_challenges')
          .select('*, creator:profiles!creator_id(*)')
          .inFilter('id', challengeIds)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      return (res as List).map((e) => HabitChallenge.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch active challenges: $e');
    }
  }

  /// Get archived/completed challenges
  Future<List<HabitChallenge>> getArchivedChallenges() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final participantRes = await supabase
          .from('habit_challenge_participants')
          .select('challenge_id')
          .eq('user_id', userId);

      final challengeIds = (participantRes as List)
          .map((e) => e['challenge_id'] as String)
          .toList();

      if (challengeIds.isEmpty) return [];

      final res = await supabase
          .from('habit_challenges')
          .select('*, creator:profiles!creator_id(*)')
          .inFilter('id', challengeIds)
          .inFilter('status', ['completed', 'archived'])
          .order('end_date', ascending: false);

      return (res as List).map((e) => HabitChallenge.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch archived challenges: $e');
    }
  }

  /// Get challenge leaderboard
  Future<List<ChallengeLeaderboardEntry>> getChallengeLeaderboard(
    String challengeId,
  ) async {
    try {
      final res = await supabase
          .from('habit_challenge_leaderboard')
          .select('*, user:profiles(*)')
          .eq('challenge_id', challengeId)
          .order('score', ascending: false);

      return (res as List)
          .map((e) => ChallengeLeaderboardEntry.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch challenge leaderboard: $e');
    }
  }

  /// Recalculate leaderboard for a challenge
  Future<void> updateChallengeLeaderboard(String challengeId) async {
    try {
      // Get challenge details
      final challengeRes = await supabase
          .from('habit_challenges')
          .select()
          .eq('id', challengeId)
          .single();
      final challenge = HabitChallenge.fromJson(challengeRes);

      // Get all participants
      final participants = await supabase
          .from('habit_challenge_participants')
          .select('user_id, habit_id')
          .eq('challenge_id', challengeId)
          .eq('status', 'active');

      final startDate = challenge.createdAt ?? DateTime.now();
      final endDate = challenge.endDate;
      final now = DateTime.now();
      final effectiveEnd = now.isBefore(endDate) ? now : endDate;

      List<Map<String, dynamic>> entries = [];

      for (var p in participants) {
        final userId = p['user_id'] as String;
        final habitId = p['habit_id'] as String;

        // Count completions
        final completedRes = await supabase
            .from('habit_logs')
            .select('id')
            .eq('habit_id', habitId)
            .eq('status', 'completed')
            .gte('target_date', startDate.toIso8601String().split('T')[0])
            .lte('target_date', effectiveEnd.toIso8601String().split('T')[0]);

        final totalCompleted = (completedRes as List).length;

        // Calculate expected days
        final daysDiff = effectiveEnd.difference(startDate).inDays + 1;
        int totalExpected = daysDiff; // Simplified for daily frequency

        if (challenge.habitFrequency == 'weekly') {
          totalExpected =
              (daysDiff / 7).ceil() * (challenge.habitFrequencyCount ?? 1);
        }

        final completionRate = totalExpected > 0
            ? (totalCompleted / totalExpected) * 100
            : 0.0;

        // Calculate streak
        int streak = 0;
        final logsRes = await supabase
            .from('habit_logs')
            .select('target_date')
            .eq('habit_id', habitId)
            .eq('status', 'completed')
            .order('target_date', ascending: false);

        if ((logsRes as List).isNotEmpty) {
          final dates = logsRes
              .map((l) => DateTime.parse(l['target_date'] as String))
              .toList();
          final today = DateTime(now.year, now.month, now.day);
          final lastDate = DateTime(
            dates[0].year,
            dates[0].month,
            dates[0].day,
          );

          if (today.difference(lastDate).inDays <= 1) {
            streak = 1;
            for (int i = 0; i < dates.length - 1; i++) {
              final d1 = DateTime(dates[i].year, dates[i].month, dates[i].day);
              final d2 = DateTime(
                dates[i + 1].year,
                dates[i + 1].month,
                dates[i + 1].day,
              );
              if (d1.difference(d2).inDays == 1) {
                streak++;
              } else {
                break;
              }
            }
          }
        }

        final score =
            (completionRate * 1.0) + (totalCompleted * 0.5) + (streak * 2.0);

        entries.add({
          'challenge_id': challengeId,
          'user_id': userId,
          'total_completed': totalCompleted,
          'total_expected': totalExpected,
          'completion_rate': completionRate,
          'current_streak': streak,
          'score': score,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      // Sort by score descending and assign rank
      entries.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double),
      );
      for (int i = 0; i < entries.length; i++) {
        entries[i]['rank'] = i + 1;
      }

      // Upsert all entries
      for (var entry in entries) {
        await supabase
            .from('habit_challenge_leaderboard')
            .upsert(entry, onConflict: 'challenge_id,user_id');
      }
    } catch (e) {
      throw Exception('Failed to update challenge leaderboard: $e');
    }
  }

  /// Archive expired challenges
  Future<void> archiveExpiredChallenges() async {
    try {
      await supabase
          .from('habit_challenges')
          .update({'status': 'archived'})
          .eq('status', 'active')
          .lt('end_date', DateTime.now().toUtc().toIso8601String());
    } catch (e) {
      // Silently fail - not critical
      print('Failed to archive expired challenges: $e');
    }
  }

  /// Get participants of a challenge
  Future<List<ChallengeParticipant>> getChallengeParticipants(
    String challengeId,
  ) async {
    try {
      final res = await supabase
          .from('habit_challenge_participants')
          .select('*, user:profiles(*)')
          .eq('challenge_id', challengeId)
          .eq('status', 'active');

      return (res as List)
          .map((e) => ChallengeParticipant.fromJson(e))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch participants: $e');
    }
  }

  /// Get challenge by ID
  Future<HabitChallenge?> getChallengeById(String challengeId) async {
    try {
      final res = await supabase
          .from('habit_challenges')
          .select('*, creator:profiles!creator_id(*)')
          .eq('id', challengeId)
          .maybeSingle();

      if (res == null) return null;
      return HabitChallenge.fromJson(res);
    } catch (e) {
      throw Exception('Failed to fetch challenge: $e');
    }
  }

  /// Get participant count for a challenge
  Future<int> getParticipantCount(String challengeId) async {
    try {
      final res = await supabase
          .from('habit_challenge_participants')
          .select('id')
          .eq('challenge_id', challengeId)
          .eq('status', 'active');

      return (res as List).length;
    } catch (e) {
      return 0;
    }
  }
}
