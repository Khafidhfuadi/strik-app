import 'package:strik_app/data/models/habit.dart';

class HabitUtils {
  /// Calculates the expected number of completions for a habit within a given date range.
  ///
  /// [habit] The habit to calculate for.
  /// [rangeStart] The start date of the range (inclusive).
  /// [rangeEnd] The end date of the range (inclusive).
  static int calculateExpectedCount(
    Habit habit,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    // 1. Determine effective start and end dates based on habit lifecycle
    DateTime effectiveStart = rangeStart;
    if (habit.createdAt != null && habit.createdAt!.isAfter(rangeStart)) {
      effectiveStart = habit.createdAt!;
    }

    DateTime effectiveEnd = rangeEnd;
    if (habit.endDate != null && habit.endDate!.isBefore(rangeEnd)) {
      effectiveEnd = habit.endDate!;
    }

    // If the effective range is invalid (e.g., created after range end), return 0
    if (effectiveStart.isAfter(effectiveEnd)) {
      return 0;
    }

    // Normalize dates to start of day for comparison
    DateTime start = DateTime(
      effectiveStart.year,
      effectiveStart.month,
      effectiveStart.day,
    );
    DateTime end = DateTime(
      effectiveEnd.year,
      effectiveEnd.month,
      effectiveEnd.day,
    );

    // Ensure we include the end date by adding 1 day to the limit for loops/differences
    // or just handle inclusive logic carefully.

    int expectedCount = 0;

    switch (habit.frequency) {
      case 'daily':
        // Check everyday in the range
        // If daysOfWeek is provided, usage it as a filter (e.g. for "daily" but selected days)
        // In the creation screen, 'daily' + specific days is possible.
        // It seems 'daily' in creation screen implies specific days if index 0 is selected.
        // Let's assume habit.daysOfWeek map to [0=Mon, 6=Sun] or [0=Sun]?
        // CreateHabitController: days = ['S', 'S', 'R', 'K', 'J', 'S', 'M']; // Sen, Sel, Rab, Kam, Jum, Sab, Min? No.
        // Standard in Dart DateTime.weekday is 1=Mon, 7=Sun.
        // CreateHabitController uses index 0..6.
        // Let's check CreateHabitController mapping:
        // days = ['S', 'S', 'R', 'K', 'J', 'S', 'M']; -> Likely Senin, Selasa, Rabu, Kamis, Jumat, Sabtu, Minggu.
        // So 0=Senin(Mon), 1=Selasa(Tue), ..., 6=Minggu(Sun).
        // DateTime.weekday: 1=Mon, ..., 7=Sun.
        // So map: (weekday - 1) == index.

        int daysCount = 0;
        for (int i = 0; i <= end.difference(start).inDays; i++) {
          DateTime current = start.add(Duration(days: i));

          // Check if this day is valid for the habit
          if (habit.daysOfWeek != null && habit.daysOfWeek!.isNotEmpty) {
            // DateTime.weekday (1..7) -> Index (0..6)
            int dayIndex = current.weekday - 1;
            if (habit.daysOfWeek!.contains(dayIndex)) {
              daysCount++;
            }
          } else {
            // If no specific days, assume every day (default daily)
            daysCount++;
          }
        }
        expectedCount = daysCount;
        break;

      case 'weekly':
        // Check number of weeks in the range.
        // Logic: for every full week (or partial?), we expect 'frequencyCount'.
        // This is tricky for arbitrary ranges.
        // Simple approach: Iterate through weeks.
        // If the range is small (e.g. 1 day), and stats are weekly...
        // Maybe we just calculate proportional?
        // Better: Count how many "periods" fall in the range.
        // For weekly: usually resets on Monday.
        // Let's use a "week bucket" approach.
        // Identify unique weeks (Year-Week) in the range.
        // For each week, add frequencyCount.
        // BUT, what if range is only 2 days of that week?
        // The user effectively has the whole week to complete it.
        // If we are viewing "This Week", expected is frequencyCount.
        // If we are viewing "Today" (custom range 1 day) for a weekly habit,
        // it's hard to say if they missed it "today".
        // HOWEVER, statistics usually imply "Active habits in this period".
        // If the period covers the week, we expect the full count.
        // If the period is partial... let's stick to a simple greedy approach:
        // For every calendar week touched by [start, end], add frequencyCount.
        // This might over-expect if range is just 1 day.
        // Refined: Only count if the *end of the week* is within range? No.

        // Let's stick to the definition: "How many times SHOULD I have done this in this period?"
        // If I have a weekly goal of 3 times.
        // If filters are "Weekly" (last 7 days), expect 3.
        // If filters are "Daily" (today), it's ambiguous.
        // Let's assume for 'Weekly' habits, we only calculate robustly if range >= 1 week.
        // If range < 1 week, maybe we pro-rate? Or just valid = 1?
        // Let's behave like standard trackers:
        // If the range overlaps with a week, we count it?
        // Actually, most logical:
        // Iterate through each week in the range.
        // Week starts Monday.

        // Let's simplify:
        // Calculate number of days in range.
        // week_count = (days / 7).ceil()?
        // expected = week_count * frequencyCount.

        // Let's try to be precise about calendar weeks for 'weekly' habits.
        // Find the start of the week for 'start' date.
        // Find the end of the week for 'end' date.
        // Count weeks.

        // BUT, if the habit was created mid-week?
        // If habit created Wednesday, and goal is 3x/week.
        // Should we expect 3x for that first partial week? Usually yes, or remaining days?
        // Taking the simple route: Full expectation for any active week.

        DateTime currentWeekStart = start.subtract(
          Duration(days: start.weekday - 1),
        );
        while (currentWeekStart.isBefore(end.add(Duration(days: 1)))) {
          // Check if this week is valid for the habit (overlapping creation/end dates)
          // We already clipped start/end to effective range.
          // So just count it.
          expectedCount += (habit.frequencyCount ?? 1);
          currentWeekStart = currentWeekStart.add(Duration(days: 7));
        }

        // Correction: The loop above might add an extra week if 'end' is exactly on boundary?
        // Let's verify.
        // Range: Mon (1st) to Sun (7th).
        // currentWeekStart = Mon(1st). Loop runs.
        // Next = Mon(8th). Is 8th before 8th (end+1)? No. Stops.
        // Result: 1 week. Correct.
        break;

      case 'monthly':
        // Specific dates in month?
        // CreateHabitController: 'days_of_week' stores dates (1..31) for monthly.
        // So it's "Monthly on dates X, Y, Z".
        if (habit.daysOfWeek != null && habit.daysOfWeek!.isNotEmpty) {
          for (int i = 0; i <= end.difference(start).inDays; i++) {
            DateTime current = start.add(Duration(days: i));
            if (habit.daysOfWeek!.contains(current.day)) {
              expectedCount++;
            }
          }
        } else {
          // Just "once a month"? Or purely frequency count?
          // Look at create screen...
          // "Tanggal berapa aja?" -> Selection of dates 1-31.
          // So it always has specific dates for monthly.
          // If empty/null? assume index 1 (1st of month)?
          // Let's assume 1 if missing.
          // But actually duplicate logic from 'daily' but check .day instead of .weekday
          for (int i = 0; i <= end.difference(start).inDays; i++) {
            DateTime current = start.add(Duration(days: i));
            // Default to 1st if none selected? Or handled by validation?
            // Let's assume if specific dates are set, we look for them.
            if (habit.daysOfWeek!.contains(current.day)) {
              expectedCount++;
            }
          }
        }
        break;
    }

    return expectedCount;
  }
}
