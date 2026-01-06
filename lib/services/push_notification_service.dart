import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:strik_app/main.dart';

import 'package:get/get.dart';
import 'package:strik_app/screens/post_detail_screen.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    // Request permission (Android 13+) - DISABLED to centralized in PermissionScreen
    // NotificationSettings settings = await _fcm.requestPermission(
    //   alert: true,
    //   badge: true,
    //   sound: true,
    // );

    // Check status instead of requesting
    final settings = await _fcm.getNotificationSettings();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted notification permission');
      }

      // Get token
      String? token = await _fcm.getToken();
      if (token != null) {
        await saveTokenToDatabase(token);
      }

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen(saveTokenToDatabase);

      // Handle message when app is launched from terminated state
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Foreground message received: ${message.notification?.title}');
        }
        // Local notifications handled elsewhere
      });

      // Handle background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    }
  }

  void _handleMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Handling notification tap: ${message.data}');
    }

    final data = message.data;
    String? postId = data['post_id'];
    String? habitLogId = data['habit_log_id'];

    // Normalize empty strings to null
    if (postId != null && postId.isEmpty) postId = null;
    if (habitLogId != null && habitLogId.isEmpty) habitLogId = null;

    if (postId != null || habitLogId != null) {
      Get.to(() => PostDetailScreen(postId: postId, habitLogId: habitLogId));
    }
  }

  Future<void> saveTokenToDatabase(String token) async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        await supabase
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', user.id);
        if (kDebugMode) {
          print('FCM Token saved to database: $token');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error saving FCM token: $e');
        }
      }
    }
  }
}
