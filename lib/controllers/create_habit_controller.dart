import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/data/repositories/habit_repository.dart';

class CreateHabitController extends GetxController {
  final HabitRepository _habitRepository = HabitRepository();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  var isRepeat = true.obs;
  var selectedFrequencyIndex = 0.obs;
  final frequencies = ['Tiap Hari', 'Mingguan', 'Bulanan'];

  final days = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];
  var selectedDays = <int>{0, 1, 2, 3, 4, 5, 6}.obs;

  var weeklyFrequency = 1.obs;
  var selectedMonthlyDates = <int>{}.obs;

  var isReminder = false.obs;
  var reminderTime = Rxn<TimeOfDay>();

  final List<Color> colors = [
    const Color(0xFF14B8A6), // Teal
    const Color(0xFF3B82F6), // Blue
    const Color(0xFFEF4444), // Red
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFEC4899), // Pink
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFF10B981), // Emerald
  ];
  var selectedColorIndex = 0.obs;

  var isLoading = false.obs;

  @override
  void onClose() {
    titleController.dispose();
    descriptionController.dispose();
    super.onClose();
  }

  void toggleDay(int index) {
    if (selectedDays.contains(index)) {
      selectedDays.remove(index);
    } else {
      selectedDays.add(index);
    }
  }

  void toggleMonthlyDate(int day) {
    if (selectedMonthlyDates.contains(day)) {
      selectedMonthlyDates.remove(day);
    } else {
      selectedMonthlyDates.add(day);
    }
  }

  void setReminder(bool value) {
    isReminder.value = value;
    if (value && reminderTime.value == null) {
      reminderTime.value = const TimeOfDay(hour: 9, minute: 0);
    }
  }

  Future<void> pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: reminderTime.value ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        // We can access theme from context or Get.theme potentially
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(
                0xFF10B981,
              ), // AppTheme.primary hardcoded or imported
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E), // AppTheme.surface
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      reminderTime.value = picked;
    }
  }

  Future<void> saveHabit() async {
    if (titleController.text.isEmpty) {
      Get.snackbar(
        'Oops',
        'Isi nama kebiasaannya dulu dong bestie!',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isLoading.value = true;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      String frequency;
      List<int>? daysOfWeek;
      int? frequencyCount;

      if (!isRepeat.value) {
        frequency = 'daily';
        daysOfWeek = [0, 1, 2, 3, 4, 5, 6];
      } else {
        final Map<int, String> frequencyMap = {
          0: 'daily',
          1: 'weekly',
          2: 'monthly',
        };
        frequency = frequencyMap[selectedFrequencyIndex.value] ?? 'daily';

        if (selectedFrequencyIndex.value == 0) {
          daysOfWeek = selectedDays.toList()..sort();
        } else if (selectedFrequencyIndex.value == 1) {
          frequencyCount = weeklyFrequency.value;
        } else if (selectedFrequencyIndex.value == 2) {
          daysOfWeek = selectedMonthlyDates.toList()..sort();
        }
      }

      final habit = Habit(
        userId: user.id,
        title: titleController.text,
        description: descriptionController.text.isNotEmpty
            ? descriptionController.text
            : null,
        color:
            '0x${colors[selectedColorIndex.value].toARGB32().toRadixString(16).toUpperCase()}',
        frequency: frequency,
        daysOfWeek: daysOfWeek,
        frequencyCount: frequencyCount,
        reminderTime: reminderTime.value,
        reminderEnabled: isReminder.value,
      );

      await _habitRepository.createHabit(habit);
      Get.back(); // Navigate back
    } catch (e) {
      Get.snackbar(
        'Error',
        'Yah error: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
