import 'package:get/get.dart';
import 'package:strik_app/data/models/user_model.dart';
import 'package:strik_app/data/repositories/friend_repository.dart';
import 'package:strik_app/main.dart'; // Access global supabase client

import 'package:supabase_flutter/supabase_flutter.dart';

class FriendController extends GetxController {
  final FriendRepository _friendRepository = FriendRepository(supabase);

  var friends = <UserModel>[].obs;
  var pendingRequests = <Map<String, dynamic>>[].obs;
  var searchResults = <UserModel>[].obs;

  var isLoadingFriends = true.obs;
  var isLoadingRequests = true.obs;
  var isSearching = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchFriends();
    fetchPendingRequests();
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

  Future<void> fetchActivityFeed() async {
    try {
      isLoadingActivity.value = true;
      activityFeed.value = await _friendRepository.getActivityFeed();
    } catch (e) {
      print('Error fetching activity feed: $e');
    } finally {
      isLoadingActivity.value = false;
    }
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
