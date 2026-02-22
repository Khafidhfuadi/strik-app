import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/data/models/habit_journal.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:strik_app/controllers/gamification_controller.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/controllers/story_controller.dart';
import 'package:strik_app/controllers/habit_controller.dart';
import 'package:flutter/material.dart'; // For Colors

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

  // Focused Month for AI Context
  var focusedMonth = DateTime.now().obs;

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
    fetchMonthlyInsight();
    _checkMonthlyEligibility();
  }

  void updateFocusMonth(DateTime month) {
    focusedMonth.value = month;
    fetchMonthlyInsight();
    _checkMonthlyEligibility();
  }

  Future<void> _checkMonthlyEligibility() async {
    try {
      final month = focusedMonth.value;
      final startOfMonth = DateTime(
        month.year,
        month.month,
        1,
      ).toIso8601String();
      final endOfMonth = DateTime(
        month.year,
        month.month + 1,
        0,
        23,
        59,
        59,
      ).toIso8601String();

      final count = await _supabase
          .from('habit_journals')
          .count(CountOption.exact)
          .eq('habit_id', habitId)
          .gte('created_at', startOfMonth)
          .lte('created_at', endOfMonth);

      isEligibleForAI.value = count >= 10;
    } catch (e) {
      print('Error checking eligibility: $e');
      isEligibleForAI.value = false;
    }
  }

  Future<void> fetchMonthlyInsight() async {
    try {
      aiInsight.value = ''; // Reset first
      final month = focusedMonth.value;
      final period = "${month.year}-${month.month.toString().padLeft(2, '0')}";

      final response = await _supabase
          .from('habit_ai_insights')
          .select()
          .eq('habit_id', habitId)
          .eq('period', period)
          .order('created_at', ascending: false);

      // Quota is technically "insights generated this month".
      // But for historical view, we just want to know if *an insight* exists to show it.
      // If we want to allow re-generating historical months, we need to check if quota allows it.
      // The user requested: "selalu tampilkan riwayat... jika sudah pernah ter generate".

      // Let's count how many generated for this specific period
      final count = (response as List).length;
      aiQuotaUsed.value = count;

      if (response.isNotEmpty) {
        aiInsight.value = response[0]['content'];
      }
    } catch (e) {
      print('Error fetching AI insight: $e');
    }
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

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
      final endOfMonth = DateTime(
        now.year,
        now.month + 1,
        0,
        23,
        59,
        59,
      ).toIso8601String();

      await _supabase
          .from('habit_journals')
          .count(CountOption.exact)
          .eq('habit_id', habitId)
          .gte('created_at', startOfMonth)
          .lte('created_at', endOfMonth);

      // We still update eligibility here for the current list view,
      // but _checkMonthlyEligibility handles the specific month context.
      // To avoid conflict, let's trust _checkMonthlyEligibility which is called on init/month change.
      // isEligibleForAI.value = count >= 10;

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

      final existingIds = journals.map((j) => j.id).toSet();
      final uniqueJournals = newJournals
          .where((j) => !existingIds.contains(j.id))
          .toList();

      journals.addAll(uniqueJournals);
      _page++;

      _checkTodayJournal();
      // No need to call _checkAiEligibility again since we set it from DB count
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

  Future<void> addJournal(
    String content, {
    DateTime? date,
    File? imageFile,
  }) async {
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

      // Double-check from DB to prevent race condition (e.g. double-tap)
      final startOfDay = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      ).toUtc().toIso8601String();
      final endOfDay = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();

      final existingDb = await _supabase
          .from('habit_journals')
          .select('id')
          .eq('habit_id', habitId)
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay)
          .maybeSingle();

      if (existingDb != null) {
        Get.snackbar(
          'Info',
          'Kamu sudah menulis jurnal pada hari ini',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // 1. Fetch Habit to check if it represents a Challenge
      final habitResponse = await _supabase
          .from('habits')
          .select('*, challenge:habit_challenges(*)')
          .eq('id', habitId)
          .single();
      final habit = Habit.fromJson(habitResponse);

      // 2. Validation: Challenge requires image
      // Check if linked to a challenge
      if (habit.challengeId != null) {
        if (imageFile == null) {
          Get.snackbar(
            'Challenge Requirement',
            'Habit Challenge wajib menyertakan foto bukti! 📸',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
          );
          return;
        }
      }

      final userId = _supabase.auth.currentUser!.id;
      String? imageUrl;

      if (imageFile != null) {
        imageUrl = await uploadJournalImage(imageFile);
      }

      final response = await _supabase
          .from('habit_journals')
          .insert({
            'habit_id': habitId,
            'user_id': userId,
            'content': content,
            'image_url': imageUrl,
            'created_at': targetDate.toUtc().toIso8601String(),
          })
          .select()
          .single();

      final newJournal = HabitJournal.fromJson(response);

      // Insert in correct order or just re-sort? Re-sorting is safer.
      journals.add(newJournal);
      journals.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _checkTodayJournal();
      await clearDraft(targetDate);

      // 3. Auto-Momentz for Challenge
      if (habit.challengeId != null && imageFile != null) {
        print(
          '[Journal] challengeId=${habit.challengeId}, StoryController registered=${Get.isRegistered<StoryController>()}',
        );
        try {
          if (Get.isRegistered<StoryController>()) {
            final storyCtrl = Get.find<StoryController>();
            final caption =
                "Progres Habit Challenge '${habit.title}'\n$content";
            print('[Journal] Memanggil createStory...');
            await storyCtrl.createStory(imageFile, caption: caption);
            print('[Journal] createStory selesai.');
          } else {
            print(
              '[Journal] StoryController belum ter-register, skip auto-Momentz',
            );
          }
        } catch (e) {
          print('[Journal] Error auto-posting to Momentz: $e');
        }

        // Auto-complete the habit!
        try {
          if (Get.isRegistered<HabitController>()) {
            print('[Journal] Memanggil markHabitAsCompleted...');
            await Get.find<HabitController>().markHabitAsCompleted(habit);
            print('[Journal] markHabitAsCompleted selesai.');
          }
        } catch (e) {
          print('[Journal] Error auto-completing habit: $e');
        }
      }

      // Award XP for Journaling
      try {
        if (Get.isRegistered<GamificationController>()) {
          // Delay sedikit agar tidak bertubrukan dengan Popup XP Completed Habit
          Future.delayed(const Duration(milliseconds: 500), () async {
            await Get.find<GamificationController>().awardXPForInteraction(
              'journaling',
            );
          });
        }
      } catch (e) {
        print('Error awarding XP: $e');
      }

      if (habit.challengeId != null && imageFile != null) {
        // Jika ini post challenge -> otomatis close detail habit dan balik ke Feed utama
        Get.until((route) => route.settings.name == '/home' || route.isFirst);
      } else {
        Get.back(); // Close dialog/sheet jurnal biasa
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal menyimpan jurnal: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> updateJournal(
    String id,
    String content, {
    File? newImageFile,
  }) async {
    try {
      final updates = <String, dynamic>{'content': content};

      if (newImageFile != null) {
        final imageUrl = await uploadJournalImage(newImageFile);
        if (imageUrl != null) {
          updates['image_url'] = imageUrl;
        }
      }

      final response = await _supabase
          .from('habit_journals')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      final updatedJournal = HabitJournal.fromJson(response);
      final index = journals.indexWhere((j) => j.id == id);
      if (index != -1) {
        journals[index] = updatedJournal;
      }
      _checkTodayJournal();
      await clearDraft(updatedJournal.createdAt.toLocal());

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

  Future<File?> pickImage({required ImageSource source}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      // Get.snackbar('Error', 'Gagal mengambil gambar: $e');
      return null;
    }
  }

  Future<File?> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = p.join(
        dir.path,
        'journal_${DateTime.now().millisecondsSinceEpoch}.webp',
      );

      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: 1080,
        minHeight: 1920,
        quality: 70,
        format: CompressFormat.webp,
      );

      if (result == null) return null;
      return File(result.path);
    } catch (e) {
      print('Compression error: $e');
      return null;
    }
  }

  Future<String?> uploadJournalImage(File file) async {
    try {
      final compressedFile = await _compressImage(file);
      if (compressedFile == null) return null;

      final fileExt = p.extension(compressedFile.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final path = '$habitId/$fileName';

      await _supabase.storage
          .from('habit-journal-images')
          .upload(
            path,
            compressedFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final imageUrl = _supabase.storage
          .from('habit-journal-images')
          .getPublicUrl(path);

      return imageUrl;
    } catch (e) {
      print('Upload error: $e');
      // If bucket doesn't exist, we might get an error here.
      // Ideally we create it if not exists, but usually buckets are pre-created.
      return null;
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
      // Use focusedMonth instead of now()
      final month = focusedMonth.value;
      final startOfMonth = DateTime(
        month.year,
        month.month,
        1,
      ).toIso8601String();
      final endOfMonth = DateTime(
        month.year,
        month.month + 1,
        0,
        23,
        59,
        59,
      ).toIso8601String();

      final journalResponse = await _supabase
          .from('habit_journals')
          .select()
          .eq('habit_id', habitId)
          .gte('created_at', startOfMonth)
          .lte('created_at', endOfMonth)
          .order('created_at', ascending: true);

      final monthJournals = (journalResponse as List)
          .map((data) => HabitJournal.fromJson(data))
          .toList();

      final recentJournals = monthJournals
          .map((j) {
            final d = j.createdAt.toLocal();
            return "- [${d.year}-${d.month}-${d.day}]: ${j.content}";
          })
          .join('\n');

      final journalsThisMonth = monthJournals.length;

      // Fetch user profile for personalization (gender & name)
      String userGender = 'Unspecified';
      String userName = 'Teman'; // Default fallback
      try {
        final userId = _supabase.auth.currentUser!.id;
        final profileData = await _supabase
            .from('profiles')
            .select('gender, username') // Fetch username too
            .eq('id', userId)
            .maybeSingle();
        if (profileData != null) {
          if (profileData['gender'] != null) {
            userGender = profileData['gender'];
          }
          if (profileData['username'] != null &&
              profileData['username'].toString().isNotEmpty) {
            userName = profileData['username'];
          }
        }
      } catch (e) {
        print("Error fetching profile: $e");
      }

      final prompt =
          '''
      Kamu adalah 'Coach Strik', AI habit coach pribadi di aplikasi Strik.
      Tugas kamu adalah menganalisis jurnal habit user untuk BULAN ${month.year}-${month.month} dan memberikan insight yang personal, suportif, dan actionable.

      Disclaimer: Jangan pernah menggunakan kata "gue", "lo", "anda". Gunakan "Aku" (sebagai Coach) dan "Kamu".
      Panggil user dengan namanya: "$userName".

      Data User:
      - Nama: $userName
      - Gender: $userGender
      - Habit: $habitTitle
      - Statistik Bulan Ini: ${jsonEncode(habitStats)}
      - Jumlah Jurnal Bulan Ini: $journalsThisMonth
      - Isi Jurnal (Format: [Tahun-Bulan-Tanggal]: Isi):
      $recentJournals
      
      PERSONALITY & TONE (Critical):
      - If Gender is "Perempuan": Make the tone EXCITING, WARM, DEEP, and REFLECTIVE. It should feel like a late-night "deeptalk" with a caring best friend. Focus on emotional support and inner growth. Call her calling name.
      - If Gender is "Laki-laki" (or Unspecified): Make the tone EXCITING, ENERGETIC, BOLD, and STRAIGHTFORWARD. Push him like a gym coach. Call his calling name.
      
      INSTRUCTION:
      - Analyze the journals and stats to find specific patterns or blockers.
      - Write a FLUID, DYNAMIC response. DO NOT use rigid headers like "Analisis", "Saran", or "Challenge".
      - Start by referencing specific details from their recent journals (context is key!).
      - Weave your analysis and advice into a natural conversation.
      - Only suggest a specific CHALLENGE if strictly relevant (e.g. if they are stuck). Otherwise, focus on support.
      - Style: Jaksel slang (Gen Z). FOLLOW THE PERSONALITY & TONE GUIDELINES ABOVE. Use emojis.
      - IMPORTANT: Do NOT use "gue" or "lo". Use "Aku" (as Coach) and "Kamu".
      - Do NOT ask questions or ask for feedback. This is a final insight/wrap-up.
      - Speak DIRECTLY to the user.
      - Use **bold** to highlight key points or calls to action.
      ''';

      // 2. Call API
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": prompt},
              ],
            },
          ],
          "generationConfig": {"maxOutputTokens": 2048},
          "safetySettings": [
            {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
            {
              "category": "HARM_CATEGORY_HATE_SPEECH",
              "threshold": "BLOCK_NONE",
            },
            {
              "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
              "threshold": "BLOCK_NONE",
            },
            {
              "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
              "threshold": "BLOCK_NONE",
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String? content;

        try {
          content = data['candidates'][0]['content']['parts'][0]['text'];
        } catch (e) {
          content = null;
        }
        if (content != null && content.isNotEmpty) {
          content = content.trim();
          // Remove thinking block if deepseek-r1 outputs it on other platforms, though we're moving to gemini
          if (content.contains('</think>')) {
            content = content.split('</think>').last.trim();
          }
          aiInsight.value = content;

          // 3. Save to DB
          final period =
              "${month.year}-${month.month.toString().padLeft(2, '0')}";
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
        print("AI Error: ${response.statusCode} - ${response.body}");
        Get.snackbar('Error', 'Gagal menghubungi Coach AI. Coba lagi nanti.');
      }
    } catch (e) {
      Get.snackbar('Error', 'Terjadi kesalahan: $e');
    } finally {
      isGeneratingAI.value = false;
    }
  }

  // --- Drafting System ---

  String _getDraftKey(DateTime date) {
    final dateStr = "${date.year}-${date.month}-${date.day}";
    return "journal_draft_${habitId}_$dateStr";
  }

  Future<void> saveDraft(String content, DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getDraftKey(date);
      if (content.trim().isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, content);
      }
    } catch (e) {
      print("Error saving draft: $e");
    }
  }

  Future<String?> getDraft(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_getDraftKey(date));
    } catch (e) {
      print("Error getting draft: $e");
      return null;
    }
  }

  Future<void> clearDraft(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getDraftKey(date));
    } catch (e) {
      print("Error clearing draft: $e");
    }
  }
}
