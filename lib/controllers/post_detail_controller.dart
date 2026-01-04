import 'package:get/get.dart';
import 'package:strik_app/data/repositories/friend_repository.dart';
import 'package:strik_app/main.dart';

class PostDetailController extends GetxController {
  final String? postId;
  final String? habitLogId;
  final FriendRepository _friendRepository = FriendRepository(supabase);

  PostDetailController({this.postId, this.habitLogId});

  var post = Rxn<Map<String, dynamic>>();
  var isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPostDetail();
  }

  Future<void> fetchPostDetail({bool showLoading = true}) async {
    try {
      if (showLoading) isLoading.value = true;

      Map<String, dynamic>? result;
      if (postId != null) {
        result = await _friendRepository.getPostById(postId!);
      } else if (habitLogId != null) {
        result = await _friendRepository.getHabitLogById(habitLogId!);
      }

      if (result != null) {
        post.value = result;
      }
    } catch (e) {
      print('Error fetching post detail: $e');
    } finally {
      if (showLoading) isLoading.value = false;
    }
  }

  Future<void> toggleReaction() async {
    if (post.value == null) return;

    final currentPost = post.value!;
    final type = currentPost['type'];
    final data = Map<String, dynamic>.from(currentPost['data']);
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    // Optimistic Update
    final List<dynamic> reactions = List.from(data['reactions'] ?? []);
    final myReactionIndex = reactions.indexWhere(
      (r) => r['user_id'] == currentUser.id,
    );

    if (myReactionIndex != -1) {
      reactions.removeAt(myReactionIndex);
    } else {
      reactions.add({'user_id': currentUser.id});
    }

    data['reactions'] = reactions;
    post.value = {...currentPost, 'data': data};

    try {
      await _friendRepository.toggleReaction(
        postId: type == 'post' ? data['id'] : null,
        habitLogId: type == 'habit_log' ? data['id'] : null,
      );

      // Refresh in background to sync with server, but don't show loading
      await fetchPostDetail(showLoading: false);
    } catch (e) {
      print('Error toggling reaction: $e');
      // Rollback on error by refreshing
      await fetchPostDetail(showLoading: false);
    }
  }
}
