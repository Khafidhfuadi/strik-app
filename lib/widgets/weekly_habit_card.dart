import 'package:flutter/material.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:strik_app/controllers/habit_controller.dart';

class WeeklyHabitCard extends StatelessWidget {
  final Habit habit;
  final Map<String, String> weeklyLogs; // Date(YYYY-MM-DD) -> status
  final DateTime weekStart;

  const WeeklyHabitCard({
    super.key,
    required this.habit,
    required this.weeklyLogs,
    required this.weekStart,
  });

  @override
  Widget build(BuildContext context) {
    Color habitColor = AppTheme.primary;
    try {
      if (habit.color.startsWith('0x')) {
        habitColor = Color(int.parse(habit.color));
      }
    } catch (_) {}

    final days = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: habitColor,
        borderRadius: BorderRadius.circular(24),
        // No border for the main card as it is filled
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  habit.title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, // Dark text on colored card
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), // Subtle dark badge
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getFrequencyText(habit),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((date) {
              final dateStr = date.toIso8601String().split('T')[0];
              final status = weeklyLogs[dateStr];
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final itemDate = DateTime(date.year, date.month, date.day);

              final isToday = itemDate.isAtSameMomentAs(today);
              final isFuture = itemDate.isAfter(today);

              return GestureDetector(
                onTap: isFuture
                    ? null
                    : () {
                        Get.find<HabitController>().toggleHabitCompletion(
                          habit,
                          date,
                        );
                      },
                child: Opacity(
                  opacity: isFuture ? 0.3 : 1.0,
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E').format(date).substring(0, 1),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withOpacity(isToday ? 1.0 : 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: status == 'completed'
                              ? Colors.white.withOpacity(0.25)
                              : (isToday
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.transparent),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: status == 'completed'
                                ? Colors.transparent
                                : Colors.white.withOpacity(
                                    0.2,
                                  ), // Subtle border
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: status == 'completed'
                            ? const Icon(
                                Icons.check,
                                size: 18,
                                color:
                                    Colors.white, // Colored checkmark on black
                              )
                            : status == 'skipped'
                            ? Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white.withOpacity(0.5),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getFrequencyText(Habit habit) {
    // Basic formatting. Could be improved based on exact requirements
    if (habit.frequency == 'daily') return 'Everyday';
    // Add logic for specific days if needed
    return 'Custom';
  }
}
