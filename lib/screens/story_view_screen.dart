// import 'dart:async'; // Unused
import 'dart:ui'; // Added for ImageFilter
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart' show Lottie;
import 'package:supabase_flutter/supabase_flutter.dart'; // Added
import 'package:get/get.dart';
import 'package:strik_app/data/models/story_model.dart';
import 'package:strik_app/controllers/story_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

class StoryViewScreen extends StatefulWidget {
  final List<List<StoryModel>> groupedStories;
  final int initialUserIndex;
  final int initialStoryIndex; // Added for smart start
  final bool smartNavigation; // Added to stop on viewed stories

  const StoryViewScreen({
    super.key,
    required this.groupedStories,
    required this.initialUserIndex,
    this.initialStoryIndex = 0, // Default to 0
    this.smartNavigation = false,
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
              initialIndex: index == widget.initialUserIndex
                  ? widget.initialStoryIndex
                  : null,
              smartNavigation: widget.smartNavigation,
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
  final int? initialIndex;
  final bool smartNavigation;

  const StoryUserPlayer({
    super.key,
    required this.stories,
    required this.onComplete,
    required this.onPrevUser,
    this.initialIndex,
    this.smartNavigation = false,
  });

  @override
  State<StoryUserPlayer> createState() => _StoryUserPlayerState();
}

class _StoryUserPlayerState extends State<StoryUserPlayer>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  int _currentIndex = 0;
  final StoryController _storyController = Get.find<StoryController>();
  bool _hasReacted = false; // State to disable reaction bar
  bool _isContentReady = false; // Added to control playback start

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this);

    // Sort logic should ideally be passed in, but safe to repeat here if raw list order unknown
    widget.stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Smart Start Logic
    int startIndex = widget.initialIndex ?? 0;
    if (widget.initialIndex == null) {
      // Auto-detect first unviewed for next users
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final firstUnviewed = widget.stories.indexWhere(
        (s) => uid != null && !s.viewers.contains(uid),
      );
      if (firstUnviewed != -1) {
        startIndex = firstUnviewed;
      }
    }

    _loadStory(startIndex);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // When parent PageView recycles this widget, we might want to reset?
  // PageView.builder keeps state for visible items.

  void _loadStory(int index) async {
    if (index >= widget.stories.length) {
      widget.onComplete();
      return;
    }

    setState(() {
      _currentIndex = index;
      _hasReacted = false; // Reset first
      _isContentReady = false; // Reset content ready state
    });

    final story = widget.stories[index];

    _animController.stop();
    _animController.reset();
    _animController.duration = const Duration(seconds: 5);

    final currentUser = _storyController.supabase.auth.currentUser;

    // 1. Mark as viewed (if not own story)
    if (currentUser != null && story.userId != currentUser.id) {
      // Fire and forget (don't await animation)
      _storyController.markAsViewed(story.id);

      // 2. Check if I reacted
      final myReaction = await _storyController.getMyReaction(story.id);
      if (mounted && myReaction != null) {
        setState(() {
          _hasReacted = true;
        });
      }
    }

    // _animController.forward(); // Removed to wait for image load

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      // Smart Navigation Check
      if (widget.smartNavigation) {
        final nextStory = widget.stories[_currentIndex + 1];
        final uid = Supabase.instance.client.auth.currentUser?.id;
        final isNextViewed = uid != null && nextStory.viewers.contains(uid);

        if (isNextViewed) {
          // If next is viewed and we are in smart mode, stop here.
          widget.onComplete();
          return;
        }
      }

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

  void _onTapUp(TapUpDetails details) {
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

  void _showViewers(StoryModel story) {
    _animController.stop(); // Pause story
    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E), // Dark background
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Yang ngeliat Momentz lo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white, // White text
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _storyController.getViewers(story.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Lottie.asset(
                        'assets/src/loading.json',
                        width: 150,
                        height: 150,
                      ),
                    );
                  }
                  final viewers = snapshot.data ?? [];
                  if (viewers.isEmpty) {
                    return const Center(
                      child: Text(
                        'Belum ada yang lihat nih',
                        style: TextStyle(
                          color: Colors.white70, // Light grey text
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: viewers.length,
                    itemBuilder: (context, index) {
                      final v = viewers[index];
                      final user = v['user']; // Profile JSON
                      final reaction = v['reaction']; // String?

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['avatar_url'] != null
                              ? NetworkImage(user['avatar_url'])
                              : null,
                          child: user['avatar_url'] == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(
                          user['username'] ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                          ), // White text
                        ),
                        trailing: reaction != null
                            ? Text(
                                reaction,
                                style: const TextStyle(fontSize: 24),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      _animController.forward(); // Resume on close
    });
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final user = story.user;
    final isMyStory =
        user?.id == _storyController.supabase.auth.currentUser?.id;

    // Use Stack for Instant Cut transitions
    return GestureDetector(
      onTapUp: _onTapUp,
      onLongPress: _onLongPressStart,
      onLongPressUp: _onLongPressEnd,
      child: Stack(
        children: [
          // Image
          Center(
            child: CachedNetworkImage(
              imageUrl: story.mediaUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => Center(
                child: Lottie.asset(
                  'assets/src/loading.json',
                  width: 150,
                  height: 150,
                ),
              ),
              imageBuilder: (context, imageProvider) {
                if (!_isContentReady) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _isContentReady = true;
                      });
                      _animController.forward();
                    }
                  });
                }
                return Image(image: imageProvider, fit: BoxFit.contain);
              },
              errorWidget: (context, url, error) =>
                  const Center(child: Icon(Icons.error, color: Colors.white)),
              fadeInDuration: const Duration(milliseconds: 200),
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
                if (isMyStory) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      _animController.stop();
                      Get.defaultDialog(
                        title: "Hapus Momentz?",
                        middleText:
                            "Yakin mau ngehapus momentz ini? Ga bisa dibalikin loh.",
                        textConfirm: "Hapus",
                        textCancel: "Batal",
                        confirmTextColor: Colors.white,
                        onCancel: () {
                          _animController.forward();
                        },
                        onConfirm: () async {
                          // 1. Close Confirmation Dialog
                          Get.back();

                          // 2. Show Loading
                          Get.dialog(
                            const Center(child: CircularProgressIndicator()),
                            barrierDismissible: false,
                          );

                          try {
                            // 3. Perform Delete
                            debugPrint(
                              "DELETING STORY: Start UI Delete Flow for ${story.id}",
                            );
                            await _storyController.deleteStory(story);
                            debugPrint(
                              "DELETING STORY: Finished Controller Delete",
                            );
                          } catch (e) {
                            debugPrint("DELETING STORY: Error in UI: $e");
                          } finally {
                            // 4. Close Loading
                            if (Get.isDialogOpen ?? false) Get.back();

                            // 5. Close Story Viewer
                            Get.back();
                          }
                        },
                      );
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

          // Bottom Area: Caption & Reaction Bar
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Caption
                  if (story.caption != null && story.caption!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              story.caption!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Reaction Bar (Floating at bottom if NOT my story)
                  if (!isMyStory)
                    // Reaction Input Bar
                    // Disable if reacted
                    IgnorePointer(
                      ignoring: _hasReacted, // Disable interactions
                      child: Opacity(
                        opacity: _hasReacted ? 0.5 : 1.0, // Grey out
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              height: 60,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
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
                      ),
                    ),

                  // Viewer Count (My Story) - Moved here to prevent overlap
                  if (isMyStory)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 10,
                        left: 20,
                        bottom: 10,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => _showViewers(story),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.remove_red_eye,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "${story.viewers.length} Stalker",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
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

  void _sendReaction(String emoji) async {
    setState(() {
      _hasReacted = true; // Optimistic update to disable bar
    });

    // 1. API Call
    await _storyController.sendReaction(
      widget.stories[_currentIndex].id,
      emoji,
    );

    // 2. Local Animation
    final id = DateTime.now().millisecondsSinceEpoch;
    final reaction = _FlyingReaction(
      id: id,
      emoji: emoji,
      onComplete: () {
        setState(() {
          _flyingReactions.removeWhere((r) => r.id == id);
        });
      },
    );

    setState(() {
      _flyingReactions.add(reaction);
    });
  }
}

class _FlyingReaction {
  final int id;
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
