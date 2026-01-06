// import 'dart:async'; // Unused
import 'dart:ui'; // Added for ImageFilter
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added
import 'package:get/get.dart';
import 'package:strik_app/data/models/story_model.dart';
import 'package:strik_app/controllers/story_controller.dart';
// import 'package:cached_network_image/cached_network_image.dart'; // Suggest adding this dependency if not present, otherwise use NetworkImage
import 'package:timeago/timeago.dart' as timeago;

class StoryViewScreen extends StatefulWidget {
  final List<List<StoryModel>> groupedStories;
  final int initialUserIndex;

  const StoryViewScreen({
    super.key,
    required this.groupedStories,
    required this.initialUserIndex,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  late PageController _userPageController;
  int _currentUserIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.initialUserIndex;
    _userPageController = PageController(initialPage: widget.initialUserIndex);
  }

  @override
  void dispose() {
    _userPageController.dispose();
    super.dispose();
  }

  void _onUserStoryComplete() {
    print(
      "User story complete. Current User Index: $_currentUserIndex, Total: ${widget.groupedStories.length}",
    );
    if (_currentUserIndex < widget.groupedStories.length - 1) {
      _userPageController.nextPage(
        duration: const Duration(
          milliseconds: 600,
        ), // Slower transition for vertical
        curve: Curves.easeInOut,
      );
    } else {
      Get.back(); // Close viewer if last user finishes
    }
  }

  void _onPrevUser() {
    if (_currentUserIndex > 0) {
      _userPageController.previousPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    } else {
      // Re-play this user? Or just stay.
      // Instagram pulls down to refresh or close?
      // Let's just do nothing or restart current user logic handled by player
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // Simple swipe down to close logic is now complicated by Vertical PageView.
          // But PageView usually handles this naturally if at top boundary?
          // Nope, standard PageView just overscrolls.
          // We might need a custom physics or stay with default behavior.
          // If primaryVelocity > 0 (Swipe Down) AND we are at top?
          // For now, let's rely on the Close Button (which we should add explicitly or rely on back gesture if confusing)
          // But the prompt asked for "Scroll down to next user" which PageView handles.
          // If "Previous user" is swiping UP (scroll down gesture)... wait.
          // Scroll Down (finger moves up) -> Next Item.
          // Scroll Up (finger moves down) -> Previous Item.
        },
        child: PageView.builder(
          controller: _userPageController,
          scrollDirection: Axis.vertical,
          itemCount: widget.groupedStories.length,
          onPageChanged: (index) {
            setState(() {
              _currentUserIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final stories = widget.groupedStories[index];
            return StoryUserPlayer(
              stories: stories,
              onComplete: _onUserStoryComplete,
              onPrevUser: _onPrevUser,
            );
          },
        ),
      ),
    );
  }
}

class StoryUserPlayer extends StatefulWidget {
  final List<StoryModel> stories;
  final VoidCallback onComplete;
  final VoidCallback onPrevUser;

  const StoryUserPlayer({
    super.key,
    required this.stories,
    required this.onComplete,
    required this.onPrevUser,
  });

  @override
  State<StoryUserPlayer> createState() => _StoryUserPlayerState();
}

class _StoryUserPlayerState extends State<StoryUserPlayer>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  int _currentIndex = 0;
  final StoryController _storyController = Get.find<StoryController>();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this);

    // Sort logic should ideally be passed in, but safe to repeat here if raw list order unknown
    widget.stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _loadStory(0);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // When parent PageView recycles this widget, we might want to reset?
  // PageView.builder keeps state for visible items.

  void _loadStory(int index) {
    if (index >= widget.stories.length) {
      widget.onComplete();
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
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      // INSTANT CUT (User requested)
      _loadStory(_currentIndex + 1);
    } else {
      // Last story of this user
      widget.onComplete();
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      // INSTANT CUT
      _loadStory(_currentIndex - 1);
    } else {
      // First story of this user -> Go to previous user
      widget.onPrevUser();
    }
  }

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
    final user = story.user;

    // Use Stack for Instant Cut transitions
    return GestureDetector(
      onTapDown: _onTapDown,
      onLongPress: _onLongPressStart,
      onLongPressUp: _onLongPressEnd,
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
                                backgroundColor: Colors.white.withOpacity(0.3),
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
                      Get.back();
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

          // Reaction Bar (Floating at bottom if not my story)
          if (user?.id != _storyController.supabase.auth.currentUser?.id)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reaction Input Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          height: 60,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                              0.1,
                            ), // Translucent white for glass effect
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(
                                0.2,
                              ), // Subtle border
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildReactionButton('❤️'),
                              _buildReactionButton('😂'),
                              _buildReactionButton('😮'),
                              _buildReactionButton('😢'),
                              _buildReactionButton('👏'),
                              _buildReactionButton('🔥'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Flying Animations
          ..._flyingReactions.map((r) => r.widget),
        ],
      ),
    );
  }

  // Reaction State
  final List<_FlyingReaction> _flyingReactions = [];

  Widget _buildReactionButton(String emoji) {
    return GestureDetector(
      onTap: () {
        _sendReaction(emoji);
      },
      child: Text(emoji, style: const TextStyle(fontSize: 28)),
    );
  }

  void _sendReaction(String emoji) {
    // 1. API Call
    final story = widget.stories[_currentIndex];
    _storyController.sendReaction(story.id, emoji);

    // 2. Local Animation
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final animation = _FlyingReaction(
      id: id,
      emoji: emoji,
      onComplete: () {
        if (mounted) {
          setState(() {
            _flyingReactions.removeWhere((r) => r.id == id);
          });
        }
      },
    );

    setState(() {
      _flyingReactions.add(animation);
    });
  }
}

class _FlyingReaction {
  final String id;
  final String emoji;
  final VoidCallback onComplete;
  late final Widget widget;

  _FlyingReaction({
    required this.id,
    required this.emoji,
    required this.onComplete,
  }) {
    widget = _FlyingReactionWidget(
      key: ValueKey(id),
      emoji: emoji,
      onComplete: onComplete,
    );
  }
}

class _FlyingReactionWidget extends StatefulWidget {
  final String emoji;
  final VoidCallback onComplete;

  const _FlyingReactionWidget({
    super.key,
    required this.emoji,
    required this.onComplete,
  });

  @override
  State<_FlyingReactionWidget> createState() => _FlyingReactionWidgetState();
}

class _FlyingReactionWidgetState extends State<_FlyingReactionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)),
    );
    _position = Tween<double>(
      begin: 0.0,
      end: -300.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward().whenComplete(() {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          bottom: 100 + _position.value.abs(), // Start above bar and fly up
          left: 0,
          right: 0, // Center horizontally for now, or randomize?
          child: Opacity(
            opacity: _opacity.value,
            child: Center(
              child: Text(widget.emoji, style: const TextStyle(fontSize: 40)),
            ),
          ),
        );
      },
    );
  }
}

extension on StoryController {
  SupabaseClient get supabase => Supabase.instance.client;
}
