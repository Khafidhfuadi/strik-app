import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/controllers/story_controller.dart';
import 'package:strik_app/core/theme.dart';
import 'package:intl/intl.dart';
import 'package:strik_app/screens/story_view_screen.dart';

class StoryArchiveScreen extends StatelessWidget {
  StoryArchiveScreen({super.key});
  final StoryController _controller =
      Get.find<StoryController>(); // Should be alive from SocialScreen

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Throwback Momentz',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        final archive = _controller.myArchive;
        if (archive.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history, color: Colors.white24, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Ga ada yang bisa di-throwback :(',
                  style: TextStyle(
                    color: Colors.white54,
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.6,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: archive.length,
          itemBuilder: (context, index) {
            final story = archive[index];
            return GestureDetector(
              onTap: () {
                // View Archive (Single story or list starting from here?)
                // Let's passed single story or list to viewer.
                // Viewing archive usually just shows that one story.
                Get.to(
                  () => StoryViewScreen(
                    groupedStories: [
                      [story],
                    ], // Archive views single story context
                    initialUserIndex: 0,
                  ),
                ); // View single
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      story.mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey[800]),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        DateFormat('dd MMM').format(story.createdAt),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}
