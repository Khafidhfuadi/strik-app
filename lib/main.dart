import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/core/theme.dart';
import 'package:get/get.dart';
import 'package:strik_app/core/auth_gate.dart';
import 'package:strik_app/services/notification_service.dart';
import 'package:strik_app/services/push_notification_service.dart';
import 'package:strik_app/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:alarm/alarm.dart';
import 'package:strik_app/services/alarm_manager_service.dart';

Future<void> main() async {
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
    );

    // Initialize Push Notification (after Supabase so we have currentUser if already logged in)
    try {
      await PushNotificationService().init();
    } catch (e) {
      debugPrint('Push notification service init failed: $e');
    }

    // Check onboarding status
    final prefs = await SharedPreferences.getInstance();
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
