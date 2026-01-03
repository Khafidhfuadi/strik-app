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
  });

  factory Habit.fromJson(Map<String, dynamic> json) {
    TimeOfDay? reminder;
    if (json['reminder_time'] != null) {
      final parts = (json['reminder_time'] as String).split(':');
      if (parts.length >= 2) {
        reminder = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
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
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    String? reminderString;
    if (reminderTime != null) {
      final hour = reminderTime!.hour.toString().padLeft(2, '0');
      final minute = reminderTime!.minute.toString().padLeft(2, '0');
      reminderString = '$hour:$minute:00';
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
    };
  }
}
