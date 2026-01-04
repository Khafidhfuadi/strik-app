import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:strik_app/controllers/habit_controller.dart';
import 'package:strik_app/controllers/friend_controller.dart';

class HomeController extends GetxController {
  var selectedIndex = 0.obs;
  var currentTab = 'Harian'.obs;

  Future<void> logout() async {
    try {
      // 1. Delete all GetX controllers to clear cached data
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
