import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:strik_app/controllers/story_controller.dart';
import 'package:strik_app/data/models/story_model.dart';
import 'package:strik_app/screens/story_view_screen.dart';
import 'package:strik_app/screens/story_camera_screen.dart'; // Added
import 'package:supabase_flutter/supabase_flutter.dart'; // Added for Supabase.instance
import 'package:strik_app/screens/story_archive_screen.dart'; // Added
import 'package:strik_app/core/theme.dart'; // Assume this exists
import 'package:strik_app/main.dart'; // for supabase auth currentUser

class StoryBar extends StatelessWidget {
  StoryBar({super.key});
  final StoryController _controller = Get.put(StoryController());

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      child: Obx(() {
        final groupedStories = _controller.groupedStories;
        final myId = supabase.auth.currentUser?.id;

        // Separate my stories from others
        final myStories = groupedStories[myId] ?? [];
        final otherStories = groupedStories.entries
            .where((e) => e.key != myId)
            .toList();

        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // My Story / Add Button
            _buildMyStoryAvatar(context, myStories),

            const SizedBox(width: 12),

            // Other Users
            ...otherStories.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildStoryAvatar(context, entry.key, entry.value),
              );
            }),
          ],
        );
      }),
    );
  }

  Widget _buildMyStoryAvatar(BuildContext context, List<StoryModel> stories) {
    bool hasStory = stories.isNotEmpty;
    return GestureDetector(
      onTap: () {
        if (hasStory) {
          // Open View or Show Action Sheet (View or Add)
          _showMyStoryOptions(context, stories);
        } else {
          // _controller.pickAndUploadStory();
          Get.to(() => const StoryCameraScreen());
        }
      },
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                margin: const EdgeInsets.all(3),
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: hasStory
                      ? Border.all(
                          color: Colors.amber,
                          width: 3,
                        ) // Active border
                      : Border.all(color: Colors.transparent),
                  image: DecorationImage(
                    image: _getUserAvatar(
                      supabase.auth.currentUser?.userMetadata?['avatar_url'],
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                child:
                    null, // Removed the grey overlay to prevent stacking. The background image handles the avatar.
              ),
              if (!hasStory)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary, // Assume Primary Color
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Icon(Icons.add, size: 16, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Strik Momentz',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Plus Jakarta Sans',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryAvatar(
    BuildContext context,
    String userId,
    List<StoryModel> stories,
  ) {
    final user = stories.first.user;
    final username = user?.username ?? 'User';
    final avatarUrl = user?.avatarUrl;

    final controller = Get.find<StoryController>();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Helper to check if a single story is viewed
    bool isViewed(StoryModel s) => s.viewers.contains(currentUserId);

    // Helper to check if a user box is fully viewed
    bool isFullyViewed(List<StoryModel> userStories) =>
        userStories.every(isViewed);

    return GestureDetector(
      onTap: () {
        // 1. Determine if Target User is Fully Viewed
        final targetIsFullyViewed = isFullyViewed(stories);

        List<List<StoryModel>> playlist;
        int initialUserIndex = 0;
        int initialStoryIndex = 0;

        if (targetIsFullyViewed) {
          // Case A: Tapped a Grey Ring (Fully Viewed)
          // Action: Show ONLY this user's stories, start from 0.
          playlist = [stories];
          initialUserIndex = 0;
          initialStoryIndex = 0;
        } else {
          // Case B: Tapped a Colorful Ring (Has Unviewed)
          // Action: Show THIS user + ALL OTHER users who have unviewed stories.
          // Skip fully viewed users.

          final allGroups = controller.groupedStories.values.toList();

          // Filter: Keep only groups that have at least one unviewed story
          // AND include the target group (which we know has unviewed).
          // Actually, just filter all by !isFullyViewed.
          // BUT ensure the target is in there (it should be).

          playlist = allGroups.where((group) {
            // Keep if NOT fully viewed, OR if it's the target user (just in case logic differs, but !fully covers it)
            return group.isNotEmpty && !isFullyViewed(group);
          }).toList();

          // Find target in the new playlist
          initialUserIndex = playlist.indexWhere(
            (g) => g.first.userId == userId,
          );

          // If for some reason target got filtered out (shouldn't happen if logic holds), fallback
          if (initialUserIndex == -1) {
            playlist = [stories];
            initialUserIndex = 0;
          }

          // Determine Start Story Index (First Unviewed)
          initialStoryIndex = stories.indexWhere((s) => !isViewed(s));
          if (initialStoryIndex == -1) initialStoryIndex = 0;
        }

        Get.to(
          () => StoryViewScreen(
            groupedStories: playlist,
            initialUserIndex: initialUserIndex,
            initialStoryIndex: initialStoryIndex,
          ),
        );
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  stories.every(
                    (s) => s.viewers.contains(
                      Supabase.instance.client.auth.currentUser?.id,
                    ),
                  )
                  ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                  : const LinearGradient(
                      colors: [Colors.amber, Colors.orange, Colors.purple],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black, // Background gap
              ),
              child: CircleAvatar(
                radius: 30,
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
            ),
          ),
          const SizedBox(height: 4),
          Text(
            username.length > 8 ? '${username.substring(0, 8)}...' : username,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Plus Jakarta Sans',
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider _getUserAvatar(String? url) {
    if (url != null && url.isNotEmpty) {
      return NetworkImage(url);
    }
    return const AssetImage(
      'assets/images/default_avatar.png',
    ); // Fallback or handle later
  }

  void _showMyStoryOptions(BuildContext context, List<StoryModel> stories) {
    Get.bottomSheet(
      Container(
        color: const Color(0xFF1E1E1E),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.white),
              title: const Text(
                'Lihat Momentz',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Get.back();
                final controller = Get.find<StoryController>();
                final allGroups = controller.groupedStories.values.toList();
                final myId = supabase.auth.currentUser?.id;
                final index = allGroups.indexWhere(
                  (s) => s.isNotEmpty && s.first.userId == myId,
                );

                if (index != -1) {
                  Get.to(
                    () => StoryViewScreen(
                      groupedStories: allGroups,
                      initialUserIndex: index,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_a_photo, color: Colors.white),
              title: const Text(
                'Tambah Momentz Baru',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Get.back();
                // _controller.pickAndUploadStory();
                Get.to(() => const StoryCameraScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive, color: Colors.white),
              title: const Text(
                'Throwback Momentz',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Get.back();
                Get.to(() => StoryArchiveScreen());
              },
            ),
          ],
        ),
      ),
    );
  }
}
