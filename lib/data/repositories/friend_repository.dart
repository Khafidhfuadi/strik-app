import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:strik_app/data/models/user_model.dart';

class FriendRepository {
  final SupabaseClient _supabase;

  FriendRepository(this._supabase);

  // Send a friend request
  Future<void> sendRequest(String receiverId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _supabase.from('friendships').insert({
      'requester_id': user.id,
      'receiver_id': receiverId,
      'status': 'pending',
    });

    // Notify receiver
    await sendNotification(
      recipientId: receiverId,
      type: 'friend_request',
      title: 'Teman Baru!',
      body: 'Seseorang ingin berteman denganmu!',
    );
  }

  // Accept a friend request
  Future<void> acceptRequest(String friendshipId) async {
    // Get requester ID before updating
    final friendship = await _supabase
        .from('friendships')
        .select('requester_id')
        .eq('id', friendshipId)
        .single();
    final requesterId = friendship['requester_id'];

    await _supabase
        .from('friendships')
        .update({
          'status': 'accepted',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', friendshipId);

    // Notify requester
    if (requesterId != null) {
      await sendNotification(
        recipientId: requesterId,
        type: 'friend_accept',
        title: 'Hore!',
        body: 'Permintaan pertemananmu diterima!',
      );
    }
  }

  // Get friendship details
  Future<Map<String, dynamic>?> getFriendship(String friendshipId) async {
    return await _supabase
        .from('friendships')
        .select()
        .eq('id', friendshipId)
        .maybeSingle();
  }

  // Reject a friend request (can also be used to remove friend)
  Future<void> rejectRequest(String friendshipId) async {
    await _supabase.from('friendships').delete().eq('id', friendshipId);
  }

  // Remove an existing friend
  Future<void> removeFriend(String friendId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Find and delete the friendship where current user is either requester or receiver
    await _supabase
        .from('friendships')
        .delete()
        .or('requester_id.eq.${user.id},receiver_id.eq.${user.id}')
        .or('requester_id.eq.$friendId,receiver_id.eq.$friendId')
        .eq('status', 'accepted');
  }

  // Get list of friends (accepted status)
  Future<List<UserModel>> getFriends() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    // Fetch friendships where user is requester or receiver AND status is accepted
    final response = await _supabase
        .from('friendships')
        .select('requester_id, receiver_id')
        .or('requester_id.eq.${user.id},receiver_id.eq.${user.id}')
        .eq('status', 'accepted');

    List<String> friendIds = [];
    for (var record in response) {
      if (record['requester_id'] == user.id) {
        friendIds.add(record['receiver_id'] as String);
      } else {
        friendIds.add(record['requester_id'] as String);
      }
    }

    if (friendIds.isEmpty) return [];

    // Fetch profiles of friends
    final profilesResponse = await _supabase
        .from('profiles')
        .select()
        .inFilter('id', friendIds);

    return (profilesResponse as List)
        .map((e) => UserModel.fromJson(e))
        .toList();
  }

  // Get pending friend requests received by currentUser
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('friendships')
        .select('''
      *,
      sender:profiles!requester_id(*)
    ''')
        .eq('receiver_id', user.id)
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(response);
  }

  // Get pending friend requests SENT by currentUser
  Future<List<Map<String, dynamic>>> getSentRequests() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('friendships')
        .select('''
      *,
      receiver:profiles!receiver_id(*)
    ''')
        .eq('requester_id', user.id)
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(response);
  }

  // Send a nudge (notification)
  Future<void> sendNudge(String recipientId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Check if nudge already sent recently (optional debounce) or just send
    await _supabase.from('notifications').insert({
      'recipient_id': recipientId,
      'sender_id': user.id,
      'type': 'nudge',
      'title': 'Strik!',
      'body': 'Temanmu mengingatkan untuk mengerjakan habit!',
    });
  }

  // Get notifications (Paginated)
  Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 10,
    DateTime? beforeDate,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    // filters first
    var query = _supabase
        .from('notifications')
        .select('*, sender:profiles!sender_id(*)')
        .eq('recipient_id', user.id);

    if (beforeDate != null) {
      query = query.lt('created_at', beforeDate.toUtc().toIso8601String());
    }

    // modifiers last
    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  // Delete a notification
  Future<void> deleteNotification(String id) async {
    await _supabase.from('notifications').delete().eq('id', id);
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String id) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
  }

  // Mark all notifications as read for current user
  Future<void> markAllNotificationsAsRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', user.id)
        .eq('is_read', false);
  }

  // Get leaderboard data (Friends + Self) with fair scoring
  // Score = (Completion Rate × 100) + (Total Completed × 0.5)
  Future<List<Map<String, dynamic>>> getLeaderboard({
    DateTime? referenceDate,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    // 1. Get all friends
    final friends = await getFriends();

    // 2. Add self to the list
    final selfProfileRes = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
    final selfUser = UserModel.fromJson(selfProfileRes);

    final allUsers = [...friends, selfUser];

    // 3. Calculate start of week (Effective Cycle Start = Monday 08:00 AM)
    final now = referenceDate ?? DateTime.now();

    // Find 'current' Monday of this calendar week
    final calendarWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final calendarMonday8am = DateTime(
      calendarWeekStart.year,
      calendarWeekStart.month,
      calendarWeekStart.day,
      8,
      0,
    );

    // Determine scoring cycle start:
    // If we are BEFORE Monday 12:00 PM (Freeze Time ends), we show the PREVIOUS cycle.
    // Freeze Time: Mon 08:00 - 12:00. During this time, we show the results of the cycle that ended at 08:00.
    final freezeEnd = calendarMonday8am.add(const Duration(hours: 4));

    DateTime startOfWeek;
    if (now.isBefore(freezeEnd)) {
      // Still in previous cycle view (including freeze time)
      startOfWeek = calendarMonday8am.subtract(const Duration(days: 7));
    } else {
      // New cycle started
      startOfWeek = calendarMonday8am;
    }

    // Calculate end of week for habit filtering and log bounding
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    print('--- GET LEADERBOARD DEBUG ---');
    print('Ref Date: $now');
    print('Scoring Cycle: $startOfWeek TO $endOfWeek');

    List<Map<String, dynamic>> leaderboard = [];

    for (var u in allUsers) {
      final habitIds = await _getHabitIdsForUser(u.id);
      if (habitIds.isEmpty) {
        // print('User ${u.username} has no habits.');
        leaderboard.add({
          'user': u,
          'score': 0.0,
          'completionRate': 0.0,
          'totalCompleted': 0,
          'totalExpected': 0,
          'totalHabits': 0,
        });
        continue;
      }

      // Get habits that existed during this scoring period
      // Only include habits created BEFORE the end of this period
      final habitsRes = await _supabase
          .from('habits')
          .select('id, frequency, days_of_week, frequency_count, created_at')
          .eq('user_id', u.id)
          .lte('created_at', endOfWeek.toUtc().toIso8601String());

      print(
        'User ${u.username}: Found ${habitsRes.length} active habits for period.',
      );

      // Calculate expected completions for the week
      int totalExpected = 0;
      final List<String> activeHabitIds = [];

      for (var habit in habitsRes) {
        activeHabitIds.add(habit['id'] as String);

        final frequency = habit['frequency'] as String;
        if (frequency == 'daily') {
          // Check if specific days are selected
          final daysOfWeek = habit['days_of_week'] as List?;
          if (daysOfWeek != null && daysOfWeek.isNotEmpty) {
            totalExpected += daysOfWeek.length; // Count selected days
          } else {
            totalExpected += 7; // Every day if no specific days
          }
        } else if (frequency == 'weekly') {
          final weeklyFreq = habit['frequency_count'] as int? ?? 1;
          totalExpected += weeklyFreq.clamp(0, 7);
        } else if (frequency == 'monthly') {
          // For monthly, use frequency_count as times per week
          final monthlyFreq = habit['frequency_count'] as int? ?? 1;
          totalExpected += monthlyFreq.clamp(0, 7);
        }
      }

      // Skip if no active habits during that period
      if (activeHabitIds.isEmpty) {
        leaderboard.add({
          'user': u,
          'score': 0.0,
          'completionRate': 0.0,
          'totalCompleted': 0,
          'totalExpected': 0,
          'totalHabits': 0,
        });
        continue;
      }

      // Count actual completions strictly within the week window
      // [startOfWeek, endOfWeek)
      print(
        'Querying logs for ${u.username}: >= $startOfWeek AND < $endOfWeek',
      );

      final completedRes = await _supabase
          .from('habit_logs')
          .select('id, completed_at') // Select completed_at for validation
          .eq('status', 'completed')
          .gte('completed_at', startOfWeek.toUtc().toIso8601String())
          .lt(
            'completed_at',
            endOfWeek.toUtc().toIso8601String(),
          ) // Strict upper bound!
          .inFilter('habit_id', activeHabitIds);

      final totalCompleted = (completedRes as List).length;
      print('User ${u.username}: Total Completed = $totalCompleted');
      if (totalCompleted > 0) {
        print(
          'Sample log dates: ${completedRes.take(3).map((e) => e['completed_at'])}',
        );
      }

      // Calculate completion rate and hybrid score
      final completionRate = totalExpected > 0
          ? (totalCompleted / totalExpected) * 100
          : 0.0;
      final hybridScore = (completionRate * 1.0) + (totalCompleted * 0.5);

      print(
        'User ${u.username}: Score = $hybridScore (Rate: $completionRate%, Count: $totalCompleted/$totalExpected)',
      );

      leaderboard.add({
        'user': u,
        'score': hybridScore,
        'completionRate': completionRate,
        'totalCompleted': totalCompleted,
        'totalExpected': totalExpected,
        'totalHabits': habitsRes.length,
      });
    }

    // 4. Sort by hybrid score desc
    leaderboard.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );

    print('--- END LEADERBOARD DEBUG ---');
    return leaderboard;
  }

  // Snapshot the current (last week's) leaderboard to history
  Future<void> snapshotWeeklyLeaderboard(DateTime weekStartDate) async {
    // Get the leaderboard AS OF that week
    // We pass the reference date to ensure we get that specific week's data
    // Reference date: Add enough buffer to be safely AFTER the freeze period (Mon 08:00-12:00).
    // +12 hours puts us at Mon 20:00, which is safe.
    final leaderboard = await getLeaderboard(
      referenceDate: weekStartDate.add(const Duration(hours: 12)),
    );

    final dateStr = DateFormat('yyyy-MM-dd').format(weekStartDate);

    final totalParticipants = leaderboard.length;

    for (int i = 0; i < leaderboard.length; i++) {
      final entry = leaderboard[i];
      final user = entry['user'] as UserModel;

      try {
        await _supabase.from('weekly_leaderboards').insert({
          'week_start_date': dateStr,
          'user_id': user.id,
          'rank': i + 1,
          'total_points': double.parse(
            (entry['score'] as double).toStringAsFixed(1),
          ),
          'completion_rate': double.parse(
            (entry['completionRate'] as double).toStringAsFixed(1),
          ),
          'total_completed': entry['totalCompleted'],
          'total_participants': totalParticipants,
          'total_habits':
              entry['totalExpected'] ??
              0, // Changed to totalExpected as per user request
        });
      } catch (e) {
        // Ignore duplicate key errors if already snapshotted
        print('Error snapshotting for ${user.username}: $e');
      }
    }
  }

  // Fetch Leaderboard History
  Future<List<Map<String, dynamic>>> getLeaderboardHistory() async {
    final response = await _supabase
        .from('weekly_leaderboards')
        .select('*, user:profiles(*)')
        .order('week_start_date', ascending: false)
        .order('rank', ascending: true);

    // Group by week
    // But since we want to display a list of weeks, maybe just return raw for now
    // Or return unique weeks?
    // Let's return raw list, controller can process.
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getPreviousWeekWinners() async {
    // ONLY show winner during FREEZE TIME (Monday 08:00-12:00)
    final now = DateTime.now();

    // Check if we're in freeze time
    if (now.weekday != DateTime.monday || now.hour < 8 || now.hour >= 12) {
      return []; // Not in freeze time, don't show winner
    }

    // We're in freeze time. Calculate the cycle that JUST ended at 08:00 today.
    final calendarWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final todayMonday8am = DateTime(
      calendarWeekStart.year,
      calendarWeekStart.month,
      calendarWeekStart.day,
      8,
      0,
    );

    // The previous cycle ended at todayMonday8am, and started 7 days before
    final startOfLastCycle = todayMonday8am.subtract(const Duration(days: 7));
    final endOfLastCycle = todayMonday8am.subtract(const Duration(seconds: 1));

    // 2. Get all friends + self
    final friends = await getFriends();
    final selfProfileRes = await _supabase
        .from('profiles')
        .select()
        .eq('id', _supabase.auth.currentUser!.id)
        .single();
    final selfUser = UserModel.fromJson(selfProfileRes);
    final allUsers = [...friends, selfUser];

    // 3. Calculate scores for all users
    final List<Map<String, dynamic>> leaderboard = [];

    for (var u in allUsers) {
      final habitIds = await _getHabitIdsForUser(u.id);
      if (habitIds.isEmpty) continue;

      // Get habits that existed during the previous cycle
      final habitsRes = await _supabase
          .from('habits')
          .select('id, frequency, days_of_week, frequency_count, created_at')
          .eq('user_id', u.id)
          .lte('created_at', endOfLastCycle.toUtc().toIso8601String());

      int totalExpected = 0;
      final List<String> activeHabitIds = [];

      for (var habit in habitsRes) {
        activeHabitIds.add(habit['id'] as String);

        final frequency = habit['frequency'] as String;
        if (frequency == 'daily') {
          final daysOfWeek = habit['days_of_week'] as List?;
          if (daysOfWeek != null && daysOfWeek.isNotEmpty) {
            totalExpected += daysOfWeek.length;
          } else {
            totalExpected += 7;
          }
        } else if (frequency == 'weekly') {
          final weeklyFreq = habit['frequency_count'] as int? ?? 1;
          totalExpected += weeklyFreq.clamp(0, 7);
        } else if (frequency == 'monthly') {
          final monthlyFreq = habit['frequency_count'] as int? ?? 1;
          totalExpected += monthlyFreq.clamp(0, 7);
        }
      }

      // Skip if no active habits during that period
      if (activeHabitIds.isEmpty) continue;

      // Count actual completions in PREVIOUS CYCLE
      final countRes = await _supabase
          .from('habit_logs')
          .select('id')
          .eq('status', 'completed')
          .gte('completed_at', startOfLastCycle.toUtc().toIso8601String())
          .lte('completed_at', endOfLastCycle.toUtc().toIso8601String())
          .inFilter('habit_id', activeHabitIds);

      final totalCompleted = (countRes as List).length;

      // Calculate hybrid score
      final completionRate = totalExpected > 0
          ? (totalCompleted / totalExpected) * 100
          : 0.0;
      final hybridScore = (completionRate * 1.0) + (totalCompleted * 0.5);

      if (hybridScore > 0) {
        leaderboard.add({'user': u, 'score': hybridScore});
      }
    }

    // Sort by score desc
    leaderboard.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );

    // Return top 3
    return leaderboard.take(3).toList();
  }

  Future<List<String>> _getHabitIdsForUser(String userId) async {
    final res = await _supabase
        .from('habits')
        .select('id')
        .eq('user_id', userId);
    return (res as List).map((e) => e['id'] as String).toList();
  }

  // Create a new post
  Future<void> createPost(String content) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Fetch user profile to get username
    final userProfile = await _supabase
        .from(
          'profiles',
        ) // Changed from 'users' to 'profiles' based on other code
        .select('username')
        .eq('id', user.id)
        .single();
    final username = userProfile['username'] ?? 'Temanmu';

    final res = await _supabase
        .from('posts')
        .insert({'user_id': user.id, 'content': content})
        .select()
        .single();

    // Fan-out notification to all friends
    final friends = await getFriends();
    for (var friend in friends) {
      await sendNotification(
        recipientId: friend.id,
        type: 'new_post',
        title: 'Feed Baru!',
        body: '$username baru saja nge-feed, klik notif biar ga FOMO!',
        postId: res['id'],
      );
    }
  }

  // Delete a post
  Future<void> deletePost(String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Supabase RLS should handle ownership check, but good to be safe
    await _supabase
        .from('posts')
        .delete()
        .eq('id', postId)
        .eq('user_id', user.id);
  }

  // Toggle reaction (Fire)
  Future<void> toggleReaction({
    String? postId,
    String? habitLogId,
    String type = 'fire',
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Check if reaction exists
    final query = _supabase.from('reactions').select().eq('user_id', user.id);
    dynamic response;

    if (postId != null) {
      response = await query.eq('post_id', postId).maybeSingle();
    } else if (habitLogId != null) {
      response = await query.eq('habit_log_id', habitLogId).maybeSingle();
    }

    if (response != null) {
      // Delete existing reaction
      await _supabase.from('reactions').delete().eq('id', response['id']);
    } else {
      // Create new reaction
      await _supabase.from('reactions').insert({
        'user_id': user.id,
        'post_id': postId,
        'habit_log_id': habitLogId,
        'type': type,
      });
    }
  }

  // Get Activity Feed (Mixed: Habits + Posts) - Paginated
  Future<List<Map<String, dynamic>>> getActivityFeed({
    int limit = 10,
    DateTime? beforeDate,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    // 1. Get friend IDs + Self ID (to see own posts too)
    final friends = await getFriends();
    final friendIds = friends.map((e) => e.id).toList();
    friendIds.add(user.id);

    if (friendIds.isEmpty) return [];

    // Use current time if no cursor provided
    final cursorDate = beforeDate ?? DateTime.now();
    final cursorIso = cursorDate.toUtc().toIso8601String();

    // Fetch posts only (habit_logs removed - auto-posts are created instead)
    final postsResponse = await _supabase
        .from('posts')
        .select('''
          *,
          user:profiles(*),
          reactions:reactions(*)
        ''')
        .inFilter('user_id', friendIds)
        .lt('created_at', cursorIso) // Cursor filter
        .order('created_at', ascending: false)
        .limit(limit);

    // Convert posts to feed format
    final mixedFeed = <Map<String, dynamic>>[];

    for (var post in postsResponse) {
      mixedFeed.add({
        'type': 'post',
        'data': post,
        'timestamp': DateTime.parse(post['created_at']),
      });
    }

    mixedFeed.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

    // Return only 'limit' items to keep page size consistent
    return mixedFeed.take(limit).toList();
  }

  // Get Single Post (for Realtime)
  Future<Map<String, dynamic>?> getPostById(String postId) async {
    final response = await _supabase
        .from('posts')
        .select('''
          *,
          user:profiles(*),
          reactions:reactions(*)
        ''')
        .eq('id', postId)
        .maybeSingle();

    if (response == null) return null;

    return {
      'type': 'post',
      'data': response,
      'timestamp': DateTime.parse(response['created_at']),
    };
  }

  // Get Single Habit Log (for Realtime)
  Future<Map<String, dynamic>?> getHabitLogById(String habitLogId) async {
    final response = await _supabase
        .from('habit_logs')
        .select('''
          *,
          habit:habits!inner(
            title,
            user:profiles!inner(*)
          ),
          reactions:reactions(*)
        ''')
        .eq('id', habitLogId)
        .maybeSingle();

    if (response == null) return null;

    return {
      'type': 'habit_log',
      'data': response,
      'timestamp': DateTime.parse(response['completed_at']),
    };
  }

  // Send Notification
  Future<void> sendNotification({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    String? postId,
    String? habitLogId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final notificationData = {
        'recipient_id': recipientId,
        'sender_id': user.id,
        'type': type,
        'title': title,
        'body': body,
      };

      if (postId != null) notificationData['post_id'] = postId;
      if (habitLogId != null) notificationData['habit_log_id'] = habitLogId;

      await _supabase.from('notifications').insert(notificationData);
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Check last poke time (based on notifications)
  Future<DateTime?> getLastPokeTime(String recipientId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('notifications')
        .select('created_at')
        .eq('sender_id', user.id)
        .eq('recipient_id', recipientId)
        .eq('type', 'poke')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response != null && response['created_at'] != null) {
      return DateTime.parse(response['created_at']);
    }
    return null;
  }

  // Search users by username
  Future<List<UserModel>> searchUsers(String query) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    if (query.isEmpty) return [];

    final response = await _supabase
        .from('profiles')
        .select()
        .ilike('username', '%$query%')
        .neq('id', user.id) // Exclude self
        .limit(20);

    return (response as List).map((e) => UserModel.fromJson(e)).toList();
  }

  // Get active habit count for a user via RPC (bypasses RLS)
  Future<int> getUserActiveHabitCount(String userId) async {
    try {
      final response = await _supabase.rpc(
        'get_user_active_habit_count',
        params: {'target_user_id': userId},
      );
      return (response as int?) ?? 0;
    } catch (e) {
      print('Error counting active habits: $e');
      return 0;
    }
  }

  // Get User Profile Details including friend status
  Future<Map<String, dynamic>> getUserProfileDetails(
    String targetUserId,
  ) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception('User not logged in');

    // 1. Fetch User Profile
    final profileRes = await _supabase
        .from('profiles')
        .select()
        .eq('id', targetUserId)
        .single();

    final user = UserModel.fromJson(profileRes);

    // 2. Fetch Active Habit Count
    final habitCount = await getUserActiveHabitCount(targetUserId);

    // 3. Determine Friend Status
    String status = 'none';

    if (currentUser.id == targetUserId) {
      status = 'self';
    } else {
      // Check friendship status
      // Check if they are friends (accepted)
      final friendCheck = await _supabase
          .from('friendships')
          .select('status, requester_id, receiver_id')
          .or(
            'requester_id.eq.${currentUser.id},receiver_id.eq.${currentUser.id}',
          )
          .or('requester_id.eq.$targetUserId,receiver_id.eq.$targetUserId')
          .maybeSingle();

      if (friendCheck != null) {
        final dbStatus = friendCheck['status'] as String;
        if (dbStatus == 'accepted') {
          status = 'accepted';
        } else if (dbStatus == 'pending') {
          if (friendCheck['requester_id'] == currentUser.id) {
            status = 'sent';
          } else {
            status = 'pending'; // Received
          }
        }
      }
    }

    return {
      'user': user,
      'active_habit_count': habitCount,
      'friendship_status': status, // self, none, pending, sent, accepted
    };
  }
}
