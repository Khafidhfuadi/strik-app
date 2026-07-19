import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:strik_app/controllers/habit_controller.dart';
import 'package:strik_app/controllers/habit_detail_controller.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/screens/create_habit_screen.dart';
import 'package:strik_app/controllers/habit_journal_controller.dart';
import 'package:strik_app/data/models/habit_journal.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:strik_app/controllers/tour_controller.dart';
import 'package:strik_app/controllers/habit_challenge_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:strik_app/services/alarm_manager_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/screens/coach_strik_ai_screen.dart';
import 'package:strik_app/screens/habit_journal_editor_screen.dart';
import 'package:strik_app/widgets/user_profile_bottom_sheet.dart';

class HabitDetailScreen extends StatefulWidget {
  final Habit habit;

  const HabitDetailScreen({super.key, required this.habit});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  static const double _sectionGap = 24;
  static const double _titleGap = 16;

  late HabitDetailController controller;
  late HabitJournalController journalController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Get.put(TourController());
    controller = Get.put(
      HabitDetailController(widget.habit.id!),
      tag: widget.habit.id,
    );
    journalController = Get.put(
      HabitJournalController(widget.habit.id!),
      tag: widget.habit.id,
    );
    _scrollController.addListener(_onScroll);

    // Fetch challenge leaderboard if this is a challenge habit
    if (widget.habit.isChallenge &&
        Get.isRegistered<HabitChallengeController>()) {
      Get.find<HabitChallengeController>().fetchChallengeLeaderboard(
        widget.habit.challengeId!,
      );
    }

    // Start Tour after loading
    ever(controller.isLoading, (isLoading) {
      if (!isLoading) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Get.find<TourController>().startHabitDetailTour(context);
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.isLoading.value) {
        Get.find<TourController>().startHabitDetailTour(context);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      journalController.fetchJournals();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context, controller),
      body: Obx(() {
        final habitController = Get.find<HabitController>();
        final currentHabit = habitController.habits.firstWhere(
          (h) => h.id == widget.habit.id,
          orElse: () => habitController.archivedHabits.firstWhere(
            (h) => h.id == widget.habit.id,
            orElse: () => widget.habit,
          ),
        );

        return RefreshIndicator(
          onRefresh: () async {
            await journalController.fetchJournals(refresh: true);
            await journalController.fetchFocusedMonthJournals();
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  currentHabit.title,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    String freqLabel;
                    if (currentHabit.frequency == 'daily') {
                      if (currentHabit.daysOfWeek != null &&
                          currentHabit.daysOfWeek!.isNotEmpty) {
                        if (currentHabit.daysOfWeek!.length == 7) {
                          freqLabel = 'Tiap Hari';
                        } else {
                          const days = [
                            'Sen',
                            'Sel',
                            'Rab',
                            'Kam',
                            'Jum',
                            'Sab',
                            'Min',
                          ];
                          final sortedDays = List<int>.from(
                            currentHabit.daysOfWeek!,
                          )..sort();
                          freqLabel = sortedDays.map((d) => days[d]).join(', ');
                        }
                      } else {
                        freqLabel = 'Tiap Hari';
                      }
                    } else if (currentHabit.frequency == 'weekly') {
                      if (currentHabit.frequencyCount != null) {
                        freqLabel = 'Mingguan: ${currentHabit.frequencyCount}x';
                      } else {
                        freqLabel = 'Mingguan';
                      }
                    } else if (currentHabit.frequency == 'monthly') {
                      if (currentHabit.daysOfWeek != null &&
                          currentHabit.daysOfWeek!.isNotEmpty) {
                        final sortedDates = List<int>.from(
                          currentHabit.daysOfWeek!,
                        )..sort();
                        freqLabel = 'Bulanan: Tgl ${sortedDates.join(', ')}';
                      } else {
                        freqLabel = 'Bulanan';
                      }
                    } else {
                      freqLabel = currentHabit.frequency.capitalizeFirst!;
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Challenge pill
                        if (currentHabit.isChallenge)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.emoji_events_rounded,
                                  size: 13,
                                  color: Color(0xFFF59E0B),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Challenge',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Frequency pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.repeat_rounded,
                                size: 13,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                freqLabel,
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Reminder pill
                        GestureDetector(
                          onTap: () => _showParticipantReminderSheet(
                            context,
                            currentHabit,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: currentHabit.reminderEnabled
                                  ? AppTheme.primary.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  currentHabit.reminderEnabled
                                      ? Icons.notifications_active_rounded
                                      : Icons.notifications_off_outlined,
                                  size: 13,
                                  color: currentHabit.reminderEnabled
                                      ? AppTheme.primary
                                      : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  currentHabit.reminderEnabled &&
                                          currentHabit.reminderTime != null
                                      ? currentHabit.reminderTime!.format(
                                          context,
                                        )
                                      : 'Atur Reminder',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: currentHabit.reminderEnabled
                                        ? AppTheme.primary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: _sectionGap),

                // Stats
                _buildStats(controller, currentHabit),

                const SizedBox(height: _sectionGap),

                // Challenge Leaderboard
                if (currentHabit.isChallenge)
                  _buildChallengeLeaderboard(currentHabit),
                if (currentHabit.isChallenge)
                  const SizedBox(height: _sectionGap),

                // History Calendar
                _buildCalendarHeader(controller),
                const SizedBox(height: _titleGap),
                _buildInteractiveCalendar(controller, currentHabit),

                const SizedBox(height: _sectionGap),

                // Description
                if (currentHabit.description != null &&
                    currentHabit.description!.isNotEmpty) ...[
                  Text(
                    'Detailnya',
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: _titleGap),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Text(
                      currentHabit.description!,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16,
                        color: AppTheme.textPrimary.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: _sectionGap),
                ],

                // Journal Section
                _buildJournalSection(context, currentHabit),
                const SizedBox(height: _sectionGap),
              ],
            ),
          ),
        );
      }),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    HabitDetailController controller,
  ) {
    // Check permissions for challenge habits
    final habitController = Get.find<HabitController>();
    final currentHabit = habitController.habits.firstWhere(
      (h) => h.id == widget.habit.id,
      orElse: () => habitController.archivedHabits.firstWhere(
        (h) => h.id == widget.habit.id,
        orElse: () => widget.habit,
      ),
    );

    final isChallenge = currentHabit.isChallenge;
    final isCreator =
        !currentHabit.isChallenge ||
        (currentHabit.isChallenge &&
            Get.find<HabitChallengeController>()
                    .getChallengeForHabit(currentHabit.challengeId)
                    ?.creatorId ==
                Supabase.instance.client.auth.currentUser?.id);

    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        onPressed: () => Get.back(),
      ),
      actions: [
        if (isChallenge)
          IconButton(
            icon: const Icon(
              Icons.help_outline_rounded,
              color: AppTheme.textPrimary,
            ),
            onPressed: () => _showChallengeHelp(context),
          ),
        if (isCreator)
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
            onPressed: () => _showActionsBottomSheet(context, currentHabit),
          ),
      ],
    );
  }

  void _showParticipantReminderSheet(BuildContext context, Habit currentHabit) {
    bool isEnabled = currentHabit.reminderEnabled;
    TimeOfDay? selectedTime = currentHabit.reminderTime;
    bool isSaving = false;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setState) {
          return Container(
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
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Atur Reminder',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Atur Alarmmu Sendiri Disini!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Aktifkan Pengingat',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: isEnabled,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (val) {
                          setState(() {
                            isEnabled = val;
                            if (isEnabled && selectedTime == null) {
                              selectedTime = const TimeOfDay(
                                hour: 18,
                                minute: 0,
                              );
                            }
                          });
                        },
                      ),
                      if (isEnabled) ...[
                        const Divider(color: Colors.white12),
                        ListTile(
                          title: const Text(
                            'Jam Pengingat',
                            style: TextStyle(color: Colors.white),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              selectedTime != null
                                  ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                                  : 'Pilih Waktu',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime:
                                  selectedTime ??
                                  const TimeOfDay(hour: 18, minute: 0),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: AppTheme.primary,
                                      onPrimary: Colors.black,
                                      surface: AppTheme.surface,
                                      onSurface: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (time != null) {
                              setState(() => selectedTime = time);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setState(() => isSaving = true);
                            try {
                              // We only want to update the reminder settings in the database directly
                              // to avoid full object replacement complications.
                              String? reminderString;
                              if (selectedTime != null) {
                                final now = DateTime.now();
                                final localDateTime = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  selectedTime!.hour,
                                  selectedTime!.minute,
                                );
                                final utcDateTime = localDateTime.toUtc();
                                reminderString =
                                    '${utcDateTime.hour.toString().padLeft(2, '0')}:${utcDateTime.minute.toString().padLeft(2, '0')}';
                              }

                              await Supabase.instance.client
                                  .from('habits')
                                  .update({
                                    'reminder_enabled': isEnabled,
                                    if (reminderString != null)
                                      'reminder_time': reminderString,
                                    if (reminderString == null)
                                      'reminder_time': null,
                                  })
                                  .eq('id', currentHabit.id!);

                              // Refresh the HabitController so the new settings take effect locally
                              await Get.find<HabitController>()
                                  .fetchHabitsAndLogs(isRefresh: true);

                              // Schedule the alarm immediately for the updated habit
                              final updatedHabit = Get.find<HabitController>()
                                  .habits
                                  .firstWhere(
                                    (h) => h.id == currentHabit.id,
                                    orElse: () => currentHabit,
                                  );

                              if (updatedHabit.reminderEnabled &&
                                  updatedHabit.reminderTime != null) {
                                await AlarmManagerService.instance
                                    .scheduleRecurringAlarm(
                                      habitId: updatedHabit.id!,
                                      habitTitle: updatedHabit.title,
                                      frequency: updatedHabit.frequency,
                                      daysOfWeek: updatedHabit.daysOfWeek,
                                      reminderTime: updatedHabit.reminderTime!,
                                    );
                              } else {
                                await AlarmManagerService.instance
                                    .cancelHabitAlarm(updatedHabit.id!);
                              }

                              Get.back(); // close bottom sheet
                            } catch (e) {
                              Get.snackbar(
                                'Error',
                                'Gagal menyimpan pengaturan: $e',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            } finally {
                              if (mounted) setState(() => isSaving = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Simpan Pengingat',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Plus Jakarta Sans',
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _showChallengeHelp(BuildContext context) {
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
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Cara Main Challenge 🏆',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildHelpSection(
              icon: Icons.camera_alt_outlined,
              title: 'Cara Mengerjakan',
              description:
                  'Upload foto bukti (Momentz) sebagai jurnal habit kamu. Pastikan sesuai frekuensi yang ditentukan ya!',
            ),
            const SizedBox(height: 16),
            _buildHelpSection(
              icon: Icons.auto_awesome_outlined,
              title: 'Setelah Complete',
              description:
                  'Kamu bakal dapet +XP buat naikin level, masuk leaderboard mingguan, dan streak api kamu bakal menyala! 🔥',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.surface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Siap, Paham!',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildHelpSection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats(HabitDetailController controller, Habit currentHabit) {
    return Container(
      key: Get.find<TourController>().keyDetailStats,
      child: Obx(() {
        if (controller.isLoading.value) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[800]!,
            highlightColor: Colors.grey[700]!,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    Column(
                      children: [
                        Container(
                          width: 60,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 40,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    if (i < 2)
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                  ],
                ],
              ),
            ),
          );
        }

        // Calculate Goal Progress if endDate exists
        Widget? goalProgress;
        if (currentHabit.endDate != null && currentHabit.createdAt != null) {
          final now = DateTime.now();
          final start = currentHabit.createdAt!;
          final end = currentHabit.endDate!;

          final totalDuration = end.difference(start).inSeconds;
          final elapsed = now.difference(start).inSeconds;

          double progress = 0.0;
          if (totalDuration > 0) {
            progress = (elapsed / totalDuration).clamp(0.0, 1.0);
          }

          final percentage = (progress * 100).toInt();

          // Calculate days left based on local calendar dates
          final endLocal = end.toLocal();
          final endDay = DateTime(endLocal.year, endLocal.month, endLocal.day);
          final nowDay = DateTime(now.year, now.month, now.day);
          final daysLeft = endDay.difference(nowDay).inDays;

          goalProgress = Column(
            children: [
              const SizedBox(height: 24),
              Divider(color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress Goal',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    currentHabit.color.startsWith('0x')
                        ? Color(int.parse(currentHabit.color))
                        : AppTheme.primary,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  daysLeft > 0
                      ? '$daysLeft hari lagi'
                      : (daysLeft == 0
                            ? 'Hari ini terakhir!'
                            : 'Udah lewat deadline'),
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    color: daysLeft >= 0
                        ? AppTheme.textSecondary
                        : Colors.redAccent,
                  ),
                ),
              ),
            ],
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Totalan',
                    '${controller.totalCompletions.value}',
                  ),
                  _buildVerticalDivider(),
                  _buildStatItem(
                    'Best Streak',
                    '${controller.bestStreak.value}',
                  ),
                  _buildVerticalDivider(),
                  _buildStatItem(
                    'Streak Aktif',
                    '${controller.currentStreak.value}',
                  ),
                ],
              ),
              if (goalProgress != null) goalProgress,
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCalendarHeader(HabitDetailController controller) {
    return Obx(
      () => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Wrapped Bulanan',
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chevron_left,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () {
                  controller.changeMonth(-1);
                  journalController.updateFocusMonth(
                    controller.focusedMonth.value,
                  );
                },
              ),
              Text(
                DateFormat('MMM yyyy').format(controller.focusedMonth.value),
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () {
                  controller.changeMonth(1);
                  journalController.updateFocusMonth(
                    controller.focusedMonth.value,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showArchiveConfirmation(BuildContext context, Habit currentHabit) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Arsipkan Habit?',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Beneran mau mengarsipkan "${currentHabit.title}"? Kamu tidak akan mendapatkan reminder dan habit ini akan dipindahkan ke arsip.',
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: Colors.white70,
          ),
        ),
        actions: [
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
          TextButton(
            onPressed: () async {
              Get.back(); // Close dialog
              final habitController = Get.find<HabitController>();
              await habitController.archiveHabit(currentHabit.id!);
            },
            child: const Text(
              'Arsipkan',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          'Hapus Habit?',
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Beneran mau hapus "${widget.habit.title}"? Progressnya bakal ilang semua loh coy.',
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Gajadi',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.white54,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog

              // Check if it's a challenge & user is creator
              if (widget.habit.challengeId != null &&
                  Get.isRegistered<HabitChallengeController>()) {
                final challengeCtrl = Get.find<HabitChallengeController>();
                final challenge = challengeCtrl.getChallengeForHabit(
                  widget.habit.challengeId,
                );

                // If challenge exists and I am the creator
                if (challenge != null &&
                    challenge.creatorId ==
                        Supabase.instance.client.auth.currentUser?.id) {
                  // Delete entire challenge (cascade to participants)
                  challengeCtrl.deleteChallenge(challenge.id!);
                  Get.back(); // Close screen
                  return;
                }
              }

              // Normal habit delete (or just leaving challenge if participant)
              final habitController = Get.find<HabitController>();
              habitController.deleteHabit(widget.habit.id!);
            },
            child: Text(
              'Hapus!',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showActionsBottomSheet(BuildContext context, Habit currentHabit) {
    final isArchived = currentHabit.isArchivedManual;

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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Edit
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: AppTheme.textPrimary,
                  size: 20,
                ),
              ),
              title: const Text(
                'Edit Habit',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                'Ubah nama, frekuensi, atau detail lainnya',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Get.back(); // Close bottom sheet
                Get.to(() => CreateHabitScreen(habit: currentHabit));
              },
            ),
            Divider(color: Colors.grey[800], height: 1),
            // Archive / Unarchive
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (isArchived ? AppTheme.primary : const Color(0xFFF59E0B))
                          .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  color: isArchived
                      ? AppTheme.primary
                      : const Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
              title: Text(
                isArchived ? 'Batalkan Arsip' : 'Arsipkan Habit',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                isArchived
                    ? 'Kembalikan habit ke daftar aktif'
                    : 'Simpan habit ke arsip tanpa menghapus data',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Get.back(); // Close bottom sheet
                _showArchiveConfirmation(context, currentHabit);
              },
            ),
            Divider(color: Colors.grey[800], height: 1),
            // Delete
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              title: const Text(
                'Hapus Habit',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                'Hapus habit beserta semua progress-nya',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Get.back(); // Close bottom sheet
                _showDeleteConfirmation(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildStatItem(String label, String value) {
    // ... same
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildInteractiveCalendar(
    HabitDetailController controller,
    Habit currentHabit,
  ) {
    return Obx(() {
      // dependence on journals and focusedMonthJournals to trigger rebuild
      journalController.journals.length;
      journalController.focusedMonthJournals.length;

      final focusedDate = controller.focusedMonth.value;
      final daysInMonth = DateUtils.getDaysInMonth(
        focusedDate.year,
        focusedDate.month,
      );
      final firstDayOfMonth = DateTime(focusedDate.year, focusedDate.month, 1);
      final firstWeekday = firstDayOfMonth.weekday;
      final offset = firstWeekday - 1;

      // Set of completed dates
      final completedSet = controller.logs
          .where((l) => l['status'] == 'completed')
          .map((l) => l['target_date'] as String)
          .toSet();

      return GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            // User swiped Left -> Go to Previous Month
            controller.changeMonth(-1);
            journalController.updateFocusMonth(controller.focusedMonth.value);
          } else if (details.primaryVelocity! < 0) {
            // User swiped Right -> Go to Next Month
            controller.changeMonth(1);
            journalController.updateFocusMonth(controller.focusedMonth.value);
          }
        },
        child: Container(
          key: Get.find<TourController>().keyDetailCalendar,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['S', 'S', 'R', 'K', 'J', 'S', 'M'].map((day) {
                  return SizedBox(
                    width: 32,
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: daysInMonth + offset,
                itemBuilder: (context, index) {
                  if (index < offset) {
                    return const SizedBox.shrink();
                  }
                  final dayNum = index - offset + 1;
                  final date = DateTime(
                    focusedDate.year,
                    focusedDate.month,
                    dayNum,
                  );
                  final dateStr = DateFormat('yyyy-MM-dd').format(date);

                  final isCompleted = completedSet.contains(dateStr);
                  final isToday = DateUtils.isSameDay(date, DateTime.now());
                  final isFuture = date.isAfter(DateTime.now());

                  // Check for journal on this date from focused month journals
                  final existingJournal = journalController.getJournalForDate(date);
                  final hasJournal = existingJournal != null;

                  Color? bgColor;
                  Color? textColor = isFuture
                      ? AppTheme.textSecondary.withValues(alpha: 0.3)
                      : AppTheme.textSecondary;
                  BoxBorder? border;

                  if (isCompleted) {
                    Color habitColor = AppTheme.primary;
                    try {
                      if (currentHabit.color.startsWith('0x')) {
                        habitColor = Color(int.parse(currentHabit.color));
                      }
                    } catch (_) {}

                    bgColor = habitColor.withValues(alpha: 0.2);
                    textColor = habitColor;
                    border = Border.all(color: habitColor, width: 1.5);
                  }

                  if (isToday) {
                    if (!isCompleted) {
                      textColor = AppTheme.textPrimary;
                      border = Border.all(color: AppTheme.primary, width: 1);
                    }
                  }

                  return GestureDetector(
                    onLongPress: (currentHabit.isArchived || isFuture)
                        ? null
                        : () {
                            _openJournalEditor(journal: existingJournal, date: date);
                          },
                    onTap: (currentHabit.isArchived || isFuture)
                        ? null
                        : () {
                            controller.toggleLog(date);
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                        border: border,
                      ),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '$dayNum',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 14,
                                color: textColor,
                                fontWeight: isCompleted || isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (hasJournal)
                              Positioned(
                                bottom: 0,
                                child: Container(
                                  width: 14,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                        ? Colors.white
                                        : AppTheme.primary,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildJournalSection(BuildContext context, Habit currentHabit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Jurnal Habit',
                  key: Get.find<TourController>().keyDetailJournal,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showTipsDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (!currentHabit.isArchived)
              Obx(() {
                if (journalController.todayJournal.value == null) {
                  return TextButton.icon(
                    onPressed: () => _openJournalEditor(habit: currentHabit),
                    icon: const Icon(
                      Icons.add,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    label: Text(
                      'Tulis Jurnal',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              }),
          ],
        ),
        const SizedBox(height: _titleGap),
        _buildAICoachCard(context),
        const SizedBox(height: _sectionGap),
        Obx(() {
          final monthJournals = journalController.focusedMonthJournals;
          final focusedMonth = journalController.focusedMonth.value;

          if (journalController.isFocusedMonthLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat(
                              'MMMM yyyy',
                              'id_ID',
                            ).format(focusedMonth),
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${monthJournals.length} jurnal di bulan ini',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _titleGap),
              if (monthJournals.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 48,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada jurnal di ${DateFormat('MMMM yyyy', 'id_ID').format(focusedMonth)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: monthJournals.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final journal = monthJournals[index];
                    return _buildJournalItem(context, journal);
                  },
                ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildJournalItem(BuildContext context, HabitJournal journal) {
    final heroTag =
        'journal-image-${journal.id ?? journal.createdAt.toIso8601String()}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openJournalEditor(journal: journal),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.03),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'EEEE, d MMM yyyy',
                            'id_ID',
                          ).format(journal.createdAt),
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        // const SizedBox(height: 6),
                        // Text(
                        //   journal.content.isNotEmpty
                        //       ? 'Catatan progres hari itu'
                        //       : 'Lampiran foto progres',
                        //   style: TextStyle(
                        //     fontFamily: 'Plus Jakarta Sans',
                        //     fontSize: 14,
                        //     fontWeight: FontWeight.w600,
                        //     color: AppTheme.textPrimary.withValues(alpha: 0.95),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Buka',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (journal.hasImages) ...[
                const SizedBox(height: 14),
                if (journal.imageUrls.length == 1)
                  // Single image: show full-width like before
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showJournalImageViewer(
                        context,
                        imageUrl: journal.imageUrls.first,
                        heroTag: '$heroTag-0',
                      ),
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          Hero(
                            tag: '$heroTag-0',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: AspectRatio(
                                aspectRatio: 4 / 3,
                                child: CachedNetworkImage(
                                  imageUrl: journal.imageUrls.first,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    return Container(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          color: Colors.white24,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.fullscreen,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Lihat penuh',
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Multiple images: horizontal scroll thumbnails
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: journal.imageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, imgIndex) {
                        final url = journal.imageUrls[imgIndex];
                        final imgHeroTag = '$heroTag-$imgIndex';
                        return GestureDetector(
                          onTap: () => _showJournalImageViewer(
                            context,
                            imageUrl: url,
                            heroTag: imgHeroTag,
                          ),
                          child: Hero(
                            tag: imgHeroTag,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 110,
                                height: 110,
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    return Container(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          color: Colors.white24,
                                          size: 20,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              Text(
                journal.content.isNotEmpty
                    ? journal.content
                    : 'Jurnal ini berisi foto progres tanpa catatan teks.',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  color: journal.content.isNotEmpty
                      ? AppTheme.textPrimary.withValues(alpha: 0.92)
                      : AppTheme.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openJournalEditor({
    Habit? habit,
    HabitJournal? journal,
    DateTime? date,
  }) {
    Get.to(
      () => HabitJournalEditorScreen(
        habit: habit ?? widget.habit,
        journalController: journalController,
        journal: journal,
        date: date,
      ),
    );
  }

  void _showJournalImageViewer(
    BuildContext context, {
    String? imageUrl,
    required String heroTag,
  }) {
    if (imageUrl == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Hero(
                      tag: heroTag,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) {
                          return const Icon(
                            Icons.broken_image,
                            color: Colors.white24,
                            size: 48,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 16,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      borderRadius: BorderRadius.circular(999),
                      child: Ink(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Cubit untuk zoom, geser untuk melihat detail gambar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAICoachCard(BuildContext context) {
    return Obx(() {
      final focusedMonth = journalController.focusedMonth.value;
      final monthlyCount = journalController.monthlyJournalCount.value;
      final quotaLeft = (3 - journalController.aiQuotaUsed.value).clamp(0, 3);

      String headline;
      String subline;
      Color accent;
      IconData statusIcon;

      if (journalController.isGeneratingAI.value) {
        headline = 'Coach lagi nyusun insight';
        subline = 'Insight bakal muncul di halaman Coach begitu selesai.';
        accent = const Color(0xFF60A5FA);
        statusIcon = Icons.auto_awesome_rounded;
      } else if (journalController.aiInsight.value.isNotEmpty) {
        headline = 'Insight bulan ini sudah siap';
        subline =
            'Buka halaman Coach buat baca analisis ${DateFormat('MMMM yyyy', 'id_ID').format(focusedMonth)}.';
        accent = AppTheme.primary;
        statusIcon = Icons.menu_book_rounded;
      } else if (journalController.isEligibleForAI.value) {
        headline = 'Jurnal bulan ini siap dianalisis';
        subline = 'Kamu masih punya $quotaLeft kuota generate bulan ini.';
        accent = const Color(0xFF6EE7B7);
        statusIcon = Icons.check_circle_outline_rounded;
      } else {
        headline = 'Kumpulin jurnal dulu buat unlock Coach';
        subline = '$monthlyCount/10 jurnal terkumpul di bulan aktif.';
        accent = const Color(0xFFF59E0B);
        statusIcon = Icons.lock_outline_rounded;
      }

      return InkWell(
        onTap: () {
          Get.to(
            () => CoachStrikAiScreen(
              habit: widget.habit,
              detailController: controller,
              journalController: journalController,
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(statusIcon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Coach Strik AI',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            DateFormat(
                              'MMM yyyy',
                              'id_ID',
                            ).format(focusedMonth),
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      headline,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subline,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        height: 1.45,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showTipsDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              'Jurnal Tips',
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTipItem(
              Icons.touch_app_outlined,
              'Tahan lama pada tanggal di kalender untuk melihat atau membuat jurnal masa lalu.',
            ),
            const SizedBox(height: 16),
            _buildTipItem(
              Icons.psychology_outlined,
              'Rutin buat jurnal minimal 10x pada setiap bulan untuk mendapatkan rekomendasi personal dari AI Coach.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Oke, Paham',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              color: AppTheme.textPrimary.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeLeaderboard(Habit habit) {
    if (!Get.isRegistered<HabitChallengeController>()) {
      return const SizedBox.shrink();
    }
    final challengeCtrl = Get.find<HabitChallengeController>();
    final challenge = challengeCtrl.getChallengeForHabit(habit.challengeId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Challenge Leaderboard',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            if (challenge != null)
              GestureDetector(
                onTap: () {
                  Share.share(
                    'Yuk join challenge "${challenge.habitTitle}" di Strik!\nKode: ${challenge.inviteCode}',
                    subject: 'Undangan Challenge Strik',
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.share, size: 14, color: Color(0xFFF59E0B)),
                      SizedBox(width: 4),
                      Text(
                        'Bagikan',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Obx(() {
          if (challengeCtrl.isLoadingLeaderboard.value) {
            return Shimmer.fromColors(
              baseColor: Colors.grey[800]!,
              highlightColor: Colors.grey[700]!,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: List.generate(
                    5,
                    (index) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: index < 4
                            ? Border(
                                bottom: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 100,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 60,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          final leaderboard = challengeCtrl.challengeLeaderboard;
          if (leaderboard.length <= 1) {
            return Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.group_add_rounded,
                      color: Color(0xFFF59E0B),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Masih Sendirian Nih?',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gas undang teman untuk mulai challenge habit!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (challenge != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Share.share(
                            'Yuk join challenge "${challenge.habitTitle}" di Strik!\nKode: ${challenge.inviteCode}',
                            subject: 'Undangan Challenge Strik',
                          );
                        },
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text(
                          'Bagikan Undangan',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: leaderboard.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final isFirst = idx == 0;
                final isLast = idx == leaderboard.length - 1;

                // Check if current user is creator and this item is NOT the creator
                final currentUser = Supabase.instance.client.auth.currentUser;
                final isCreatorView = challenge?.creatorId == currentUser?.id;
                final isSelf = item.userId == currentUser?.id;
                final canKick = isCreatorView && !isSelf;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isFirst
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                        : null,
                    borderRadius: BorderRadius.only(
                      topLeft: isFirst
                          ? const Radius.circular(20)
                          : Radius.zero,
                      topRight: isFirst
                          ? const Radius.circular(20)
                          : Radius.zero,
                      bottomLeft: isLast
                          ? const Radius.circular(20)
                          : Radius.zero,
                      bottomRight: isLast
                          ? const Radius.circular(20)
                          : Radius.zero,
                    ),
                    border: !isLast
                        ? Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Rank
                      SizedBox(
                        width: 28,
                        child: Text(
                          isFirst ? '\u{1F451}' : '#${item.rank}',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: isFirst ? 18 : 14,
                            fontWeight: FontWeight.bold,
                            color: isFirst
                                ? const Color(0xFFF59E0B)
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Avatar
                      GestureDetector(
                        onTap: () =>
                            UserProfileBottomSheet.show(context, item.userId),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[700],
                          backgroundImage: item.user?.avatarUrl != null
                              ? NetworkImage(item.user!.avatarUrl!)
                              : null,
                          child: item.user?.avatarUrl == null
                              ? const Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.white54,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Username
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              UserProfileBottomSheet.show(context, item.userId),
                          child: Text(
                            item.user?.username ?? 'User',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 14,
                              color: isFirst
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                              fontWeight: isFirst
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // Stats
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.score.toStringAsFixed(0)} pts',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isFirst
                                  ? const Color(0xFFF59E0B)
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '${item.completionRate.toStringAsFixed(0)}% | ${item.currentStreak}d streak',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      // Kick Button
                      if (canKick) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            if (challenge != null) {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (context) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                    horizontal: 16,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(24),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 4,
                                        margin: const EdgeInsets.only(
                                          bottom: 24,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[700],
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                        ),
                                        title: const Text(
                                          'Hapus Peserta',
                                          style: TextStyle(
                                            fontFamily: 'Plus Jakarta Sans',
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red,
                                          ),
                                        ),
                                        subtitle: const Text(
                                          'Keluarkan dari challenge ini',
                                          style: TextStyle(
                                            fontFamily: 'Plus Jakarta Sans',
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.pop(context); // Close sheet
                                          _showKickConfirmation(
                                            context,
                                            challenge.id!,
                                            item.userId,
                                            item.user?.username ?? 'User',
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  void _showKickConfirmation(
    BuildContext context,
    String challengeId,
    String userId,
    String username,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Peserta?',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Yakin ingin mengeluarkan "$username" dari challenge ini?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Get.find<HabitChallengeController>().kickParticipant(
                challengeId,
                userId,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Hapus',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
