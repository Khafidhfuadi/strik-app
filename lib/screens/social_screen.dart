import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:strik_app/controllers/friend_controller.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/screens/add_friend_screen.dart';
import 'package:strik_app/screens/notifications_screen.dart';
import 'package:strik_app/widgets/custom_loading_indicator.dart';

class SocialScreen extends StatefulWidget {
  final Widget? bottomNavigationBar;
  const SocialScreen({super.key, this.bottomNavigationBar});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final FriendController _controller = Get.put(FriendController());
  int _selectedIndex = 0;
  final List<String> _tabs = ['Feed', 'Rank', 'Circle'];
  late PageController _pageController;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      _controller.loadMoreActivityFeed();
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // Mark feed as viewed when Feed tab is tapped
    if (index == 0) {
      _controller.markFeedAsViewed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar: widget.bottomNavigationBar,
      body: SafeArea(
        child: Column(
          children: [
            // Custom AppBar Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text(
                    'Sosialita',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Obx(() {
                    final unreadCount =
                        _controller.unreadNotificationCount.value;
                    return IconButton(
                      icon: Badge(
                        label: Text('$unreadCount'),
                        isLabelVisible: unreadCount > 0,
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () =>
                          Get.to(() => const NotificationsScreen()),
                    );
                  }),
                  IconButton(
                    icon: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Get.to(() => const AddFriendScreen()),
                  ),
                ],
              ),
            ),

            // Custom Tab Chips (Matching Home Style) with Badges
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _tabs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final label = entry.value;
                    final isActive = _selectedIndex == index;

                    return GestureDetector(
                      onTap: () => _onTabTapped(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.grey[900]
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.plusJakartaSans(
                                color: isActive
                                    ? Colors.white
                                    : Colors.grey[600],
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            // Badges
                            if (index != 0)
                              Obx(() {
                                int count = 0;
                                if (index == 1) {
                                  // Feed Tab
                                  count = _controller.newFeedCount.value;
                                } else if (index == 2) {
                                  // Friends Tab
                                  count = _controller.friends.length;
                                }

                                if (count > 0) {
                                  return Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: index == 1 && count > 0
                                          ? Colors.red
                                          : (isActive
                                                ? Colors.white24
                                                : Colors.grey[800]),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      count > 99 ? '99+' : '$count',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _selectedIndex = index);
                  if (index == 0) {
                    // 0 is now Activity Feed
                    _controller.markFeedAsViewed();
                  }
                },
                children: [
                  _buildActivityFeedTab(),
                  _buildLeaderboardTab(),
                  _buildFriendsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    _controller.fetchLeaderboard();

    return Obx(() {
      if (_controller.isLoadingLeaderboard.value) {
        return const Center(child: CustomLoadingIndicator());
      }

      if (_controller.leaderboard.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Belum ada suhu nih! 🥶',
                style: GoogleFonts.plusJakartaSans(color: Colors.grey),
              ),
            ],
          ),
        );
      }

      final topThree = _controller.leaderboard.take(3).toList();
      final rest = _controller.leaderboard.skip(3).toList();

      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Info Text
          Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.only(bottom: 24),
            child: Text(
              'Leaderboard reset tiap Senin 🔄',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ),

          // Top 3 Podium - Cleaner Design
          if (topThree.isNotEmpty)
            Container(
              height: 200,
              margin: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (topThree.length >= 2)
                    _buildMinimalPodiumItem(topThree[1], 2),
                  _buildMinimalPodiumItem(topThree[0], 1),
                  if (topThree.length >= 3)
                    _buildMinimalPodiumItem(topThree[2], 3),
                ],
              ),
            ),

          // Rest of the list
          ...rest.asMap().entries.map((entry) {
            final index = entry.key + 3; // 4th place onwards
            final data = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[900]!.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: data['user'].avatarUrl != null
                        ? NetworkImage(data['user'].avatarUrl)
                        : null,
                    backgroundColor: Colors.grey[800],
                    child: data['user'].avatarUrl == null
                        ? Text(
                            data['user'].username?[0].toUpperCase() ?? '?',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      data['user'].username ?? 'Unknown',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '${data['score']}',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    ' Striks',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    });
  }

  Widget _buildMinimalPodiumItem(Map<String, dynamic> data, int place) {
    final isFirst = place == 1;
    final double avatarSize = isFirst ? 80 : 60;
    // Elegant colors, less saturated
    final Color color = place == 1
        ? const Color(0xFFFFD700)
        : (place == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: CircleAvatar(
                radius: avatarSize / 2,
                backgroundImage: data['user'].avatarUrl != null
                    ? NetworkImage(data['user'].avatarUrl)
                    : null,
                backgroundColor: Colors.grey[800],
                child: data['user'].avatarUrl == null
                    ? Text(
                        data['user'].username?[0].toUpperCase() ?? '?',
                        style: TextStyle(
                          fontSize: avatarSize / 3,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data['user'].username ?? 'Unknown',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${data['score']}',
              style: GoogleFonts.spaceGrotesk(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Clean pedestal
          Container(
            width: double.infinity,
            height: isFirst ? 30 : 15,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$place',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.grey[500],
                fontWeight: FontWeight.bold,
                fontSize: isFirst ? 14 : 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeedTab() {
    _controller.fetchActivityFeed();
    final currentUser = Supabase.instance.client.auth.currentUser;

    return Column(
      children: [
        // Create Post Input
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primary.withOpacity(0.2),
                child: const Icon(
                  Icons.edit,
                  size: 16,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Spill kegiatan lo hari ini...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: Colors.grey[600],
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (value) {
                    _controller.createPost(value);
                  },
                ),
              ),
              Obx(
                () => _controller.isCreatingPost.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        // Feed List
        Expanded(
          child: Obx(() {
            if (_controller.isLoadingActivity.value) {
              return const Center(child: CustomLoadingIndicator());
            }

            if (_controller.activityFeed.isEmpty) {
              return Center(
                child: Text(
                  'Masih sepi nih, belum ada yang pamer! 🦗',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => _controller.fetchActivityFeed(refresh: true),
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                itemCount:
                    _controller.activityFeed.length +
                    (_controller.isLoadingMoreActivity.value ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _controller.activityFeed.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CustomLoadingIndicator()),
                    );
                  }
                  final item = _controller.activityFeed[index];
                  final type = item['type'];
                  final data = item['data'];
                  final date = item['timestamp'] as DateTime;

                  // Map data based on type
                  String titleText = '';
                  String username = '';
                  String? avatarUrl;
                  List reactions = data['reactions'] ?? [];

                  // Helper to check my reaction
                  bool hasReacted = false;
                  if (currentUser != null) {
                    hasReacted = reactions.any(
                      (r) => r['user_id'] == currentUser.id,
                    );
                  }

                  if (type == 'habit_log') {
                    // Habit Log
                    final habit = data['habit'];
                    final user = habit['user'];
                    username = user['username'] ?? 'User';
                    avatarUrl = user['avatar_url'];
                    titleText = habit['title'];
                  } else {
                    // Post
                    final user = data['user'];
                    username = user['username'] ?? 'User';
                    avatarUrl = user['avatar_url'];
                    titleText = data['content'];
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
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
                              backgroundImage: avatarUrl != null
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl == null
                                  ? Text(username[0].toUpperCase())
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.plusJakartaSans(
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
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                          ),
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
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    timeago.format(date),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (type == 'post' &&
                                data['user_id'] == currentUser?.id)
                              IconButton(
                                icon: const Icon(
                                  Icons.more_horiz,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.grey[900],
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    builder: (context) => Container(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Handle Bar
                                          Container(
                                            width: 40,
                                            height: 4,
                                            margin: const EdgeInsets.only(
                                              bottom: 24,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[700],
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          // Delete Option
                                          InkWell(
                                            onTap: () {
                                              Navigator.pop(
                                                context,
                                              ); // Close sheet
                                              _controller.deletePost(
                                                data['id'],
                                              );
                                            },
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                    horizontal: 16,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red,
                                                    size: 24,
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Text(
                                                    'Hapus Postingan',
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                          color: Colors.red,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),

                        // Reaction Button
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (type == 'habit_log') {
                                  _controller.toggleReaction(
                                    habitLogId: data['id'],
                                  );
                                } else {
                                  _controller.toggleReaction(
                                    postId: data['id'],
                                  );
                                }
                              },
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
                                    // Fire Icon (Lottie or Static)
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Lottie.asset(
                                        'assets/src/strik-logo.json',
                                        animate: hasReacted,
                                        repeat: false,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${reactions.length}',
                                      style: GoogleFonts.spaceGrotesk(
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
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFriendsTab() {
    // Auto-refresh when building this tab
    _controller.fetchPendingRequests();
    if (_controller.friends.isEmpty) _controller.fetchFriends();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Pending Requests (Incoming)
          Obx(() {
            if (_controller.pendingRequests.isNotEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                color: Colors.amber.withOpacity(0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request Masuk (${_controller.pendingRequests.length})',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._controller.pendingRequests.map((req) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          req['sender']['username'] ?? 'User',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              onPressed: () =>
                                  _controller.acceptRequest(req['id']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () =>
                                  _controller.rejectRequest(req['id']),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          // Sent Requests (Outgoing)
          Obx(() {
            if (_controller.sentRequests.isNotEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.withOpacity(0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request Terkirim (${_controller.sentRequests.length})',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._controller.sentRequests.map((req) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text(
                            req['receiver']['username']?[0].toUpperCase() ??
                                '?',
                          ),
                        ),
                        title: Text(
                          req['receiver']['username'] ?? 'User',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Lagi digantung... 👻',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          // Friends List
          Obx(() {
            if (_controller.friends.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Belum ada bestie nih 😔\nTap + buat nambah temen!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(color: Colors.grey),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _controller.friends.length,
              itemBuilder: (context, index) {
                final friend = _controller.friends[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(friend.username?[0].toUpperCase() ?? '?'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          friend.username ?? 'User',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      FutureBuilder<bool>(
                        future: _controller.canPokeUser(friend.id),
                        builder: (context, snapshot) {
                          final canPoke = snapshot.data ?? true;
                          return IconButton(
                            onPressed: () async {
                              if (canPoke) {
                                await _controller.sendNudge(friend.id);
                                setState(
                                  () {},
                                ); // Trigger rebuild to show disabled state
                              } else {
                                // Show remaining time when disabled icon is tapped
                                final currentUser =
                                    Supabase.instance.client.auth.currentUser;
                                if (currentUser != null) {
                                  final friendship = await Supabase
                                      .instance
                                      .client
                                      .from('friendships')
                                      .select('last_poke_at')
                                      .or(
                                        'and(requester_id.eq.${currentUser.id},receiver_id.eq.${friend.id}),and(requester_id.eq.${friend.id},receiver_id.eq.${currentUser.id})',
                                      )
                                      .eq('status', 'accepted')
                                      .maybeSingle();

                                  if (friendship != null &&
                                      friendship['last_poke_at'] != null) {
                                    final lastPokeAt = DateTime.parse(
                                      friendship['last_poke_at'],
                                    ).toLocal();
                                    final now = DateTime.now();
                                    final minutesSinceLastPoke = now
                                        .difference(lastPokeAt)
                                        .inMinutes;
                                    final minutesRemaining =
                                        1440 - minutesSinceLastPoke;
                                    final hoursRemaining =
                                        (minutesRemaining / 60).ceil().clamp(
                                          1,
                                          24,
                                        );

                                    Get.snackbar(
                                      'Sabar dulu!',
                                      'Lo baru bisa colek lagi dalam $hoursRemaining jam. Kasih jeda dong! 😅',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: Colors.orange
                                          .withOpacity(0.8),
                                      colorText: Colors.white,
                                    );
                                  }
                                }
                              }
                            },
                            icon: Text(
                              '👋',
                              style: TextStyle(
                                fontSize: 24,
                                color: canPoke
                                    ? null
                                    : Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            tooltip: canPoke ? 'Colek' : 'Belum bisa colek',
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}
