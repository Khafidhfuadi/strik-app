import 'package:flutter/material.dart';
import 'package:strik_app/data/models/habit_challenge.dart';

class Habit {
  final String? id;
  final String userId;
  // Backing fields for local data
  final String _title;
  final String? _description;
  final String _color;
  final String _frequency;
  final List<int>? _daysOfWeek;
  final int? _frequencyCount;
  final DateTime? _endDate;
  final TimeOfDay? _reminderTime; // Renamed backing field

  final bool reminderEnabled;
  final DateTime? createdAt;
  final bool isPublic;
  final int? sortOrder;
  final String? challengeId;
  final HabitChallenge? challenge; // Reference to the challenge source of truth

  Habit({
    this.id,
    required this.userId,
    required String title,
    String? description,
    required String color,
    required String frequency,
    List<int>? daysOfWeek,
    int? frequencyCount,
    TimeOfDay? reminderTime, // Constructor parameter remains same
    this.reminderEnabled = false,
    this.createdAt,
    DateTime? endDate,
    this.isPublic = true,
    this.sortOrder,
    this.challengeId,
    this.challenge,
  }) : _title = title,
       _description = description,
       _color = color,
       _frequency = frequency,
       _daysOfWeek = daysOfWeek,
       _frequencyCount = frequencyCount,
       _endDate = endDate,
       _reminderTime = reminderTime;

  // Getters that prioritize Challenge data if linked
  String get title => challenge?.habitTitle ?? _title;
  String? get description => challenge?.habitDescription ?? _description;
  String get color => challenge?.habitColor ?? _color;
  String get frequency => challenge?.habitFrequency ?? _frequency;
  List<int>? get daysOfWeek => challenge?.habitDaysOfWeek ?? _daysOfWeek;
  int? get frequencyCount => challenge?.habitFrequencyCount ?? _frequencyCount;
  DateTime? get endDate => challenge?.endDate ?? _endDate;

  // For reminder, we prioritize challenge reminder if exists
  TimeOfDay? get reminderTime => challenge?.reminderTime ?? _reminderTime;

  bool get isChallenge => challengeId != null;

  bool get isArchived {
    if (challenge != null) {
      return !challenge!.isActive;
    }
    if (endDate != null) {
      final endOfDay = DateTime(
        endDate!.year,
        endDate!.month,
        endDate!.day,
        23,
        59,
        59,
      );
      return DateTime.now().isAfter(endOfDay);
    }
    return false;
  }

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
      title: json['title'] ?? '',
      description: json['description'],
      color: json['color'] ?? '0xFF000000',
      frequency: json['frequency'] ?? 'daily',
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
      challengeId: json['challenge_id'] as String?,
      challenge: json['challenge'] != null
          ? HabitChallenge.fromJson(json['challenge'])
          : null,
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
