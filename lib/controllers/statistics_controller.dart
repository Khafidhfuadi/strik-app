import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/data/repositories/habit_repository.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/utils/habit_utils.dart';

enum StatsFilter { weekly, monthly, yearly, allTime, custom }

class StatisticsController extends GetxController {
  final HabitRepository _habitRepository = HabitRepository();
  final List<StreamSubscription> _subscriptions = [];

  var habits = <Habit>[].obs;
  var allLogs = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  var isGeneratingAI = false.obs;

  // AI Quota
  var aiQuotaUsed = 0.obs;
  final int aiQuotaLimit = 10;

  // Filter State
  var selectedFilter = StatsFilter.weekly.obs;
  var customRange = Rx<DateTimeRange?>(null);

  // Global Stats (Filtered)
  var globalCompletionCount = 0.obs;
  var globalCompletionRate = 0.0.obs;

  // Map of habitId -> its specific logs (Filtered)
  var habitLogsMap = <String, List<Map<String, dynamic>>>{}.obs;

  // Displayed Range
  var displayedStart = DateTime.now().obs;
  var displayedEnd = DateTime.now().obs;

  // Heatmap Data: DateTime -> Intensity level (0-4) or count (Filtered)
  var overallHeatmap = <DateTime, int>{}.obs;

  // Chart Data: X (index) -> Value
  // We need metadata for labels (e.g., 'Mon', 'Jan').
  var chartData = <ChartDataPoint>[].obs;

  var topStreaks = <Map<String, dynamic>>[].obs;

  // New Insights (Filtered)
  var goldenHour = 'Belum ada data'.obs;
  var bestDay = 'Belum ada data'.obs;
  var aiInsight = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchData();
    _loadAiQuota();
    _subscribeToRealtimeUpdates();
  }

  Future<void> _loadAiQuota() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      final response = await Supabase.instance.client
          .from('user_ai_quotas')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) {
        // Create new quota record
        await Supabase.instance.client.from('user_ai_quotas').insert({
          'user_id': user.id,
          'count': 0,
          'month': currentMonth,
          'year': currentYear,
          'last_updated': now.toIso8601String(),
        });
        aiQuotaUsed.value = 0;
      } else {
        // Check if month changed
        if (response['month'] != currentMonth ||
            response['year'] != currentYear) {
          // Reset for new month
          await Supabase.instance.client
              .from('user_ai_quotas')
              .update({
                'count': 0,
                'month': currentMonth,
                'year': currentYear,
                'last_updated': now.toIso8601String(),
              })
              .eq('user_id', user.id);
          aiQuotaUsed.value = 0;
        } else {
          aiQuotaUsed.value = response['count'] as int;
        }
      }
    } catch (e) {
      print('Error loading AI quota: $e');
    }
  }

  Future<void> incrementAiQuota() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      aiQuotaUsed.value++;

      await Supabase.instance.client
          .from('user_ai_quotas')
          .update({
            'count': aiQuotaUsed.value,
            'last_updated': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id);
    } catch (e) {
      print('Error incrementing AI quota: $e');
    }
  }

  @override
  void onClose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.onClose();
  }

  void _subscribeToRealtimeUpdates() {
    _subscriptions.add(
      _habitRepository.subscribeToHabitLogs().listen(
        (event) {
          fetchData();
        },
        onError: (e) {
          // print('Stream error: $e');
        },
      ),
    );

    _subscriptions.add(
      _habitRepository.subscribeToHabits().listen(
        (event) {
          fetchData();
        },
        onError: (e) {
          // print('Stream error: $e');
        },
      ),
    );
  }

  void setFilter(StatsFilter filter) {
    selectedFilter.value = filter;
    _processData();
  }

  Future<void> updateHabitOrder() async {
    await _habitRepository.updateHabitOrder(habits);
  }

  void setCustomRange(DateTimeRange range) {
    customRange.value = range;
    selectedFilter.value = StatsFilter.custom;
    _processData();
  }

  Future<void> fetchData() async {
    try {
      if (habits.isEmpty) isLoading.value = true;

      final results = await Future.wait([
        _habitRepository.getHabits(),
        _habitRepository.getAllLogs(),
      ]);

      final newHabits = results[0] as List<Habit>;
      final newAllLogs = results[1] as List<Map<String, dynamic>>;

      // Only update habits if different to avoid flicker
      if (!_areHabitListsEqual(habits, newHabits)) {
        habits.assignAll(newHabits);
      }

      // Always update logs as they might have changed
      allLogs.value = newAllLogs;

      _processData();

      // Fetch latest AI insight
      _fetchLatestAiInsight();
    } catch (e) {
      Get.snackbar('Error', 'Gagal ambil data statistik: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchLatestAiInsight() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Fetch the LATEST insight, regardless of date.
      // Since we are replacing data, there should ideally be only one or we grab the last inserted.
      final response = await Supabase.instance.client
          .from('ai_coach_messages')
          .select('message')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        aiInsight.value = response['message'] as String;
      }
    } catch (e) {
      print('Error fetching latest insight: $e');
    }
  }

  bool _areHabitListsEqual(List<Habit> a, List<Habit> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].title != b[i].title) {
        return false;
      }
    }
    return true;
  }

  void _processData() {
    // 1. Determine Date Range based on Filter
    DateTime start;
    DateTime end = DateTime.now();
    // Normalize end to end of day
    end = DateTime(end.year, end.month, end.day, 23, 59, 59);

    switch (selectedFilter.value) {
      case StatsFilter.weekly:
        // Current Week (Mon-Sun)
        start = end.subtract(Duration(days: end.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case StatsFilter.monthly:
        // Current Month (1st - End)
        start = DateTime(end.year, end.month, 1);
        break;
      case StatsFilter.yearly:
        // Current Year (Jan 1st - End)
        start = DateTime(end.year, 1, 1);
        break;
      case StatsFilter.allTime:
        // Find earliest log date or default to a safe past date
        if (allLogs.isNotEmpty) {
          DateTime minDate = end;
          for (var l in allLogs) {
            final d = DateTime.parse(l['target_date']);
            if (d.isBefore(minDate)) minDate = d;
          }
          start = DateTime(minDate.year, minDate.month, minDate.day);
        } else {
          start = DateTime(2024); // Fallback
        }
        break;
      case StatsFilter.custom:
        if (customRange.value != null) {
          start = customRange.value!.start;
          end = customRange.value!.end.add(
            const Duration(hours: 23, minutes: 59, seconds: 59),
          );
        } else {
          // Fallback to weekly if null
          start = end.subtract(Duration(days: end.weekday - 1));
          start = DateTime(start.year, start.month, start.day);
        }
        break;
    }

    displayedStart.value = start;
    displayedEnd.value = end;

    // 2. Filter Logs
    final filteredLogs = allLogs.where((log) {
      final date = DateTime.parse(log['target_date'] as String);
      return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          date.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    // 3. Partition filtered logs by habit
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (var habit in habits) {
      map[habit.id!] = [];
    }

    final Map<DateTime, int> heatMapCounts = {};

    for (var log in filteredLogs) {
      final habitId = log['habit_id'];
      if (map.containsKey(habitId)) {
        map[habitId]!.add(log);
      }

      // Heatmap Data Processing
      if (log['status'] == 'completed') {
        final date = DateTime.parse(log['target_date'] as String);
        final normalizedDate = DateTime(date.year, date.month, date.day);
        heatMapCounts[normalizedDate] =
            (heatMapCounts[normalizedDate] ?? 0) + 1;
      }
    }
    habitLogsMap.value = map;

    // 4. Global Stats
    final completedLogs = filteredLogs
        .where((l) => l['status'] == 'completed')
        .toList();
    globalCompletionCount.value = completedLogs.length;

    // New Logic: Calculate Expected Count for Rate
    int totalExpected = 0;
    for (var habit in habits) {
      totalExpected += HabitUtils.calculateExpectedCount(habit, start, end);
    }

    // Ensure totalExpected is at least the number of completed logs
    // (to avoid rate > 100% if edge cases occur, e.g. extra logs)
    if (totalExpected < completedLogs.length) {
      totalExpected = completedLogs.length;
    }

    // Also consider skipped logs?
    // If strict completion: Rate = Completed / Expected.
    // If "Success Rate" where skip = excused?
    // User asked "missed a habit... percentage remains 100%".
    // This implies Rate = Completed / (Completed + Missed + Skipped) roughly.
    // Our Expected Count covers (Completed + Missed + Skipped).
    // So Rate = Completed / Expected.

    if (totalExpected > 0) {
      globalCompletionRate.value = (completedLogs.length / totalExpected) * 100;
      // Cap at 100% just in case
      if (globalCompletionRate.value > 100.0) {
        globalCompletionRate.value = 100.0;
      }
    } else {
      globalCompletionRate.value = 0.0;
    }

    // Keep skippedLogs for other uses if needed
    // final skippedLogs = filteredLogs
    //    .where((l) => l['status'] == 'skipped')
    //    .toList();

    // We used to calculate totalActioned here, but now we usage totalExpected for insights.

    // 5. Heatmap (Use filtered counts? Or Keep Heatmap 90 days fixed?
    // Usually Heatmap is fixed history. But "Keaktifan" could reflect filter.
    // Let's make heatmap reflect filter if possible, OR just keep it fixed 90 days for "GitHub style".
    // User asked for "statistik filter", implying filtering everything.
    // But Heatmap usually shows long term context.
    // Let's Update Heatmap to show the filtered range if it's longer than default,
    // or just show the filtered data points.
    overallHeatmap.value = heatMapCounts;

    // 6. Chart Data Generation
    _generateChartData(start, end, completedLogs);

    // 7. Top 3 Best Streaks Ranking (All-time context)
    _updateTopStreaks();

    // 8. Global Insights (Golden Hour & Best Day)
    _calculateGlobalInsights(filteredLogs);

    // 9. AI Advisor Logic (Manual Trigger Only)
    // _generateAIInsight(completedLogs, totalActioned);
  }

  void generateManualInsight() {
    final start = displayedStart.value;
    final end = displayedEnd.value;

    final filteredLogs = allLogs.where((log) {
      final date = DateTime.parse(log['target_date'] as String);
      return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          date.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    final completedLogs = filteredLogs
        .where((l) => l['status'] == 'completed')
        .toList();

    // Recalculate Expected for manual insight context
    int totalExpected = 0;
    for (var habit in habits) {
      totalExpected += HabitUtils.calculateExpectedCount(habit, start, end);
    }
    if (totalExpected < completedLogs.length) {
      totalExpected = completedLogs.length;
    }

    _generateAIInsight(completedLogs, totalExpected);
  }

  void _generateAIInsight(
    List<Map<String, dynamic>> completedLogs,
    int totalActioned,
  ) {
    if (habits.isEmpty) {
      aiInsight.value =
          "Yuk mulai bikin habit dulu biar gue bisa kasih saran kece! 🌱";
      return;
    }

    // Check Quota
    if (aiQuotaUsed.value >= aiQuotaLimit) {
      aiInsight.value =
          "Kuota Coach Strik abis nih bulan ini (Maks 10x). Balik lagi bulan depan ya! 📅❌";
      return;
    }

    // Try Gemini First
    // Try OpenRouter AI First
    final apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      _fetchGeminiInsight(completedLogs, totalActioned).catchError((e) {
        // Handle error gracefully - maybe show error message in insight
        aiInsight.value =
            "Maaf, Coach Strik lagi pusing (Error AI). Coba lagi nanti ya! 😵‍💫";
        isGeneratingAI.value = false;
      });
    } else {
      // No key
      aiInsight.value =
          "Kunci API belum disetting nih. Coach Strik nggak bisa mikir! 🔑❌";
    }
  }

  Future<void> _fetchGeminiInsight(
    List<Map<String, dynamic>> completedLogs,
    int totalActioned,
  ) async {
    try {
      aiInsight.value = "";
      isGeneratingAI.value = true;
      // aiInsight.value = "Lagi nanya Coach Strik... 🤖💭"; // Removed, handled by UI state

      final rate = globalCompletionRate.value;

      // Prepare Data Summary
      Map<String, int> habitCounts = {};
      for (var log in completedLogs) {
        habitCounts[log['habit_id']] = (habitCounts[log['habit_id']] ?? 0) + 1;
      }

      String topHabit = "-";
      String worstHabit = "-";
      int maxCount = -1;
      int minCount = 999999;

      for (var habit in habits) {
        int count = habitCounts[habit.id] ?? 0;
        if (count > maxCount) {
          maxCount = count;
          topHabit = habit.title;
        }
        if (count < minCount) {
          minCount = count;
          worstHabit = habit.title;
        }
      }

      String vibeInstruction;
      if (rate >= 80) {
        vibeInstruction =
            "Praise them like a proud coy. Use words like 'Gacor', 'Gokil', 'Gila', etc.";
      } else if (rate >= 50) {
        vibeInstruction =
            "Give a gentle encouragement. Tell them they are doing okay but can do better.";
      } else {
        vibeInstruction =
            "Give a gentle roast + motivation. Tell them to wake up and grind more.";
      }

      final prompt =
          '''
      You are "Coach Strik", a Gen-Z motivational habit coach (Bahasa Indonesia).
      
      STATS:
      - Rate: ${rate.toStringAsFixed(1)}%
      - Top: $topHabit
      - Worst: $worstHabit
      - Golden Hour: ${goldenHour.value}
      
      INSTRUCTION:
      - Give a short, punchy comment (max 2 sentences).
      - Style: Jaksel slang, emojis, energetic.
      - GOAL: $vibeInstruction
      - NO lists. NO "Here is your insight". NO quotes around the response. NO reasoning output. just the final response text.
      - Speak DIRECTLY to the user.
      ''';

      final apiKey = dotenv.env['OPENROUTER_API_KEY'];
      if (apiKey == null) throw Exception('No OPENROUTER_API_KEY found');

      final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer':
              'https://github.com/Khafidhfuadi/strik-app', // Optional: Your site URL
          'X-Title': 'Strik App', // Optional: Your site name
        },
        body: jsonEncode({
          "model": "deepseek/deepseek-r1-0528:free",
          "messages": [
            {"role": "user", "content": prompt},
          ],
          "max_tokens": 512,
          "stream": false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String? content = data['choices'][0]['message']['content'];
        if (content != null && content.isNotEmpty) {
          // Cleanup potential garbage formatting
          content = content.trim();
          // Remove wrapping quotes if present
          if (content.startsWith('"') && content.endsWith('"')) {
            content = content.substring(1, content.length - 1);
          }
          aiInsight.value = content;
          _saveAiInsight(content);
          incrementAiQuota();
          incrementAiQuota();
        } else {
          aiInsight.value = "Coach Strik lagi bengong. Coba lagi ya! 😶";
        }
      } else {
        print("OpenRouter API Error: ${response.body}");
        aiInsight.value =
            "Coach Strik lagi error nih. Cek koneksi atau kuota API! ⚠️";
      }
    } catch (e) {
      print("OpenRouter Critical Error: $e");
      aiInsight.value = "Ada masalah teknis di otak Coach Strik. 🤯";
    } finally {
      isGeneratingAI.value = false;
    }
  }

  Future<void> _saveAiInsight(String message) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Replace logic: Delete existing messages for this user first
      await Supabase.instance.client
          .from('ai_coach_messages')
          .delete()
          .eq('user_id', user.id);

      // Insert new message
      await Supabase.instance.client.from('ai_coach_messages').insert({
        'user_id': user.id,
        'message': message,
        'date': DateTime.now().toIso8601String().split('T')[0],
      });
    } catch (e) {
      print('Error saving AI insight: $e');
    }
  }

  void _calculateGlobalInsights(List<Map<String, dynamic>> filteredLogs) {
    if (filteredLogs.isEmpty) {
      goldenHour.value = 'Belum ada data';
      bestDay.value = 'Belum ada data';
      return;
    }

    // 1. Golden Hour (Based on completed_at)
    final completedWithTime = filteredLogs
        .where((l) => l['status'] == 'completed' && l['completed_at'] != null)
        .toList();

    if (completedWithTime.isNotEmpty) {
      final hourCounts = <int, int>{};
      for (var log in completedWithTime) {
        final dt = DateTime.parse(log['completed_at']).toLocal();
        final hour = dt.hour;
        hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
      }

      var maxHour = 0;
      var maxCount = 0;
      hourCounts.forEach((hour, count) {
        if (count > maxCount) {
          maxCount = count;
          maxHour = hour;
        }
      });

      final hourStr = maxHour.toString().padLeft(2, '0');
      final nextHourStr = ((maxHour + 1) % 24).toString().padLeft(2, '0');
      goldenHour.value = '$hourStr:00 - $nextHourStr:00';
    } else {
      goldenHour.value = '-';
    }

    // 2. Best Day (Based on target_date)
    final completedLogs = filteredLogs.where((l) => l['status'] == 'completed');
    if (completedLogs.isNotEmpty) {
      final dayCounts = <int, int>{}; // 1 (Mon) - 7 (Sun)
      for (var log in completedLogs) {
        final dt = DateTime.parse(log['target_date']);
        final day = dt.weekday;
        dayCounts[day] = (dayCounts[day] ?? 0) + 1;
      }

      var maxDay = 1;
      var maxDayCount = 0;
      dayCounts.forEach((day, count) {
        if (count > maxDayCount) {
          maxDayCount = count;
          maxDay = day;
        }
      });

      const days = [
        'Senin',
        'Selasa',
        'Rabu',
        'Kamis',
        'Jumat',
        'Sabtu',
        'Minggu',
      ];
      bestDay.value = days[maxDay - 1];
    } else {
      bestDay.value = '-';
    }
  }

  void _updateTopStreaks() {
    List<Map<String, dynamic>> rankings = [];

    for (var habit in habits) {
      final habitLogs = allLogs
          .where((l) => l['habit_id'] == habit.id && l['status'] == 'completed')
          .toList();

      final currentStreak = _calculateStreak(habitLogs);
      if (currentStreak > 0) {
        rankings.add({'habit': habit, 'streak': currentStreak});
      }
    }

    rankings.sort((a, b) => (b['streak'] as int).compareTo(a['streak'] as int));
    topStreaks.value = rankings.take(3).toList();
  }

  int _calculateBestStreak(List<Map<String, dynamic>> completedLogs) {
    if (completedLogs.isEmpty) return 0;

    final dates =
        completedLogs
            .map((l) => DateTime.parse(l['target_date']))
            .map((d) => DateTime(d.year, d.month, d.day))
            .toSet()
            .toList()
          ..sort((a, b) => a.compareTo(b));

    int maxStreak = 0;
    int currentStreak = 0;

    for (int i = 0; i < dates.length; i++) {
      if (i == 0) {
        currentStreak = 1;
      } else {
        if (dates[i].difference(dates[i - 1]).inDays == 1) {
          currentStreak++;
        } else {
          if (currentStreak > maxStreak) maxStreak = currentStreak;
          currentStreak = 1;
        }
      }
    }
    if (currentStreak > maxStreak) maxStreak = currentStreak;

    return maxStreak;
  }

  void _generateChartData(
    DateTime start,
    DateTime end,
    List<Map<String, dynamic>> logs,
  ) {
    List<ChartDataPoint> points = [];

    // For 'All Time' with range > 1 year or 'Yearly', use Monthly Aggregation
    // Check if range > 365 days for All Time/Custom
    final rangeDays = end.difference(start).inDays;

    if (selectedFilter.value == StatsFilter.yearly ||
        ((selectedFilter.value == StatsFilter.allTime ||
                selectedFilter.value == StatsFilter.custom) &&
            rangeDays > 90)) {
      // Aggregate by Month (Year-Month)
      // Map "YYYY-MM" -> count
      Map<String, int> monthlyCounts = {};

      // Generate all months in range first
      DateTime current = DateTime(start.year, start.month);
      List<DateTime> monthsList = [];
      while (current.isBefore(end) ||
          (current.year == end.year && current.month == end.month)) {
        monthsList.add(current);
        // next month
        if (current.month == 12) {
          current = DateTime(current.year + 1, 1);
        } else {
          current = DateTime(current.year, current.month + 1);
        }
      }
      monthsList.sort((a, b) => a.compareTo(b)); // Ensure sorted

      for (var log in logs) {
        final d = DateTime.parse(log['target_date']);
        final key = "${d.year}-${d.month}";
        monthlyCounts[key] = (monthlyCounts[key] ?? 0) + 1;
      }

      List<String> monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];

      for (int i = 0; i < monthsList.length; i++) {
        final m = monthsList[i];
        final key = "${m.year}-${m.month}";

        // Label: if multiple years, show 'Jan 24'. If single year view (yearly filter), show 'Jan'.
        String label;
        if (selectedFilter.value == StatsFilter.yearly &&
            start.year == end.year) {
          label = monthNames[m.month - 1]; // Just month
        } else {
          // For all time, 'Jan', 'Feb' might be ambiguous if 2023 and 2024 exist.
          // Let's shorten year: 'Jan 24'
          final y = m.year.toString().substring(2);
          label = "${monthNames[m.month - 1]} $y";
        }

        points.add(
          ChartDataPoint(
            x: i.toDouble(),
            y: (monthlyCounts[key] ?? 0).toDouble(),
            label: label,
          ),
        );
      }
    } else {
      // Daily Aggregation (Weekly, Monthly, Custom/AllTime < 90 days)
      final dayCount = end.difference(start).inDays + 1;

      // Map Date -> Count
      Map<DateTime, int> dailyCounts = {};
      for (var log in logs) {
        final d = DateTime.parse(log['target_date']);
        final normalized = DateTime(d.year, d.month, d.day);
        dailyCounts[normalized] = (dailyCounts[normalized] ?? 0) + 1;
      }

      for (int i = 0; i < dayCount; i++) {
        final date = start.add(Duration(days: i));
        final normalized = DateTime(date.year, date.month, date.day);

        String label = '';
        if (selectedFilter.value == StatsFilter.weekly) {
          const days = ['Sn', 'Sl', 'Rb', 'Km', 'Jm', 'Sb', 'Mn']; // Mon-Sun
          // weekday 1=Mon -> index 0 for array
          label = days[(date.weekday - 1) % 7];
        } else {
          // Include date for monthly/custom
          if (i % 5 == 0 || dayCount <= 7) {
            label = '${date.day}';
          }
        }

        points.add(
          ChartDataPoint(
            x: i.toDouble(),
            y: (dailyCounts[normalized] ?? 0).toDouble(),
            label: label,
          ),
        );
      }
    }

    chartData.value = points;
  }

  Map<String, dynamic> getStatsForHabit(String habitId) {
    // 1. Total for filtered period
    final filteredLogs = habitLogsMap[habitId] ?? [];
    final filteredCompleted = filteredLogs
        .where((l) => l['status'] == 'completed')
        .toList();
    final filteredSkipped = filteredLogs
        .where((l) => l['status'] == 'skipped')
        .toList();

    // 2. Streaks (from all logs, unfiltered)
    final habitAllLogs = allLogs
        .where((l) => l['habit_id'] == habitId && l['status'] == 'completed')
        .toList();

    final currentStreak = _calculateStreak(habitAllLogs);
    final bestStreak = _calculateBestStreak(habitAllLogs);

    return {
      'total': filteredCompleted.length,
      'skipped': filteredSkipped.length,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
    };
  }

  Map<DateTime, int> getHeatmapForHabit(String habitId) {
    if (!habitLogsMap.containsKey(habitId)) return {};
    final logs = habitLogsMap[habitId]!;
    final Map<DateTime, int> heat = {};
    for (var log in logs) {
      if (log['status'] == 'completed') {
        final date = DateTime.parse(log['target_date']);
        final normalized = DateTime(date.year, date.month, date.day);
        heat[normalized] = 1;
      }
    }
    return heat;
  }

  int _calculateStreak(List<Map<String, dynamic>> completedLogs) {
    if (completedLogs.isEmpty) return 0;

    final dates =
        completedLogs
            .map((l) => DateTime.parse(l['target_date']))
            .map((d) => DateTime(d.year, d.month, d.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    if (dates.isEmpty) return 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (dates.first.isBefore(todayDate.subtract(const Duration(days: 1)))) {
      return 0;
    }

    int streak = 1;
    for (int i = 0; i < dates.length - 1; i++) {
      if (dates[i].difference(dates[i + 1]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}

class ChartDataPoint {
  final double x;
  final double y;
  final String label;

  ChartDataPoint({required this.x, required this.y, required this.label});
}
