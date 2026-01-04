import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class UpdateProfileController extends GetxController {
  final usernameController = TextEditingController();
  var isLoading = false.obs;
  var selectedImage = Rxn<File>();
  final ImagePicker _picker = ImagePicker();

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

  Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        selectedImage.value = File(image.path);
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal pilih gambar: $e');
    }
  }

  Future<String?> uploadAvatar() async {
    if (selectedImage.value == null) return null;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    try {
      final fileName = 'avatar.jpg';
      final filePath = '${user.id}/$fileName';

      // Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from('avatars')
          .upload(
            filePath,
            selectedImage.value!,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true, // Replace if exists
            ),
          );

      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      Get.snackbar('Error', 'Gagal upload avatar: $e');
      return null;
    }
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
      String? avatarUrl;

      // 1. Upload avatar if selected
      if (selectedImage.value != null) {
        avatarUrl = await uploadAvatar();
        if (avatarUrl == null) {
          isLoading.value = false;
          return; // Upload failed
        }
      }

      // 2. Prepare update data
      final Map<String, dynamic> profileUpdate = {
        'username': newUsername,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final Map<String, dynamic> metadataUpdate = {'username': newUsername};

      if (avatarUrl != null) {
        profileUpdate['avatar_url'] = avatarUrl;
        metadataUpdate['avatar_url'] = avatarUrl;
      }

      // 3. Update public profile
      await Supabase.instance.client
          .from('profiles')
          .update(profileUpdate)
          .eq('id', user.id);

      // 4. Update auth metadata
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: metadataUpdate),
      );

      Get.back(); // Close bottom sheet
      Get.snackbar('Sukses', 'Profil berhasil diupdate! 🎉');
    } catch (e) {
      Get.snackbar('Error', 'Gagal update profil: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
