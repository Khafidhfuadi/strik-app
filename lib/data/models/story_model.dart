import 'package:strik_app/data/models/user_model.dart';
// import 'package:timeago/timeago.dart' as timeago; // Unused

class StoryModel {
  final String id;
  final String userId;
  final String mediaUrl;
  final String mediaType;
  final DateTime createdAt;
  final List<String> viewers;
  final UserModel? user;
  final String? caption;

  StoryModel({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.viewers,
    this.user,
    this.caption,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    final uniqueViewers = ((json['story_views'] as List?) ?? [])
        .map((e) => e['viewer_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    return StoryModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      mediaUrl: json['media_url'] ?? '',
      mediaType: json['media_type'] ?? 'image',
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      viewers: uniqueViewers,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      caption: json['caption'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'created_at': createdAt.toIso8601String(),
      'viewers': viewers,
      'caption': caption,
    };
  }

  // Helper to check if expired (e.g. for robust client checks)
  bool get isExpired {
    return DateTime.now().difference(createdAt).inHours >= 24;
  }

  int get uniqueViewerCount => viewers.toSet().length;
}
