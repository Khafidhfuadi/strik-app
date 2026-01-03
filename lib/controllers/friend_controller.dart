import 'package:get/get.dart';
import 'package:strik_app/data/models/user_model.dart';
import 'package:strik_app/data/repositories/friend_repository.dart';
import 'package:strik_app/main.dart'; // Access global supabase client

import 'package:supabase_flutter/supabase_flutter.dart';

class FriendController extends GetxController {
  final FriendRepository _friendRepository = FriendRepository(supabase);

  var friends = <UserModel>[].obs;
  var pendingRequests = <Map<String, dynamic>>[].obs;
  var sentRequests = <Map<String, dynamic>>[].obs;
  var searchResults = <UserModel>[].obs;

  var isLoadingFriends = true.obs;
  var isLoadingRequests = true.obs;
  var isSearching = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchFriends();
    fetchPendingRequests();
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    // Subscribe to public.posts
    supabase
        .channel('public:posts')
        .onPostgresChanges(
          event:
              PostgresChangeEvent.all, // Listen to ALL events (Insert & Delete)
          schema: 'public',
          table: 'posts',
          callback: (payload) async {
            if (payload.eventType == PostgresChangeEvent.insert) {
              final newPostId = payload.newRecord['id'];
              if (newPostId != null) {
                final newPost = await _friendRepository.getPostById(newPostId);
                if (newPost != null) {
                  activityFeed.insert(0, newPost);
                  newFeedCount.value++;
                }
              }
            } else if (payload.eventType == PostgresChangeEvent.delete) {
              final deletedId = payload.oldRecord['id'];
              if (deletedId != null) {
                activityFeed.removeWhere(
                  (item) =>
                      item['type'] == 'post' && item['data']['id'] == deletedId,
                );
              }
            }
          },
        )
        .subscribe();

    // Subscribe to public.habit_logs
    supabase
        .channel('public:habit_logs')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'habit_logs',
          callback: (payload) async {
            // Only care about completed logs
            if (payload.newRecord['status'] == 'completed') {
              final newLogId = payload.newRecord['id'];
              if (newLogId != null) {
                final newLog = await _friendRepository.getHabitLogById(
                  newLogId,
                );
                if (newLog != null) {
                  activityFeed.insert(0, newLog);
                  newFeedCount.value++;
                }
              }
            }
          },
        )
        .subscribe();

    // Subscribe to public.reactions
    supabase
        .channel('public:reactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reactions',
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.insert) {
              _handleNewReaction(payload.newRecord);
            } else if (payload.eventType == PostgresChangeEvent.delete) {
              _handleDeletedReaction(payload.oldRecord);
            }
          },
        )
        .subscribe();

    // Subscribe to public.notifications (for user)
    // Assuming RLS allows us to receive our own notifications or we filter client side?
    // Realtime usually broadcasts all unless set up otherwise, but RLS on SELECT applies to initial fetch,
    // Realtime RLS is separate config. Assuming "broadcast" is enabled for table.
    // We will just filter by recipient_id here to be safe/simple for now.
    final myId = supabase.auth.currentUser?.id;
    if (myId != null) {
      supabase
          .channel('public:notifications')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'recipient_id',
              value: myId,
            ),
            callback: (payload) {
              Get.snackbar(
                payload.newRecord['title'] ?? 'Notif',
                payload.newRecord['body'] ?? 'Punya update baru nih!',
                snackPosition: SnackPosition.TOP,
              );
              // Refresh notifications list if we had one
              // fetchNotifications();
            },
          )
          .subscribe();
    }
  }

  void _handleNewReaction(Map<String, dynamic> reaction) {
    // Find item in feed
    final postId = reaction['post_id'];
    final habitLogId = reaction['habit_log_id'];

    int index = -1;
    if (postId != null) {
      index = activityFeed.indexWhere(
        (item) => item['type'] == 'post' && item['data']['id'] == postId,
      );
    } else if (habitLogId != null) {
      index = activityFeed.indexWhere(
        (item) =>
            item['type'] == 'habit_log' && item['data']['id'] == habitLogId,
      );
    }

    if (index != -1) {
      final item = activityFeed[index];
      final updatedData = Map<String, dynamic>.from(item['data']);
      final reactions = List<dynamic>.from(updatedData['reactions'] ?? []);

      // Check if reaction from this user already exists
      final existingIndex = reactions.indexWhere(
        (r) => r['user_id'] == reaction['user_id'],
      );

      if (existingIndex != -1) {
        // If existing is optimistic, replace it with real one
        final existing = reactions[existingIndex];
        if (existing['id'].toString().startsWith('optimistic_')) {
          reactions[existingIndex] = reaction;
        }
        // If it's real (duplicate event?), do nothing
      } else {
        // No existing reaction, add it
        reactions.add(reaction);
      }

      updatedData['reactions'] = reactions;
      item['data'] = updatedData;
      activityFeed[index] = item;
    }
  }

  void _handleDeletedReaction(Map<String, dynamic> oldRecord) {
    // Delete event might only contain ID depending on replica identity.
    // If we have ID, we have to search ALL reactions... which is slow.
    // Or we just fetchFeed again? Seamless is better.
    // Assuming we have ID.
    final id = oldRecord['id'];
    if (id == null) return;

    // Iterate to find where this reaction lives
    for (int i = 0; i < activityFeed.length; i++) {
      final item = activityFeed[i];
      final data = item['data'];
      final reactions = data['reactions'] as List?;
      if (reactions != null) {
        final rIndex = reactions.indexWhere((r) => r['id'] == id);
        if (rIndex != -1) {
          // Found it! Remove it.
          final updatedData = Map<String, dynamic>.from(data);
          final newReactions = List<dynamic>.from(reactions);
          newReactions.removeAt(rIndex);
          updatedData['reactions'] = newReactions;

          item['data'] = updatedData;
          activityFeed[i] = item;
          return;
        }
      }
    }
  }

  Future<void> fetchFriends() async {
    try {
      isLoadingFriends.value = true;
      friends.value = await _friendRepository.getFriends();
    } catch (e) {
      print('Error fetching friends: $e');
    } finally {
      isLoadingFriends.value = false;
    }
  }

  Future<void> fetchPendingRequests() async {
    try {
      isLoadingRequests.value = true;
      pendingRequests.value = await _friendRepository.getPendingRequests();
      sentRequests.value = await _friendRepository.getSentRequests();
    } catch (e) {
      print('Error fetching requests: $e');
    } finally {
      isLoadingRequests.value = false;
    }
  }

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      searchResults.clear();
      return;
    }

    try {
      isSearching.value = true;
      searchResults.value = await _friendRepository.searchUsers(query);
    } catch (e) {
      Get.snackbar('Waduh!', 'Gagal nyari bestie nih, coba lagi ya! 🧐');
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> sendFriendRequest(String userId) async {
    try {
      await _friendRepository.sendRequest(userId);
      Get.snackbar('Yeay!', 'Request sent! Tungguin di-acc ya bestie!');
      // Update search result UI state if needed to show "Sent"
    } catch (e) {
      if (e is PostgrestException && e.code == '23505') {
        Get.snackbar('Eits!', 'Udah pernah request atau udah temenan kok! 😅');
      } else {
        print(e);
        Get.snackbar('Yah...', 'Gagal ngirim request, sinyal aman? 🥺');
      }
    }
  }

  Future<void> acceptRequest(String friendshipId) async {
    try {
      await _friendRepository.acceptRequest(friendshipId);
      Get.snackbar('Gas!', 'Udah temenan nih! Yuk, compete! 🤩');
      fetchPendingRequests();
      fetchFriends();
    } catch (e) {
      Get.snackbar('Ups...', 'Gagal nerima request, coba lagi dong! 😢');
    }
  }

  Future<void> rejectRequest(String friendshipId) async {
    try {
      await _friendRepository.rejectRequest(friendshipId);
      Get.snackbar('Oke deh', 'Request ditolak. Gapapa, cari bestie lain! 👋');
      fetchPendingRequests();
    } catch (e) {
      Get.snackbar('Waduh', 'Gagal nolak request, error nih! 😵');
    }
  }

  // --- Engagement Features ---

  var leaderboard = <Map<String, dynamic>>[].obs;
  var activityFeed = <Map<String, dynamic>>[].obs;
  var notifications = <Map<String, dynamic>>[].obs;
  var isLoadingLeaderboard = false.obs;
  var isLoadingActivity = false.obs;

  var newFeedCount = 0.obs;
  DateTime? _lastViewedFeedTime;

  Future<void> fetchLeaderboard() async {
    try {
      isLoadingLeaderboard.value = true;
      leaderboard.value = await _friendRepository.getLeaderboard();
    } catch (e) {
      print('Error fetching leaderboard: $e');
    } finally {
      isLoadingLeaderboard.value = false;
    }
  }

  var isCreatingPost = false.obs;

  Future<void> fetchActivityFeed() async {
    try {
      isLoadingActivity.value = true;
      activityFeed.value = await _friendRepository.getActivityFeed();

      // Calculate new feed count
      if (_lastViewedFeedTime == null) {
        newFeedCount.value = activityFeed.length;
      } else {
        newFeedCount.value = activityFeed.where((item) {
          // Repository now returns 'timestamp' as DateTime object in the map
          final date = item['timestamp'] as DateTime;
          return date.isAfter(_lastViewedFeedTime!);
        }).length;
      }
    } catch (e) {
      print('Error fetching activity feed: $e');
    } finally {
      isLoadingActivity.value = false;
    }
  }

  Future<void> createPost(String content) async {
    if (content.trim().isEmpty) return;

    try {
      isCreatingPost.value = true;
      await _friendRepository.createPost(content);
      Get.snackbar('Mantap!', 'Postingan udah naik nih! 🔥');
      fetchActivityFeed(); // Refresh feed
    } catch (e) {
      Get.snackbar('Waduh', 'Gagal posting, sinyal aman? 🤯');
      isCreatingPost.value = false;
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      // Optimistic update
      activityFeed.removeWhere(
        (item) => item['type'] == 'post' && item['data']['id'] == postId,
      );

      await _friendRepository.deletePost(postId);
      Get.snackbar('Sip!', 'Postingan udah dihapus! 🗑️');
    } catch (e) {
      Get.snackbar('Waduh', 'Gagal hapus postingan, error nih! 😵');
      fetchActivityFeed(); // Revert
    }
  }

  Future<void> toggleReaction({String? postId, String? habitLogId}) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // 1. Find item index
      int index = -1;
      if (postId != null) {
        index = activityFeed.indexWhere(
          (item) => item['type'] == 'post' && item['data']['id'] == postId,
        );
      } else if (habitLogId != null) {
        index = activityFeed.indexWhere(
          (item) =>
              item['type'] == 'habit_log' && item['data']['id'] == habitLogId,
        );
      }

      if (index == -1) return;

      // 2. Determine action (Add or Remove) based on current state
      final item = activityFeed[index];
      final data = item['data'];
      final reactions = List<dynamic>.from(data['reactions'] ?? []);
      final myReactionIndex = reactions.indexWhere(
        (r) => r['user_id'] == currentUser.id,
      );

      // 3. Optimistic Update
      final updatedData = Map<String, dynamic>.from(data);
      final updatedReactions = List<dynamic>.from(reactions);

      if (myReactionIndex != -1) {
        // Remove reaction
        updatedReactions.removeAt(myReactionIndex);
      } else {
        // Add fake reaction (ID will be replaced by Realtime)
        updatedReactions.add({
          'id': 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
          'user_id': currentUser.id,
          'post_id': postId,
          'habit_log_id': habitLogId,
          'type': 'fire',
        });
      }

      updatedData['reactions'] = updatedReactions;
      item['data'] = updatedData;
      activityFeed[index] = item; // Trigger UI update via Obx

      // 4. API Call
      await _friendRepository.toggleReaction(
        postId: postId,
        habitLogId: habitLogId,
      );

      // No fetchActivityFeed()! Realtime will conform the state.
    } catch (e) {
      print('Error reacting: $e');
      // Ideally revert optimistic update here
      Get.snackbar('Waduh', 'Gagal ngasih reaction! 😢');
    }
  }

  void markFeedAsViewed() {
    newFeedCount.value = 0;
    _lastViewedFeedTime = DateTime.now();
  }

  Future<void> fetchNotifications() async {
    try {
      notifications.value = await _friendRepository.getNotifications();
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  Future<void> sendNudge(String userId) async {
    try {
      await _friendRepository.sendNudge(userId);
      Get.snackbar('Terciduk!', 'Udah dicolek! Semoga dia peka ya! 🫣');
    } catch (e) {
      Get.snackbar('Yah...', 'Gagal nyolek, dia lagi sibuk kali ya? 😔');
    }
  }
}
