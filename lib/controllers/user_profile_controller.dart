import 'package:get/get.dart';
import 'package:strik_app/data/models/user_model.dart';
import 'package:strik_app/data/repositories/friend_repository.dart';
import 'package:strik_app/main.dart'; // Access global supabase
import 'package:strik_app/controllers/friend_controller.dart'; // For refreshing lists

class UserProfileController extends GetxController {
  final FriendRepository _friendRepository = FriendRepository(supabase);

  var isLoading = true.obs;
  var user = Rxn<UserModel>();
  var activeHabitCount = 0.obs;

  // Status: 'self', 'none', 'pending' (received), 'sent', 'accepted'
  var friendshipStatus = 'none'.obs;

  Future<void> loadUserProfile(String userId) async {
    isLoading.value = true;
    try {
      final data = await _friendRepository.getUserProfileDetails(userId);

      user.value = data['user'] as UserModel;
      activeHabitCount.value = data['active_habit_count'] as int;
      friendshipStatus.value = data['friendship_status'] as String;
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat profil user: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendFriendRequest() async {
    if (user.value == null) return;

    try {
      await _friendRepository.sendRequest(user.value!.id);
      friendshipStatus.value = 'sent';
      Get.snackbar('Yeay!', 'Request sent! Tungguin di-acc ya bestie!');

      // Refresh global friend lists if needed
      if (Get.isRegistered<FriendController>()) {
        Get.find<FriendController>().fetchPendingRequests();
      }
    } catch (e) {
      Get.snackbar('Ups!', 'Gagal ngirim request. Coba lagi kack!');
    }
  }

  // Accept request logic: We need friendship ID to accept.
  // Repository accepts by Friendship ID, but we only have User ID here easily.
  // We need to fetch the friendship ID first or overload repository method.
  // Let's modify logic to fetch friendship ID implicitly?
  // Or better: The `getUserProfileDetails` could return friendship ID if exists.
  // For simplicity and to avoid changing Repo contract too much for now:
  // We will find the friendship ID from pending requests list in FriendController or re-query.
  // Actually, let's just use FriendController logic if possible, or implement a lookup.

  // Re-thinking: getUserProfileDetails calculates status but doesn't return ID.
  // Let's add a quick lookup method here or in repo.
  // Since we want to keep it simple, we'll traverse `FriendController.pendingRequests` if available.

  Future<void> acceptFriendRequest() async {
    if (user.value == null) return;

    try {
      // Find friendship ID
      // Iterate pending requests in FriendController
      String? friendshipId;
      if (Get.isRegistered<FriendController>()) {
        final friendCtrl = Get.find<FriendController>();
        final request = friendCtrl.pendingRequests.firstWhereOrNull(
          (req) => req['requester_id'] == user.value!.id,
        );
        friendshipId = request?['id'];
      }

      if (friendshipId == null) {
        // Fallback: Query direct
        final res = await supabase
            .from('friendships')
            .select('id')
            .eq('requester_id', user.value!.id)
            .eq('receiver_id', supabase.auth.currentUser!.id)
            .eq('status', 'pending')
            .maybeSingle();

        friendshipId = res?['id'];
      }

      if (friendshipId != null) {
        if (Get.isRegistered<FriendController>()) {
          await Get.find<FriendController>().acceptRequest(friendshipId);
        } else {
          await _friendRepository.acceptRequest(friendshipId);
        }
        friendshipStatus.value = 'accepted';
        // Snackbars handled by FriendController or we do it here if using repo directly
        // If using FriendController, it shows snackbar.
      } else {
        Get.snackbar('Error', 'Data request tidak ditemukan');
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal menerima: $e');
    }
  }

  Future<void> rejectFriendRequest() async {
    if (user.value == null) return;

    try {
      String? friendshipId;
      // Try lookup
      final res = await supabase
          .from('friendships')
          .select('id')
          .eq('requester_id', user.value!.id)
          .eq('receiver_id', supabase.auth.currentUser!.id)
          .eq('status', 'pending')
          .maybeSingle();
      friendshipId = res?['id'];

      if (friendshipId != null) {
        if (Get.isRegistered<FriendController>()) {
          await Get.find<FriendController>().rejectRequest(friendshipId);
        } else {
          await _friendRepository.rejectRequest(friendshipId);
        }
        friendshipStatus.value = 'none';
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal menolak: $e');
    }
  }
}
