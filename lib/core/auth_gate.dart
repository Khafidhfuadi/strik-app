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
import 'package:strik_app/services/push_notification_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CustomLoadingIndicator()));
        }

        final session = snapshot.data?.session;

        if (session != null) {
          // User is logged in - ensure controllers are initialized
          // Use putIfAbsent to avoid recreating if they already exist
          Get.put(HabitController(), permanent: false);
          Get.put(HomeController(), permanent: false);
          Get.put(FriendController(), permanent: false);
          Get.put(GamificationController(), permanent: false);

          // Refresh/Init Push Notifications (will save token if user logged in)
          PushNotificationService().init();

          return const HomeScreen();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}
