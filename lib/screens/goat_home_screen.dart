import 'dart:async';
import 'dart:math';
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
import 'package:strik_app/data/models/habit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =============================================================================
// GOAT THEME CONSTANTS - Emerald Green + Platinum
// =============================================================================
const Color _goatEmerald = Color(0xFF00E676);
const Color _goatDarkGreen = Color(0xFF002E0F);
const Color _goatSurface = Color(0xFF0A1A0F);
const Color _goatPlatinum = Color(0xFFE0E0E0);
const Color _goatGlow = Color(0xFF00C853);

class GoatHomeScreen extends StatefulWidget {
  final Widget bottomNavigationBar;

  const GoatHomeScreen({super.key, required this.bottomNavigationBar});

  @override
  State<GoatHomeScreen> createState() => _GoatHomeScreenState();
}

class _GoatHomeScreenState extends State<GoatHomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  Timer? _alarmCheckTimer;
  late AnimationController _ringAnimController;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Circular progress ring animation
    _ringAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ringAnimation = CurvedAnimation(
      parent: _ringAnimController,
      curve: Curves.easeOutCubic,
    );
    _ringAnimController.forward();

    // Periodic alarm consistency check
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
    _ringAnimController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Get.find<HabitController>().checkDailyRefresh();
    }
  }

  // ===========================================================================
  // XP ANIMATION (Emerald themed)
  // ===========================================================================
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
                  if (value > 0.8) opacity = (1.0 - value) * 5;

                  String textAmount;
                  if (amount == amount.roundToDouble()) {
                    textAmount = amount.toInt().toString();
                  } else {
                    textAmount = amount.toStringAsFixed(1);
                  }

                  final isPositive = amount > 0;

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
                            color: isPositive
                                ? _goatEmerald
                                : const Color(0xFFFF5757),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isPositive
                                            ? _goatEmerald
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
                                isPositive
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                color: Colors.black,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${isPositive ? '+' : ''}$textAmount XP',
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
                onEnd: () => entry?.remove(),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(entry);
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final HabitController controller = Get.find();
    final GamificationController gamification = Get.find();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_goatDarkGreen, Color(0xFF050F08), Colors.black],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // 2. Emerald particles
          const Positioned.fill(
            child: LegendParticleBackground(particleColor: _goatEmerald),
          ),

          // 3. Content
          SafeArea(
            child: Obx(() {
              if (controller.isLoading.value) {
                return Column(
                  children: [
                    _buildGreetingHeader(context, gamification),
                    const Expanded(
                      child: Center(child: CustomLoadingIndicator()),
                    ),
                  ],
                );
              }

              // Single scroll page - NO tabs
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Greeting Header
                  SliverToBoxAdapter(
                    child: _buildGreetingHeader(context, gamification),
                  ),

                  // Circular Progress Ring
                  SliverToBoxAdapter(
                    child: _buildCircularProgress(controller, gamification),
                  ),

                  // Habit Section Title
                  SliverToBoxAdapter(
                    child: _buildSectionTitle(
                      controller.habitsForToday.isEmpty
                          ? 'Mulai Hari Ini'
                          : 'Habits',
                    ),
                  ),

                  // Habit Grid or Empty State
                  controller.habitsForToday.isEmpty
                      ? SliverToBoxAdapter(child: _buildEmptyState())
                      : _buildHabitGrid(controller),

                  // All Done State (if habits exist but all completed)
                  if (controller.habitsForToday.isNotEmpty &&
                      controller.sortedHabits.isEmpty &&
                      controller.isAllHabitsCompletedForToday &&
                      !controller.showCompleted.value)
                    SliverToBoxAdapter(child: _buildAllDoneState()),

                  // Weekly Heatmap Section
                  if (controller.habits.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _buildSectionTitle('Minggu Ini')),
                    SliverToBoxAdapter(child: _buildWeeklyHeatmap(controller)),
                  ],

                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            }),
          ),
        ],
      ),
      bottomNavigationBar: widget.bottomNavigationBar,
    );
  }

  // ===========================================================================
  // GREETING HEADER (Minimal: Avatar + Name + Actions)
  // ===========================================================================
  Widget _buildGreetingHeader(
    BuildContext context,
    GamificationController gamification,
  ) {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final username =
        metadata?['username'] ?? user?.email?.split('@')[0] ?? 'User';
    final avatarUrl = metadata?['avatar_url'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          // Avatar (tap for profile)
          GestureDetector(
            onTap: () => _showProfileBottomSheet(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _goatEmerald, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _goatEmerald.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
                image: avatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: _goatSurface,
              ),
              child: avatarUrl == null
                  ? Center(
                      child: Text(
                        username.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _goatEmerald,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          // Greeting + GOAT badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $username',
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Get.to(() => const LevelProgressionScreen());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_goatEmerald, _goatGlow],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'G.O.A.T  Lvl ${gamification.currentLevel}',
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          _buildHeaderIcon(
            Icons.filter_list,
            () => _showFilterBottomSheet(context),
          ),
          const SizedBox(width: 8),
          _buildHeaderIcon(Icons.add, () => _navigateAndRefresh(context)),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _goatEmerald.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: _goatEmerald.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, color: _goatEmerald, size: 20),
      ),
    );
  }

  // ===========================================================================
  // CIRCULAR PROGRESS RING
  // ===========================================================================
  Widget _buildCircularProgress(
    HabitController controller,
    GamificationController gamification,
  ) {
    final completedCount = controller.todayLogs.values
        .where((s) => s == 'completed')
        .length;
    final totalCount = controller.habitsForToday.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: AnimatedBuilder(
          animation: _ringAnimation,
          builder: (context, child) {
            return SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ring
                  CustomPaint(
                    size: const Size(180, 180),
                    painter: _GoatRingPainter(
                      progress: progress * _ringAnimation.value,
                      bgColor: _goatEmerald.withValues(alpha: 0.1),
                      fgColor: _goatEmerald,
                      glowColor: _goatGlow,
                      strokeWidth: 10,
                    ),
                  ),

                  // Center content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: _goatEmerald,
                          shadows: [
                            Shadow(
                              color: _goatEmerald.withValues(alpha: 0.5),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$completedCount / $totalCount',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          color: _goatPlatinum.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'kelar hari ini',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          color: _goatPlatinum.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION TITLE
  // ===========================================================================
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _goatPlatinum.withValues(alpha: 0.8),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================
  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: () =>
          Get.find<HabitController>().fetchHabitsAndLogs(isRefresh: true),
      color: _goatEmerald,
      backgroundColor: Colors.black,
      child: SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 48,
                color: _goatEmerald.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'Belum ada habit nih, gass bikin!',
                style: TextStyle(
                  color: _goatEmerald.withValues(alpha: 0.5),
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ALL DONE STATE
  // ===========================================================================
  Widget _buildAllDoneState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Lottie.asset(
              'assets/src/complete-habit.json',
              width: 200,
              height: 200,
              repeat: false,
            ),
            const SizedBox(height: 12),
            Text(
              'Mantap! Semua habit hari ini udah kelar',
              style: TextStyle(
                color: _goatEmerald.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HABIT GRID (2 columns, tap to complete, long press for options)
  // ===========================================================================
  SliverPadding _buildHabitGrid(HabitController controller) {
    final habits = controller.sortedHabits;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final habit = habits[index];
          return Obx(() {
            final status = controller.todayLogs[habit.id];
            return _GoatHabitTile(
              habit: habit,
              status: status,
              onTap: () async {
                HapticFeedback.mediumImpact();
                await controller.toggleHabitStatus(
                  habit,
                  status,
                  DismissDirection.startToEnd, // complete / undo
                );
                // Re-animate ring
                _ringAnimController.reset();
                _ringAnimController.forward();
              },
              onLongPress: () =>
                  _showHabitOptionsSheet(context, habit, status, controller),
            );
          });
        }, childCount: habits.length),
      ),
    );
  }

  // ===========================================================================
  // HABIT OPTIONS BOTTOM SHEET (long press)
  // ===========================================================================
  void _showHabitOptionsSheet(
    BuildContext context,
    Habit habit,
    String? status,
    HabitController controller,
  ) {
    HapticFeedback.heavyImpact();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _goatSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: _goatEmerald.withValues(alpha: 0.4)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _goatEmerald.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              habit.title,
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Complete / Undo Complete
            _buildOptionTile(
              icon: status == 'completed' ? Icons.undo : Icons.check_circle,
              label: status == 'completed' ? 'Batalin' : 'Sikat!',
              color: _goatEmerald,
              onTap: () {
                Get.back();
                controller.toggleHabitStatus(
                  habit,
                  status,
                  DismissDirection.startToEnd,
                );
                _ringAnimController.reset();
                _ringAnimController.forward();
              },
            ),

            // Skip / Undo Skip
            _buildOptionTile(
              icon: status == 'skipped' ? Icons.undo : Icons.skip_next,
              label: status == 'skipped' ? 'Gajadi skip' : 'Skip dlu',
              color: const Color(0xFFFF5757),
              onTap: () {
                Get.back();
                controller.toggleHabitStatus(
                  habit,
                  status,
                  DismissDirection.endToStart,
                );
                _ringAnimController.reset();
                _ringAnimController.forward();
              },
            ),

            // View Detail
            _buildOptionTile(
              icon: Icons.info_outline,
              label: 'Lihat Detail',
              color: _goatPlatinum,
              onTap: () {
                Get.back();
                Get.to(() => HabitDetailScreen(habit: habit));
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

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Space Grotesk',
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // ===========================================================================
  // WEEKLY HEATMAP (inline, per-habit)
  // ===========================================================================
  Widget _buildWeeklyHeatmap(HabitController controller) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final dayLabels = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: controller.habits.map((habit) {
          return Obx(() {
            final logs = controller.weeklyLogs[habit.id] ?? {};
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _goatEmerald.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: _goatPlatinum.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final day = weekStart.add(Duration(days: i));
                      final dayStr = day.toIso8601String().split('T')[0];
                      final status = logs[dayStr];
                      final isToday =
                          day.day == now.day &&
                          day.month == now.month &&
                          day.year == now.year;
                      final isFuture = day.isAfter(now);

                      Color dotColor;
                      IconData? dotIcon;
                      if (status == 'completed') {
                        dotColor = _goatEmerald;
                        dotIcon = Icons.check;
                      } else if (status == 'skipped') {
                        dotColor = const Color(0xFFFF5757);
                        dotIcon = Icons.close;
                      } else if (status == 'missed') {
                        dotColor = Colors.orange;
                        dotIcon = Icons.remove;
                      } else if (isFuture) {
                        dotColor = Colors.white.withValues(alpha: 0.08);
                      } else {
                        dotColor = Colors.white.withValues(alpha: 0.15);
                      }

                      return Column(
                        children: [
                          Text(
                            dayLabels[i],
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 10,
                              color: isToday
                                  ? _goatEmerald
                                  : _goatPlatinum.withValues(alpha: 0.4),
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: dotColor.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: isToday
                                  ? Border.all(color: _goatEmerald, width: 1.5)
                                  : null,
                              boxShadow: status == 'completed'
                                  ? [
                                      BoxShadow(
                                        color: _goatEmerald.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: dotIcon != null
                                ? Icon(dotIcon, size: 14, color: dotColor)
                                : null,
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            );
          });
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================
  void _navigateAndRefresh(BuildContext context) async {
    await Get.to(() => const CreateHabitScreen());
    Get.find<HabitController>().fetchHabitsAndLogs(isRefresh: true);
  }

  // ===========================================================================
  // PROFILE BOTTOM SHEET
  // ===========================================================================
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
          color: _goatSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: _goatEmerald.withValues(alpha: 0.4)),
          ),
          boxShadow: [
            BoxShadow(
              color: _goatEmerald.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _goatEmerald.withValues(alpha: 0.3),
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
                color: _goatSurface,
                border: Border.all(color: _goatEmerald, width: 2),
                image: avatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: _goatEmerald.withValues(alpha: 0.4),
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
                          color: _goatEmerald,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),

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
            Divider(color: _goatEmerald.withValues(alpha: 0.15)),
            const SizedBox(height: 8),

            ListTile(
              leading: const Icon(Icons.edit_rounded, color: _goatEmerald),
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
            ListTile(
              leading: const Icon(Icons.alarm, color: _goatEmerald),
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

  // ===========================================================================
  // EDIT PROFILE BOTTOM SHEET
  // ===========================================================================
  void _showEditProfileBottomSheet(BuildContext context) {
    final updateController = Get.put(UpdateProfileController());
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final currentAvatarUrl = metadata?['avatar_url'] as String?;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _goatSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: _goatEmerald.withValues(alpha: 0.4)),
          ),
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
                  color: _goatEmerald.withValues(alpha: 0.3),
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
                color: _goatEmerald,
              ),
            ),
            const SizedBox(height: 24),

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
                      color: _goatEmerald.withValues(alpha: 0.15),
                      border: Border.all(color: _goatEmerald, width: 2),
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
                            color: _goatEmerald,
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
                                    color: _goatEmerald,
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
                  color: _goatEmerald.withValues(alpha: 0.5),
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

  // ===========================================================================
  // FILTER BOTTOM SHEET
  // ===========================================================================
  void _showFilterBottomSheet(BuildContext context) {
    final controller = Get.find<HabitController>();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _goatSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: _goatEmerald.withValues(alpha: 0.4)),
          ),
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
                  color: _goatEmerald.withValues(alpha: 0.3),
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
                color: _goatEmerald,
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
                activeThumbColor: _goatEmerald,
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
                activeThumbColor: _goatEmerald,
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
// GOAT HABIT TILE (Grid card with tap-to-complete)
// =============================================================================
class _GoatHabitTile extends StatelessWidget {
  final Habit habit;
  final String? status;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GoatHabitTile({
    required this.habit,
    this.status,
    required this.onTap,
    required this.onLongPress,
  });

  Color _parseHabitColor() {
    try {
      final colorStr = habit.color.replaceAll('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (_) {
      return _goatEmerald;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == 'completed';
    final isSkipped = status == 'skipped';
    final habitColor = _parseHabitColor();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isCompleted
                ? [
                    _goatEmerald.withValues(alpha: 0.15),
                    _goatDarkGreen.withValues(alpha: 0.8),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.white.withValues(alpha: 0.02),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted
                ? _goatEmerald.withValues(alpha: 0.6)
                : isSkipped
                ? const Color(0xFFFF5757).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
            width: isCompleted ? 1.5 : 1,
          ),
          boxShadow: isCompleted
              ? [
                  BoxShadow(
                    color: _goatEmerald.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Color accent dot + status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: habitColor,
                      boxShadow: [
                        BoxShadow(
                          color: habitColor.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  // Status indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? _goatEmerald
                          : isSkipped
                          ? const Color(0xFFFF5757).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: isCompleted
                            ? _goatEmerald
                            : isSkipped
                            ? const Color(0xFFFF5757)
                            : Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.black,
                          )
                        : isSkipped
                        ? const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFFFF5757),
                          )
                        : null,
                  ),
                ],
              ),

              // Title
              Text(
                habit.title,
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: isCompleted
                      ? _goatPlatinum.withValues(alpha: 0.5)
                      : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  decorationColor: _goatEmerald.withValues(alpha: 0.5),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Tap hint
              Text(
                isCompleted
                    ? 'tap untuk batalin'
                    : isSkipped
                    ? 'tahan untuk opsi'
                    : 'tap untuk sikat',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 10,
                  color: isCompleted
                      ? _goatEmerald.withValues(alpha: 0.5)
                      : _goatPlatinum.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CIRCULAR PROGRESS RING PAINTER
// =============================================================================
class _GoatRingPainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final Color fgColor;
  final Color glowColor;
  final double strokeWidth;

  _GoatRingPainter({
    required this.progress,
    required this.bgColor,
    required this.fgColor,
    required this.glowColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Foreground arc
    if (progress > 0) {
      final sweepAngle = 2 * pi * progress;

      // Glow
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        glowPaint,
      );

      // Main arc
      final fgPaint = Paint()
        ..color = fgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoatRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
