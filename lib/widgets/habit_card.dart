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
        margin: const EdgeInsets.only(bottom: 12),
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
                    : Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: status == null
                    ? Border.all(color: Colors.black26)
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
                  Text(
                    habit.title,
                    style: TextStyle(
                      color: Colors.black, // Always black for high contrast
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: status == 'completed'
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            if (status != null)
              Text(
                status == 'completed' ? 'Completed' : 'Skipped',
                style: TextStyle(color: textColor, fontSize: 12),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}
