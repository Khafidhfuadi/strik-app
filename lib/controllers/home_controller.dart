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

      // Sanitization for verbose TimezoneInfo strings (e.g. "TimezoneInfo(Asia/Jakarta, ...)")
      if (timeZoneString.contains('TimezoneInfo')) {
        final regex = RegExp(r'([a-zA-Z]+/[a-zA-Z_]+)');
        final match = regex.firstMatch(timeZoneString);
        if (match != null && match.group(1) != null) {
          timeZoneString = match.group(1)!;
        }
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
