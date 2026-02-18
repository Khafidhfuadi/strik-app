import 'package:flutter/material.dart';
import 'package:strik_app/data/models/user_model.dart';

class HabitChallenge {
  final String? id;
  final String creatorId;
  final String habitTitle;
  final String? habitDescription;
  final String habitColor;
  final String habitFrequency;
  final List<int>? habitDaysOfWeek;
  final int? habitFrequencyCount;
  final DateTime endDate;
  final TimeOfDay? reminderTime; // New field
  final bool showInFeed;
  final String inviteCode;
  final String status; // 'active', 'completed', 'archived'
  final DateTime? createdAt;
  final UserModel? creator;

  HabitChallenge({
    this.id,
    required this.creatorId,
    required this.habitTitle,
    this.habitDescription,
    required this.habitColor,
    required this.habitFrequency,
    this.habitDaysOfWeek,
    this.habitFrequencyCount,
    required this.endDate,
    this.reminderTime,
    this.showInFeed = true,
    required this.inviteCode,
    this.status = 'active',
    this.createdAt,
    this.creator,
  });

  bool get isExpired => DateTime.now().isAfter(endDate);
  bool get isActive => status == 'active' && !isExpired;

  String get inviteUrl => 'https://strik.app/challenge/$inviteCode';

  factory HabitChallenge.fromJson(Map<String, dynamic> json) {
    TimeOfDay? reminder;
    if (json['habit_reminder_time'] != null) {
      final parts = (json['habit_reminder_time'] as String).split(':');
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

    return HabitChallenge(
      id: json['id'],
      creatorId: json['creator_id'],
      habitTitle: json['habit_title'],
      habitDescription: json['habit_description'],
      habitColor: json['habit_color'] ?? '0xFF4CAF50',
      habitFrequency: json['habit_frequency'] ?? 'daily',
      habitDaysOfWeek: json['habit_days_of_week'] != null
          ? List<int>.from(json['habit_days_of_week'])
          : null,
      habitFrequencyCount: json['habit_frequency_count'],
      endDate: DateTime.parse(json['end_date']).toLocal(),
      reminderTime: reminder,
      showInFeed: json['show_in_feed'] ?? true,
      inviteCode: json['invite_code'],
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : null,
      creator: json['creator'] != null
          ? UserModel.fromJson(json['creator'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'creator_id': creatorId,
      'habit_title': habitTitle,
      'habit_description': habitDescription,
      'habit_color': habitColor,
      'habit_frequency': habitFrequency,
      'habit_days_of_week': habitDaysOfWeek,
      'habit_frequency_count': habitFrequencyCount,
      'end_date': endDate.toUtc().toIso8601String(),
      'show_in_feed': showInFeed,
      'invite_code': inviteCode,
      'status': status,
    };
  }
}

class ChallengeParticipant {
  final String? id;
  final String challengeId;
  final String userId;
  final String habitId;
  final DateTime? joinedAt;
  final String status;
  final UserModel? user;

  ChallengeParticipant({
    this.id,
    required this.challengeId,
    required this.userId,
    required this.habitId,
    this.joinedAt,
    this.status = 'active',
    this.user,
  });

  factory ChallengeParticipant.fromJson(Map<String, dynamic> json) {
    return ChallengeParticipant(
      id: json['id'],
      challengeId: json['challenge_id'],
      userId: json['user_id'],
      habitId: json['habit_id'],
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at']).toLocal()
          : null,
      status: json['status'] ?? 'active',
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'challenge_id': challengeId,
      'user_id': userId,
      'habit_id': habitId,
      'status': status,
    };
  }
}

class ChallengeLeaderboardEntry {
  final String? id;
  final String challengeId;
  final String userId;
  final int totalCompleted;
  final int totalExpected;
  final double completionRate;
  final int currentStreak;
  final double score;
  final int rank;
  final DateTime? updatedAt;
  final UserModel? user;

  ChallengeLeaderboardEntry({
    this.id,
    required this.challengeId,
    required this.userId,
    this.totalCompleted = 0,
    this.totalExpected = 0,
    this.completionRate = 0.0,
    this.currentStreak = 0,
    this.score = 0.0,
    this.rank = 0,
    this.updatedAt,
    this.user,
  });

  factory ChallengeLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return ChallengeLeaderboardEntry(
      id: json['id'],
      challengeId: json['challenge_id'],
      userId: json['user_id'],
      totalCompleted: json['total_completed'] ?? 0,
      totalExpected: json['total_expected'] ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
      currentStreak: json['current_streak'] ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      rank: json['rank'] ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at']).toLocal()
          : null,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'challenge_id': challengeId,
      'user_id': userId,
      'total_completed': totalCompleted,
      'total_expected': totalExpected,
      'completion_rate': completionRate,
      'current_streak': currentStreak,
      'score': score,
      'rank': rank,
    };
  }

  ChallengeLeaderboardEntry copyWith({
    String? id,
    String? challengeId,
    String? userId,
    int? totalCompleted,
    int? totalExpected,
    double? completionRate,
    int? currentStreak,
    double? score,
    int? rank,
    DateTime? updatedAt,
    UserModel? user,
  }) {
    return ChallengeLeaderboardEntry(
      id: id ?? this.id,
      challengeId: challengeId ?? this.challengeId,
      userId: userId ?? this.userId,
      totalCompleted: totalCompleted ?? this.totalCompleted,
      totalExpected: totalExpected ?? this.totalExpected,
      completionRate: completionRate ?? this.completionRate,
      currentStreak: currentStreak ?? this.currentStreak,
      score: score ?? this.score,
      rank: rank ?? this.rank,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
    );
  }
}
