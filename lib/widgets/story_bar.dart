import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/controllers/story_controller.dart';
import 'package:strik_app/data/models/story_model.dart';
import 'package:strik_app/screens/story_view_screen.dart';
import 'package:strik_app/screens/story_archive_screen.dart'; // Added
import 'package:strik_app/screens/story_camera_screen.dart'; // Added
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
                    // TODO: Replace with Real User Avatar
                    image: _getUserAvatar(
                      null,
                    ), // Null for self if checking locally or need to fetch
                    fit: BoxFit.cover,
                  ),
                ),
                child: !hasStory
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person, color: Colors.white70),
                      )
                    : null,
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

    return GestureDetector(
      onTap: () {
        Get.to(() => StoryViewScreen(stories: stories));
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
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
                'Lihat Story',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Get.back();
                Get.to(() => StoryViewScreen(stories: stories));
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_a_photo, color: Colors.white),
              title: const Text(
                'Tambah Story Baru',
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
                'Arsip Cerita',
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
