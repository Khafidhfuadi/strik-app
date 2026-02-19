import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:strik_app/data/models/user_model.dart';
import 'package:strik_app/data/repositories/friend_repository.dart';
import 'package:strik_app/controllers/story_controller.dart'; // Added
import 'package:strik_app/main.dart'; // Access global supabase client
import 'package:strik_app/controllers/gamification_controller.dart';

// import 'package:google_fonts/google_fonts.dart'; // Removed
// import 'package:lottie/lottie.dart'; // Unused for now
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/widgets/primary_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FriendController extends GetxController {
  final FriendRepository _friendRepository = FriendRepository(supabase);

  var friends = <UserModel>[].obs;
  var pendingRequests = <Map<String, dynamic>>[].obs;
  var sentRequests = <Map<String, dynamic>>[].obs;
  var searchResults = <UserModel>[].obs;

  var isLoadingFriends = true.obs;
  var isLoadingRequests = true.obs;
  var isSearching = false.obs;

  // Leaderboard Transition Logic
  var isTransitionPeriod = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchFriends();
    fetchPendingRequests();
    _subscribeToRealtime();
    fetchNotifications();
    // checkWeeklyWinner(); // Removed - popup dialog disabled
    _loadLastViewedTime();

    // Initial fetch
    fetchActivityFeed();
    fetchLeaderboard();
  }

  Future<void> _loadLastViewedTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastViewedFeedMarker = prefs.getString('last_feed_marker');
    } catch (e) {
      print('Error loading last viewed marker: $e');
    }
  }

  bool _hasShownWinner = false;

  Future<void> checkWeeklyWinner() async {
    // Prevent duplicate dialogs in session
    if (_hasShownWinner) return;

    try {
      final winners = await _friendRepository.getPreviousWeekWinners();
      if (winners.isNotEmpty) {
        final rank1 = winners[0];
        final winnerUser = rank1['user'] as UserModel;

        // Since we are showing the winner, it means we are in the freeze period
        // Trigger a snapshot of the leaderboard for history
        // Use a safe reference date (Last Monday 08:00)
        final now = DateTime.now();
        final calendarWeekStart = now.subtract(Duration(days: now.weekday - 1));
        final lastWeekStart = DateTime(
          calendarWeekStart.year,
          calendarWeekStart.month,
          calendarWeekStart.day,
          8,
          0,
        ).subtract(const Duration(days: 7));

        // This is fire-and-forget to avoid blocking the UI
        _friendRepository.snapshotWeeklyLeaderboard(lastWeekStart);

        _hasShownWinner = true;

        // CHECK & AWARD XP FOR CURRENT USER (Top 3)
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null && Get.isRegistered<GamificationController>()) {
          final gameCtrl = Get.find<GamificationController>();

          for (int i = 0; i < winners.length; i++) {
            final u = winners[i]['user'] as UserModel;
            if (u.id == currentUser.id) {
              int xp = 0;
              if (i == 0) {
                xp = 50;
              } else if (i == 1)
                xp = 30;
              else if (i == 2)
                xp = 15;

              if (xp > 0) {
                // Award XP
                // Note: Ideally we check if already awarded for this specific week from logs,
                // but for now relying on session check + freeze time window.
                await gameCtrl.awardXP(
                  xp.toDouble(),
                  reason: 'Weekly Rank #${i + 1}',
                );
                Get.snackbar(
                  'Weekly Reward',
                  'Selamat! Kamu Juara ${i + 1} minggu lalu! +$xp XP',
                  backgroundColor: const Color(0xFFFFD700),
                  colorText: Colors.black,
                  duration: const Duration(seconds: 5),
                );
              }
              break;
            }
          }
        }

        // Wait a bit for app to settle
        await Future.delayed(const Duration(seconds: 2));

        Get.dialog(
          Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFD700), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lottie Trophy or Icon Placeholder for now if asset missing
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFFFD700),
                    size: 64,
                  ),
                  // Lottie.asset('assets/src/trophy.json', height: 100),
                  const SizedBox(height: 16),
                  Text(
                    'JUARA MINGGU LALU! 👑',
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: Color(0xFFFFD700),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: winnerUser.avatarUrl != null
                          ? NetworkImage(winnerUser.avatarUrl!)
                          : null,
                      backgroundColor: Colors.grey[800],
                      child: winnerUser.avatarUrl == null
                          ? Text(
                              winnerUser.username?[0].toUpperCase() ?? '?',
                              style: const TextStyle(
                                fontSize: 32,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    winnerUser.username ?? 'Unknown',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Menyala abangkuh! 🔥',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(text: 'Keren!', onPressed: () => Get.back()),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error checking winner: $e');
    }
  }

  // History Logic
  var leaderboardHistory = <Map<String, dynamic>>[].obs;
  var isLoadingHistory = false.obs;

  Future<void> fetchLeaderboardHistory() async {
    isLoadingHistory.value = true;
    try {
      leaderboardHistory.value = await _friendRepository
          .getLeaderboardHistory();
    } catch (e) {
      print('Error fetching history: $e');
    } finally {
      isLoadingHistory.value = false;
    }
  }

  // Historical Leaderboard Detail
  var historicalLeaderboard = <Map<String, dynamic>>[].obs;
  var isLoadingHistoricalLeaderboard = false.obs;

  Future<void> fetchHistoricalLeaderboard(DateTime referenceDate) async {
    isLoadingHistoricalLeaderboard.value = true;
    historicalLeaderboard.clear();
    try {
      // Add buffer to ensure we catch the week correctly (e.g. +12h from Monday 00:00)
      // The referenceDate passed from UI should be the Monday of that week.
      // FriendRepository.getLeaderboard uses a reference date to calculate the week.
      // If we pass Monday, it should work.
      historicalLeaderboard.value = await _friendRepository.getLeaderboard(
        referenceDate: referenceDate.add(const Duration(hours: 12)),
      );
    } catch (e) {
      print('Error fetching historical leaderboard: $e');
    } finally {
      isLoadingHistoricalLeaderboard.value = false;
    }
  }

  // DEBUG: Force backfill for last week
  Future<void> debugBackfillLastWeekHistory() async {
    try {
      final now = DateTime.now();

      // Calculate "Last Monday 08:00" relative to now
      // First find current week's Monday 08:00
      final calendarWeekStart = now.subtract(Duration(days: now.weekday - 1));
      final thisMonday8am = DateTime(
        calendarWeekStart.year,
        calendarWeekStart.month,
        calendarWeekStart.day,
        8,
        0,
      );

      // Backfill for the previous week (7 days before this Monday)
      final lastWeekStart = thisMonday8am.subtract(const Duration(days: 7));

      await _friendRepository.snapshotWeeklyLeaderboard(lastWeekStart);
      Get.snackbar(
        'Success',
        'Backfill history completed for ${DateFormat('dd MMM yyyy').format(lastWeekStart)}!',
      );
      fetchLeaderboardHistory();
    } catch (e) {
      Get.snackbar('Error', 'Backfill failed: $e');
    }
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
                  // Only increment if user is NOT viewing Feed tab
                  // and the post is NOT from the current user
                  final postUserId = newPost['data']?['user_id'];
                  final myId = supabase.auth.currentUser?.id;
                  if (!_isFeedTabActive && postUserId != myId) {
                    newFeedCount.value++;
                    hasNewSocialActivity.value = true;
                  }
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
                  // Only increment if user is NOT viewing Feed tab
                  // and the log is NOT from the current user
                  final logUserId =
                      payload.newRecord['user_id'] ??
                      newLog['data']?['habit']?['user']?['id'];
                  final myId = supabase.auth.currentUser?.id;
                  if (!_isFeedTabActive && logUserId != myId) {
                    newFeedCount.value++;
                    hasNewSocialActivity.value = true;
                  }
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

              // Add to local list and increment unread count
              notifications.insert(0, payload.newRecord);
              unreadNotificationCount.value++;
              hasNewSocialActivity.value = true;
            },
          )
          .subscribe();
    }

    // Subscribe to public.friendships
    supabase
        .channel('public:friendships')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (payload) {
            fetchFriends();
            fetchPendingRequests();
          },
        )
        .subscribe();
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

      // Critical Fix: Ensure NO duplicates by removing any existing reaction by this user first.
      // This handles:
      // 1. Replacing optimistic reaction (user_id matches)
      // 2. Preventing duplicate real reactions (if DB sends double events)
      // 3. Ensuring count never exceeds 1 per user
      reactions.removeWhere((r) => r['user_id'] == reaction['user_id']);

      // Add the new valid reaction from Realtime
      reactions.add(reaction);

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
    print('DEBUG: acceptRequest called for friendshipId: $friendshipId');
    try {
      // 1. Get Friendship details to find requester
      final friendship = await _friendRepository.getFriendship(friendshipId);
      if (friendship == null) {
        print('DEBUG: Friendship not found for ID: $friendshipId');
        throw Exception('Friendship not found');
      }

      final requesterId = friendship['requester_id'] as String;
      print('DEBUG: Found requesterId: $requesterId');

      // 2. Accept Request
      await _friendRepository.acceptRequest(friendshipId);
      print('DEBUG: Friend request accepted in DB');

      // Award XP
      try {
        if (Get.isRegistered<GamificationController>()) {
          final gameCtrl = Get.find<GamificationController>();

          print('DEBUG: Awarding XP to current user (receiver)');
          // Award Current User
          await gameCtrl.awardXP(
            30.0,
            reason: 'New Friend',
            referenceId: 'friend_$friendshipId', // Unique ref
          );

          print('DEBUG: Awarding XP to requester (sender)');
          // Award Requester
          await gameCtrl.awardXPToUser(
            requesterId,
            30.0,
            reason: 'New Friend',
            referenceId:
                'friend_$friendshipId', // Same ref unique to friendship-user pair in logic
          );
        } else {
          print('DEBUG: GamificationController not registered');
        }
      } catch (e) {
        print('Error awarding XP: $e');
      }

      Get.snackbar('Gas!', 'Udah temenan nih! Yuk, compete! 🤩');

      // Refresh all data
      fetchPendingRequests();
      await fetchFriends(); // Await to ensure we have friends list
      fetchActivityFeed();
      fetchLeaderboard();

      // Also refresh stories
      try {
        Get.find<StoryController>().fetchStories();
      } catch (e) {
        print('Error refreshing stories: $e');
      }
    } catch (e) {
      print('DEBUG: Error in acceptRequest: $e');
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

  Future<void> removeFriend(String friendId, String friendName) async {
    // Show confirmation dialog
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          'Hapus Teman?',
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Yakin mau hapus $friendName dari daftar teman? Kalian bakal ga bisa liat aktivitas satu sama lain lagi.',
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Gajadi',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.white54,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back(); // Close dialog
              try {
                await _friendRepository.removeFriend(friendId);
                fetchFriends();
              } catch (e) {
                Get.snackbar('Waduh', 'Gagal hapus teman, error nih! 😵');
              }
            },
            child: Text(
              'Hapus',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // --- Engagement Features ---

  var leaderboard = <Map<String, dynamic>>[].obs;
  var activityFeed = <Map<String, dynamic>>[].obs;
  var notifications = <Map<String, dynamic>>[].obs;
  var unreadNotificationCount = 0.obs;
  var isLoadingLeaderboard = false.obs;
  var isLoadingActivity = false.obs;

  var hasMoreActivity = true.obs;
  var isLoadingMoreActivity = false.obs;

  // Notification Pagination State
  var hasMoreNotifications = true.obs;
  var isLoadingMoreNotifications = false.obs;

  // Duplicates removed

  var newFeedCount = 0.obs;
  String? _lastViewedFeedMarker;
  bool _isFeedTabActive = false;
  var hasNewSocialActivity = false.obs;

  Future<void> fetchLeaderboard({bool refresh = false}) async {
    try {
      if (!refresh) {
        isLoadingLeaderboard.value = true;
      }

      final now = DateTime.now();
      // Check if it's Monday between 08:00 and 12:00
      if (now.weekday == DateTime.monday && now.hour >= 8 && now.hour < 12) {
        isTransitionPeriod.value = true;
        // Fetch data for the previous week
        // Subtract 7 days to get a date in the previous week
        final lastWeekDate = now.subtract(const Duration(days: 7));
        leaderboard.value = await _friendRepository.getLeaderboard(
          referenceDate: lastWeekDate,
        );
      } else {
        isTransitionPeriod.value = false;
        leaderboard.value = await _friendRepository.getLeaderboard();
      }
    } catch (e) {
      print('Error fetching leaderboard: $e');
    } finally {
      isLoadingLeaderboard.value = false;
    }
  }

  var isCreatingPost = false.obs;

  Future<void> fetchActivityFeed({bool refresh = false}) async {
    try {
      if (refresh) {
        // isLoadingActivity.value = true; // Don't show full screen loader on refresh
        // activityFeed.clear(); // Don't clear list to avoid flicker
        hasMoreActivity.value = true;
        // Refresh stories too if StoryController is initialized
        if (Get.isRegistered<StoryController>()) {
          try {
            Get.find<StoryController>().fetchStories();
          } catch (_) {}
        }
      } else {
        isLoadingActivity.value = true;
      }

      // Initial load (limit 10)
      final newItems = await _friendRepository.getActivityFeed(limit: 10);
      activityFeed.value = newItems;

      // Check if we have more
      hasMoreActivity.value = newItems.length >= 10;

      // Calculate new feed count
      if (_lastViewedFeedMarker == null) {
        // Try loading if not ready
        await _loadLastViewedTime();
      }

      if (_lastViewedFeedMarker == null) {
        // First time user: don't show badge, auto-save current top as marker
        newFeedCount.value = 0;
        if (activityFeed.isNotEmpty) {
          final item = activityFeed.first;
          _lastViewedFeedMarker = '${item['type']}_${item['data']['id']}';
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('last_feed_marker', _lastViewedFeedMarker!);
          } catch (_) {}
        }
      } else {
        int count = 0;
        bool foundMarker = false;

        for (var item in activityFeed) {
          final id = '${item['type']}_${item['data']['id']}';
          if (id == _lastViewedFeedMarker) {
            foundMarker = true;
            break;
          }
          count++;
        }

        newFeedCount.value = foundMarker ? count : activityFeed.length;
      }
    } catch (e) {
      print('Error fetching activity feed: $e');
    } finally {
      isLoadingActivity.value = false;
    }
  }

  Future<void> loadMoreActivityFeed() async {
    if (isLoadingMoreActivity.value || !hasMoreActivity.value) return;

    try {
      isLoadingMoreActivity.value = true;

      DateTime? lastTimestamp;
      if (activityFeed.isNotEmpty) {
        final lastItem = activityFeed.last;
        lastTimestamp = lastItem['timestamp'] as DateTime;
      }

      final newItems = await _friendRepository.getActivityFeed(
        limit: 10,
        beforeDate: lastTimestamp,
      );

      if (newItems.isEmpty) {
        hasMoreActivity.value = false;
      } else {
        activityFeed.addAll(newItems);
        if (newItems.length < 10) {
          hasMoreActivity.value = false;
        }
      }
    } catch (e) {
      print('Error loading more activity: $e');
    } finally {
      isLoadingMoreActivity.value = false;
    }
  }

  Future<bool> createPost(String content) async {
    if (content.trim().isEmpty) return false;

    try {
      isCreatingPost.value = true;
      await _friendRepository.createPost(content);
      Get.snackbar('Mantap!', 'Postingan udah naik nih! 🔥');
      return true;
    } catch (e) {
      Get.snackbar('Waduh', 'Gagal posting, sinyal aman? 🤯');
      return false;
    } finally {
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

      final item = activityFeed[index];
      // Check for XP Eligibility (48h)
      final itemTimestamp = item['timestamp'] as DateTime? ?? DateTime.now();
      final twentyFourHoursAgo = DateTime.now().subtract(
        const Duration(hours: 24),
      );
      final isEligibleForXP = itemTimestamp.isAfter(twentyFourHoursAgo);

      // 2. Determine action (Add or Remove) based on current state
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

        // Award XP for reaction (with deduplication via referenceId)
        if (isEligibleForXP) {
          try {
            if (Get.isRegistered<GamificationController>()) {
              final refId = postId != null
                  ? 'react_post_$postId'
                  : 'react_habitlog_$habitLogId';
              Get.find<GamificationController>().awardXPForInteraction(
                'react_momentz',
                referenceId: refId,
              );
            }
          } catch (_) {}
        }

        // --- NEW: Send Notification if not owner ---
        String? ownerId;
        if (postId != null) {
          final postOwner = data['user'];
          if (postOwner != null) {
            ownerId = postOwner['id'];
          }
        } else if (habitLogId != null) {
          final habit = data['habit'];
          final habitOwner = habit['user'];
          if (habitOwner != null) {
            ownerId = habitOwner['id'];
          }
        }

        if (ownerId != null && ownerId != currentUser.id) {
          // Fetch sender's username
          final senderUsername =
              currentUser.userMetadata?['username'] ??
              currentUser.email?.split('@')[0] ??
              'Teman';

          await _friendRepository.sendNotification(
            recipientId: ownerId,
            type: 'reaction',
            title: 'Strik!',
            body: '$senderUsername baru nge-strik feed lo, nih! 🔥',
            postId: postId,
            habitLogId: habitLogId,
          );
        }
        // -------------------------------------------
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

  Future<void> markFeedAsViewed() async {
    _isFeedTabActive = true;
    newFeedCount.value = 0;

    // Save the top most item as marker
    if (activityFeed.isNotEmpty) {
      final item = activityFeed.first;
      final markerId = '${item['type']}_${item['data']['id']}';
      _lastViewedFeedMarker = markerId;

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_feed_marker', markerId);
      } catch (e) {
        print('Error saving last viewed marker: $e');
      }
    }
  }

  void markFeedAsLeft() {
    _isFeedTabActive = false;
  }

  void clearSocialDot() {
    hasNewSocialActivity.value = false;
  }

  Future<void> pokeUser(String friendId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Check if already poked today (using Notification History)
      final lastPokeAt = await _friendRepository.getLastPokeTime(friendId);

      if (lastPokeAt != null) {
        final now = DateTime.now();
        // Ensure lastPokeAt is in local time for comparison if needed,
        // but difference accounts for it if both are UTC or Local.
        // DateTime.parse returns local or UTC depending on string.
        // Helper returns DateTime.parse so it depends on DB string (usually UTC).
        // Let's ensure strict UTC diff or just diff.
        final minutesSinceLastPoke = now
            .difference(lastPokeAt.toLocal())
            .inMinutes;

        if (minutesSinceLastPoke < 1440) {
          // 24 hours = 1440 minutes
          final minutesRemaining = 1440 - minutesSinceLastPoke;
          final hoursRemaining = (minutesRemaining / 60).ceil().clamp(1, 24);
          Get.snackbar(
            'Sabar dulu!',
            'Lo baru bisa colek lagi dalam $hoursRemaining jam. Kasih jeda dong! 😅',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange.withOpacity(0.8),
            colorText: Colors.white,
          );
          return;
        }
      }

      final senderName =
          currentUser.userMetadata?['full_name'] ??
          currentUser.email?.split('@')[0] ??
          'Temanmu';
      // Send poke notification
      await _friendRepository.sendNotification(
        recipientId: friendId,
        type: 'poke',
        title: '$senderName nyolek lo! 👋',
        body:
            'Hi, $senderName nyolek lo nih! Jangan lupa lakuin habit hari ini, ya!',
      );

      // No need to update friendships table anymore

      Get.snackbar(
        'Sukses!',
        'Udah dicolek tuh! Semoga dia langsung semangat! 🔥',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Yah...', 'Gagal nyolek, dia lagi sibuk kali ya? 😔');
    }
  }

  Future<void> fetchNotifications({bool refresh = false}) async {
    try {
      if (refresh) {
        notifications.clear();
        hasMoreNotifications.value = true;
      }

      final data = await _friendRepository.getNotifications(limit: 10);
      notifications.value = data;
      hasMoreNotifications.value = data.length >= 10;

      // Calculate unread count
      unreadNotificationCount.value = data
          .where((notif) => notif['is_read'] == false)
          .length;
    } catch (e) {
      print('Error fetching notifications: $e');
      Get.snackbar(
        'Error',
        'Gagal load notifikasi: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> loadMoreNotifications() async {
    if (isLoadingMoreNotifications.value || !hasMoreNotifications.value) return;

    try {
      isLoadingMoreNotifications.value = true;

      DateTime? lastTimestamp;
      if (notifications.isNotEmpty) {
        final lastItem = notifications.last;
        lastTimestamp = DateTime.parse(lastItem['created_at']);
      }

      final newItems = await _friendRepository.getNotifications(
        limit: 10,
        beforeDate: lastTimestamp,
      );

      if (newItems.isEmpty) {
        hasMoreNotifications.value = false;
      } else {
        notifications.addAll(newItems);
        if (newItems.length < 10) {
          hasMoreNotifications.value = false;
        }
      }
    } catch (e) {
      print('Error loading more notifications: $e');
    } finally {
      isLoadingMoreNotifications.value = false;
    }
  }

  Future<void> deleteNotification(String id) async {
    // Optimistic update
    final originalList = List<Map<String, dynamic>>.from(notifications);
    notifications.removeWhere((n) => n['id'] == id);

    try {
      await _friendRepository.deleteNotification(id);
    } catch (e) {
      print('Error deleting notification: $e');
      notifications.value = originalList; // Revert
      Get.snackbar('Gagal', 'Gagal menghapus notifikasi');
    }
  }

  Future<void> sendNudge(String friendId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Check if already poked today (using Notification History)
      final lastPokeAt = await _friendRepository.getLastPokeTime(friendId);

      if (lastPokeAt != null) {
        final now = DateTime.now();
        final minutesSinceLastPoke = now
            .difference(lastPokeAt.toLocal())
            .inMinutes;

        if (minutesSinceLastPoke < 1440) {
          // 24 hours = 1440 minutes
          final minutesRemaining = 1440 - minutesSinceLastPoke;
          final hoursRemaining = (minutesRemaining / 60).ceil().clamp(1, 24);
          Get.snackbar(
            'Sabar dulu!',
            'Lo baru bisa colek lagi dalam $hoursRemaining jam. Kasih jeda dong! 😅',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange.withOpacity(0.8),
            colorText: Colors.white,
          );
          return;
        }
      }

      final senderName =
          currentUser.userMetadata?['full_name'] ??
          currentUser.email?.split('@')[0] ??
          'Temanmu';
      // Send poke notification
      await _friendRepository.sendNotification(
        recipientId: friendId,
        type: 'poke',
        title: '$senderName nyolek lo! 👋',
        body:
            'Hi, $senderName nyolek lo nih! Jangan lupa lakuin habit hari ini, ya!',
      );

      // No need to update friendships table anymore

      Get.snackbar('Terciduk!', 'Udah dicolek! Semoga dia peka ya! 🫣');
    } catch (e) {
      Get.snackbar('Yah...', 'Gagal nyolek, dia lagi sibuk kali ya? 😔');
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      // Update in database
      await _friendRepository.markNotificationAsRead(notificationId);

      // Update local state
      final index = notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        notifications[index]['is_read'] = true;
        notifications.refresh();

        // Decrement unread count
        if (unreadNotificationCount.value > 0) {
          unreadNotificationCount.value--;
        }
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      if (unreadNotificationCount.value == 0) return;

      // Update in database
      await _friendRepository.markAllNotificationsAsRead();

      // Update local state
      for (var n in notifications) {
        n['is_read'] = true;
      }
      notifications.refresh();
      unreadNotificationCount.value = 0;
    } catch (e) {
      Get.snackbar('Waduh', 'Gagal update status notifikasi: $e');
    }
  }

  Future<bool> canPokeUser(String friendId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return false;

      final friendship = await Supabase.instance.client
          .from('friendships')
          .select('last_poke_at')
          .or(
            'and(requester_id.eq.${currentUser.id},receiver_id.eq.$friendId),and(requester_id.eq.$friendId,receiver_id.eq.${currentUser.id})',
          )
          .eq('status', 'accepted')
          .maybeSingle();

      if (friendship != null && friendship['last_poke_at'] != null) {
        final lastPokeAt = DateTime.parse(friendship['last_poke_at']).toLocal();
        final now = DateTime.now();
        final minutesSinceLastPoke = now.difference(lastPokeAt).inMinutes;

        return minutesSinceLastPoke >= 1440; // Can poke if 24+ hours passed
      }

      return true; // Never poked before, can poke
    } catch (e) {
      return true; // On error, allow poke
    }
  }
}
