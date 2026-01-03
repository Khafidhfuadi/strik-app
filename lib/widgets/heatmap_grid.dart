import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:strik_app/core/theme.dart';

class HeatmapGrid extends StatelessWidget {
  final Map<DateTime, int> datasets;
  final DateTime startDate;
  final DateTime endDate;
  final Color baseColor;

  const HeatmapGrid({
    super.key,
    required this.datasets,
    required this.startDate,
    required this.endDate,
    this.baseColor = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    // Generate dates
    final days = endDate.difference(startDate).inDays + 1;

    // Group by weeks for Column (Week) of Rows (Day)
    // We want a scrollable horizontal list of weeks
    // Each week has 7 slots (Mon-Sun or Sun-Sat). Let's start Monday (1).

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140, // 7 days * boxSize + spacing
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            reverse:
                true, // Show latest week first? Or standard? Usually GitHub is L->R. User might want latest.
            // Let's do standard L->R but scroll to end maybe? Or just R->L for mobile ease?
            itemCount: (days / 7).ceil(),
            itemBuilder: (context, weekIndex) {
              // Week 0 is startDate week
              final weekStart = startDate.add(Duration(days: weekIndex * 7));

              return Container(
                margin: const EdgeInsets.only(right: 4),
                child: Column(
                  children: List.generate(7, (dayIndex) {
                    final currentDay = weekStart.add(Duration(days: dayIndex));
                    if (currentDay.isAfter(endDate)) {
                      return const SizedBox(
                        width: 14,
                        height: 14,
                      ); // Placeholder
                    }

                    final normalized = DateTime(
                      currentDay.year,
                      currentDay.month,
                      currentDay.day,
                    );
                    final count = datasets[normalized] ?? 0;
                    final intensity =
                        (count > 4 ? 4 : count) / 4.0; // Max 4 for coloring
                    final hasData = count > 0;

                    return Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: hasData
                            ? baseColor.withValues(
                                alpha: 0.2 + (intensity * 0.8),
                              )
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: hasData ? null : null,
                    );
                  }),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Less',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 4),
            _legendBox(Colors.white.withValues(alpha: 0.05)),
            _legendBox(baseColor.withValues(alpha: 0.4)),
            _legendBox(baseColor.withValues(alpha: 0.6)),
            _legendBox(baseColor.withValues(alpha: 0.8)),
            _legendBox(baseColor),
            const SizedBox(width: 4),
            Text(
              'More',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendBox(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
