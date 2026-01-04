import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize Timezone
    tz.initializeTimeZones();
    // Get local timezone
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    final String timeZoneString = timeZoneName.toString();
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneString));
    } catch (e) {
      // Handle verbose timezone names (e.g., "TimezoneInfo(Asia/Jakarta, ...)")
      // which happen on some Android devices/versions.
      bool setSuccessfully = false;

      // 1. Try to extract IANA ID using Regex
      final regex = RegExp(r'([a-zA-Z]+/[a-zA-Z_]+)');
      final match = regex.firstMatch(timeZoneString);
      if (match != null) {
        final extractedName = match.group(1);
        if (extractedName != null) {
          try {
            tz.setLocalLocation(tz.getLocation(extractedName));
            setSuccessfully = true;
            print('Successfully extracted and set timezone: $extractedName');
          } catch (_) {}
        }
      }

      // 2. Fallback to Asia/Jakarta (Default for this app)
      if (!setSuccessfully) {
        print(
          'Warning: Could not set local timezone "$timeZoneName". Falling back to Asia/Jakarta.',
        );
        try {
          tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
        } catch (fallbackError) {
          print('Critical: Failed to set fallback timezone. Using UTC.');
          tz.setLocalLocation(tz.getLocation('UTC'));
        }
      }
    }

    // Android Initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Initialization settings
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap
        if (kDebugMode) {
          print('Notification tapped: ${details.payload}');
        }
      },
    );
  }

  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfTime(time),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder_channel',
            'Daily Reminders',
            channelDescription: 'Channel for daily habit reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        // Permission denied - silently fail
        if (kDebugMode) {
          print('Exact alarms not permitted. Reminder not scheduled.');
        }
      } else {
        rethrow;
      }
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
