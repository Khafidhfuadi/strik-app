import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/data/models/story_model.dart';
import 'package:path/path.dart' as p;

class StoryRepository {
  final SupabaseClient _supabase;

  StoryRepository(this._supabase);

  // Fetch all active stories (created in last 24h)
  // Optionally filter by userIds if provided (for friends only)
  Future<List<StoryModel>> getActiveStories({List<String>? friendIds}) async {
    try {
      // 1. Select and Time Filter
      final isoDate = DateTime.now()
          .subtract(const Duration(hours: 24))
          .toUtc()
          .toIso8601String();

      var builder = _supabase
          .from('stories')
          .select('*, user:profiles(*), story_views(viewer_id)')
          .gt('created_at', isoDate);

      print('DEBUG: Fetching active stories gt than $isoDate');

      // 2. Friend Filter
      if (friendIds != null) {
        final visibleIds = [...friendIds, _supabase.auth.currentUser!.id];
        builder = builder.filter('user_id', 'in', '(${visibleIds.join(',')})');
      }

      // 3. Order and Execute
      final List<dynamic> response = await builder.order(
        'created_at',
        ascending: false,
      );

      print('DEBUG: Fetched ${response.length} stories');
      return response.map((json) => StoryModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching stories: $e');
      return [];
    }
  }

  // Fetch ONLY my archived stories (active and expired)
  Future<List<StoryModel>> getMyArchive({int limit = 20}) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final List<dynamic> response = await _supabase
          .from('stories')
          .select('*, user:profiles(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map((json) => StoryModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching archive: $e');
      return [];
    }
  }

  // Upload Story
  // 1. Upload to Storage
  // 2. Insert to DB
  Future<void> uploadStory(
    File processedImage,
    String userId, {
    String? caption,
  }) async {
    try {
      final fileExt = p.extension(processedImage.path);
      // Create a unique filename: userID/timestamp.jpg
      final fileName =
          '$userId/${DateTime.now().millisecondsSinceEpoch}$fileExt';

      // 1. Upload to Supabase Storage
      await _supabase.storage
          .from('stories')
          .upload(
            fileName,
            processedImage,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/webp',
            ), // We assume WebP from controller
          );

      // Get Public URL
      final publicUrl = _supabase.storage
          .from('stories')
          .getPublicUrl(fileName);

      // 2. Insert into DB
      await _supabase.from('stories').insert({
        'user_id': userId,
        'media_url': publicUrl,
        'media_type': 'image', // Hardcoded for now
        'caption': caption,
      });
    } catch (e) {
      throw Exception('Failed to upload story: $e');
    }
  }

  Future<void> deleteStory(String storyId, String url) async {
    print("DELETING STORY (Repo): ID=$storyId, URL=$url");
    try {
      // 1. Delete from DB and check if it actually deleted something
      final deleted = await _supabase
          .from('stories')
          .delete()
          .eq('id', storyId)
          .select();
      print("DELETING STORY (Repo): Deleted Rows: ${deleted.length}");
      if (deleted.isEmpty) {
        print(
          "DELETING STORY (Repo): WARNING! No rows deleted. Check RLS Policies.",
        );
      } else {
        print("DELETING STORY (Repo): DB Record Deleted Successfully");
      }

      // 2. Delete from Storage (Extract path from URL)
      // URL: .../storage/v1/object/public/stories/userId/filename.webp
      // Path: userId/filename.webp

      // Heuristic to extract path: parts after 'stories/'
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      final storiesIndex = pathSegments.indexOf('stories');
      if (storiesIndex != -1 && storiesIndex + 1 < pathSegments.length) {
        final storagePath = pathSegments.sublist(storiesIndex + 1).join('/');
        print("DELETING STORY (Repo): Extracted Path=$storagePath");
        await _supabase.storage.from('stories').remove([storagePath]);
        print("DELETING STORY (Repo): Storage File Removed");
      } else {
        print("DELETING STORY (Repo): Could not extract path from URL");
      }
    } catch (e) {
      print('Error deleting story: $e');
      rethrow;
    }
  }

  // Send reaction to a story
  Future<void> sendReaction(String storyId, String reactionType) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Send reaction.
    // If unique constraint exists, this handles it.
    // We should probably catch error if they try again, or UI should prevent.
    try {
      await _supabase.from('reactions').insert({
        'user_id': user.id,
        'story_id': storyId,
        'type': reactionType,
      });
    } catch (e) {
      // Ignore if duplicate
      print('Reaction already sent or error: $e');
    }
  }

  Future<void> markAsViewed(String storyId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('story_views').insert({
        'story_id': storyId,
        'viewer_id': user.id,
      });
    } catch (e) {
      // Ignore unique violation (already viewed)
    }
  }

  // Get viewers for a story (Owner only)
  // Returns List of {user: Profile, reaction: Reaction?}
  Future<List<Map<String, dynamic>>> getViewers(String storyId) async {
    try {
      final response = await _supabase
          .from('story_views')
          .select('''
            *,
            viewer:profiles(*)
          ''')
          .eq('story_id', storyId)
          .order('created_at', ascending: false);

      // Fetch reactions for this story separately to merge
      final reactionsRes = await _supabase
          .from('reactions')
          .select('user_id, type')
          .eq('story_id', storyId);

      final Map<String, String> reactionMap = {
        for (var r in reactionsRes) r['user_id'] as String: r['type'] as String,
      };

      return (response as List).map((view) {
        final viewerId = view['viewer_id'];
        return {
          'user': view['viewer'], // Profile object
          'viewed_at': view['created_at'],
          'reaction': reactionMap[viewerId], // String? (e.g., '❤️')
        };
      }).toList();
    } catch (e) {
      print('Error fetching viewers: $e');
      return [];
    }
  }

  // Check if I have reacted (for UI state)
  Future<String?> getMyReaction(String storyId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final res = await _supabase
        .from('reactions')
        .select('type')
        .eq('story_id', storyId)
        .eq('user_id', user.id)
        .maybeSingle();

    return res?['type'] as String?;
  }
}
