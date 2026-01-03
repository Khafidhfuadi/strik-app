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
