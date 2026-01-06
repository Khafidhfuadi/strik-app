import 'dart:io';
import 'package:flutter/material.dart'; // Added for Colors in ImageCropper settings
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added for Realtime
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:strik_app/data/models/story_model.dart';
import 'package:strik_app/data/repositories/story_repository.dart';
import 'package:strik_app/data/repositories/friend_repository.dart'; // Added
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
      // Fetch Friends first to filter stories
      // We use a local instance of FriendRepository to avoid circular controller dependencies
      final friendRepo = FriendRepository(supabase);
      final friends = await friendRepo.getFriends();
      final friendIds = friends.map((f) => f.id).toList();

      // Fetch Active Stories (Filtered by friends)
      final active = await _repository.getActiveStories(friendIds: friendIds);
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
        await createStory(File(croppedFile.path));
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal memilih gambar: $e');
    }
  }

  Future<void> createStory(File file, {String? caption}) async {
    if (isUploading.value) return;
    isUploading.value = true;

    try {
      // 1. Image Processing (Crop) - Optional based on requirements
      // For stories, usually full screen, but let's assume raw or simple crop.
      // We can add ImageCropper here if needed.

      // 2. Compress Image (Aggressive)
      final File? compressedFile = await _compressImage(file);

      if (compressedFile == null) {
        throw Exception('Compression failed');
      }

      // 3. Upload
      final userId = supabase.auth.currentUser!.id;
      await _repository.uploadStory(compressedFile, userId, caption: caption);

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

  // Delete a story
  Future<void> deleteStory(StoryModel story) async {
    try {
      // Optimistic Update: Remove from list immediately
      activeStories.remove(story);
      myArchive.remove(story);

      await _repository.deleteStory(story.id, story.mediaUrl);
    } catch (e) {
      // Revert if failed (optional, but good UX)
      // For now just error
      Get.snackbar('Error', 'Failed to delete story');
    }
  }

  Future<void> sendReaction(String storyId, String type) async {
    await _repository.sendReaction(storyId, type);
  }

  Future<void> markAsViewed(String storyId) async {
    // 1. Optimistic Local Update
    // Wrap in microtask to avoid setState during build error if called from initState
    Future.microtask(() {
      final index = activeStories.indexWhere((s) => s.id == storyId);
      if (index != -1) {
        final story = activeStories[index];
        final currentUserId = supabase.auth.currentUser?.id;

        if (currentUserId != null && !story.viewers.contains(currentUserId)) {
          final updatedViewers = List<String>.from(story.viewers)
            ..add(currentUserId);

          final updatedStory = StoryModel(
            id: story.id,
            userId: story.userId,
            mediaUrl: story.mediaUrl,
            mediaType: story.mediaType,
            createdAt: story.createdAt,
            viewers: updatedViewers,
            user: story.user,
          );

          activeStories[index] = updatedStory;
          activeStories.refresh(); // Force GetX update
        }
      }
    });

    // 2. API Call
    await _repository.markAsViewed(storyId);
  }

  Future<List<Map<String, dynamic>>> getViewers(String storyId) async {
    return await _repository.getViewers(storyId);
  }

  Future<String?> getMyReaction(String storyId) async {
    return await _repository.getMyReaction(storyId);
  }
}
