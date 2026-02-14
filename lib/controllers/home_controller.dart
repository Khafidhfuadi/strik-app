import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:strik_app/controllers/habit_controller.dart';
import 'package:strik_app/controllers/friend_controller.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:strik_app/services/alarm_manager_service.dart';

class HomeController extends GetxController {
  var selectedIndex = 0.obs;
  var currentTab = 'Harian'.obs;

  @override
  void onInit() {
    super.onInit();
    _syncTimezone();
  }

  Future<void> _syncTimezone() async {
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      String timeZoneString = timeZoneName.toString();

      // Sanitization for verbose TimezoneInfo strings
      if (timeZoneString.contains('TimezoneInfo') ||
          timeZoneString.contains('Output')) {
        final regex = RegExp(r'([A-Za-z]+/[A-Za-z_]+)');
        final match = regex.firstMatch(timeZoneString);
        if (match != null) {
          timeZoneString = match.group(1)!;
        }
      }

      // Strict validation: Must contain '/' and NOT contain 'TimezoneInfo'
      // Valid IANA timezones are like "Asia/Jakarta", "America/New_York"
      bool isValid =
          timeZoneString.contains('/') &&
          !timeZoneString.contains('TimezoneInfo') &&
          !timeZoneString.contains(' ');

      if (!isValid) {
        print(
          'Invalid timezone format detected: "$timeZoneName". Skipping update.',
        );
        return;
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'timezone': timeZoneString})
            .eq('id', user.id);
      }
    } catch (e) {
      print('Failed to sync timezone: $e');
    }
  }

  Future<void> logout() async {
    try {
      // 1. Delete all GetX controllers to clear cached data
      try {
        await AlarmManagerService.instance.cancelAllAlarms();
      } catch (e) {
        print('Error canceling alarms: $e');
      }

      Get.delete<HabitController>(force: true);
      Get.delete<HomeController>(force: true);
      Get.delete<FriendController>(force: true);

      // 2. Sign out from Supabase
      await Supabase.instance.client.auth.signOut();

      // Note: AuthGate will handle navigation back to login screen
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal logout: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
