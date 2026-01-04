import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:strik_app/controllers/habit_detail_controller.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/data/models/habit.dart';

class HabitDetailScreen extends StatelessWidget {
  final Habit habit;
  final HabitDetailController controller;

  HabitDetailScreen({super.key, required this.habit})
    : controller = Get.put(HabitDetailController(habit.id!), tag: habit.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppTheme.textPrimary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.textPrimary),
            onPressed: () {
              // TODO: Navigate to Edit
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.textPrimary),
            onPressed: () {
              // TODO: Confirm and delete
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              habit.title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              habit.frequency == 'daily'
                  ? 'Tiap Hari'
                  : habit.frequency.capitalizeFirst!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Stats
            Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
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
                      'Streak',
                      '${controller.currentStreak.value}',
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 32),

            // History Calendar
            Obx(
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
                        icon: Icon(
                          Icons.chevron_left,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () => controller.changeMonth(-1),
                      ),
                      Text(
                        DateFormat(
                          'MMM yyyy',
                        ).format(controller.focusedMonth.value),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () => controller.changeMonth(1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildInteractiveCalendar(controller),

            const SizedBox(height: 32),

            // Description
            if (habit.description != null && habit.description!.isNotEmpty) ...[
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
                  habit.description!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: AppTheme.textPrimary.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
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

  Widget _buildInteractiveCalendar(HabitDetailController controller) {
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
                      if (habit.color.startsWith('0x')) {
                        habitColor = Color(int.parse(habit.color));
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
}
