class HabitJournal {
  final String? id;
  final String habitId;
  final String userId;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;

  HabitJournal({
    this.id,
    required this.habitId,
    required this.userId,
    required this.content,
    this.imageUrls = const [],
    required this.createdAt,
  });

  /// Backward-compatible getter: returns the first image URL or null.
  String? get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  /// Whether this journal has any attached images.
  bool get hasImages => imageUrls.isNotEmpty;

  factory HabitJournal.fromJson(Map<String, dynamic> json) {
    // Read from image_urls (array) first, fallback to image_url (legacy string)
    List<String> urls = [];
    if (json['image_urls'] != null && (json['image_urls'] as List).isNotEmpty) {
      urls = (json['image_urls'] as List).cast<String>();
    } else if (json['image_url'] != null) {
      urls = [json['image_url'] as String];
    }

    return HabitJournal(
      id: json['id'],
      habitId: json['habit_id'],
      userId: json['user_id'],
      content: json['content'],
      imageUrls: urls,
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'habit_id': habitId,
      'user_id': userId,
      'content': content,
      'image_urls': imageUrls,
      // Also write image_url for backward compat with old app versions
      'image_url': imageUrl,
      // created_at is handled by DB default or passed if needed
    };
  }
}
