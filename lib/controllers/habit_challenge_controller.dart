import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:strik_app/data/models/habit_challenge.dart';
import 'package:strik_app/data/repositories/habit_challenge_repository.dart';

class HabitChallengeController extends GetxController {
  final HabitChallengeRepository _repository = HabitChallengeRepository();

  var activeChallenges = <HabitChallenge>[].obs;
  var archivedChallenges = <HabitChallenge>[].obs;
  var challengeLeaderboard = <ChallengeLeaderboardEntry>[].obs;
  var isLoading = false.obs;
  var isLoadingLeaderboard = false.obs;

  // Pending invite code to show in bottom sheet after challenge creation
  var pendingInviteCode = ''.obs;
  var pendingHabitTitle = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    await _repository.archiveExpiredChallenges();
    await fetchActiveChallenges();
    await fetchArchivedChallenges();
  }

  Future<void> fetchActiveChallenges() async {
    try {
      isLoading.value = true;
      activeChallenges.value = await _repository.getActiveChallenges();
    } catch (e) {
      print('Error fetching active challenges: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchArchivedChallenges() async {
    try {
      archivedChallenges.value = await _repository.getArchivedChallenges();
    } catch (e) {
      print('Error fetching archived challenges: $e');
    }
  }

  Future<HabitChallenge?> createChallenge({
    required String habitTitle,
    String? habitDescription,
    required String habitColor,
    required String habitFrequency,
    List<int>? habitDaysOfWeek,
    int? habitFrequencyCount,
    required DateTime endDate,
    required String creatorHabitId,
  }) async {
    try {
      final challenge = await _repository.createChallenge(
        habitTitle: habitTitle,
        habitDescription: habitDescription,
        habitColor: habitColor,
        habitFrequency: habitFrequency,
        habitDaysOfWeek: habitDaysOfWeek,
        habitFrequencyCount: habitFrequencyCount,
        endDate: endDate,
        creatorHabitId: creatorHabitId,
      );
      activeChallenges.insert(0, challenge);
      return challenge;
    } catch (e) {
      Get.snackbar('Error', 'Gagal membuat challenge: $e');
      return null;
    }
  }

  /// Look up challenge by invite code
  Future<HabitChallenge?> lookupChallenge(String inviteCode) async {
    try {
      return await _repository.getChallengeByInviteCode(inviteCode);
    } catch (e) {
      Get.snackbar('Error', 'Challenge tidak ditemukan');
      return null;
    }
  }

  /// Join an existing challenge
  Future<bool> joinChallenge(HabitChallenge challenge) async {
    try {
      await _repository.joinChallenge(challenge);
      await fetchActiveChallenges();
      Get.snackbar(
        'Berhasil',
        'Kamu bergabung challenge "${challenge.habitTitle}"',
      );
      return true;
    } catch (e) {
      final msg = e.toString().contains('sudah bergabung')
          ? 'Kamu sudah bergabung challenge ini'
          : 'Gagal bergabung challenge';
      Get.snackbar('Oops', msg);
      return false;
    }
  }

  /// Copy invite link to clipboard
  Future<void> copyInviteLink(HabitChallenge challenge) async {
    await Clipboard.setData(ClipboardData(text: challenge.inviteCode));
    Get.snackbar(
      'Tersalin!',
      'Kode undangan "${challenge.inviteCode}" berhasil disalin. Bagikan ke temanmu!',
    );
  }

  /// Fetch leaderboard for a specific challenge
  Future<void> fetchChallengeLeaderboard(String challengeId) async {
    try {
      isLoadingLeaderboard.value = true;
      // Update scores first
      await _repository.updateChallengeLeaderboard(challengeId);
      // Then fetch
      final rawList = await _repository.getChallengeLeaderboard(challengeId);

      // Assign ranks based on sort order (index)
      challengeLeaderboard.value = rawList
          .asMap()
          .entries
          .map((e) => e.value.copyWith(rank: e.key + 1))
          .toList();
    } catch (e) {
      print('Error fetching challenge leaderboard: $e');
    } finally {
      isLoadingLeaderboard.value = false;
    }
  }

  /// Get participant count
  Future<int> getParticipantCount(String challengeId) async {
    return await _repository.getParticipantCount(challengeId);
  }

  /// Check if a habit is part of an active challenge
  bool isHabitInActiveChallenge(String? challengeId) {
    if (challengeId == null) return false;
    return activeChallenges.any((c) => c.id == challengeId && c.isActive);
  }

  /// Get challenge for a specific habit challengeId
  HabitChallenge? getChallengeForHabit(String? challengeId) {
    if (challengeId == null) return null;
    try {
      return activeChallenges.firstWhere((c) => c.id == challengeId);
    } catch (_) {
      try {
        return archivedChallenges.firstWhere((c) => c.id == challengeId);
      } catch (_) {
        return null;
      }
    }
  }

  /// Kick participant
  Future<void> kickParticipant(String challengeId, String userId) async {
    try {
      await _repository.removeParticipant(challengeId, userId);
      // Refresh leaderboard after kicking
      await fetchChallengeLeaderboard(challengeId);
      Get.snackbar('Bye Bye 👋', 'Peserta berhasil dikeluarkan dari challenge');
    } catch (e) {
      Get.snackbar('Error', 'Gagal mengeluarkan peserta: $e');
    }
  }

  /// Refresh all
  Future<void> refreshAll() async {
    await _repository.archiveExpiredChallenges();
    await fetchActiveChallenges();
    await fetchArchivedChallenges();
  }
}
