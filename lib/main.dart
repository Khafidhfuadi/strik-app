import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strik_app/core/theme.dart';
import 'package:get/get.dart';
import 'package:strik_app/core/auth_gate.dart';
import 'package:strik_app/services/notification_service.dart';
import 'package:strik_app/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await NotificationService().init();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const StrikApp());
}

final supabase = Supabase.instance.client;

class StrikApp extends StatelessWidget {
  const StrikApp({super.key});

  Future<bool> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Strik',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: FutureBuilder<bool>(
        future: _checkOnboardingStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final onboardingCompleted = snapshot.data ?? false;
          return onboardingCompleted
              ? const AuthGate()
              : const OnboardingScreen();
        },
      ),
    );
  }
}
