import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:strik_app/controllers/habit_controller.dart';
import 'package:strik_app/controllers/home_controller.dart';

import 'package:strik_app/controllers/gamification_controller.dart';
import 'package:strik_app/controllers/update_profile_controller.dart';
import 'package:strik_app/screens/create_habit_screen.dart';
import 'package:strik_app/screens/habit_detail_screen.dart';
import 'package:strik_app/screens/level_progression_screen.dart';
import 'package:strik_app/screens/notification_debug_screen.dart';
import 'package:strik_app/widgets/custom_loading_indicator.dart';
import 'package:strik_app/widgets/custom_text_field.dart';
import 'package:strik_app/widgets/primary_button.dart';
import 'package:strik_app/widgets/legend_particle_background.dart';
import 'package:strik_app/widgets/weekly_habit_card.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Gold Theme Constants ---
const Color _gold = Color(0xFFFFD700);
const Color _darkGold = Color(0xFF4B3B00);
const Color _darkGrey = Color(0xFF1A1A1A);
const Color _surfaceDark = Color(0xFF1E1E1E);

class SuhuHomeScreen extends StatefulWidget {
  final Widget bottomNavigationBar;

  const SuhuHomeScreen({super.key, required this.bottomNavigationBar});

  @override
  State<SuhuHomeScreen> createState() => _SuhuHomeScreenState();
}

class _SuhuHomeScreenState extends State<SuhuHomeScreen>
    with WidgetsBindingObserver {
  late PageController _pageController;
  Timer? _alarmCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final homeController = Get.find<HomeController>();
    int initialPage = 0;
    if (homeController.currentTab.value == 'Mingguan') initialPage = 1;
    _pageController = PageController(initialPage: initialPage);

    // Periodic check for alarm consistency (every 1 minute)
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

  // --- XP Animation (Gold themed) ---
  void _showXPAnimation(double amount) {
    if (amount == 0) return;

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 60,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 2000),
                curve: Curves.linear,
                builder: (context, value, child) {
                  final scaleCurve = const Interval(
                    0.0,
                    0.4,
                    curve: Curves.elasticOut,
                  ).transform(value);

                  final moveCurve = const Interval(
                    0.0,
                    1.0,
                    curve: Curves.easeOutCubic,
                  ).transform(value);

                  double opacity = 1.0;
                  if (value > 0.8) {
                    opacity = (1.0 - value) * 5;
                  }

                  String textAmount;
                  if (amount == amount.roundToDouble()) {
                    textAmount = amount.toInt().toString();
                  } else {
                    textAmount = amount.toStringAsFixed(1);
                  }

                  return Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -60 * moveCurve),
                      child: Transform.scale(
                        scale: scaleCurve.clamp(0.0, 2.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: amount > 0 ? _gold : const Color(0xFFFF5757),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (amount > 0
                                            ? _gold
                                            : const Color(0xFFFF5757))
                                        .withValues(alpha: 0.4),
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

  // --- Tab Logic ---
  void _onTabChanged(int index) {
    final homeController = Get.find<HomeController>();
    final tabs = ['Harian', 'Mingguan'];
    if (index >= 0 && index < tabs.length) {
      homeController.currentTab.value = tabs[index];
    }
  }

  void _onTabTapped(int index) {
    final homeController = Get.find<HomeController>();
    final tabs = ['Harian', 'Mingguan'];
    if (index >= 0 && index < tabs.length) {
      homeController.currentTab.value = tabs[index];
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final HabitController controller = Get.find();
    final HomeController homeController = Get.find();
    final GamificationController gamificationController = Get.find();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_darkGold, _darkGrey, Colors.black],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // 2. Particles
          const Positioned.fill(child: LegendParticleBackground()),

          // 3. Content
          SafeArea(
            child: Obx(() {
              if (controller.isLoading.value) {
                return Column(
                  children: [
                    _buildAppBar(context),
                    const Expanded(
                      child: Center(child: CustomLoadingIndicator()),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildAppBar(context),
                  _buildSuhuHeader(gamificationController),

                  // Tab Bar
                  Container(
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
                        _buildTodayPage(controller),
                        _buildWeeklyList(controller),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
      bottomNavigationBar: widget.bottomNavigationBar,
    );
  }

  // ==========================================================================
  // APP BAR
  // ==========================================================================
  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Strik',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      colors: [_gold, Color(0xFFFFF8E7)],
                    ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                  shadows: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Lottie.asset(
                'assets/src/strik-logo.json',
                width: 35,
                height: 35,
                repeat: false,
              ),
            ],
          ),
          Row(
            children: [
              _buildIconButton(
                Icons.filter_list,
                () => _showFilterBottomSheet(context),
              ),
              const SizedBox(width: 8),
              _buildIconButton(Icons.add, () => _navigateAndRefresh(context)),
              const SizedBox(width: 8),
              _buildIconButton(
                Icons.manage_accounts,
                () => _showProfileBottomSheet(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: _gold.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: _gold, size: 20),
      ),
    );
  }

  // ==========================================================================
  // SUHU HEADER (Gamification)
  // ==========================================================================
  Widget _buildSuhuHeader(GamificationController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Get.to(() => const LevelProgressionScreen());
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _gold.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: _gold.withValues(alpha: 0.1),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.star_rounded, color: _gold, size: 30),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${controller.currentLevelName.toUpperCase()} (Lvl ${controller.currentLevel})',
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: _gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '${controller.currentXP == controller.currentXP.roundToDouble() ? controller.currentXP.toInt() : controller.currentXP} / ${controller.xpToNextLevel} XP',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: _gold.withValues(alpha: 0.8),
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
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.1,
                            ),
                            color: _gold,
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

  // ==========================================================================
  // TAB CHIP
  // ==========================================================================
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
            color: isActive ? _gold.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isActive
                ? Border.all(color: _gold.withValues(alpha: 0.5))
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              color: isActive ? _gold : Colors.grey[600],
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      }),
    );
  }

  // ==========================================================================
  // TODAY PAGE
  // ==========================================================================
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
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                color: _gold,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                '${controller.todayLogs.values.where((s) => s == 'completed').length} kelar • ${controller.todayLogs.values.where((s) => s == 'skipped').length} skip',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: _gold.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildTodayList(controller)),
      ],
    );
  }

  // ==========================================================================
  // TODAY LIST (with empty states, RefreshIndicator, swipe)
  // ==========================================================================
  Widget _buildTodayList(HabitController controller) {
    // No habits at all
    if (controller.habitsForToday.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => controller.fetchHabitsAndLogs(isRefresh: true),
        color: _gold,
        backgroundColor: Colors.black,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Text(
                  'Belum ada habit nih, gass bikin!',
                  style: TextStyle(color: _gold.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final habits = controller.sortedHabits;

    // All done state
    if (habits.isEmpty &&
        controller.isAllHabitsCompletedForToday &&
        !controller.showCompleted.value) {
      return RefreshIndicator(
        onRefresh: () => controller.fetchHabitsAndLogs(isRefresh: true),
        color: _gold,
        backgroundColor: Colors.black,
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
                    Text(
                      'Mantap! Semua habit hari ini udah kelar',
                      style: TextStyle(
                        color: _gold.withValues(alpha: 0.9),
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
      color: _gold,
      backgroundColor: Colors.black,
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
                    HapticFeedback.heavyImpact();
                    await controller.toggleHabitStatus(
                      habit,
                      status,
                      direction,
                    );
                    return false;
                  },
                  background: _buildSwipeBackground(
                    Alignment.centerLeft,
                    status == 'completed' ? Icons.undo : Icons.check,
                    status == 'completed' ? 'batalin' : 'sikat',
                    _gold,
                    Colors.black,
                  ),
                  secondaryBackground: _buildSwipeBackground(
                    Alignment.centerRight,
                    status == 'skipped' ? Icons.undo : Icons.close,
                    status == 'skipped' ? 'gajadi' : 'skip dlu',
                    const Color(0xFFFF5757),
                    Colors.white,
                  ),
                  child: SuhuHabitCard(
                    habit: habit,
                    status: status,
                    onTap: () => Get.to(() => HabitDetailScreen(habit: habit)),
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  // ==========================================================================
  // SWIPE BACKGROUND (pill design, same as HomeScreen)
  // ==========================================================================
  Widget _buildSwipeBackground(
    Alignment alignment,
    IconData icon,
    String text,
    Color color,
    Color textColor,
  ) {
    return Container(
      alignment: alignment,
      padding: alignment == Alignment.centerLeft
          ? const EdgeInsets.only(right: 20)
          : const EdgeInsets.only(left: 20),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(100),
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

  // ==========================================================================
  // WEEKLY LIST (with empty state, RefreshIndicator)
  // ==========================================================================
  Widget _buildWeeklyList(HabitController controller) {
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    final weekStart = now.subtract(Duration(days: currentWeekday - 1));

    if (controller.habits.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => controller.fetchHabitsAndLogs(isRefresh: true),
        color: _gold,
        backgroundColor: Colors.black,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Text(
                  'Belum ada habit nih!',
                  style: TextStyle(color: _gold.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.fetchHabitsAndLogs(isRefresh: true),
      color: _gold,
      backgroundColor: Colors.black,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: controller.habits.length,
        itemBuilder: (context, index) {
          final habit = controller.habits[index];
          return Obx(() {
            final logs = controller.weeklyLogs[habit.id] ?? {};
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
                color: Colors.black.withValues(alpha: 0.5),
              ),
              child: WeeklyHabitCard(
                habit: habit,
                weeklyLogs: logs,
                weekStart: weekStart,
              ),
            );
          });
        },
      ),
    );
  }

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================
  void _navigateAndRefresh(BuildContext context) async {
    await Get.to(() => const CreateHabitScreen());
    Get.find<HabitController>().fetchHabitsAndLogs(isRefresh: true);
  }

  // ==========================================================================
  // PROFILE BOTTOM SHEET (full: avatar, email, edit profile, alarm, logout)
  // ==========================================================================
  void _showProfileBottomSheet(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final username =
        metadata?['username'] ?? user?.email?.split('@')[0] ?? 'User';
    final email = user?.email ?? '-';
    final avatarUrl = metadata?['avatar_url'] as String?;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: _gold.withValues(alpha: 0.5))),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 10,
            ),
          ],
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
                color: _gold.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Avatar with Gold Border
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(color: _gold, width: 2),
                image: avatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: avatarUrl == null
                  ? Center(
                      child: Text(
                        username.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _gold,
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
                color: _gold,
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
            Divider(color: _gold.withValues(alpha: 0.2)),
            const SizedBox(height: 8),

            // Edit Profile
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: _gold),
              title: const Text(
                'Edit Profil',
                style: TextStyle(
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
                Get.back();
                _showEditProfileBottomSheet(context);
              },
            ),

            // Alarm Schedule
            ListTile(
              leading: const Icon(Icons.alarm, color: _gold),
              title: const Text(
                'Alarm Mendatang',
                style: TextStyle(
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
                Get.back();
                Get.to(() => const AlarmManagementScreen());
              },
            ),

            // Logout
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFEF4444),
              ),
              title: const Text(
                'Logout',
                style: TextStyle(
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

  // ==========================================================================
  // EDIT PROFILE BOTTOM SHEET (full: avatar picker, username edit)
  // ==========================================================================
  void _showEditProfileBottomSheet(BuildContext context) {
    final updateController = Get.put(UpdateProfileController());
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final currentAvatarUrl = metadata?['avatar_url'] as String?;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: _gold.withValues(alpha: 0.5))),
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
                  color: _gold.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Edit Profil',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _gold,
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
                      color: _gold.withValues(alpha: 0.2),
                      border: Border.all(color: _gold, width: 2),
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
                            color: _gold,
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
                                    color: _gold,
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
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: _gold.withValues(alpha: 0.5),
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
            const SizedBox(height: 16),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  // ==========================================================================
  // FILTER BOTTOM SHEET
  // ==========================================================================
  void _showFilterBottomSheet(BuildContext context) {
    final controller = Get.find<HabitController>();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: _gold.withValues(alpha: 0.5))),
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
                  color: _gold.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Filter Habit',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _gold,
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
                activeThumbColor: _gold,
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
                activeThumbColor: _gold,
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

// =============================================================================
// SUHU HABIT CARD (Premium Gold themed)
// =============================================================================
class SuhuHabitCard extends StatelessWidget {
  final Habit habit;
  final String? status;
  final VoidCallback onTap;

  const SuhuHabitCard({
    super.key,
    required this.habit,
    this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == 'completed';
    final isSkipped = status == 'skipped';

    Color glowColor = Colors.white.withValues(alpha: 0.1);
    if (isCompleted) glowColor = _gold;
    if (isSkipped) glowColor = Colors.redAccent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted ? _gold : Colors.white12,
            width: isCompleted ? 2 : 1,
          ),
          boxShadow: isCompleted
              ? [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Custom Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? _gold : Colors.transparent,
                border: Border.all(color: isCompleted ? _gold : Colors.white54),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.black)
                  : isSkipped
                  ? const Icon(Icons.close, size: 16, color: Colors.redAccent)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                habit.title,
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: isCompleted ? Colors.grey : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  decorationColor: _gold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
