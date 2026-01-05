import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:strik_app/controllers/post_detail_controller.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/widgets/custom_loading_indicator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostDetailScreen extends StatelessWidget {
  final String? postId;
  final String? habitLogId;

  const PostDetailScreen({super.key, this.postId, this.habitLogId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      PostDetailController(postId: postId, habitLogId: habitLogId),
      tag: postId ?? habitLogId,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Detail Feed',
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CustomLoadingIndicator());
        }

        final post = controller.post.value;
        if (post == null) {
          return const Center(
            child: Text(
              'Yah, postnya udah ilang coy! 💨',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        final type = post['type'];
        final data = post['data'];
        final timestamp = post['timestamp'] as DateTime;
        final currentUser = Supabase.instance.client.auth.currentUser;

        // Extract metadata based on type
        String titleText = '';
        String username = '';
        String? avatarUrl;
        List reactions = data['reactions'] ?? [];

        if (type == 'habit_log') {
          final habit = data['habit'];
          final user = habit['user'];
          username = user['username'] ?? 'User';
          avatarUrl = user['avatar_url'];
          titleText = habit['title'];
        } else {
          final user = data['user'];
          username = user['username'] ?? 'User';
          avatarUrl = user['avatar_url'];
          titleText = data['content'];
        }

        bool hasReacted = false;
        if (currentUser != null) {
          hasReacted = reactions.any((r) => r['user_id'] == currentUser.id);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900]!.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Text(
                              username[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: type == 'habit_log'
                                      ? ' abis bantai '
                                      : ' ngepost: ',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                                if (type == 'habit_log')
                                  TextSpan(
                                    text: titleText,
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (type == 'post') ...[
                            const SizedBox(height: 4),
                            Text(
                              titleText,
                              style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            timeago.format(timestamp),
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => controller.toggleReaction(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: hasReacted
                              ? const Color(0xFFFF5757).withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hasReacted
                                ? const Color(0xFFFF5757)
                                : Colors.grey[800]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Opacity(
                                opacity: hasReacted ? 1.0 : 0.4,
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.matrix(
                                    hasReacted
                                        ? [
                                            1,
                                            0,
                                            0,
                                            0,
                                            0,
                                            0,
                                            1,
                                            0,
                                            0,
                                            0,
                                            0,
                                            0,
                                            1,
                                            0,
                                            0,
                                            0,
                                            0,
                                            0,
                                            1,
                                            0,
                                          ]
                                        : [
                                            0.2126,
                                            0.7152,
                                            0.0722,
                                            0,
                                            0,
                                            0.2126,
                                            0.7152,
                                            0.0722,
                                            0,
                                            0,
                                            0.2126,
                                            0.7152,
                                            0.0722,
                                            0,
                                            0,
                                            0,
                                            0,
                                            0,
                                            1,
                                            0,
                                          ],
                                  ),
                                  child: Lottie.asset(
                                    'assets/src/strik-logo.json',
                                    animate: hasReacted,
                                    repeat: false,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${reactions.length}',
                              style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                color: hasReacted
                                    ? const Color(0xFFFF5757)
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
