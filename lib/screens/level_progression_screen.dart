import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/controllers/gamification_controller.dart';
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
          SizedBox(
            height: 420, // Adjust height for content
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

          const SizedBox(height: 16),

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

          // 3. User Progress & History Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'History',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. XP History List
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Obx(() {
                if (controller.xpHistory.isEmpty) {
                  return const Center(
                    child: Text(
                      'No history yet',
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
                    final amount = log['amount'] as int;
                    final isPositive = amount > 0;
                    final date = DateTime.parse(log['created_at']);

                    return ListTile(
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
                        log['reason'] ?? 'XP Adjustment',
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
                        '${isPositive ? '+' : ''}$amount XP',
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
          ),
        ],
      ),
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
                ],
              ),
              Stack(
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
            ],
          ),
          const Divider(color: Colors.white10, height: 32),

          // Benefits List
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(), // Content fits
              children: [
                _buildBenefitItem(
                  Icons.check_circle,
                  'Complete Habit',
                  '+${benefits.completeHabit.round()} XP',
                ),
                _buildBenefitItem(
                  Icons.cancel,
                  'Skip Habit',
                  '${benefits.skipHabit.round()} XP',
                ),
                _buildBenefitItem(
                  Icons.camera_alt,
                  'New Momentz',
                  '+${benefits.newMomentz} XP',
                ), // Show double for precision?
                _buildBenefitItem(
                  Icons.favorite,
                  'Reaction',
                  '+${benefits.react} XP',
                ),
                _buildBenefitItem(
                  Icons.add_circle,
                  'New Habit',
                  '+${benefits.newHabit.round()} XP',
                ),
                if (level >= 8)
                  _buildBenefitItem(
                    Icons.stars,
                    'Exclusive UI',
                    'Unlocked',
                    isSpecial: true,
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
}
