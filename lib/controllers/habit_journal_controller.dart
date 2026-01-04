import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/data/models/habit_journal.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HabitJournalController extends GetxController {
  final String habitId;
  final SupabaseClient _supabase = Supabase.instance.client;

  var journals = <HabitJournal>[].obs;
  var isLoading = true.obs;
  var isLoadingMore = false.obs;
  var hasMore = true.obs;
  int _page = 0;
  final int _limit = 10;

  var todayJournal = Rxn<HabitJournal>();

  HabitJournalController(this.habitId);

  var aiInsight = ''.obs;
  var isGeneratingAI = false.obs;
  var aiQuotaUsed = 0.obs;
  var isEligibleForAI = false.obs;
  var isAiCardVisible = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchJournals(refresh: true);
    fetchAiQuota();
  }

  Future<void> fetchAiQuota() async {
    try {
      final now = DateTime.now();
      final period = "${now.year}-${now.month.toString().padLeft(2, '0')}";

      final response = await _supabase
          .from('habit_ai_insights')
          .select()
          .eq('habit_id', habitId)
          .eq('period', period);

      aiQuotaUsed.value = (response as List).length;

      // Check for existing insight for this month to display immediately?
      if (aiQuotaUsed.value > 0) {
        // Load the latest one

        // Better to sort by created_at desc
        (response as List).sort(
          (a, b) => DateTime.parse(
            b['created_at'],
          ).compareTo(DateTime.parse(a['created_at'])),
        );
        if (response.isNotEmpty) {
          aiInsight.value = response[0]['content'];
        }
      }
    } catch (e) {
      print('Error fetching AI quota: $e');
    }
  }

  void _checkAiEligibility() {
    // Check if we have >= 10 journals in CURRENT month or total?
    // User said "minimal 10 jurnal pada bulan tersebut atau kombinasi dari bulan sebelumnya"
    // "setiap bulannya hanya dapat men generate 2x".
    // Let's assume >= 10 total journals implies enough data for an insight.
    // Or specifically >= 10 in current month.
    // "AI container akan muncul jika terdapat minimal 10 jurnal pada bulan tersebut" -> strict month check.
    // "atau kombinasi dari bulan sebelumnya" -> loose check.
    // Let's go with Total Journals >= 10 for better UX, or confirm.
    // User phrase: "minimal 10 jurnal pada bulan tersebut atau kombinasi dari bulan sebelumnya"
    // This likely means "Total journals availability to analyze".
    // Let's use journals.length >= 10.
    isEligibleForAI.value = journals.length >= 10;
  }

  Future<void> fetchJournals({bool refresh = false}) async {
    try {
      if (refresh) {
        isLoading.value = true;
        _page = 0;
        hasMore.value = true;
        journals.clear();
      } else {
        if (!hasMore.value || isLoadingMore.value) return;
        isLoadingMore.value = true;
      }

      final start = _page * _limit;
      final end = start + _limit - 1;

      final response = await _supabase
          .from('habit_journals')
          .select()
          .eq('habit_id', habitId)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(start, end);

      final List<HabitJournal> newJournals = (response as List)
          .map((data) => HabitJournal.fromJson(data))
          .toList();

      if (newJournals.length < _limit) {
        hasMore.value = false;
      }

      journals.addAll(newJournals);
      _page++;

      _checkTodayJournal();
      if (refresh) {
        _checkAiEligibility();
      }
    } catch (e) {
      print('Error fetching journals: $e');
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  void _checkTodayJournal() {
    final now = DateTime.now();
    try {
      todayJournal.value = journals.firstWhere((journal) {
        final journalDate = journal.createdAt.toLocal();
        return journalDate.year == now.year &&
            journalDate.month == now.month &&
            journalDate.day == now.day;
      });
    } catch (e) {
      todayJournal.value = null; // No journal for today
    }
  }

  Future<void> addJournal(String content, {DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();

      // Check if journal exists for this date locally first
      final existingIndex = journals.indexWhere((j) {
        final jDate = j.createdAt.toLocal();
        return jDate.year == targetDate.year &&
            jDate.month == targetDate.month &&
            jDate.day == targetDate.day;
      });

      if (existingIndex != -1) {
        Get.snackbar(
          'Info',
          'Kamu sudah menulis jurnal pada hari ini',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final userId = _supabase.auth.currentUser!.id;

      // If date is provided (past date), we need to set created_at explicitly.
      // If it's today (default), we can let it or set it too.
      // Let's set it explicitly to be safe and accurate to the target date.
      // We'll set it to the current time component of that day if user wants,
      // or just noon to be safe for "day" representaiton?
      // Actually, if it's a past date "journal", usually we just want the date part to be correct.
      // Let's use the current time but on that target day, or just that target DateTime object.

      final response = await _supabase
          .from('habit_journals')
          .insert({
            'habit_id': habitId,
            'user_id': userId,
            'content': content,
            'created_at': targetDate.toUtc().toIso8601String(),
          })
          .select()
          .single();

      final newJournal = HabitJournal.fromJson(response);

      // Insert in correct order or just re-sort? Re-sorting is safer.
      journals.add(newJournal);
      journals.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _checkTodayJournal();

      Get.back(); // Close dialog/sheet
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal menyimpan jurnal: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> updateJournal(String id, String content) async {
    try {
      final response = await _supabase
          .from('habit_journals')
          .update({'content': content})
          .eq('id', id)
          .select()
          .single();

      final updatedJournal = HabitJournal.fromJson(response);
      final index = journals.indexWhere((j) => j.id == id);
      if (index != -1) {
        journals[index] = updatedJournal;
      }
      _checkTodayJournal();

      Get.back();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal update jurnal: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> deleteJournal(String id) async {
    try {
      await _supabase.from('habit_journals').delete().eq('id', id);
      journals.removeWhere((j) => j.id == id);
      _checkTodayJournal();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal hapus jurnal: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> generateAiInsight(
    String habitTitle,
    Map<String, dynamic> habitStats,
  ) async {
    if (aiQuotaUsed.value >= 3) {
      Get.snackbar(
        'Limit Tercapai',
        'Kamu cuma bisa generate 3x rekomendasi per bulan untuk habit ini.',
      );
      return;
    }

    try {
      isGeneratingAI.value = true;
      aiInsight.value = "";

      // 1. Prepare Data
      // Get last 10-20 journal entries text
      final recentJournals = journals
          .take(15)
          .map(
            (j) =>
                "- [${j.createdAt.year}-${j.createdAt.month}-${j.createdAt.day}]: ${j.content}",
          )
          .join('\n');

      final currentMonth = DateTime.now().month;
      final journalsThisMonth = journals
          .where((j) => j.createdAt.month == currentMonth)
          .length;

      // Fetch user profile for personalization (gender)
      String userGender = 'Unspecified';
      try {
        final userId = _supabase.auth.currentUser!.id;
        final profileData = await _supabase
            .from('profiles')
            .select('gender')
            .eq('id', userId)
            .maybeSingle();
        if (profileData != null && profileData['gender'] != null) {
          userGender = profileData['gender'];
        }
      } catch (e) {
        // Ignore profile fetch error, default to Unspecified
        print('Error fetching profile gender: $e');
      }

      final prompt =
          '''
      You are "Coach Strik", a Gen-Z motivational habit coach (Bahasa Indonesia).
      
      USER INFO:
      - Gender: $userGender 
      (If Laki-laki: call him "Bro", "Bang", or "Coy". If Perempuan: call her "Sis", "Kak", or "Bestie".)

      HABIT CONTEXT:
      - Habit: $habitTitle
      - Total Journals: ${journals.length}
      - Journals (This Month): $journalsThisMonth
      - Stats: ${jsonEncode(habitStats)}
      
      RECENT USER JOURNALS:
      $recentJournals
      
      INSTRUCTION:
      - Analyze the journals and stats.
      - Find patterns, mood, or blockers.
      - Give a HIGHLY DETAILED recommendation (2-3 paragraphs).
      - Style: Jaksel slang, empathetic but pushy, use emojis.
      - Structure:
        1. **Analisis Gue 🧐**: What you observe from their journals.
        2. **Saran Coach 💡**: Concrete improvement steps.
        3. **Challenge 🔥**: One specific action for tomorrow.
      - Speak DIRECTLY to the user ("Lo").
      - Use **bold** for key terms or section headers.
      ''';

      // 2. Call API
      final apiKey = dotenv.env['OPENROUTER_API_KEY'];
      if (apiKey == null) throw Exception('No OPENROUTER_API_KEY found');

      final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/Khafidhfuadi/strik-app',
          'X-Title': 'Strik App',
        },
        body: jsonEncode({
          "model": "google/gemma-3n-e2b-it:free",
          "messages": [
            {"role": "user", "content": prompt},
          ],
          "max_tokens": 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String? content = data['choices'][0]['message']['content'];
        if (content != null && content.isNotEmpty) {
          content = content.trim();
          aiInsight.value = content;

          // 3. Save to DB
          final now = DateTime.now();
          final period = "${now.year}-${now.month.toString().padLeft(2, '0')}";
          final userId = _supabase.auth.currentUser!.id;

          await _supabase.from('habit_ai_insights').insert({
            'habit_id': habitId,
            'user_id': userId,
            'content': content,
            'period': period,
          });

          aiQuotaUsed.value++;
        }
      } else {
        print("AI Error: ${response.body}");
        Get.snackbar('Error', 'Gagal menghubungi Coach AI. Coba lagi nanti.');
      }
    } catch (e) {
      Get.snackbar('Error', 'Terjadi kesalahan: $e');
    } finally {
      isGeneratingAI.value = false;
    }
  }
}
