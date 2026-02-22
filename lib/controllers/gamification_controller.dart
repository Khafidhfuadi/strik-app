import 'dart:async';
import 'package:get/get.dart';
import 'package:strik_app/data/repositories/gamification_repository.dart';
import 'package:strik_app/main.dart'; // To access global supabase client
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LevelBenefits {
  final int level;
  final double completeHabit;
  final double skipHabit;
  final double newMomentz;
  final double react;
  final double newHabit;
  final double journaling;

  const LevelBenefits({
    required this.level,
    required this.completeHabit,
    required this.skipHabit,
    required this.newMomentz,
    required this.react,
    required this.newHabit,
    required this.journaling,
  });
}

class GamificationController extends GetxController {
  final GamificationRepository _repository = GamificationRepository(supabase);

  // Level Benefits Configuration
  LevelBenefits getBenefitsForLevel(int level) {
    if (level <= 3) {
      return const LevelBenefits(
        level: 1, // Represents 1-3
        completeHabit: 5,
        skipHabit: -3,
        newMomentz: 1,
        react: 1,
        newHabit: 10,
        journaling: 3,
      );
    }
    switch (level) {
      case 4:
        return const LevelBenefits(
          level: 4,
          completeHabit: 5.5,
          skipHabit: -3,
          newMomentz: 1.5,
          react: 1,
          newHabit: 15,
          journaling: 3.5,
        );
      case 5:
        return const LevelBenefits(
          level: 5,
          completeHabit: 6.5,
          skipHabit: -3,
          newMomentz: 2,
          react: 1,
          newHabit: 20,
          journaling: 4,
        );
      case 6:
        return const LevelBenefits(
          level: 6,
          completeHabit: 7.5,
          skipHabit: -3,
          newMomentz: 2.5,
          react: 1,
          newHabit: 25,
          journaling: 4.5,
        );
      case 7:
        return const LevelBenefits(
          level: 7,
          completeHabit: 8.5,
          skipHabit: -3,
          newMomentz: 3,
          react: 1,
          newHabit: 30,
          journaling: 5,
        );
      case 8:
        return const LevelBenefits(
          level: 8,
          completeHabit: 9.5,
          skipHabit: -3,
          newMomentz: 3.5,
          react: 1,
          newHabit: 35,
          journaling: 5.5,
        );
      case 9:
        return const LevelBenefits(
          level: 9,
          completeHabit: 10.5,
          skipHabit: -3,
          newMomentz: 4,
          react: 1,
          newHabit: 40,
          journaling: 6,
        );
      case 10:
      default:
        return const LevelBenefits(
          level: 10,
          completeHabit: 11.5,
          skipHabit: -3,
          newMomentz: 4.5,
          react: 1,
          newHabit: 45,
          journaling: 6.5,
        );
    }
  }

  double getXPReward(String actionType) {
    final benefits = getBenefitsForLevel(currentLevel.value);
    switch (actionType) {
      case 'complete_habit':
        return benefits.completeHabit;
      case 'skip_habit':
        return benefits.skipHabit;
      case 'new_habit':
        return benefits.newHabit;
      case 'new_momentz':
        return benefits.newMomentz;
      case 'react_momentz':
        return benefits.react;
      case 'journaling':
        return benefits.journaling;
      default:
        return 0;
    }
  }

  Future<void> awardXPForInteraction(String type, {String? referenceId}) async {
    final amount = getXPReward(type);
    if (amount != 0) {
      String reason = 'Activity';
      if (type == 'new_momentz') reason = 'New Momentz';
      if (type == 'react_momentz') reason = 'Reaction';
      if (type == 'new_habit') reason = 'New Habit';
      if (type == 'complete_habit') reason = 'Completed Habit';
      if (type == 'skip_habit') reason = 'Skipped Habit';
      if (type == 'journaling') reason = 'Journal Entry';

      if (referenceId != null) {
        await awardXPIfNotAwarded(
          amount,
          reason: reason,
          referenceId: referenceId,
        );
      } else {
        await awardXP(amount, reason: reason);
      }
    }
  }

  /// Award XP using atomic RPC which inherently handles the idempotency safely.
  Future<void> awardXPIfNotAwarded(
    double amount, {
    required String reason,
    required String referenceId,
  }) async {
    try {
      await awardXP(amount, reason: reason, referenceId: referenceId);
    } catch (e) {
      print('Error checking/awarding XP for reference $referenceId: $e');
    }
  }

  var currentXP = 0.0.obs;
  var currentLevel = 1.obs;
  var isLoading = false.obs;

  bool _isShowingIntro = false;

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void onInit() {
    super.onInit();
    fetchGamificationData();

    // Listen to auth state changes to Handle Logout/Login
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        fetchGamificationData();
        // checkAndShowGamificationIntro is called from home screens,
        // so no need to call it here (would cause double bottom sheet).
      } else if (event == AuthChangeEvent.signedOut) {
        // Reset state on logout
        currentXP.value = 0.0;
        currentLevel.value = 1;
        isLoading.value = false;
      }
    });
  }

  Future<void> fetchGamificationData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      currentXP.value = 0.0;
      currentLevel.value = 1;
      return;
    }

    isLoading.value = true;
    try {
      final userData = await _repository.getCurrentUserGamificationData();
      if (userData != null) {
        currentXP.value = userData.xp;

        // Auto-correct level if XP warrants a higher level
        int expectedLevel = 1;
        // Logic similar to awardXP loop
        while (true) {
          if (expectedLevel >= 10) break;
          final threshold = getXPThreshold(expectedLevel);
          if (userData.xp >= threshold) {
            expectedLevel++;
          } else {
            break;
          }
        }

        if (expectedLevel > userData.level) {
          print(
            'DEBUG: Level mismatch detected. XP: ${userData.xp}, Level: ${userData.level}, Expected: $expectedLevel. Correcting...',
          );
          currentLevel.value = expectedLevel;
          // Sync correction to DB
          await _repository.updateXPAndLevel(userData.xp, expectedLevel);
        } else {
          currentLevel.value = userData.level;
        }
      }
    } catch (e) {
      print('Error fetching gamification data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> checkAndShowGamificationIntro() async {
    // Guard: prevent showing the bottom sheet multiple times concurrently
    if (_isShowingIntro) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
      print('DEBUG: No user found for gamification intro check');
      return;
    }

    final metadata = user.userMetadata;
    final hasSeenIntro = metadata?['has_seen_gamification_intro'] == true;
    print('DEBUG: hasSeenIntro: $hasSeenIntro');

    if (hasSeenIntro) return;

    _isShowingIntro = true;

    // Fetch retroactive stats
    int totalCompleted = 0;
    try {
      totalCompleted = await _repository.getTotalCompletedHabitsCount();
    } catch (e) {
      print('Error fetching total completed habits: $e');
    }

    final benefits = getBenefitsForLevel(1);
    final retroactiveXP = (totalCompleted * benefits.completeHabit).toInt();

    // Calculate potential new level
    int calcLevel = 1;
    double calcXP = retroactiveXP.toDouble();
    // Basic calculation loop matching awardXP logic
    while (true) {
      if (calcLevel >= 10) break;
      final threshold = getXPThreshold(calcLevel);
      if (calcXP >= threshold) {
        // Cumulative: Do NOT subtract threshold
        calcLevel++;
      } else {
        break;
      }
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFFFFD700), width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.bolt_rounded, color: Color(0xFFFFD700), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Introducing XP & Levels!',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Habit yang kamu selesaikan sekarang dapet XP! Karena kamu anak rajin, kita hitungin habit yang udah kelar sebelumnya.',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 16,
                color: Colors.grey[400],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$totalCompleted',
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Habits',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 40, color: Colors.white10),
                  Column(
                    children: [
                      Text(
                        '+$retroactiveXP',
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFD700),
                        ),
                      ),
                      const Text(
                        'XP Earned',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _buildRuleItem(
                    Icons.check_circle_outline,
                    'Selesain Habit',
                    '+${benefits.completeHabit.toInt()} XP',
                    Colors.greenAccent,
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _buildRuleItem(
                    Icons.add_circle_outline,
                    'Bikin Habit Baru',
                    '+${benefits.newHabit.toInt()} XP',
                    Colors.blueAccent,
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _buildRuleItem(
                    Icons.remove_circle_outline,
                    'Skip / Lupa',
                    '${benefits.skipHabit.toInt()} XP',
                    Colors.redAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (retroactiveXP > 0)
              Text(
                'Kamu langsung lompat ke Level $calcLevel! 🚀',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // Apply changes
                  if (retroactiveXP > 0) {
                    currentXP.value = calcXP;
                    currentLevel.value = calcLevel;
                    await _repository.updateXPAndLevel(calcXP, calcLevel);
                  }

                  // Update metadata in Supabase
                  await supabase.auth.updateUser(
                    UserAttributes(data: {'has_seen_gamification_intro': true}),
                  );

                  Get.back();
                  _isShowingIntro = false;
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Klaim XP Gw!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      isDismissible: false,
    );
  }

  int get xpToNextLevel => getXPThreshold(currentLevel.value);

  int getXPThreshold(int level) {
    switch (level) {
      case 1:
        return 100;
      case 2:
        return 300;
      case 3:
        return 800;
      case 4:
        return 1400;
      case 5:
        return 2100;
      case 6:
        return 2900;
      case 7:
        return 3800;
      case 8:
        return 4800;
      case 9:
        return 5900;
      case 10:
      default:
        return 7100;
    }
  }

  double get xpProgress {
    if (xpToNextLevel == 0) return 0.0;

    // Calculate progress within the current level's range
    double startXP = (currentLevel.value == 1)
        ? 0.0
        : getXPThreshold(currentLevel.value - 1).toDouble();
    double endXP = getXPThreshold(currentLevel.value).toDouble();

    // Ensure we don't divide by zero if start == end (shouldn't happen with valid thresholds)
    if (endXP <= startXP) return 1.0;

    double progress = (currentXP.value - startXP) / (endXP - startXP);
    return progress.clamp(0.0, 1.0);
  }

  // Event stream for UI animations
  final _xpEventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get xpEventStream => _xpEventController.stream;

  var xpHistory = <Map<String, dynamic>>[].obs;

  Future<void> awardXP(
    double amount, {
    String reason = 'Activity',
    String? referenceId,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _repository.incrementUserXP(
        userId: user.id,
        amount: amount,
        reason: reason,
        referenceId:
            referenceId ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (response['success'] == true) {
        final newXP = (response['xp'] as num).toDouble();
        final newLevel = response['level'] as int;
        final leveledUp = response['leveled_up'] as bool;

        currentXP.value = newXP;
        currentLevel.value = newLevel;

        _xpEventController.add({
          'amount': amount,
          'newLevel': newLevel,
          'leveledUp': leveledUp,
        });

        fetchXPHistory();

        if (leveledUp) {
          _showLevelUpDialog(newLevel);
        }
      } else if (response['success'] == false) {
        if (response['xp'] != null) {
          currentXP.value = (response['xp'] as num).toDouble();
        }
        if (response['level'] != null) {
          currentLevel.value = response['level'] as int;
        }
      }
    } catch (e) {
      print('Error updating XP: $e');
    }
  }

  // DEBUG: Reset intro status for testing
  Future<void> resetGamificationIntro() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.auth.updateUser(
      UserAttributes(data: {'has_seen_gamification_intro': false}),
    );

    Get.snackbar(
      'Debug',
      'Gamification Intro Reset! Restart app to see it.',
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  Future<void> fetchXPHistory() async {
    try {
      final history = await _repository.getXPHistory();
      xpHistory.assignAll(history);
    } catch (e) {
      print('Error fetching XP history: $e');
    }
  }

  Future<void> awardXPToUser(
    String userId,
    double amount, {
    String reason = 'Activity',
    String? referenceId,
  }) async {
    print('DEBUG: awardXPToUser called for userId: $userId, amount: $amount');
    try {
      final response = await _repository.incrementUserXP(
        userId: userId,
        amount: amount,
        reason: reason,
        referenceId:
            referenceId ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (response['success'] == true) {
        print('DEBUG: XP Awarded securely for user $userId');
      } else {
        print('DEBUG: XP already awarded to user $userId for ref $referenceId');
      }
    } catch (e) {
      print('Error awarding XP to user $userId: $e');
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    _xpEventController.close();
    super.onClose();
  }

  Widget _buildRuleItem(IconData icon, String label, String xp, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          xp,
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showLevelUpDialog(int newLevel) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // Dark theme surface
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFFD700),
              width: 2,
            ), // Gold border
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.whatshot, color: Color(0xFFFFD700), size: 64),
              const SizedBox(height: 16),
              const Text(
                'LEVEL UP!',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: Color(0xFFFFD700),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You reached Level $newLevel!',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Awesome!'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Level definitions
  final List<Map<String, dynamic>> levels = [
    {'level': 1, 'name': 'Newbie'},
    {'level': 2, 'name': 'Pejuang Rutin'},
    {'level': 3, 'name': 'Konsisten Abiez'},
    {'level': 4, 'name': 'Jagoan Strik'},
    {'level': 5, 'name': 'Pro'},
    {'level': 6, 'name': 'Master'},
    {'level': 7, 'name': 'Veteran'},
    {'level': 8, 'name': 'SUHU'},
    {'level': 9, 'name': 'LEGEND'},
    {'level': 10, 'name': 'GOAT'},
  ];

  String get currentLevelName {
    final levelData = levels.firstWhere(
      (data) => data['level'] == currentLevel.value,
      orElse: () => {'name': 'Unknown'},
    );
    return levelData['name'] as String;
  }

  int getXpRequiredForLevel(int level) {
    if (level <= 1) return 0;
    // For now let's just use the list and fallback to formula for higher levels
    if (level <= levels.length) {
      return levels[level - 1]['xp'] as int;
    }
    return level * 100; // Fallback to old formula if level exceeds defined list
  }
}
