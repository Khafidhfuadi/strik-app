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
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:strik_app/controllers/tour_controller.dart';

class HabitDetailScreen extends StatefulWidget {
  final Habit habit;

  const HabitDetailScreen({super.key, required this.habit});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
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
          orElse: () => widget.habit,
        );

        return RefreshIndicator(
          onRefresh: () async {
            await journalController.fetchJournals(refresh: true);
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
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    String label;
                    if (currentHabit.frequency == 'daily') {
                      if (currentHabit.daysOfWeek != null &&
                          currentHabit.daysOfWeek!.isNotEmpty) {
                        if (currentHabit.daysOfWeek!.length == 7) {
                          label = 'Tiap Hari';
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
                          // Sort safely
                          final sortedDays = List<int>.from(
                            currentHabit.daysOfWeek!,
                          )..sort();
                          label = sortedDays.map((d) => days[d]).join(', ');
                        }
                      } else {
                        label = 'Tiap Hari';
                      }
                    } else if (currentHabit.frequency == 'weekly') {
                      if (currentHabit.frequencyCount != null) {
                        label = 'Mingguan: ${currentHabit.frequencyCount}x';
                      } else {
                        label = 'Mingguan';
                      }
                    } else if (currentHabit.frequency == 'monthly') {
                      if (currentHabit.daysOfWeek != null &&
                          currentHabit.daysOfWeek!.isNotEmpty) {
                        final sortedDates = List<int>.from(
                          currentHabit.daysOfWeek!,
                        )..sort();
                        label = 'Bulanan: Tanggal ${sortedDates.join(', ')}';
                      } else {
                        label = 'Bulanan';
                      }
                    } else {
                      label = currentHabit.frequency.capitalizeFirst!;
                    }

                    return Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      currentHabit.reminderEnabled
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                      size: 16,
                      color: currentHabit.reminderEnabled
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentHabit.reminderEnabled &&
                              currentHabit.reminderTime != null
                          ? 'Diingetin: ${currentHabit.reminderTime!.format(context)}'
                          : 'Reminder Off',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        color: currentHabit.reminderEnabled
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                        fontWeight: currentHabit.reminderEnabled
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Stats
                _buildStats(controller, currentHabit),

                const SizedBox(height: 32),

                // History Calendar
                _buildCalendarHeader(controller),
                const SizedBox(height: 16),
                _buildInteractiveCalendar(controller, currentHabit),

                const SizedBox(height: 32),

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
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 32),
                ],

                // Journal Section
                _buildJournalSection(context),
                const SizedBox(height: 32),
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
    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        onPressed: () => Get.back(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: AppTheme.textPrimary),
          onPressed: () {
            final habitController = Get.find<HabitController>();
            final currentHabit = habitController.habits.firstWhere(
              (h) => h.id == widget.habit.id,
              orElse: () => widget.habit,
            );
            Get.to(() => CreateHabitScreen(habit: currentHabit));
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.textPrimary),
          onPressed: () => _showDeleteConfirmation(context),
        ),
      ],
    );
  }

  Widget _buildStats(HabitDetailController controller, Habit currentHabit) {
    return Container(
      key: Get.find<TourController>().keyDetailStats,
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
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
          final daysLeft = end.difference(now).inDays;

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
      // dependence on journals to trigger rebuild
      journalController.journals.length;

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

                  // Check for journal on this date
                  final hasJournal = journalController.journals.any((j) {
                    final jDate = j.createdAt.toLocal();
                    return jDate.year == date.year &&
                        jDate.month == date.month &&
                        jDate.day == date.day;
                  });

                  Color? bgColor;
                  Color? textColor = isFuture
                      ? AppTheme.textSecondary.withOpacity(0.3)
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
                    onLongPress: () {
                      if (!isFuture) {
                        // Find existing journal to edit, or null to create new
                        final journal = journalController.journals
                            .firstWhereOrNull((j) {
                              final jDate = j.createdAt.toLocal();
                              return jDate.year == date.year &&
                                  jDate.month == date.month &&
                                  jDate.day == date.day;
                            });
                        _showJournalDialog(
                          context,
                          journal: journal,
                          date: date,
                        );
                      }
                    },
                    onTap: () {
                      if (!isFuture) {
                        controller.toggleLog(date);
                      }
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

  Widget _buildJournalSection(BuildContext context) {
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
            Obx(() {
              if (journalController.todayJournal.value == null) {
                return TextButton.icon(
                  onPressed: () => _showJournalDialog(context),
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
        const SizedBox(height: 16),
        const SizedBox(height: 16),
        _buildAICoachCard(context),
        const SizedBox(height: 24),
        Obx(() {
          if (journalController.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (journalController.journals.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                    'Belum ada jurnal',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount:
                journalController.journals.length +
                (journalController.isLoadingMore.value ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == journalController.journals.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final journal = journalController.journals[index];
              return _buildJournalItem(context, journal);
            },
          );
        }),
      ],
    );
  }

  Widget _buildJournalItem(BuildContext context, HabitJournal journal) {
    return GestureDetector(
      onTap: () => _showJournalDialog(context, journal: journal),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
            if (journal.imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: journal.imageUrl!,
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 150,
                    color: Colors.white.withValues(alpha: 0.05),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) {
                    return Container(
                      height: 150,
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.white24),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (journal.content.isNotEmpty)
              Text(
                journal.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  color: AppTheme.textPrimary.withValues(alpha: 0.9),
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showJournalDialog(
    BuildContext context, {
    HabitJournal? journal,
    DateTime? date,
  }) {
    final textController = TextEditingController(text: journal?.content ?? '');
    final isEditing = journal != null;
    final displayDate = date ?? (journal?.createdAt ?? DateTime.now());

    // Mutable state for the dialog
    File? selectedImage;
    String? existingImageUrl = journal?.imageUrl;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Jurnal' : 'Tulis Jurnal',
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'EEEE, d MMM yyyy',
                            'id_ID',
                          ).format(displayDate),
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (isEditing)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          Get.back(); // close sheet
                          _confirmDeleteJournal(journal);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: textController,
                  maxLines: 6,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Gimana habit kamu hari ini?',
                    hintStyle: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: AppTheme.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),

                // Image Preview Area
                if (selectedImage != null || existingImageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: selectedImage != null
                              ? Image.file(
                                  selectedImage!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  existingImageUrl!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedImage = null;
                                existingImageUrl = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Action Buttons (Camera / Gallery)
                Row(
                  children: [
                    _buildImagePickerButton(
                      context,
                      Icons.camera_alt_outlined,
                      'Kamera',
                      () async {
                        final file = await journalController.pickImage(
                          source: ImageSource.camera,
                        );
                        if (file != null) {
                          setState(() {
                            selectedImage = file;
                            // Reset existing if new one picked
                            // existingImageUrl = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildImagePickerButton(
                      context,
                      Icons.photo_library_outlined,
                      'Galeri',
                      () async {
                        final file = await journalController.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (file != null) {
                          setState(() {
                            selectedImage = file;
                          });
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final content = textController.text.trim();
                      if (content.isEmpty &&
                          selectedImage == null &&
                          existingImageUrl == null) {
                        Get.snackbar(
                          'Error',
                          'Isi konten atau upload foto dulu ya',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }

                      if (isEditing) {
                        journalController.updateJournal(
                          journal.id!,
                          content,
                          newImageFile: selectedImage,
                        );
                      } else {
                        journalController.addJournal(
                          content,
                          date: date,
                          imageFile: selectedImage,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Simpan',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
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

  Widget _buildImagePickerButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAICoachCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: journalController.aiInsight.value.isEmpty,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coach Strik AI',
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Obx(
                    () => Text(
                      journalController.aiInsight.value.isNotEmpty
                          ? 'Lihat analisis bulan ${DateFormat('MMMM yyyy', 'id_ID').format(journalController.focusedMonth.value)}!'
                          : 'Analisis habit bulanan',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: journalController.aiInsight.value.isNotEmpty
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Obx(
            () => journalController.isEligibleForAI.value
                ? const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondary,
                  )
                : const Icon(Icons.lock, color: Colors.grey, size: 20),
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() {
                  if (journalController.aiInsight.value.isNotEmpty) {
                    return _buildStyledText(journalController.aiInsight.value);
                  } else if (!journalController.isEligibleForAI.value) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tulis minimal 10 jurnal bulan ini buat dianalisis sama Coach Strik AI!',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Text(
                      'Cari tau insight bulan ini buat tau pola habit kamu dan tips memperbaikinya.',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: AppTheme.textSecondary,
                      ),
                    );
                  }
                }),
                const SizedBox(height: 20),
                Obx(() {
                  if (journalController.isEligibleForAI.value) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: !journalController.isGeneratingAI.value
                            ? () {
                                _confirmGenerateAi(context);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: journalController.isGeneratingAI.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                journalController.aiInsight.value.isEmpty
                                    ? 'Generate Insight ✨'
                                    : 'Regenerate Insight 🔄',
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                }),
                const SizedBox(height: 8),
                Obx(() {
                  if (journalController.isEligibleForAI.value) {
                    return Center(
                      child: Text(
                        "Sisa kuota bulan ini: ${3 - journalController.aiQuotaUsed.value}x",
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmGenerateAi(BuildContext context) {
    if (journalController.aiQuotaUsed.value >= 3) {
      Get.snackbar(
        'Limit Habis',
        'Jatah coach bulan ini udah kepake semua. Tunggu bulan depan ya! 🌚',
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        colorText: Colors.redAccent,
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Minta Saran Coach Strik AI?",
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tindakan ini bakal pake 1 kuota generate kamu.",
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Sisa Kuota: ${3 - journalController.aiQuotaUsed.value}x lagi (Bulan ini)",
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              "Batal",
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.white60,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Get.back(); // Close dialog

              // Prepare stats logic here since we moved it out of the button
              final totalLogs = controller.logs.length;
              final completed = controller.logs
                  .where((l) => l['status'] == 'completed')
                  .length;
              final skipped = controller.logs
                  .where((l) => l['status'] == 'skipped')
                  .length;

              final stats = {
                'total_logs': totalLogs,
                'completed': completed,
                'skipped': skipped,
                'rate': totalLogs > 0
                    ? (completed / totalLogs * 100).toStringAsFixed(1)
                    : '0',
              };

              journalController.generateAiInsight(widget.habit.title, stats);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              "Lanjut Gas!",
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledText(String text) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<TextSpan> spans = [];
    // Regex to match **bold** OR *bold*, allowing newlines
    final RegExp exp = RegExp(r'(\*{1,2})(.*?)(\1)', dotAll: true);
    final matches = exp.allMatches(text);

    int lastIndex = 0;
    for (final match in matches) {
      // Add text before the match
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        );
      }

      // Add the bold text (without asterisks)
      spans.add(
        TextSpan(
          text: match.group(2), // The content inside the asterisks
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: Colors.white, // Pure white for bold
            fontSize: 14,
            fontWeight: FontWeight.bold, // BOLD
            height: 1.6,
          ),
        ),
      );

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 14,
            height: 1.6,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  void _confirmDeleteJournal(HabitJournal journal) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          'Hapus Jurnal?',
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            color: Colors.white,
          ),
        ),
        content: Text(
          'Yakin mau hapus jurnal ini?',
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Gajadi')),
          TextButton(
            onPressed: () {
              Get.back();
              journalController.deleteJournal(journal.id!);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
}
