import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/core/theme.dart';
import 'package:get/get.dart';
import 'package:strik_app/core/auth_gate.dart';
import 'package:strik_app/services/notification_service.dart';
import 'package:strik_app/services/push_notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:strik_app/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:alarm/alarm.dart';
import 'package:strik_app/services/alarm_manager_service.dart';
import 'package:strik_app/services/home_widget_service.dart';
import 'package:strik_app/screens/email_confirmation_error_screen.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");

  try {
    debugPrint("Background Handler Data: ${message.data}"); // LOG DATA PAYLOAD
    if (message.data['type'] == 'new_story') {
      final String? username = message.data['username'];
      final String? mediaUrl = message.data['media_url'];
      final String? createdAt = message.data['created_at'];

      debugPrint(
        "Found new_story from: $username, url: $mediaUrl, time: $createdAt",
      ); // LOG EXTRACTED DATA

      if (username != null && mediaUrl != null) {
        debugPrint("Updating widget from background...");

        String timeString = "Baru aja";
        if (createdAt != null) {
          try {
            final date = DateTime.parse(createdAt).toLocal();
            // Safe manual formatting HH:mm
            final hour = date.hour.toString().padLeft(2, '0');
            final minute = date.minute.toString().padLeft(2, '0');
            timeString = "$hour:$minute";
          } catch (e) {
            print("Date parse error: $e");
          }
        }

        await HomeWidgetService.updateWidget(
          title: "Momentz: $username",
          subtitle: timeString,
          imageUrl: mediaUrl,
        );
        debugPrint("Background widget update called");

        // Show Local Notification manually (since we sent Data-Only)
        final String? title = message.data['title'];
        final String? body = message.data['body'];
        if (title != null && body != null) {
          await _showLocalNotification(title, body);
        }
      } else {
        debugPrint("Missing username or mediaUrl in payload");
      }
    } else {
      debugPrint("Message type is not new_story: ${message.data['type']}");
    }
  } catch (e) {
    debugPrint("Error in background widget update: $e");
  }
}

// Helper for Background Notification
Future<void> _showLocalNotification(String title, String body) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  const AndroidNotificationDetails
  androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'high_importance_channel', // Must match channel ID in Manifest if defined
    'High Importance Notifications',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.show(
    0, // Notification ID
    title,
    body,
    platformChannelSpecifics,
  );
}

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await initializeDateFormatting('id_ID', null);

      bool onboardingCompleted = false;
      String? errorMessage;

      try {
        // Load .env file
        await dotenv.load(fileName: ".env");

        // Initialize Alarm
        await Alarm.init();

        // Initialize AlarmManagerService for recurring alarms
        await AlarmManagerService.init();

        // Initialize Firebase
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        // Initialize notification service
        try {
          await NotificationService().init();
        } catch (e) {
          debugPrint('Notification service init failed: $e');
          // Continue even if notification fails
        }

        // Initialize Supabase
        await Supabase.initialize(
          url: dotenv.env['SUPABASE_URL']!,
          anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
          debug: true,
        );

        // Initialize Push Notification (after Supabase so we have currentUser if already logged in)
        try {
          await PushNotificationService().init();
        } catch (e) {
          debugPrint('Push notification service init failed: $e');
        }

        // Check onboarding status
        final prefs = await SharedPreferences.getInstance();
        Get.put(prefs); // Register SharedPreferences for dependency injection
        onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
      } catch (e, stackTrace) {
        debugPrint('Error during initialization: $e');
        debugPrint('Stack trace: $stackTrace');
        errorMessage = e.toString();
      }

      runApp(
        StrikApp(
          onboardingCompleted: onboardingCompleted,
          errorMessage: errorMessage,
        ),
      );
    },
    (error, stack) {
      if (error is AuthException &&
          (error.statusCode == 'otp_expired' ||
              error.message.contains('Token has expired') ||
              error.message.contains('Email link is invalid'))) {
        debugPrint("Caught expired OTP error: ${error.message}");
        // Navigate to friendly error screen instead of crashing or showing scary error
        // Use a slight delay to ensure GetMaterialApp is mounted effectively if this happens during startup
        Future.delayed(const Duration(milliseconds: 500), () {
          Get.to(() => const EmailConfirmationErrorScreen());
        });
      } else {
        debugPrint("Unhandled error: $error");
        // debugPrintStack(stackTrace: stack); // optional
      }
    },
  );
}

final supabase = Supabase.instance.client;

class StrikApp extends StatelessWidget {
  final bool onboardingCompleted;
  final String? errorMessage;

  const StrikApp({
    super.key,
    required this.onboardingCompleted,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Strik',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: errorMessage != null
          ? _ErrorScreen(errorMessage: errorMessage!)
          : (onboardingCompleted ? const AuthGate() : const OnboardingScreen()),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String errorMessage;

  const _ErrorScreen({required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Initialization Error',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Try to restart the app
                  // In production, you might want to implement proper restart logic
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
