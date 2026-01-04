import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:strik_app/controllers/habit_controller.dart';
import 'package:strik_app/controllers/habit_detail_controller.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/screens/create_habit_screen.dart';
import 'package:strik_app/controllers/habit_journal_controller.dart';
import 'package:strik_app/data/models/habit_journal.dart';

class HabitDetailScreen extends StatelessWidget {
  final Habit habit;
  final HabitDetailController controller;
  final HabitJournalController journalController;

  HabitDetailScreen({super.key, required this.habit})
    : controller = Get.put(HabitDetailController(habit.id!), tag: habit.id),
      journalController = Get.put(
        HabitJournalController(habit.id!),
        tag: habit.id,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context, controller),
      body: Obx(() {
        final habitController = Get.find<HabitController>();
        final currentHabit = habitController.habits.firstWhere(
          (h) => h.id == habit.id,
          orElse: () => habit,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                currentHabit.title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currentHabit.frequency == 'daily'
                    ? 'Tiap Hari'
                    : currentHabit.frequency.capitalizeFirst!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
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
                        ? 'Ingat: ${currentHabit.reminderTime!.format(context)}'
                        : 'Reminder Off',
                    style: GoogleFonts.plusJakartaSans(
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
              _buildStats(controller),

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
                  style: GoogleFonts.spaceGrotesk(
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
                    style: GoogleFonts.plusJakartaSans(
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
              (h) => h.id == habit.id,
              orElse: () => habit,
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

  Widget _buildStats(HabitDetailController controller) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Totalan', '${controller.totalCompletions.value}'),
            _buildVerticalDivider(),
            _buildStatItem('Best Streak', '${controller.bestStreak.value}'),
            _buildVerticalDivider(),
            _buildStatItem('Streak', '${controller.currentStreak.value}'),
          ],
        ),
      );
    });
  }

  Widget _buildCalendarHeader(HabitDetailController controller) {
    return Obx(
      () => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Wrapped Bulanan',
            style: GoogleFonts.spaceGrotesk(
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
                onPressed: () => controller.changeMonth(-1),
              ),
              Text(
                DateFormat('MMM yyyy').format(controller.focusedMonth.value),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () => controller.changeMonth(1),
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
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Beneran mau hapus "${habit.title}"? Progressnya bakal ilang semua loh coy.',
          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Gajadi',
              style: GoogleFonts.plusJakartaSans(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              final habitController = Get.find<HabitController>();
              habitController.deleteHabit(habit.id!);
            },
            child: Text(
              'Hapus!',
              style: GoogleFonts.plusJakartaSans(
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
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
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
          } else if (details.primaryVelocity! < 0) {
            // User swiped Right -> Go to Next Month
            controller.changeMonth(1);
          }
        },
        child: Container(
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
                        style: GoogleFonts.plusJakartaSans(
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
                        child: Text(
                          '$dayNum',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: textColor,
                            fontWeight: isCompleted || isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
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
            Text(
              'Jurnal',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
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
                    style: GoogleFonts.plusJakartaSans(
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
                    style: GoogleFonts.plusJakartaSans(
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
            itemCount: journalController.journals.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
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
                  style: GoogleFonts.plusJakartaSans(
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
            const SizedBox(height: 8),
            Text(
              journal.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
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

  void _showJournalDialog(BuildContext context, {HabitJournal? journal}) {
    final textController = TextEditingController(text: journal?.content ?? '');
    final isEditing = journal != null;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Edit Jurnal' : 'Tulis Jurnal',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      Get.back(); // close sheet
                      _confirmDeleteJournal(journal!);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: textController,
              maxLines: 6,
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Gimana habit kamu hari ini? Apa yang kamu rasain?',
                hintStyle: GoogleFonts.plusJakartaSans(
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final content = textController.text.trim();
                  if (content.isEmpty) {
                    Get.snackbar(
                      'Error',
                      'Konten jurnal tidak boleh kosong',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                    return;
                  }

                  if (isEditing) {
                    journalController.updateJournal(journal!.id!, content);
                  } else {
                    journalController.addJournal(content);
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
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

  void _confirmDeleteJournal(HabitJournal journal) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          'Hapus Jurnal?',
          style: GoogleFonts.spaceGrotesk(color: Colors.white),
        ),
        content: Text(
          'Yakin mau hapus jurnal ini?',
          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
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
}
