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
  }

  // Accept a friend request
  Future<void> acceptRequest(String friendshipId) async {
    await _supabase
        .from('friendships')
        .update({
          'status': 'accepted',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', friendshipId);
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

    // Fetch pending requests where user is the receiver
    // We also want the profile of the requester
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

    // 3. For each user, count completed habits in last 7 days
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    List<Map<String, dynamic>> leaderboard = [];

    for (var u in allUsers) {
      // Aggregate query would be better in SQL function, but doing in client for speed of dev
      // Count 'completed' logs in last 7 days
      final countRes = await _supabase
          .from('habit_logs')
          .select('id') // just select id to count
          .eq('status', 'completed')
          .gte('completed_at', sevenDaysAgo.toIso8601String())
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

  Future<List<String>> _getHabitIdsForUser(String userId) async {
    final res = await _supabase
        .from('habits')
        .select('id')
        .eq('user_id', userId);
    return (res as List).map((e) => e['id'] as String).toList();
  }

  // Get Activity Feed
  // Shows recent completions from friends
  Future<List<Map<String, dynamic>>> getActivityFeed() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    // 1. Get friend IDs
    final friends = await getFriends();
    final friendIds = friends.map((e) => e.id).toList();

    if (friendIds.isEmpty) return [];

    // 2. Query logs from these users
    final response = await _supabase
        .from('habit_logs')
        .select('''
          *,
          habit:habits!inner(
            title,
            user:profiles!inner(*)
          )
        ''')
        .eq('status', 'completed')
        .inFilter(
          'habit.user_id',
          friendIds,
        ) // This filter might be tricky with nested relations in Supabase
        // Alternative: Filter by habit_id where habit.user_id IN friends.
        // Simpler approach:
        // Get all habits of friends first? No, too many.
        // Deep filtering in Supabase is possible.
        // Let's try to filter by the top-level habit relation if possible, or use a customized query.
        // Actually, 'habit.user_id' works if using "!inner" join on habits.
        .order('completed_at', ascending: false)
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
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
