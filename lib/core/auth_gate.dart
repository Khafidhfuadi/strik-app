import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:strik_app/main.dart';
import 'package:strik_app/screens/auth_screen.dart';
import 'package:strik_app/screens/home_screen.dart';
import 'package:strik_app/widgets/custom_loading_indicator.dart';
import 'package:strik_app/controllers/habit_controller.dart';
import 'package:strik_app/controllers/home_controller.dart';
import 'package:strik_app/controllers/friend_controller.dart';
import 'package:strik_app/controllers/gamification_controller.dart';
import 'package:strik_app/controllers/habit_challenge_controller.dart';
import 'package:strik_app/controllers/story_controller.dart';
import 'package:strik_app/services/push_notification_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange.handleError((error) {
        if (error is AuthException) {
          debugPrint(
            'AuthGate: Auth Exception caught: ${error.message}, code: ${error.statusCode}',
          );
        }
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CustomLoadingIndicator()));
        }

        final session = snapshot.data?.session;
        final event = snapshot.data?.event;

        if (session != null) {
          // User is logged in - ensure controllers are initialized
          debugPrint(
            'AuthGate: Session found! User: ${session.user.email}, Event: $event',
          );

          Get.put(HabitController(), permanent: false);
          Get.put(HomeController(), permanent: false);
          Get.put(FriendController(), permanent: false);
          Get.put(GamificationController(), permanent: false);
          Get.put(HabitChallengeController(), permanent: false);
          // StoryController harus global agar auto-post dari jurnal challenge selalu bisa berjalan
          if (!Get.isRegistered<StoryController>()) {
            Get.put(StoryController(), permanent: false);
          }

          // Refresh/Init Push Notifications (will save token if user logged in)
          PushNotificationService().init();

          return const HomeScreen();
        } else {
          debugPrint('AuthGate: No session found. Event: $event');
          if (event == AuthChangeEvent.passwordRecovery) {
            // Handle password recovery if needed in future
          }
          return const AuthScreen();
        }
      },
    );
  }
}
