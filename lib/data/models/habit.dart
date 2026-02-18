import 'package:flutter/material.dart';

class Habit {
  final String? id;
  final String userId;
  final String title;
  final String? description;
  final String color;
  final String frequency;
  final List<int>? daysOfWeek;
  final int? frequencyCount;
  final TimeOfDay? reminderTime;
  final bool reminderEnabled;
  final DateTime? createdAt;
  final DateTime? endDate;
  final bool isPublic;
  final int? sortOrder;
  final String? challengeId;

  Habit({
    this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.color,
    required this.frequency,
    this.daysOfWeek,
    this.frequencyCount,
    this.reminderTime,
    this.reminderEnabled = false,
    this.createdAt,
    this.endDate,
    this.isPublic = true,
    this.sortOrder,
    this.challengeId,
  });

  bool get isChallenge => challengeId != null;

  factory Habit.fromJson(Map<String, dynamic> json) {
    TimeOfDay? reminder;
    if (json['reminder_time'] != null) {
      final parts = (json['reminder_time'] as String).split(':');
      if (parts.length >= 2) {
        final now = DateTime.now();
        // Assume stored time is UTC
        final utcWithTime = DateTime.utc(
          now.year,
          now.month,
          now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        final localTime = utcWithTime.toLocal();
        reminder = TimeOfDay(hour: localTime.hour, minute: localTime.minute);
      }
    }

    return Habit(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      color: json['color'],
      frequency: json['frequency'],
      daysOfWeek: json['days_of_week'] != null
          ? List<int>.from(json['days_of_week'])
          : null,
      frequencyCount: json['frequency_count'],
      reminderTime: reminder,
      reminderEnabled: json['reminder_enabled'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date']).toLocal()
          : null,
      isPublic: json['is_public'] ?? true,
      sortOrder: json['sort_order'],
      challengeId: json['challenge_id'],
    );
  }

  Map<String, dynamic> toJson() {
    String? reminderString;
    if (reminderTime != null) {
      // Convert Local TimeOfDay to UTC string
      final now = DateTime.now();
      final localDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        reminderTime!.hour,
        reminderTime!.minute,
      );
      final utcDateTime = localDateTime.toUtc();
      reminderString = '${utcDateTime.hour}:${utcDateTime.minute}';
    }

    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'color': color,
      'frequency': frequency,
      'days_of_week': daysOfWeek,
      'frequency_count': frequencyCount,
      'reminder_time': reminderString,
      'reminder_enabled': reminderEnabled,
      'end_date': endDate?.toUtc().toIso8601String(),
      'is_public': isPublic,
      'sort_order': sortOrder,
      'challenge_id': challengeId,
    };
  }
}
