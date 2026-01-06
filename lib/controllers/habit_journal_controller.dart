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

      final count = await _supabase
          .from('habit_journals')
          .count(CountOption.exact)
          .eq('habit_id', habitId);

      // Update eligibility based on total count in DB
      isEligibleForAI.value = count >= 10;

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

      Get.back(); // Close dialog/sheet
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
      Get.snackbar('Error', 'Gagal mengambil gambar: $e');
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
