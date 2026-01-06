class HabitJournal {
  final String? id;
  final String habitId;
  final String userId;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;

  HabitJournal({
    this.id,
    required this.habitId,
    required this.userId,
    required this.content,
    this.imageUrl,
    required this.createdAt,
  });

  factory HabitJournal.fromJson(Map<String, dynamic> json) {
    return HabitJournal(
      id: json['id'],
      habitId: json['habit_id'],
      userId: json['user_id'],
      content: json['content'],
      imageUrl: json['image_url'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'habit_id': habitId,
      'user_id': userId,
      'content': content,
      'image_url': imageUrl,
      // created_at is handled by DB default or passed if needed
    };
  }
}
