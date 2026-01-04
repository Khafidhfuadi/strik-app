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
          'updated_at': DateTime.now().toIso8601String(),
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

  // Reject a friend request (can also be used to remove friend)
  Future<void> rejectRequest(String friendshipId) async {
    await _supabase.from('friendships').delete().eq('id', friendshipId);
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

  // Get notifications
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('notifications')
        .select('*, sender:profiles!sender_id(*)')
        .eq('recipient_id', user.id)
        .order('created_at', ascending: false)
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String id) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
  }

  // Get leaderboard data (Friends + Self)
  // Consumes a lot of reads if friends list is huge, but fine for MVP
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    // 1. Get all friends
    final friends = await getFriends();

    // 2. Add self to the list
    // We need our own profile first
    final selfProfileRes = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
    final selfUser = UserModel.fromJson(selfProfileRes);

    final allUsers = [...friends, selfUser];

    // 3. For each user, count completed habits in CURRENT WEEK (starting Monday)
    final now = DateTime.now();
    // Calculate start of week (Monday)
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(
      currentWeekStart.year,
      currentWeekStart.month,
      currentWeekStart.day,
    );

    List<Map<String, dynamic>> leaderboard = [];

    for (var u in allUsers) {
      // Aggregate query would be better in SQL function, but doing in client for speed of dev
      // Count 'completed' logs since start of week
      final countRes = await _supabase
          .from('habit_logs')
          .select('id') // just select id to count
          .eq('status', 'completed')
          .gte('completed_at', startOfWeek.toUtc().toIso8601String())
          .inFilter(
            'habit_id',
            (await _getHabitIdsForUser(u.id)),
          ); // Helper needed to get habit IDs for user

      leaderboard.add({'user': u, 'score': (countRes as List).length});
    }

    // 4. Sort by score desc
    leaderboard.sort(
      (a, b) => (b['score'] as int).compareTo(a['score'] as int),
    );

    return leaderboard;
  }

  Future<UserModel?> getPreviousWeekWinner() async {
    // 1. Get dates for previous week
    final now = DateTime.now();
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final startOfCurrentWeek = DateTime(
      currentWeekStart.year,
      currentWeekStart.month,
      currentWeekStart.day,
    );

    final endOfLastWeek = startOfCurrentWeek.subtract(
      const Duration(seconds: 1),
    );
    final startOfLastWeek = startOfCurrentWeek.subtract(
      const Duration(days: 7),
    );

    // 2. Get all friends + self
    // Note: duplicated logic from getLeaderboard, refactor if time permits
    final friends = await getFriends();
    final selfProfileRes = await _supabase
        .from('profiles')
        .select()
        .eq('id', _supabase.auth.currentUser!.id)
        .single();
    final selfUser = UserModel.fromJson(selfProfileRes);
    final allUsers = [...friends, selfUser];

    // 3. Find winner
    UserModel? winner;
    int maxScore = -1;

    for (var u in allUsers) {
      final countRes = await _supabase
          .from('habit_logs')
          .select('id')
          .eq('status', 'completed')
          .gte('completed_at', startOfLastWeek.toIso8601String())
          .lte('completed_at', endOfLastWeek.toIso8601String())
          .inFilter('habit_id', (await _getHabitIdsForUser(u.id)));

      final score = (countRes as List).length;
      if (score > maxScore) {
        maxScore = score;
        winner = u;
      }
    }

    // Only return winner if they actually did something (> 0 habits)
    if (maxScore > 0) return winner;
    return null;
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
        title: 'Update Baru!',
        body: 'Temanmu baru saja membuat postingan. Cek yuk!',
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
}
