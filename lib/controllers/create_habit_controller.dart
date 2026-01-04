import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/data/repositories/habit_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:strik_app/services/notification_service.dart';
import 'package:strik_app/core/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:strik_app/widgets/primary_button.dart';

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
    const Color(0xFF5EEAD4), // Pastel Teal
    const Color(0xFF93C5FD), // Pastel Blue
    const Color(0xFFFCA5A5), // Pastel Red
    const Color(0xFFFCD34D), // Pastel Amber
    const Color(0xFFF9A8D4), // Pastel Pink
    const Color(0xFFC4B5FD), // Pastel Purple
    const Color(0xFF6EE7B7), // Pastel Emerald
  ];
  var selectedColorIndex = 0.obs;
  var isPublic = true.obs;

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

  Future<void> setReminder(bool value) async {
    if (value) {
      final status = await Permission.notification.status;
      if (status.isGranted || status.isProvisional) {
        isReminder.value = true;
        if (reminderTime.value == null) {
          reminderTime.value = const TimeOfDay(hour: 9, minute: 0);
        }
      } else if (status.isDenied || status.isPermanentlyDenied) {
        // Show bottom sheet to ask for permission
        isReminder.value = false;
        _showPermissionBottomSheet();
      }
    } else {
      isReminder.value = false;
    }
  }

  void _showPermissionBottomSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Izin Notifikasi Dulu Dong! \u{1F514}',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Supaya Striks bisa ingetin kamu buat ngerjain habit, aktifin dulu ya izin notifikasinya.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Boleh, Aktifin!',
              onPressed: () async {
                Get.back(); // Close bottom sheet
                final status = await Permission.notification.request();
                if (status.isGranted) {
                  setReminder(true);
                } else if (status.isPermanentlyDenied) {
                  // Optional: Guide user to settings if permanently denied
                  openAppSettings();
                }
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Get.back(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Nanti Aja Deh',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
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
        'Isi nama kebiasaannya dulu dong coy!',
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
        isPublic: isPublic.value,
      );

      await _habitRepository.createHabit(habit);

      if (isReminder.value && reminderTime.value != null) {
        await NotificationService().scheduleDailyNotification(
          id: habit.hashCode, // Simple ID generation for now
          title: 'Waktunya ${titleController.text}!',
          body: 'Yuk semangat! Jangan lupa ${titleController.text} ya coy!',
          time: reminderTime.value!,
        );
      }

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
