import 'package:get/get.dart';
import 'package:strik_app/data/models/user_model.dart';
import 'package:strik_app/data/repositories/friend_repository.dart';
import 'package:strik_app/main.dart'; // Access global supabase client

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
      Get.snackbar('Error', 'Failed to search users: $e');
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> sendFriendRequest(String userId) async {
    try {
      await _friendRepository.sendRequest(userId);
      Get.snackbar('Success', 'Friend request sent!');
      // Update search result UI state if needed to show "Sent"
    } catch (e) {
      Get.snackbar('Error', 'Failed to send request: $e');
    }
  }

  Future<void> acceptRequest(String friendshipId) async {
    try {
      await _friendRepository.acceptRequest(friendshipId);
      Get.snackbar('Success', 'Friend request accepted!');
      fetchPendingRequests();
      fetchFriends();
    } catch (e) {
      Get.snackbar('Error', 'Failed to accept request: $e');
    }
  }

  Future<void> rejectRequest(String friendshipId) async {
    try {
      await _friendRepository.rejectRequest(friendshipId);
      Get.snackbar('Success', 'Friend request rejected');
      fetchPendingRequests();
    } catch (e) {
      Get.snackbar('Error', 'Failed to reject request: $e');
    }
  }
}
