import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // Added for HapticFeedback

import 'package:strik_app/controllers/friend_controller.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/screens/add_friend_screen.dart';
import 'package:strik_app/screens/notifications_screen.dart';
import 'package:strik_app/widgets/custom_loading_indicator.dart';
import 'package:strik_app/widgets/story_bar.dart';
import 'package:strik_app/controllers/tour_controller.dart';

class SocialScreen extends StatefulWidget {
  final Widget? bottomNavigationBar;
  const SocialScreen({super.key, this.bottomNavigationBar});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final FriendController _controller = Get.put(FriendController());
  // Helper for Story refresh if needed, but StoryBar handles its own controller
  // However, linking refresh is good.

  int _selectedIndex = 0;
  final List<String> _tabs = ['Feed', 'Rank', 'Circle'];
  late PageController _pageController;

  GlobalKey? _getTabKey(int index) {
    // Only verify keys if tour is NOT shown to prevent duplication error
    if (Get.find<TourController>().isSocialTourShown.value) return null;

    if (index == 1) return Get.find<TourController>().keySocialRank;
    if (index == 2) return Get.find<TourController>().keySocialCircle;
    return null;
  }

  final _scrollController = ScrollController();
  final TextEditingController _postController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Get.put(TourController());
    _pageController = PageController(initialPage: _selectedIndex);
    _scrollController.addListener(_onScroll);

    // Start Tour
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<TourController>().startSocialTour(context);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _postController.dispose();
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
    HapticFeedback.lightImpact(); // Haptic feedback
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
    } else {
      _controller.markFeedAsLeft();
    }
  }

  Widget _buildBadgeUI(int count, int index, bool isActive) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: index == 0
            ? Colors.red
            : (isActive ? Colors.white24 : Colors.grey[800]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
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
                    'Sosialita',
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  const Spacer(),
                  // Dynamic Action Button based on Tab with Animation
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: _selectedIndex == 0
                        ? Obx(() {
                            final unreadCount =
                                _controller.unreadNotificationCount.value;
                            return IconButton(
                              key: const ValueKey(
                                0,
                              ), // Unique key for animation
                              icon: Badge(
                                label: Text('$unreadCount'),
                                isLabelVisible: unreadCount > 0,
                                child: const Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Get.to(() => const NotificationsScreen());
                              },
                            );
                          })
                        : _selectedIndex == 1
                        ? IconButton(
                            key: const ValueKey(1),
                            icon: const Icon(
                              Icons.history_rounded,
                              color: Colors.white,
                            ),
                            onPressed: _showHistorySheet,
                            tooltip: 'Riwayat Mingguan',
                          )
                        : Obx(() {
                            final tourController = Get.find<TourController>();
                            return IconButton(
                              key: !tourController.isSocialTourShown.value
                                  ? tourController.keySocialSearch
                                  : null,
                              icon: const Icon(
                                Icons.person_add_alt_1_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  Get.to(() => const AddFriendScreen()),
                            );
                          }),
                  ),
                ],
              ),
            ),

            // Custom Tab Chips (Matching Home Style) with Badges
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Obx(
                  () => Row(
                    children: _tabs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final label = entry.value;
                      final isActive = _selectedIndex == index;

                      return GestureDetector(
                        key: _getTabKey(index),
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
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
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
                              if (index == 2)
                                Obx(
                                  () => _buildBadgeUI(
                                    _controller.friends.length,
                                    index,
                                    isActive,
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
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
                  } else {
                    _controller.markFeedAsLeft();
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
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _showPostBottomSheet,
              backgroundColor: AppTheme.primary, // Used AppTheme here
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.edit_outlined),
            )
          : null,
    );
  }

  void _showPostBottomSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Buat Feed Baru',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _postController,
              autofocus: true,
              maxLines: 4,
              minLines: 2,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Curhat apa tudey?',
                hintStyle: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Colors.grey[600],
                ),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Obx(
                () => ElevatedButton(
                  onPressed: _controller.isCreatingPost.value
                      ? null
                      : () async {
                          if (_postController.text.trim().isEmpty) return;
                          if (await _controller.createPost(
                            _postController.text,
                          )) {
                            _postController.clear();
                            Navigator.of(
                              context,
                            ).pop(); // Close bottom sheet safely
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _controller.isCreatingPost.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Gas Kirim',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
            // Add padding for keyboard
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
      isScrollControlled: true, // Important for full keyboard adjustment
      enterBottomSheetDuration: const Duration(milliseconds: 300),
      exitBottomSheetDuration: const Duration(milliseconds: 300),
    );
  }

  String _getWeeklyWinnerTitle() {
    // List of Gen-Z Indo titles
    final titles = [
      'MENYALA ABANGKUH! 🔥',
      'SIPALING RAJIN EUYY',
      'GASPOL POLL BESTIE',
      'KEREN BANGET SIH LO',
      'KONSISTEN BANGET CUYY',
      'NGALAHIN SEMUA NI BOSS',
      'AJIB PARAH DAH',
      'SULTAN HABBIT OF THE WEEK',
      'GG ABIZZ DAH',
      'MVP OF THE WEEK',
      'SIPALING MAGER AKHIRNYA JUARA 1',
    ];

    // Get current week number to use as seed
    final now = DateTime.now();
    final weekNumber = ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7)
        .floor();

    // Use week number as index (modulo to stay within bounds)
    return titles[weekNumber % titles.length];
  }

  Widget _buildLeaderboardTab() {
    return Obx(() {
      if (_controller.isLoadingLeaderboard.value) {
        return const Center(child: CustomLoadingIndicator());
      }

      if (_controller.leaderboard.isEmpty) {
        return RefreshIndicator(
          onRefresh: () => _controller.fetchLeaderboard(refresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
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
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      if (_controller.isTransitionPeriod.value) {
        final winner = _controller.leaderboard.first;
        return Stack(
          children: [
            // Full-screen confetti overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Lottie.asset(
                  'assets/src/confetti.json',
                  fit: BoxFit.cover,
                  repeat: true,
                ),
              ),
            ),
            // Content
            RefreshIndicator(
              onRefresh: () => _controller.fetchLeaderboard(refresh: true),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Transition Title
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const Text(
                        'Leaderboard Mingguan',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          onPressed: _showHistorySheet,
                          icon: const Icon(
                            Icons.history_rounded,
                            color: AppTheme.primary,
                          ),
                          tooltip: 'Riwayat Mingguan',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Leaderboard baru dimulai pukul 12:00',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Winner Spotlight - Compact Design
                  GestureDetector(
                    onTap: () => _showUserDetailDialog(winner, 1),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.withValues(alpha: 0.15),
                            Colors.orange.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Weekly Title - Gen-Z Style
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.amber.shade300,
                                Colors.orange.shade400,
                                Colors.amber.shade200,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              _getWeeklyWinnerTitle(),
                              style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Trophy (confetti now full-screen)
                          Lottie.asset(
                            'assets/src/new-trophy.json',
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                            repeat: true,
                          ),

                          // Winner Info
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.amber, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundImage: winner['user'].avatarUrl != null
                                  ? NetworkImage(winner['user'].avatarUrl)
                                  : null,
                              backgroundColor: Colors.grey[800],
                              child: winner['user'].avatarUrl == null
                                  ? Text(
                                      winner['user'].username?[0]
                                              .toUpperCase() ??
                                          '?',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            winner['user'].username ?? 'Unknown',
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.emoji_events,
                                color: Colors.amber,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${winner['score'].toStringAsFixed(1)} pts',
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  color: Colors.amber,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Rest of leaderboard title
                  Text(
                    'Peringkat Lainnya',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ..._controller.leaderboard.skip(1).map((data) {
                    final index = _controller.leaderboard.indexOf(data);
                    return GestureDetector(
                      onTap: () => _showUserDetailDialog(data, index + 1),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
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
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
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
                                      data['user'].username?[0].toUpperCase() ??
                                          '?',
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
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              '${data['score'].toStringAsFixed(1)} pts',
                              style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      }

      final topThree = _controller.leaderboard.take(3).toList();
      final rest = _controller.leaderboard.skip(3).toList();

      return RefreshIndicator(
        onRefresh: () => _controller.fetchLeaderboard(refresh: true),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Title Section
            const Text(
              'Leaderboard Mingguan',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Info Row with Reset Info and Help Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.white54),
                const SizedBox(width: 6),
                Text(
                  'Reset setiap Senin pukul 12:00',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: Text(
                          'Sistem Scoring Leaderboard',
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sistem scoring yang adil untuk semua!',
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Formula:',
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Score = (Completion Rate × 100) + (Total Completed × 0.5)',
                                  style: const TextStyle(
                                    fontFamily: 'Courier',
                                    // Keep source code pro or use monospace
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Contoh:',
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildExampleRow(
                                '7/7 habit (100%)',
                                '103.5 pts',
                                true,
                              ),
                              const SizedBox(height: 4),
                              _buildExampleRow(
                                '11/14 habit (78.6%)',
                                '84.1 pts',
                                false,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Text(
                                    '🔥',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Perfect week (100% completion)',
                                      style: const TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Divider(color: Colors.white24),
                              const SizedBox(height: 16),
                              Text(
                                'Siklus Mingguan:',
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoBullet(
                                'Senin 12:00 - Senin 07:59',
                                'Masa akumulasi poin.',
                              ),
                              const SizedBox(height: 4),
                              _buildInfoBullet(
                                'Senin 08:00 - 12:00',
                                'Freeze Time (Showcase Pemenang).',
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Habit yang selesai saat Freeze Time akan diakumulasi ke minggu berikutnya.',
                                        style: TextStyle(
                                          fontFamily: 'Plus Jakarta Sans',
                                          color: Colors.blue[100],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Mengerti!',
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

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
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showUserDetailDialog(data, index + 1);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
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
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
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
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              if (data['completionRate'] >= 100)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Text(
                                    '🔥',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              Text(
                                '${data['score'].toStringAsFixed(1)}',
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                ' pts',
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${data['completionRate'].toStringAsFixed(0)}% • ${data['totalCompleted']}/${data['totalExpected']}',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
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
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _showUserDetailDialog(data, place);
        },
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
            const SizedBox(height: 8),
            Text(
              data['user'].username ?? 'Unknown',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (data['completionRate'] >= 100)
                        const Padding(
                          padding: EdgeInsets.only(right: 2),
                          child: Text('🔥', style: TextStyle(fontSize: 9)),
                        ),
                      Text(
                        '${data['score'].toStringAsFixed(1)}',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${data['completionRate'].toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: color.withOpacity(0.7),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
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
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: Colors.grey[500],
                  fontWeight: FontWeight.bold,
                  fontSize: isFirst ? 14 : 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetailDialog(Map<String, dynamic> data, int rank) {
    final completionRate = data['completionRate'] as double;
    final totalCompleted = data['totalCompleted'] as int;
    final totalExpected = data['totalExpected'] as int;
    final score = data['score'] as double;
    final user = data['user'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: user.avatarUrl != null
                  ? NetworkImage(user.avatarUrl)
                  : null,
              backgroundColor: Colors.grey[800],
              child: user.avatarUrl == null
                  ? Text(
                      user.username?[0].toUpperCase() ?? '?',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username ?? 'Unknown',
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Rank #$rank',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: Colors.amber,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Score Display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Score',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        if (completionRate >= 100)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Text('🔥', style: TextStyle(fontSize: 16)),
                          ),
                        Text(
                          '${score.toStringAsFixed(1)} pts',
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Calculation Breakdown
              Text(
                'Perhitungan:',
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),

              _buildCalculationRow(
                'Completion Rate',
                '$totalCompleted / $totalExpected habits',
                '${completionRate.toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 4),
              _buildCalculationRow(
                'Rate Score',
                '${completionRate.toStringAsFixed(1)} × 1.0',
                completionRate.toStringAsFixed(1),
              ),
              const SizedBox(height: 4),
              _buildCalculationRow(
                'Volume Bonus',
                '$totalCompleted × 0.5',
                (totalCompleted * 0.5).toStringAsFixed(1),
              ),
              const Divider(height: 24, color: Colors.white24),
              _buildCalculationRow(
                'Total Score',
                '${completionRate.toStringAsFixed(1)} + ${(totalCompleted * 0.5).toStringAsFixed(1)}',
                '${score.toStringAsFixed(1)} pts',
                isTotal: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tutup',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(
    String label,
    String calculation,
    String result, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: isTotal ? Colors.white : Colors.white70,
                  fontSize: isTotal ? 14 : 12,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (!isTotal)
                Text(
                  calculation,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        Text(
          result,
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            color: isTotal ? Colors.amber : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isTotal ? 16 : 13,
          ),
        ),
      ],
    );
  }

  Widget _buildExampleRow(String scenario, String score, bool isWinner) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isWinner ? Colors.green.withOpacity(0.1) : Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWinner ? Colors.green.withOpacity(0.3) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              scenario,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
          Row(
            children: [
              if (isWinner)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text('✓', style: TextStyle(color: Colors.green)),
                ),
              Text(
                score,
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: isWinner ? Colors.green : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeedTab() {
    final currentUser = Supabase.instance.client.auth.currentUser;

    return Column(
      children: [
        // Stories
        // Stories
        Obx(() {
          final tourController = Get.find<TourController>();
          return Container(
            key: !tourController.isSocialTourShown.value
                ? tourController.keySocialStory
                : null,
            child: StoryBar(),
          );
        }),

        // Feed List
        Expanded(
          child: Obx(() {
            if (_controller.isLoadingActivity.value) {
              return const Center(child: CustomLoadingIndicator());
            }

            if (_controller.activityFeed.isEmpty) {
              final tourController = Get.find<TourController>();
              if (!tourController.isSocialTourShown.value) {
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [_buildDummyFeedCard()],
                );
              }

              return const Center(
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
                  vertical: 0,
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
                    key:
                        index == 0 &&
                            !Get.find<TourController>().isSocialTourShown.value
                        ? Get.find<TourController>().keySocialFeed
                        : null,
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
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
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
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    timeago.format(date),
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
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
                                                    style: const TextStyle(
                                                      fontFamily:
                                                          'Plus Jakarta Sans',
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
                                HapticFeedback.lightImpact();
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
                    }),
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
                    }),
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
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: Colors.grey,
                    ),
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
                return GestureDetector(
                  onLongPress: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.grey[900],
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (context) => Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.person_remove,
                                color: Colors.red,
                              ),
                              title: const Text(
                                'Hapus Teman',
                                style: TextStyle(color: Colors.red),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _controller.removeFriend(
                                  friend.id,
                                  friend.username ?? 'Unknown',
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
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
                          backgroundImage: friend.avatarUrl != null
                              ? NetworkImage(friend.avatarUrl!)
                              : null,
                          child: friend.avatarUrl == null
                              ? Text(friend.username?[0].toUpperCase() ?? '?')
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            friend.username ?? 'User',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
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
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoBullet(String time, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6, right: 8),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.white54,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.white70,
                fontSize: 13,
              ),
              children: [
                TextSpan(
                  text: '$time: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showHistorySheet() {
    _controller.fetchLeaderboardHistory();
    Get.bottomSheet(
      Container(
        height: Get.height * 0.6,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Peringkat',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),

            // DEBUG BUTTON
            // TextButton(
            //   onPressed: _controller.debugBackfillLastWeekHistory,
            //   child: const Text(
            //     'Debug: Generate Data Minggu Lalu',
            //     style: TextStyle(color: Colors.white24),
            //   ),
            // ),
            // const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                if (_controller.isLoadingHistory.value) {
                  return const Center(child: CustomLoadingIndicator());
                }

                if (_controller.leaderboardHistory.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.history_toggle_off,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Belum ada riwayat mingguan.',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final myId = Supabase.instance.client.auth.currentUser?.id;
                final myHistory = _controller.leaderboardHistory
                    .where((e) => e['user_id'] == myId)
                    .toList();

                if (myHistory.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada data visual.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: myHistory.length,
                  itemBuilder: (context, index) {
                    final data = myHistory[index];
                    final date = DateTime.parse(data['week_start_date']);
                    final endDate = date.add(const Duration(days: 6));
                    final dateStr =
                        '${DateFormat('d MMM').format(date)} - ${DateFormat('d MMM yyyy').format(endDate)}';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.emoji_events_outlined,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data['total_participants'] != null
                                      ? 'Rank #${data['rank']} dari ${data['total_participants']}'
                                      : 'Rank #${data['rank']}',
                                  style: const TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    color: AppTheme.secondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${data['total_points']} pts',
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(data['completion_rate'] as num).toStringAsFixed(0)}% Rate • ${data['total_habits'] ?? 0} Habits',
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildDummyFeedCard() {
    final tourController = Get.find<TourController>();
    return Obx(
      () => Container(
        key: !tourController.isSocialTourShown.value
            ? tourController.keySocialFeed
            : null,
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
                  backgroundColor: AppTheme.primary,
                  child: const Icon(Icons.flash_on, color: Colors.black),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Strik Team',
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Admin',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                color: AppTheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Baru saja',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Selamat datang di Strik! Cari temanmu dan mulai saling memotivasi! 🔥',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Dummy Reactions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '12',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
