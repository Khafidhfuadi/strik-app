import 'dart:io';
import 'package:flutter/material.dart'; // Added for Colors in ImageCropper settings
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added for Realtime
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:strik_app/data/models/story_model.dart';
import 'package:strik_app/data/repositories/story_repository.dart';
import 'package:strik_app/main.dart';
import 'package:path/path.dart' as p;
import 'package:image_cropper/image_cropper.dart'; // Added
import 'package:strik_app/core/theme.dart'; // Needed for AppTheme

class StoryController extends GetxController {
  final StoryRepository _repository = StoryRepository(supabase);
  final ImagePicker _picker = ImagePicker();

  var activeStories = <StoryModel>[].obs;
  var myArchive = <StoryModel>[].obs;

  var isLoading = false.obs;
  var isUploading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchStories();
    _subscribeToStories();
  }

  @override
  void onClose() {
    supabase.removeAllChannels();
    super.onClose();
  }

  void _subscribeToStories() {
    supabase
        .channel('public:stories')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'stories',
          callback: (payload) {
            // Simple approach: Refetch all when any new story is added.
            // Optimizations can include adding the payload directly if it matches criteria.
            print('New story detected! Refetching...');
            fetchStories();
          },
        )
        .subscribe();
  }

  // Fetch both active (feed) and archive
  Future<void> fetchStories() async {
    try {
      // isLoading.value = true; // Don't show global loading for background refresh
      // Fetch Active Stories (Global for now, simpler)
      final active = await _repository.getActiveStories();
      activeStories.assignAll(
        active,
      ); // Use assignAll for better GetX reactivity

      // Toggle this off after debugging
      // Get.snackbar('Debug', 'Loaded ${active.length} active stories');

      // Fetch My Archive
      final archive = await _repository.getMyArchive();
      myArchive.assignAll(archive);
    } catch (e) {
      print('Error fetching stories in controller: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Group active stories by User
  Map<String, List<StoryModel>> get groupedStories {
    final Map<String, List<StoryModel>> grouped = {};
    for (var story in activeStories) {
      if (grouped.containsKey(story.userId)) {
        grouped[story.userId]!.add(story);
      } else {
        grouped[story.userId] = [story];
      }
    }
    return grouped;
  }

  Future<void> pickAndUploadStory() async {
    try {
      // 1. Pick Image
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      // 1b. Crop Image (Square 1:1)
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Story',
            toolbarColor: AppTheme.primary,
            toolbarWidgetColor: Colors.black,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Story',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        await uploadStoryFile(File(croppedFile.path));
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal memilih gambar: $e');
    }
  }

  Future<void> uploadStoryFile(File file) async {
    try {
      isUploading.value = true;
      Get.snackbar(
        'Uploading',
        'Sedang mengupload story...',
        showProgressIndicator: true,
      );

      // 2. Compress Image (Aggressive)
      final File? compressedFile = await _compressImage(file);

      if (compressedFile == null) {
        throw Exception('Compression failed');
      }

      // 3. Upload
      final userId = supabase.auth.currentUser!.id;
      await _repository.uploadStory(compressedFile, userId);

      Get.back(); // Close snackbar
      Get.snackbar('Success', 'Story berhasil diupload!');

      // Refresh
      fetchStories();
    } catch (e) {
      Get.snackbar('Error', 'Gagal upload story: $e');
    } finally {
      isUploading.value = false;
    }
  }

  Future<File?> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = p.join(
        dir.path,
        'story_${DateTime.now().millisecondsSinceEpoch}.webp',
      );

      // 1080px width target, 65% quality WebP
      // This usually results in 50-100KB for normal photos
      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: 1080,
        minHeight: 1920,
        quality: 65,
        format: CompressFormat.webp,
      );

      if (result == null) return null;
      return File(result.path);
    } catch (e) {
      print('Compression error: $e');
      return null;
    }
  }

  Future<void> deleteStory(StoryModel story) async {
    try {
      await _repository.deleteStory(story.id, story.mediaUrl);
      activeStories.removeWhere((s) => s.id == story.id);
      myArchive.removeWhere((s) => s.id == story.id);
      Get.back();
      Get.snackbar('Deleted', 'Story dihapus');
    } catch (e) {
      Get.snackbar('Error', 'Gagal hapus story');
    }
  }
}
