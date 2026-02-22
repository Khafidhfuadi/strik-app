import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/controllers/gamification_controller.dart';
import 'package:strik_app/widgets/rank_history_detail_sheet.dart';
import 'package:intl/intl.dart';

class LevelProgressionScreen extends StatefulWidget {
  const LevelProgressionScreen({super.key});

  @override
  State<LevelProgressionScreen> createState() => _LevelProgressionScreenState();
}

class _LevelProgressionScreenState extends State<LevelProgressionScreen> {
  final GamificationController controller = Get.find();
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    controller.fetchXPHistory();
    // Start page at current level (0-indexed)
    // Level 1 -> Index 0
    int initialPage = (controller.currentLevel.value - 1).clamp(0, 9);
    _pageController = PageController(
      viewportFraction: 0.9,
      initialPage: initialPage,
    );
    _currentPage = initialPage;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // App Theme
      appBar: AppBar(
        title: const Text(
          'Level Rewards',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Swipeable Level Cards
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: 10, // Levels 1-10
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final level = index + 1;
                final levelData = controller.levels.firstWhere(
                  (l) => l['level'] == level,
                  orElse: () => {'name': 'Unknown', 'xp_required': 0},
                );
                final benefits = controller.getBenefitsForLevel(level);
                final isCurrentLevel = level == controller.currentLevel.value;
                final isLocked = level > controller.currentLevel.value;

                return _buildLevelCard(
                  level,
                  levelData,
                  benefits,
                  isCurrentLevel,
                  isLocked,
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // 2. Page Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(10, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? const Color(0xFFFFD700)
                      : Colors.white12,
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // 3. User Progress & History Button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total XP',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Obx(
                      () => Text(
                        '${controller.currentXP.value} XP',
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFD700),
                        ),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _showHistoryBottomSheet(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.history, color: Colors.white70, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'History',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // XP HISTORY BOTTOM SHEET
  // ===========================================================================
  void _showHistoryBottomSheet() {
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle + Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.history, color: Color(0xFFFFD700), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'XP History',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10, height: 1),
                ],
              ),
            ),

            // History list
            Expanded(
              child: Obx(() {
                if (controller.xpHistory.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada riwayat XP',
                      style: TextStyle(color: Colors.white38),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: controller.xpHistory.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final log = controller.xpHistory[index];
                    final amount = (log['amount'] as num).toDouble();
                    final isPositive = amount > 0;
                    final date = DateTime.parse(log['created_at']);

                    String formatXP(double val) {
                      if (val == val.roundToDouble()) {
                        return val.toInt().toString();
                      }
                      return val.toStringAsFixed(1);
                    }

                    final reason = log['reason'] ?? 'XP Adjustment';
                    final habitTitle = log['habit_title'] as String?;

                    // Use habit title as primary display if reason is habit-related
                    String displayTitle = reason;
                    if (habitTitle != null) {
                      if (reason == 'Completed Habit') {
                        displayTitle = 'Completed: $habitTitle';
                      }
                      if (reason == 'Skipped Habit') {
                        displayTitle = 'Skipped: $habitTitle';
                      }
                      if (reason == 'New Habit') {
                        displayTitle = 'New Habit: $habitTitle';
                      }
                    }

                    return ListTile(
                      onTap: () {
                        Get.bottomSheet(
                          RankHistoryDetailSheet(log: log),
                          isScrollControlled: true,
                        );
                      },
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? const Color(0xFF1B3A2B)
                              : const Color(0xFF3A1B1B),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPositive
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: isPositive
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        displayTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('dd MMM, HH:mm').format(date.toLocal()),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Text(
                        '${isPositive ? '+' : ''}${formatXP(amount)} XP',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPositive
                              ? const Color(0xFFFFD700)
                              : Colors.redAccent,
                        ),
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

  Widget _buildLevelCard(
    int level,
    Map<String, dynamic> levelData,
    LevelBenefits benefits,
    bool isCurrent,
    bool isLocked,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: isCurrent
            ? Border.all(color: const Color(0xFFFFD700), width: 2)
            : Border.all(color: Colors.white10),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          // Header: Shield Icon and Level Name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LEVEL $level',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isCurrent
                          ? const Color(0xFFFFD700)
                          : Colors.white54,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    levelData['name'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.flag_rounded,
                        size: 14,
                        color: isCurrent
                            ? const Color(0xFFFFD700).withValues(alpha: 0.6)
                            : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Target: ${controller.getXPThreshold(level)} XP',
                        style: TextStyle(
                          fontSize: 12,
                          color: isCurrent
                              ? const Color(0xFFFFD700).withValues(alpha: 0.6)
                              : Colors.white38,
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onLongPress: () {
                  if (isCurrent) {
                    controller.resetGamificationIntro();
                  }
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.shield,
                      size: 60,
                      color: isCurrent
                          ? const Color(0xFFFFD700)
                          : Colors.grey[800],
                    ),
                    Text(
                      '$level',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? Colors.black : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isCurrent) ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(controller.xpProgress * 100).toInt()}%',
                      style: TextStyle(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: controller.xpProgress,
                    backgroundColor: Colors.white10,
                    color: const Color(0xFFFFD700),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ],
          const Divider(color: Colors.white10, height: 32),

          // Benefits List
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              // physics: const NeverScrollableScrollPhysics(), // Allow scrolling
              children: [
                _buildBenefitItem(
                  Icons.check_circle,
                  'Complete Habit',
                  '+${_formatBenefit(benefits.completeHabit)} XP',
                ),
                _buildBenefitItem(
                  Icons.cancel,
                  'Skip Habit',
                  '${_formatBenefit(benefits.skipHabit)} XP',
                ),
                _buildBenefitItem(
                  Icons.camera_alt,
                  'New Momentz',
                  '+${_formatBenefit(benefits.newMomentz)} XP',
                ),
                _buildBenefitItem(
                  Icons.favorite,
                  'Reaction',
                  '+${_formatBenefit(benefits.react)} XP',
                ),
                _buildBenefitItem(
                  Icons.add_circle,
                  'New Habit',
                  '+${_formatBenefit(benefits.newHabit)} XP',
                ),
                if (level >= 8)
                  _buildBenefitItem(
                    Icons.stars,
                    'Exclusive UI',
                    'Unlocked',
                    isSpecial: true,
                  ),
                const Divider(color: Colors.white10, height: 16),
                _buildBenefitItem(
                  Icons.book_rounded,
                  'Journaling',
                  '+${_formatBenefit(benefits.journaling)} XP',
                ),
                _buildBenefitItem(
                  Icons.people_alt_rounded,
                  'Mutual Friend',
                  '+5 XP',
                ),
                _buildBenefitItem(
                  Icons.emoji_events_rounded,
                  'Rank Mingguan #1',
                  '+15 XP',
                  isSpecial: true,
                ),
                _buildBenefitItem(
                  Icons.emoji_events_rounded,
                  'Rank Mingguan #2',
                  '+10 XP',
                ),
                _buildBenefitItem(
                  Icons.emoji_events_rounded,
                  'Rank Mingguan #3',
                  '+5 XP',
                ),
              ],
            ),
          ),

          if (isCurrent)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Current Level',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(
    IconData icon,
    String label,
    String value, {
    bool isSpecial = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSpecial
                  ? Colors.purple.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: isSpecial ? Colors.purpleAccent : Colors.white70,
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: value.startsWith('-')
                  ? Colors.redAccent
                  : (isSpecial ? Colors.purpleAccent : const Color(0xFFFFD700)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBenefit(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }
}
