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
    // 1. Align Start Date to the previous Monday to ensure Week 0 is full (or padded at start)
    // Weekday: Mon=1 ... Sun=7.
    final int daysToSubtract =
        startDate.weekday - 1; // Mon (1) -> 0. Sun (7) -> 6.
    final DateTime alignedStart = startDate.subtract(
      Duration(days: daysToSubtract),
    );

    // 2. Calculate Total Days from aligned start
    final days = endDate.difference(alignedStart).inDays + 1;
    final int weeks = (days / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140, // 7 days * boxSize + spacing
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            reverse: false, // Standard L->R
            // If we want to show Newest (Right) initially, we might need a scroll controller,
            // but standard ListView starts at Left. Users can scroll right.
            itemCount: weeks,
            itemBuilder: (context, weekIndex) {
              final weekStart = alignedStart.add(Duration(days: weekIndex * 7));

              return Container(
                margin: const EdgeInsets.only(right: 4),
                child: Column(
                  children: List.generate(7, (dayIndex) {
                    final currentDay = weekStart.add(Duration(days: dayIndex));

                    // Don't render future days
                    if (currentDay.isAfter(endDate)) {
                      return const SizedBox(
                        width: 14,
                        height: 14,
                        child: SizedBox(),
                      );
                    }

                    // Don't render days before requested startDate (padding for week alignment)
                    if (currentDay.isBefore(startDate)) {
                      return const SizedBox(
                        width: 14,
                        height: 14,
                        child: SizedBox(),
                      );
                    }

                    final normalized = DateTime(
                      currentDay.year,
                      currentDay.month,
                      currentDay.day,
                    );
                    final count = datasets[normalized] ?? 0;
                    final intensity = (count > 4 ? 4 : count) / 4.0;
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
