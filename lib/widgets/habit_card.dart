import 'package:flutter/material.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/data/models/habit.dart';

class HabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback? onTap;
  final String? status; // 'completed', 'skipped', or null

  const HabitCard({super.key, required this.habit, this.onTap, this.status});

  @override
  Widget build(BuildContext context) {
    // Parse color from string 0x...
    Color habitColor = AppTheme.primary;
    if (status == null) {
      try {
        if (habit.color.startsWith('0x')) {
          habitColor = Color(int.parse(habit.color));
        }
      } catch (e) {
        // Fallback
      }
    } else {
      // Dim color if completed/skipped
      habitColor = AppTheme.surface;
    }

    // Improve contrast for text
    final Color textColor = status == null ? Colors.black : Colors.white54;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Margin removed to let parent control layout (e.g. inside Dismissible)
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: habitColor,
          borderRadius: BorderRadius.circular(16),
          border: status != null ? Border.all(color: Colors.white12) : null,
        ),
        child: Row(
          children: [
            // Checkbox area (visual only for now/todo)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: status == 'completed'
                    ? AppTheme.primary
                    : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: status == null
                    ? Border.all(color: Colors.black12)
                    : null,
              ),
              child: status == 'completed'
                  ? const Icon(Icons.check, size: 16, color: Colors.black)
                  : status == 'skipped'
                  ? const Icon(Icons.close, size: 16, color: Colors.white54)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          habit.title,
                          style: TextStyle(
                            color:
                                (status == 'completed' || status == 'skipped')
                                ? Colors.grey
                                : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            decoration: status == 'completed'
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (habit.isChallenge) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                size: 12,
                                color: Colors.black87,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Challenge',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (status != null)
              Text(
                status == 'completed' ? 'Completed' : 'Skipped',
                style: TextStyle(color: textColor, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
