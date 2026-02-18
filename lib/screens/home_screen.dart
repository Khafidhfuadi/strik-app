import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart'; // Added for HapticFeedback
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/controllers/habit_controller.dart';
import 'package:strik_app/controllers/home_controller.dart';
import 'package:strik_app/controllers/friend_controller.dart';
import 'package:strik_app/screens/create_habit_screen.dart';
import 'package:strik_app/screens/habit_detail_screen.dart';
import 'package:strik_app/screens/social_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/controllers/tour_controller.dart';
import 'package:strik_app/widgets/habit_card.dart';
import 'package:strik_app/widgets/weekly_habit_card.dart';
import 'package:strik_app/screens/statistics_screen.dart';
import 'package:strik_app/widgets/custom_loading_indicator.dart';
import 'package:strik_app/controllers/update_profile_controller.dart';
import 'package:strik_app/widgets/custom_text_field.dart';
import 'package:strik_app/widgets/primary_button.dart';
import 'package:strik_app/screens/notification_debug_screen.dart';
import 'package:strik_app/controllers/gamification_controller.dart';
import 'package:strik_app/controllers/habit_challenge_controller.dart';
import 'package:strik_app/data/models/habit_challenge.dart';
import 'package:strik_app/screens/level_progression_screen.dart';
import 'package:strik_app/screens/suhu_home_screen.dart';
import 'package:strik_app/screens/legend_home_screen.dart';
import 'package:strik_app/screens/goat_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late PageController _pageController;

  Timer? _alarmCheckTimer;

  @override
  void initState() {
    super.initState();
    Get.put(TourController());
    WidgetsBinding.instance.addObserver(this);
    final homeController = Get.find<HomeController>();
    // Initialize PageController based on current tab
    int initialPage = 0;
    if (homeController.currentTab.value == 'Mingguan') initialPage = 1;
    _pageController = PageController(initialPage: initialPage);

    // Periodic check for alarm consistency (every 1 minute)
    // This helps catch cases where the alarm might handle execution but fail to reschedule
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      Get.find<HabitController>().checkAlarmConsistency();
    });

    // Check for Gamification Intro
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<GamificationController>()) {
        Get.find<GamificationController>().checkAndShowGamificationIntro();
      }
    });

    // Listen to XP events for animation
    if (Get.isRegistered<GamificationController>()) {
      Get.find<GamificationController>().xpEventStream.listen((event) {
        if (mounted) {
          _showXPAnimation((event['amount'] as num).toDouble());
        }
      });
    }

    // Start Tour (Only if using default home screen, logic checks implemented in trigger)
    // Wait for content to load so keys are attached to widgets (not loading indicator)
    ever(Get.find<HabitController>().isLoading, (isLoading) {
      if (!isLoading) {
        // Slight delay to ensure frame is painted
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Get.find<TourController>().startDefaultHomeTour(context);
        });
      }
    });

    // Also check initial state in case data is already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.find<HabitController>().isLoading.value) {
        Get.find<TourController>().startDefaultHomeTour(context);
      }
    });
  }

  void _showXPAnimation(double amount) {
    if (amount == 0) return;

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 60, // Below header approx
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 2000),
                curve: Curves.linear, // Use linear time for simpler control
                builder: (context, value, child) {
                  // 1. Bounce Scale: Fast (first 40% of time)
                  // 0.0 -> 0.4 mapped to 0.0 -> 1.0 for elastic curve
                  final scaleCurve = const Interval(
                    0.0,
                    0.4,
                    curve: Curves.elasticOut,
                  ).transform(value);

                  // 2. Move Up: Slow & Steady (full duration)
                  final moveCurve = const Interval(
                    0.0,
                    1.0,
                    curve: Curves.easeOutCubic,
                  ).transform(value);

                  // 3. Opacity: Fade out at end (last 20%)
                  double opacity = 1.0;
                  if (value > 0.8) {
                    opacity = (1.0 - value) * 5;
                  }

                  // Format amount
                  String textAmount;
                  if (amount == amount.roundToDouble()) {
                    textAmount = amount.toInt().toString();
                  } else {
                    textAmount = amount.toStringAsFixed(1);
                  }

                  return Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -60 * moveCurve), // Move up
                      child: Transform.scale(
                        scale: scaleCurve.clamp(
                          0.0,
                          2.0,
                        ), // Prevent extreme overshoot
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: amount > 0
                                ? const Color(0xFFFFD700)
                                : const Color(0xFFFF5757),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (amount > 0
                                            ? const Color(0xFFFFD700)
                                            : const Color(0xFFFF5757))
                                        .withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                amount > 0
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                color: Colors.black,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${amount > 0 ? '+' : ''}$textAmount XP',
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                onEnd: () {
                  entry?.remove();
                },
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(entry);
  }

  @override
  void dispose() {
    _alarmCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Get.find<HabitController>().checkDailyRefresh();
    }
  }

  void _onTabChanged(int index) {
    // Sync tab change from PageView
    final homeController = Get.find<HomeController>();
    final tabs = ['Harian', 'Mingguan'];
    if (index >= 0 && index < tabs.length) {
      homeController.currentTab.value = tabs[index];
    }
  }

  void _onTabTapped(int index) {
    // 1. Update state IMMEDIATELY for snappy UI
    final homeController = Get.find<HomeController>();
    final tabs = ['Harian', 'Mingguan'];
    if (index >= 0 && index < tabs.length) {
      homeController.currentTab.value = tabs[index];
    }

    // 2. Animate PageView
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final HabitController controller = Get.find();
    final HomeController homeController = Get.find();
    final GamificationController gamificationController = Get.find();

    return Obx(() {
      final navBar = _buildBottomNavigationBar(homeController);

      if (homeController.selectedIndex.value == 1) {
        return SocialScreen(bottomNavigationBar: navBar);
      }

      if (homeController.selectedIndex.value == 2) {
        return Scaffold(
          body: const StatisticsScreen(),
          bottomNavigationBar: navBar,
        );
      }

      // Check GOAT Status (Level 10+)
      if (gamificationController.currentLevel.value >= 10) {
        return GoatHomeScreen(bottomNavigationBar: navBar);
      }

      // Check Legend Status (Level 9)
      if (gamificationController.currentLevel.value >= 9) {
        return LegendHomeScreen(bottomNavigationBar: navBar);
      }

      // Check Suhu Status (Level 8)
      if (gamificationController.currentLevel.value >= 8) {
        return SuhuHomeScreen(bottomNavigationBar: navBar);
      }

      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Row(
            children: [
              Text(
                'Strik',
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              // const SizedBox(width: 4),
              Lottie.asset(
                'assets/src/kareem-logo.json',
                width: 50,
                height: 50,
                repeat: false,
              ),
            ],
          ),
          backgroundColor: AppTheme.background,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: () => _showFilterBottomSheet(context),
            ),
            IconButton(
              icon: const Icon(Icons.add_link_rounded, color: Colors.white),
              onPressed: () => _showJoinChallengeBottomSheet(context),
              tooltip: 'Gabung Challenge',
            ),
            IconButton(
              key: Get.find<TourController>().keyHomeFab,
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _navigateAndRefresh(context),
            ),
            //profile icon
            IconButton(
              key: Get.find<TourController>().keyHomeProfile,
              icon: const Icon(Icons.manage_accounts, color: Colors.white),
              onPressed: () => _showProfileBottomSheet(context),
            ),
          ],
        ),
        body: controller.isLoading.value
            ? const Center(child: CustomLoadingIndicator())
            : Column(
                children: [
                  _buildGamificationHeader(gamificationController),
                  // Tab Bar
                  Container(
                    key: Get.find<TourController>().keyHomeDate,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        _buildTabChip('Harian', 0, homeController),
                        const SizedBox(width: 12),
                        _buildTabChip('Mingguan', 1, homeController),
                      ],
                    ),
                  ),

                  // Content Area with PageView
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: _onTabChanged,
                      children: [
                        // Today Page
                        _buildTodayPage(controller),
                        // Weekly Page
                        _buildWeeklyList(controller),
                      ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: navBar,
      );
    });
  }

  Widget _buildGamificationHeader(GamificationController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Get.to(() => const LevelProgressionScreen());
        },
        child: Container(
          key: Get.find<TourController>().keyHomeGamification,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFFFD700),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${controller.currentLevelName} (Lvl ${controller.currentLevel})',
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${controller.currentXP == controller.currentXP.roundToDouble() ? controller.currentXP.toInt() : controller.currentXP} / ${controller.xpToNextLevel} XP',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: controller.xpProgress),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return LinearProgressIndicator(
                            value: value,
                            backgroundColor: Colors.grey[800],
                            color: const Color(0xFFFFD700),
                            minHeight: 6,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(String label, int index, HomeController homeController) {
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Obx(() {
        final isActive = homeController.currentTab.value == label;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.grey[900] : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              color: isActive ? Colors.white : Colors.grey[600],
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTodayPage(HabitController controller) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: controller.todayProgress,
                backgroundColor: Colors.grey[800],
                color: const Color(0xFFFF5757),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                '${controller.todayLogs.values.where((s) => s == 'completed').length} kelar • ${controller.todayLogs.values.where((s) => s == 'skipped').length} skip',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildTodayList(controller)),
        // Archived challenges link
        if (Get.isRegistered<HabitChallengeController>())
          Obx(() {
            final archivedCount =
                Get.find<HabitChallengeController>().archivedChallenges.length;
            if (archivedCount == 0) return const SizedBox.shrink();
            return InkWell(
              onTap: () => _showArchivedChallengesBottomSheet(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Arsip Challenge ($archivedCount)',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTodayList(HabitController controller) {
    // Check if there are any habits scheduled for today at all
    if (controller.habitsForToday.isEmpty) {
      // Show Dummy Habit Card for Tour if not shown
      // Make it reactive to tour state
      final tourController = Get.find<TourController>();
      return Obx(() {
        if (!tourController.isHomeTourShown.value) {
          // Create a dummy habit
          final dummyHabit = Habit(
            id: 'dummy_tour_habit',
            userId: 'dummy',
            title: 'Minum Air Putih',
            // icon: '💧', // Prop not available
            color: '2196F3', // Blue
            frequency: 'daily',
            // targetCount: 1, // Prop not available
            // unit: 'gelas', // Prop not available
            createdAt: DateTime.now(),
          );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Dummy Card for Tour Target
              AbsorbPointer(
                absorbing: true, // Prevent interaction
                child: Container(
                  key: tourController.keyHomeHabitCard,
                  child: HabitCard(
                    habit: dummyHabit,
                    status: null, // Initial state
                    onTap: () {},
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Ini contoh habit buat latihan',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: () => controller.fetchHabitsAndLogs(isRefresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: const Center(
                  child: Text(
                    'Belum ada habit nih, gass bikin!',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ],
          ),
        );
      });
    }

    final habits = controller.sortedHabits;

    // Check if all habits are completed and hidden
    if (habits.isEmpty &&
        controller.isAllHabitsCompletedForToday &&
        !controller.showCompleted.value) {
      return RefreshIndicator(
        onRefresh: () => controller.fetchHabitsAndLogs(isRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset(
                      'assets/src/complete-habit.json',
                      width: 250,
                      height: 250,
                      repeat: false,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Mantap! Semua habit hari ini udah kelar 🎉',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.fetchHabitsAndLogs(isRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: habits.length,
        itemBuilder: (context, index) {
          final habit = habits[index];

          return Obx(() {
            final status = controller.todayLogs[habit.id];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Dismissible(
                  key: Key(habit.id!),
                  confirmDismiss: (direction) async {
                    HapticFeedback.lightImpact();
                    await controller.toggleHabitStatus(
                      habit,
                      status,
                      direction,
                    );
                    return false; // Toggle handled in controller
                  },
                  background: _buildSwipeBackground(
                    Alignment.centerLeft,
                    status == 'completed' ? Icons.undo : Icons.check,
                    status == 'completed' ? 'batalin' : 'sikat',
                    AppTheme.primary,
                    Colors.black,
                  ),
                  secondaryBackground: _buildSwipeBackground(
                    Alignment.centerRight,
                    status == 'skipped' ? Icons.undo : Icons.close,
                    status == 'skipped' ? 'gajadi' : 'skip dlu',
                    const Color(0xFFFF5757),
                    Colors.white,
                  ),
                  child: Container(
                    key: index == 0
                        ? Get.find<TourController>().keyHomeHabitCard
                        : null,
                    child: HabitCard(
                      habit: habit,
                      status: status,
                      onTap: () =>
                          Get.to(() => HabitDetailScreen(habit: habit)),
                    ),
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildSwipeBackground(
    Alignment alignment,
    IconData icon,
    String text,
    Color color,
    Color textColor,
  ) {
    return Container(
      // Outer container is transparent
      alignment: alignment,
      // Add padding to create a "gap" between the card and the pill background
      padding: alignment == Alignment.centerLeft
          ? const EdgeInsets.only(right: 20)
          : const EdgeInsets.only(left: 20),
      child: Container(
        // The Pill shape
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(100), // Fully rounded pill
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alignment == Alignment.centerLeft) ...[
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (alignment == Alignment.centerRight) ...[
              const SizedBox(width: 8),
              Icon(icon, color: textColor, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyList(HabitController controller) {
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    final weekStart = now.subtract(Duration(days: currentWeekday - 1));

    if (controller.habits.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => controller.fetchHabitsAndLogs(isRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: const Center(
                child: Text(
                  'Belum ada habit nih!',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.fetchHabitsAndLogs(isRefresh: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: controller.habits.length,
        itemBuilder: (context, index) {
          final habit = controller.habits[index];
          return Obx(() {
            final logs = controller.weeklyLogs[habit.id] ?? {};
            return WeeklyHabitCard(
              habit: habit,
              weeklyLogs: logs,
              weekStart: weekStart,
            );
          });
        },
      ),
    );
  }

  Widget _buildBottomNavigationBar(HomeController homeController) {
    return BottomNavigationBar(
      backgroundColor: AppTheme.surface,
      selectedItemColor: AppTheme.primary,
      unselectedItemColor: Colors.white54,
      currentIndex: homeController.selectedIndex.value,
      onTap: (index) {
        HapticFeedback.lightImpact();
        homeController.selectedIndex.value = index;
        // Clear red dot when entering Social tab
        if (index == 1 && Get.isRegistered<FriendController>()) {
          Get.find<FriendController>().clearSocialDot();
        }
      },
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Obx(() {
            final hasNew =
                Get.isRegistered<FriendController>() &&
                Get.find<FriendController>().hasNewSocialActivity.value;
            return Badge(
              isLabelVisible: hasNew,
              backgroundColor: Colors.red,
              smallSize: 8,
              child: const Icon(Icons.wc_rounded),
            );
          }),
          label: 'Social',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_rounded),
          label: 'Stats',
        ),
      ],
    );
  }

  void _navigateAndRefresh(BuildContext context) async {
    await Get.to(() => const CreateHabitScreen());
    Get.find<HabitController>().fetchHabitsAndLogs(isRefresh: true);

    // Check if a challenge was just created
    if (Get.isRegistered<HabitChallengeController>()) {
      final challengeCtrl = Get.find<HabitChallengeController>();
      if (challengeCtrl.pendingInviteCode.value.isNotEmpty) {
        final code = challengeCtrl.pendingInviteCode.value;
        final title = challengeCtrl.pendingHabitTitle.value;
        challengeCtrl.pendingInviteCode.value = '';
        challengeCtrl.pendingHabitTitle.value = '';
        // Delay to let the navigation settle
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _showChallengeInviteBottomSheet(context, code, title);
        });
      }
    }
  }

  void _showChallengeInviteBottomSheet(
    BuildContext context,
    String inviteCode,
    String habitTitle,
  ) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFF59E0B),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Challenge Dibuat!',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bagikan kode ini ke temanmu untuk bergabung challenge "$habitTitle"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.link, color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    inviteCode,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: inviteCode));
                  Get.snackbar(
                    'Tersalin!',
                    'Kode undangan berhasil disalin',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text(
                  'Salin Kode Undangan',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Share.share(
                    'Gaskeun join challenge "$habitTitle" di Strik! Pake kode ini: $inviteCode',
                    subject: 'Mabar Challenge Strik',
                  );
                },
                icon: const Icon(Icons.share, size: 18),
                label: const Text(
                  'Bagikan Undangan',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Get.back(),
              child: const Text(
                'Tutup',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showJoinChallengeBottomSheet(BuildContext context) {
    final codeController = TextEditingController();
    final isSearching = false.obs;

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Gabung Challenge',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Masukkan kode undangan dari temanmu',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Space Grotesk',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'KODE UNDANGAN',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  letterSpacing: 3,
                ),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSearching.value
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.isEmpty) {
                            Get.snackbar(
                              'Oops',
                              'Masukkan kode undangan dulu',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                            return;
                          }
                          if (!Get.isRegistered<HabitChallengeController>()) {
                            return;
                          }

                          isSearching.value = true;
                          final ctrl = Get.find<HabitChallengeController>();
                          final challenge = await ctrl.lookupChallenge(code);
                          isSearching.value = false;

                          if (challenge != null) {
                            Get.back(); // Close input sheet
                            _showChallengePreviewBottomSheet(
                              context,
                              challenge,
                            );
                          } else {
                            Get.snackbar(
                              'Oops',
                              'Kode undangan tidak valid atau challenge tidak ditemukan',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSearching.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Cari Challenge',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showChallengePreviewBottomSheet(
    BuildContext context,
    dynamic challenge,
  ) {
    final isJoining = false.obs;
    final habitChallenge = challenge as HabitChallenge;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFF59E0B),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              habitChallenge.habitTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (habitChallenge.habitDescription != null &&
                habitChallenge.habitDescription!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                habitChallenge.habitDescription!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13,
                  color: Colors.white54,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _buildChallengeInfoRow(
                    'Frekuensi',
                    habitChallenge.habitFrequency.capitalizeFirst ?? '',
                  ),
                  const SizedBox(height: 8),
                  _buildChallengeInfoRow(
                    'Berakhir',
                    '${habitChallenge.endDate.day}/${habitChallenge.endDate.month}/${habitChallenge.endDate.year}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Obx(
              () => SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isJoining.value
                      ? null
                      : () async {
                          isJoining.value = true;
                          final ctrl = Get.find<HabitChallengeController>();
                          final success = await ctrl.joinChallenge(
                            habitChallenge,
                          );
                          isJoining.value = false;
                          if (success) {
                            Navigator.of(context).pop();
                            Get.find<HabitController>().fetchHabitsAndLogs(
                              isRefresh: true,
                            );
                          }
                        },
                  icon: isJoining.value
                      ? const SizedBox.shrink()
                      : const Icon(Icons.handshake_outlined, size: 18),
                  label: isJoining.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Gabung Challenge!',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Get.back(),
              child: const Text(
                'Batal',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showArchivedChallengesBottomSheet(BuildContext context) {
    final challenges = Get.find<HabitChallengeController>().archivedChallenges;

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Icon(Icons.archive_outlined, color: Colors.grey[400], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Arsip Challenge',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: challenges.length,
                separatorBuilder: (_, __) =>
                    Divider(color: Colors.grey[800], height: 1),
                itemBuilder: (context, index) {
                  final c = challenges[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.grey,
                      size: 28,
                    ),
                    title: Text(
                      c.habitTitle,
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      'Berakhir: ${c.endDate.day}/${c.endDate.month}/${c.endDate.year}',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        c.status == 'completed' ? 'Selesai' : 'Arsip',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildChallengeInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 13,
            color: Colors.white54,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  void _showProfileBottomSheet(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final username =
        metadata?['username'] ?? user?.email?.split('@')[0] ?? 'User';
    final email = user?.email ?? '-';
    // Use avatar_url if available, otherwise null
    final avatarUrl = metadata?['avatar_url'] as String?;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.2),
                border: Border.all(color: AppTheme.primary, width: 2),
                image: avatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatarUrl == null
                  ? Center(
                      child: Text(
                        username.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),

            // User Info
            Text(
              username,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.white54,
              ),
            ),

            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            // Reset Tutorial Button
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.restart_alt_rounded,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              title: const Text(
                'Reset Tutorial',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Get.back(); // Close bottom sheet
                Get.find<TourController>().resetAllTours();
              },
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 8),

            // Edit Profile (Placeholder)
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Colors.white),
              title: Text(
                'Edit Profil',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white54,
              ),
              onTap: () {
                Get.back(); // Close view profile sheet
                _showEditProfileBottomSheet(context);
              },
            ),

            // Alarm Schedule
            ListTile(
              leading: const Icon(Icons.alarm),
              title: Text(
                'Alarm Mendatang',
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white54,
              ),
              onTap: () {
                Get.back(); // Close profile sheet
                Get.to(() => const AlarmManagementScreen());
              },
            ),

            // Logout
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFEF4444),
              ),
              title: Text(
                'Logout',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Get.back();
                Get.find<HomeController>().logout();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _showEditProfileBottomSheet(BuildContext context) {
    final updateController = Get.put(UpdateProfileController());
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final currentAvatarUrl = metadata?['avatar_url'] as String?;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Edit Profil',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Avatar Picker
            Center(
              child: GestureDetector(
                onTap: () => updateController.pickImage(),
                child: Obx(() {
                  final selectedImage = updateController.selectedImage.value;

                  return Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      border: Border.all(color: AppTheme.primary, width: 2),
                      image: selectedImage != null
                          ? DecorationImage(
                              image: FileImage(selectedImage),
                              fit: BoxFit.cover,
                            )
                          : (currentAvatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(currentAvatarUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                    ),
                    child: selectedImage == null && currentAvatarUrl == null
                        ? const Icon(
                            Icons.add_a_photo_rounded,
                            color: AppTheme.primary,
                            size: 32,
                          )
                        : Stack(
                            children: [
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.black,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tap untuk ubah foto',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
            ),
            const SizedBox(height: 24),

            CustomTextField(
              controller: updateController.usernameController,
              label: 'Username',
              hintText: 'Masukkan username baru',
            ),
            const SizedBox(height: 24),
            Obx(
              () => PrimaryButton(
                text: 'Simpan',
                onPressed: () => updateController.updateProfile(),
                isLoading: updateController.isLoading.value,
              ),
            ),
            const SizedBox(height: 16), // Padding for bottom safe area
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    final controller = Get.find<HabitController>();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Filter Habit',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Obx(
              () => SwitchListTile(
                title: const Text(
                  'Tampilkan yang udah kelar',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    color: Colors.white,
                  ),
                ),
                value: controller.showCompleted.value,
                onChanged: (val) => controller.showCompleted.value = val,
                activeThumbColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Obx(
              () => SwitchListTile(
                title: const Text(
                  'Tampilkan yang di-skip',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    color: Colors.white,
                  ),
                ),
                value: controller.showSkipped.value,
                onChanged: (val) => controller.showSkipped.value = val,
                activeThumbColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(text: 'Terapkan Filter', onPressed: () => Get.back()),
            const SizedBox(height: 16),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}
