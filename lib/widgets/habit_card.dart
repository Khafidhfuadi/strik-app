import 'package:flutter/material.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/data/models/habit.dart';

class HabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback? onTap;

  const HabitCard({super.key, required this.habit, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Parse color from string 0x...
    Color habitColor = AppTheme.primary;
    try {
      if (habit.color.startsWith('0x')) {
        habitColor = Color(int.parse(habit.color));
      }
    } catch (e) {
      // Fallback
    }

    // Improve contrast for text on colored backgrounds
    // Using a simple luminance check failure safe, or just enforcing black/dark text on these neon colors
    // Our palette is neon, so black text is usually best.
    final Color textColor = Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: habitColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Checkbox area (visual only for now/todo)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (habit.description != null &&
                      habit.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      habit.description!,
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}
