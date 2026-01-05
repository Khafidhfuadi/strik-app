import 'dart:async';
import 'dart:convert';
import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:strik_app/data/models/habit.dart';

class AlarmManagerService {
  static AlarmManagerService? _instance;
  static AlarmManagerService get instance => _instance!;

  StreamSubscription<AlarmSettings>? _ringSubscription;

  AlarmManagerService._();

  static Future<void> init() async {
    _instance = AlarmManagerService._();
    await _instance!._startListening();
  }

  Future<void> _startListening() async {
    _ringSubscription = Alarm.ringStream.stream.listen((alarmSettings) async {
      final alarmId = alarmSettings.id;
      // Derive base ID (ensure it's the even number of the pair)
      final baseId = alarmId & ~1;

      // Get metadata using baseId
      final metadata = await _getAlarmMetadata(baseId);
      if (metadata == null) {
        return;
      }

      // Calculate next occurrence and reschedule
      final nextDateTime = _calculateNextOccurrence(
        metadata['frequency'],
        metadata['daysOfWeek'],
        TimeOfDay(
          hour: metadata['reminderTime']['hour'],
          minute: metadata['reminderTime']['minute'],
        ),
      );

      if (nextDateTime != null) {
        // Toggle ID: if current is even (baseId), next is odd (baseId + 1), and vice versa
        final nextAlarmId = (alarmId == baseId) ? baseId + 1 : baseId;

        // Reschedule alarm
        final newAlarmSettings = AlarmSettings(
          id: nextAlarmId,
          dateTime: nextDateTime,
          assetAudioPath: 'assets/src/alarm.mp3',
          volumeSettings: VolumeSettings.fixed(volume: 0.8),
          notificationSettings: NotificationSettings(
            title: metadata['habitTitle'],
            body: 'Yuk semangat kerjain habit kamu! 🔥',
            stopButton: 'Stop',
            icon: '@mipmap/ic_launcher',
          ),
        );

        await Alarm.set(alarmSettings: newAlarmSettings);
        print('Alarm rescheduled for: $nextDateTime with ID: $nextAlarmId');
      }
    });
  }

  DateTime? _calculateNextOccurrence(
    String frequency,
    List<dynamic>? daysOfWeek,
    TimeOfDay reminderTime,
  ) {
    final now = DateTime.now();
    DateTime nextTime = DateTime(
      now.year,
      now.month,
      now.day,
      reminderTime.hour,
      reminderTime.minute,
    );

    if (frequency == 'daily') {
      // Find next valid day of week
      if (daysOfWeek == null || daysOfWeek.isEmpty) {
        daysOfWeek = [0, 1, 2, 3, 4, 5, 6]; // All days
      }

      for (int i = 0; i <= 14; i++) {
        final candidate = nextTime.add(Duration(days: i));

        // If it's today, make sure time hasn't passed
        if (i == 0 && candidate.isBefore(now)) {
          continue;
        }

        final dayIndex = candidate.weekday - 1; // 0=Mon, 6=Sun

        if (daysOfWeek.contains(dayIndex)) {
          return candidate;
        }
      }
    } else if (frequency == 'weekly') {
      // Just add 7 days
      return nextTime.add(const Duration(days: 7));
    } else if (frequency == 'monthly') {
      // Find next valid date in month
      if (daysOfWeek == null || daysOfWeek.isEmpty) {
        return null;
      }

      // Start from tomorrow
      for (int monthOffset = 0; monthOffset <= 12; monthOffset++) {
        final baseDate = DateTime(now.year, now.month + monthOffset, 1);

        for (var date in daysOfWeek) {
          try {
            final candidate = DateTime(
              baseDate.year,
              baseDate.month,
              date as int,
              reminderTime.hour,
              reminderTime.minute,
            );

            // Check if this date is valid and in the future
            if (candidate.month == baseDate.month && candidate.isAfter(now)) {
              return candidate;
            }
          } catch (e) {
            // Invalid date (e.g., Feb 30), skip
            continue;
          }
        }
      }
    }

    return null;
  }

  Future<void> scheduleRecurringAlarm({
    required String habitId,
    required String habitTitle,
    required String frequency,
    required List<int>? daysOfWeek,
    required TimeOfDay reminderTime,
  }) async {
    // Generate base alarm ID from habit ID (ensure it's even)
    int baseId = habitId.hashCode;
    if (baseId < 0) baseId = -baseId;
    baseId = baseId & ~1; // Force even number

    // Calculate first occurrence
    final firstDateTime = _calculateNextOccurrence(
      frequency,
      daysOfWeek,
      reminderTime,
    );

    if (firstDateTime == null) {
      print('Could not calculate next occurrence');
      return;
    }

    // Save metadata using baseId
    await _saveAlarmMetadata(baseId, {
      'habitId': habitId,
      'habitTitle': 'Waktunya $habitTitle!',
      'frequency': frequency,
      'daysOfWeek': daysOfWeek,
      'reminderTime': {
        'hour': reminderTime.hour,
        'minute': reminderTime.minute,
      },
    });

    // Schedule alarm using baseId
    final alarmSettings = AlarmSettings(
      id: baseId,
      dateTime: firstDateTime,
      assetAudioPath: 'assets/src/alarm.mp3',
      volumeSettings: VolumeSettings.fixed(volume: 0.8),
      notificationSettings: NotificationSettings(
        title: 'Waktunya $habitTitle!',
        body: 'Yuk semangat kerjain habit kamu! 🔥',
        stopButton: 'Stop',
        icon: '@mipmap/ic_launcher',
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);
  }

  Future<void> cancelHabitAlarm(String habitId) async {
    int baseId = habitId.hashCode;
    if (baseId < 0) baseId = -baseId;
    baseId = baseId & ~1; // Force even number

    // Cancel both potential IDs (base and base+1)
    await Alarm.stop(baseId);
    await Alarm.stop(baseId + 1);

    await _deleteAlarmMetadata(baseId);
    print('Alarm cancelled for habit $habitId');
  }

  Future<void> _saveAlarmMetadata(
    int alarmId,
    Map<String, dynamic> metadata,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_metadata_$alarmId', jsonEncode(metadata));
  }

  Future<Map<String, dynamic>?> _getAlarmMetadata(int alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('alarm_metadata_$alarmId');
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  Future<void> _deleteAlarmMetadata(int alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('alarm_metadata_$alarmId');
  }

  void dispose() {
    _ringSubscription?.cancel();
  }

  // Migration: Schedule alarms for existing habits
  Future<void> migrateExistingHabits(List<Habit> habits) async {
    for (var habit in habits) {
      try {
        // Expect Habit object, not JSON
        final String title = habit.title;
        final bool reminderEnabled = habit.reminderEnabled;

        if (!reminderEnabled) {
          continue;
        }

        final String? habitId = habit.id;
        final String frequency = habit.frequency;
        final List<int>? daysOfWeek = habit.daysOfWeek;
        final TimeOfDay? reminderTime = habit.reminderTime;

        if (habitId == null || reminderTime == null) {
          continue;
        }

        // Check if metadata already exists (already migrated)
        int baseId = habitId.hashCode;
        if (baseId < 0) baseId = -baseId;
        baseId = baseId & ~1;

        final existingMetadata = await _getAlarmMetadata(baseId);

        if (existingMetadata != null) {
          continue;
        }

        // Schedule recurring alarm
        await scheduleRecurringAlarm(
          habitId: habitId,
          habitTitle: title,
          frequency: frequency,
          daysOfWeek: daysOfWeek,
          reminderTime: reminderTime,
        );
      } catch (e) {
        continue;
      }
    }
  }
}
