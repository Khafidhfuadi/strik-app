import 'package:alarm/alarm.dart';

class AlarmService {
  static Future<void> setAlarm({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: dateTime,
      assetAudioPath: 'assets/src/alarm.mp3',
      volumeSettings: VolumeSettings.fixed(volume: 0.8),
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: 'Stop',
        icon: 'notification_icon',
      ),
      // enableNotificationOnKill is handled by warningNotificationOnKill in v5 if needed, default is usually false but we can ignore for now or check docs.
      // Default behavior is usually good.
    );

    await Alarm.set(alarmSettings: alarmSettings);
  }

  static Future<void> stopAlarm(int id) async {
    await Alarm.stop(id);
  }
}
