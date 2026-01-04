import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdateProfileController extends GetxController {
  final usernameController = TextEditingController();
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final metadata = user.userMetadata;
      usernameController.text =
          metadata?['username'] ?? user.email?.split('@')[0] ?? '';
    }
  }

  @override
  void onClose() {
    usernameController.dispose();
    super.onClose();
  }

  Future<void> updateProfile() async {
    final newUsername = usernameController.text.trim();
    if (newUsername.isEmpty) {
      Get.snackbar('Error', 'Username gak boleh kosong coy!');
      return;
    }

    isLoading.value = true;
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      isLoading.value = false;
      return;
    }

    try {
      // 1. Update public profile
      await Supabase.instance.client
          .from('profiles')
          .update({
            'username': newUsername,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      // 2. Update auth metadata (for local UI consistency without refetching profile)
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'username': newUsername}),
      );

      Get.back(); // Close bottom sheet
      Get.snackbar('Sukses', 'Profil berhasil diupdate! 🎉');

      // Ideally, trigger a refresh in HomeController if it listens to this,
      // but Auth state change might propagate automatically or require manual UI rebuild.
      // For now, the Profile Bottom Sheet rebuilds when opened, so it should fetch fresh data.
    } catch (e) {
      Get.snackbar('Error', 'Gagal update profil: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
