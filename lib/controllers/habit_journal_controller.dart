import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/data/models/habit_journal.dart';

class HabitJournalController extends GetxController {
  final String habitId;
  final SupabaseClient _supabase = Supabase.instance.client;

  var journals = <HabitJournal>[].obs;
  var isLoading = true.obs;
  var todayJournal = Rxn<HabitJournal>();

  HabitJournalController(this.habitId);

  @override
  void onInit() {
    super.onInit();
    fetchJournals();
  }

  Future<void> fetchJournals() async {
    try {
      isLoading.value = true;
      final response = await _supabase
          .from('habit_journals')
          .select()
          .eq('habit_id', habitId)
          .order('created_at', ascending: false)
          .limit(20); // Limit to recent journals for now

      final List<HabitJournal> loadedJournals = (response as List)
          .map((data) => HabitJournal.fromJson(data))
          .toList();

      journals.value = loadedJournals;
      _checkTodayJournal();
    } catch (e) {
      print('Error fetching journals: $e');
    } finally {
      isLoading.value = false;
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

  Future<void> addJournal(String content) async {
    try {
      if (todayJournal.value != null) {
        Get.snackbar(
          'Info',
          'Kamu sudah menulis jurnal hari ini',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('habit_journals')
          .insert({'habit_id': habitId, 'user_id': userId, 'content': content})
          .select()
          .single();

      final newJournal = HabitJournal.fromJson(response);
      journals.insert(0, newJournal);
      todayJournal.value = newJournal;

      Get.back(); // Close dialog/sheet
      Get.snackbar(
        'Sukses',
        'Jurnal berhasil disimpan!',
        snackPosition: SnackPosition.BOTTOM,
      );
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
      Get.snackbar(
        'Sukses',
        'Jurnal berhasil diupdate!',
        snackPosition: SnackPosition.BOTTOM,
      );
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
      Get.snackbar(
        'Sukses',
        'Jurnal dihapus',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal hapus jurnal: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
