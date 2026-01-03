import 'package:flutter/material.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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
                    color: Colors.black, // Dark text on colored card
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _getFrequencyText(habit), // e.g. "Everyday" or "Mo-Th, Sa"
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
              final isToday = _isSameDay(date, DateTime.now());

              return Column(
                children: [
                  Text(
                    DateFormat('E').format(date).substring(0, 3), // Mon, Tue...
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.black54,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isToday
                          ? Colors.black.withOpacity(0.1) // Highlight today
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: status == 'completed'
                        ? const Icon(
                            Icons.check,
                            size: 20,
                            color: Colors.black,
                          ) // Checkmark
                        : status == 'skipped'
                        ? const Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.black38,
                          )
                        : null, // Empty for not done
                  ),
                ],
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
