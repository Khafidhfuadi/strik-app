import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:strik_app/controllers/friend_controller.dart';
import 'package:strik_app/screens/add_friend_screen.dart';
import 'package:strik_app/screens/notifications_screen.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/widgets/custom_loading_indicator.dart';
import 'package:timeago/timeago.dart' as timeago;

class SocialScreen extends StatefulWidget {
  final Widget? bottomNavigationBar;
  const SocialScreen({super.key, this.bottomNavigationBar});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final FriendController _controller = Get.put(FriendController());
  int _selectedIndex = 0;
  final List<String> _tabs = ['Ranking', 'Feed', 'Friends'];
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                    'Community',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () => Get.to(() => const NotificationsScreen()),
                  ),
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

            // Custom Tab Chips (Matching Home Style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        color: isActive ? Colors.grey[900] : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          color: isActive ? Colors.white : Colors.grey[600],
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _selectedIndex = index),
                children: [
                  _buildLeaderboardTab(),
                  _buildActivityFeedTab(),
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
                'No scores yet!',
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
                    ' pts',
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

    return Obx(() {
      if (_controller.isLoadingActivity.value) {
        return const Center(child: CustomLoadingIndicator());
      }

      if (_controller.activityFeed.isEmpty) {
        return const Center(
          child: Text(
            'No activity yet. Be the first!',
            style: TextStyle(color: Colors.white54),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _controller.activityFeed.length,
        itemBuilder: (context, index) {
          final log = _controller.activityFeed[index];
          final habit = log['habit'];
          final user = habit['user'];
          final date = DateTime.parse(log['completed_at']);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  child: Text(user['username'][0].toUpperCase()),
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
                              text: user['username'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: ' just crushed ',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                            TextSpan(
                              text: habit['title'],
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
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
              ],
            ),
          );
        },
      );
    });
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
                          'Menunggu konfirmasi...',
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
                      IconButton(
                        onPressed: () => _controller.sendNudge(friend.id),
                        icon: const Text('👋', style: TextStyle(fontSize: 24)),
                        tooltip: 'Colek',
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
