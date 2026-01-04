class HabitJournal {
  final String? id;
  final String habitId;
  final String userId;
  final String content;
  final DateTime createdAt;

  HabitJournal({
    this.id,
    required this.habitId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory HabitJournal.fromJson(Map<String, dynamic> json) {
    return HabitJournal(
      id: json['id'],
      habitId: json['habit_id'],
      userId: json['user_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'habit_id': habitId,
      'user_id': userId,
      'content': content,
      // created_at is handled by DB default or passed if needed
    };
  }
}
