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
    TimeOfDay reminderTime, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
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

        // If it's today (relative to referenceDate), make sure time hasn't passed
        // ONLY if referenceDate was NOT provided (meaning we are scheduling from now)
        // If referenceDate IS provided (e.g. "tomorrow"), we accept the time even if it's earlier in the day than now
        if (referenceDate == null &&
            i == 0 &&
            candidate.isBefore(DateTime.now())) {
          continue;
        }

        final dayIndex = candidate.weekday - 1; // 0=Mon, 6=Sun

        if (daysOfWeek.contains(dayIndex)) {
          return candidate;
        }
      }
    } else if (frequency == 'weekly') {
      // Just add 7 days (simplified logic for now, assumes starting from a valid day)
      return nextTime.add(const Duration(days: 7));
    } else if (frequency == 'monthly') {
      // Find next valid date in month
      if (daysOfWeek == null || daysOfWeek.isEmpty) {
        return null;
      }

      // Start from current month (relative to referenceDate)
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

            // Check if this date is valid and in the future relative to now
            if (candidate.month == baseDate.month &&
                candidate.isAfter(DateTime.now())) {
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

  /// Call this when a habit is completed EARLY.
  /// It cancels the current pending alarm (if any) and schedules the NEXT one.
  Future<void> completeHabit(String habitId) async {
    int baseId = habitId.hashCode;
    if (baseId < 0) baseId = -baseId;
    baseId = baseId & ~1;

    // 1. Get metadata
    final metadata = await _getAlarmMetadata(baseId);
    if (metadata == null) {
      print('No alarm metadata found for completed habit $habitId');
      return;
    }

    // 2. Stop current alarms (so it doesn't ring today)
    await Alarm.stop(baseId);
    await Alarm.stop(baseId + 1);

    // 3. Calculate NEXT occurrence starting from TOMORROW (or next week/month)
    // We assume if you completed it today, you don't want another alarm today.

    final frequency = metadata['frequency'];
    final daysOfWeek = (metadata['daysOfWeek'] as List?)?.cast<int>();
    final reminderTimeMap = metadata['reminderTime'];
    final reminderTime = TimeOfDay(
      hour: reminderTimeMap['hour'],
      minute: reminderTimeMap['minute'],
    );

    DateTime referenceDate;
    if (frequency == 'weekly') {
      // For weekly, we just add 7 days from now?
      // Actually, if I complete it today (Monday), and it's a Weekly habit for Monday,
      // the next one is next Monday.
      // If I complete it today (Tuesday), and it's a Weekly habit for Monday (overdue?),
      // the logic is tricky.
      // Let's use the standard "Next Occurrence" logic but starting from TOMORROW.
      referenceDate = DateTime.now().add(const Duration(days: 1));
    } else {
      // Daily/Monthly: Start searching from tomorrow
      referenceDate = DateTime.now().add(const Duration(days: 1));
    }

    final nextDateTime = _calculateNextOccurrence(
      frequency,
      daysOfWeek,
      reminderTime,
      referenceDate: referenceDate,
    );

    if (nextDateTime != null) {
      // 4. Schedule the next one
      // Toggle ID mechanism isn't strictly needed here since we stopped both,
      // but let's stick to baseId for simplicity or toggle if we want to be fancy.
      // Since we stopped both, we can just use baseId.

      final newAlarmSettings = AlarmSettings(
        id: baseId,
        dateTime: nextDateTime,
        assetAudioPath: 'assets/src/alarm.mp3',
        volumeSettings: VolumeSettings.fixed(volume: 0.8),
        notificationSettings: NotificationSettings(
          title: metadata['habitTitle'] ?? 'Habit Reminder',
          body: 'Yuk semangat kerjain habit kamu! 🔥',
          stopButton: 'Stop',
          icon: '@mipmap/ic_launcher',
        ),
      );

      await Alarm.set(alarmSettings: newAlarmSettings);
      print('Alarm rescheduled after completion for: $nextDateTime');
    }
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

  // Self-Healing: Check and restore missing alarms
  Future<void> ensureAlarmsAreScheduled(List<Habit> habits) async {
    final scheduledAlarms = await Alarm.getAlarms();
    final now = DateTime.now();

    for (var habit in habits) {
      if (!habit.reminderEnabled ||
          habit.id == null ||
          habit.reminderTime == null) {
        continue;
      }

      int baseId = habit.id.hashCode;
      if (baseId < 0) baseId = -baseId;
      baseId = baseId & ~1; // Even number

      // Calculate when the alarm SHOULD be
      final expectedTime = _calculateNextOccurrence(
        habit.frequency,
        habit.daysOfWeek,
        habit.reminderTime!,
      );

      if (expectedTime == null) continue;

      // Check if either ID exists and is valid
      // Valid means:
      // 1. Logic ID matches (baseId or baseId+1)
      // 2. Scheduled time is AFTER now given a small margin (or matches expected)
      // Actually, simplest check: Do we have ANY future alarm for this habit?

      bool hasValidAlarm = false;
      bool hasBadAlarm = false;

      for (var alarm in scheduledAlarms) {
        if (alarm.id == baseId || alarm.id == baseId + 1) {
          hasBadAlarm = true; // Found something, assumed bad unless valid
          if (alarm.dateTime.isAfter(now)) {
            hasValidAlarm = true;
            hasBadAlarm = false; // It's valid
            break;
          }
        }
      }

      if (!hasValidAlarm) {
        print('MISSING ALARM FOUND for ${habit.title}. Restoring...');

        // Remove old ones ONLY if we found them (to avoid "Error in Flutter" log)
        if (hasBadAlarm) {
          await Alarm.stop(baseId);
          await Alarm.stop(baseId + 1);
        }

        // Reschedule
        await scheduleRecurringAlarm(
          habitId: habit.id!,
          habitTitle: habit.title,
          frequency: habit.frequency,
          daysOfWeek: habit.daysOfWeek,
          reminderTime: habit.reminderTime!,
        );
      }
    }
  }

  Future<void> cancelAllAlarms() async {
    // 1. Stop all scheduled alarms
    final alarms = await Alarm.getAlarms();
    for (var alarm in alarms) {
      await Alarm.stop(alarm.id);
    }

    // 2. Clear all metadata
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith('alarm_metadata_')) {
        await prefs.remove(key);
      }
    }
    print('All alarms and metadata cleared');
  }
}
