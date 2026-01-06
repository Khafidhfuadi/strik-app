// import 'dart:async'; // Unused
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added
import 'package:get/get.dart';
import 'package:strik_app/data/models/story_model.dart';
import 'package:strik_app/controllers/story_controller.dart';
// import 'package:cached_network_image/cached_network_image.dart'; // Suggest adding this dependency if not present, otherwise use NetworkImage
import 'package:timeago/timeago.dart' as timeago;

class StoryViewScreen extends StatefulWidget {
  final List<StoryModel> stories;
  const StoryViewScreen({Key? key, required this.stories}) : super(key: key);

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentIndex = 0;

  final StoryController _storyController = Get.find<StoryController>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(vsync: this);

    // Sort stories by date (oldest first usually for stories?)
    // Instagram shows Oldest -> Newest (Chronological)
    // Our fetch sorted by DESC (Newest first). We should reverse it for viewing.
    widget.stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _loadStory(0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _loadStory(int index) {
    if (index < 0) return; // Should not happen
    if (index >= widget.stories.length) {
      Get.back(); // Close viewer when done
      return;
    }

    setState(() {
      _currentIndex = index;
    });

    _animController.stop();
    _animController.reset();
    _animController.duration = const Duration(seconds: 5);

    _animController.forward();

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    // Mark as viewed (Not robustly implemented in backend yet, but call good to have)
    // _storyController.markAsViewed(widget.stories[index]);
  }

  void _nextStory() {
    print('Next story');
    if (_currentIndex < widget.stories.length - 1) {
      _loadStory(_currentIndex + 1);
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Get.back();
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      _loadStory(_currentIndex - 1);
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Restart current? Or nothing.
      _loadStory(0); // Restart first
    }
  }

  // Tap Handler
  void _onTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    if (dx < screenWidth / 3) {
      _prevStory();
    } else {
      _nextStory();
    }
  }

  void _onLongPressStart() {
    _animController.stop();
  }

  void _onLongPressEnd() {
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final user = story.user; // Might be null ideally shouldn't

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPress: _onLongPressStart,
        onLongPressUp: _onLongPressEnd,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            Get.back(); // Swipe down to close
          }
        },
        child: Stack(
          children: [
            // Image
            Center(
              child: Image.network(
                story.mediaUrl,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (ctx, err, trace) =>
                    const Center(child: Icon(Icons.error, color: Colors.white)),
              ),
            ),

            // Overlay Gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black54,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Progress Bars
            Positioned(
              top: 50,
              left: 10,
              right: 10,
              child: Row(
                children: widget.stories.asMap().entries.map((entry) {
                  final idx = entry.key;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: idx == _currentIndex
                          ? AnimatedBuilder(
                              animation: _animController,
                              builder: (ctx, child) {
                                return LinearProgressIndicator(
                                  value: _animController.value,
                                  backgroundColor: Colors.white.withOpacity(
                                    0.3,
                                  ),
                                  valueColor: const AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                );
                              },
                            )
                          : LinearProgressIndicator(
                              value: idx < _currentIndex ? 1.0 : 0.0,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation(
                                Colors.white,
                              ),
                            ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // User Info
            Positioned(
              top: 70,
              left: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: user?.avatarUrl != null
                        ? NetworkImage(user!.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    user?.username ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeago.format(story.createdAt),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (user?.id ==
                      _storyController.supabase.auth.currentUser?.id) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () async {
                        _animController.stop();
                        await _storyController.deleteStory(story);
                        // If deleted, maybe close or refresh
                        // Ideally remove from local list and continue
                        // For MVP simply close
                      },
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} // Fix reference to supabase via controller

extension on StoryController {
  SupabaseClient get supabase =>
      Get.find<StoryController>().activeStories.first.user != null
      ? Supabase.instance.client
      : Supabase
            .instance
            .client; // Hacky, use Supabase.instance.client directly in widget
}
