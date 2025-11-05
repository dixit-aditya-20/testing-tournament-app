import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseMessagingService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Initialize notifications
  static Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      announcement: false,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    // Initialize local notifications
    const AndroidInitializationSettings androidInitializationSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitializationSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        _onNotificationTap(response);
      },
    );

    // Configure foreground notification presentation
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Get FCM token
    await _getFCMToken();

    // Handle initial notification when app is terminated
    _handleInitialMessage();
  }

  // Get FCM token and save to Firestore
  static Future<void> _getFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        // Save token to Firestore or your backend
        await _saveTokenToFirestore(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('FCM Token refreshed: $newToken');
        _saveTokenToFirestore(newToken);
      });
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    // Implement your logic to save token to Firestore
    // This depends on your user authentication system
    print('Save this token to your user document: $token');
  }

  // Show foreground notification
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    AppleNotification? apple = message.notification?.apple;

    // Create notification details
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'high_importance_channel', // channel id
      'High Importance Notifications', // channel name
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    // Show notification
    if (notification != null) {
      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        notification.title,
        notification.body,
        platformChannelSpecifics,
        payload: jsonEncode(message.data),
      );
    }
  }

  // Handle notification tap
  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      _handleNotificationData(data);
    }
  }

  // Handle when app is opened from notification
  static void _onMessageOpenedApp(RemoteMessage message) {
    _handleNotificationData(message.data);
  }

  // Handle initial message when app is terminated
  static void _handleInitialMessage() async {
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationData(initialMessage.data);
    }
  }

  // Handle notification data and navigate accordingly
  static void _handleNotificationData(Map<String, dynamic> data) {
    final String type = data['type'] ?? 'general';

    // Use a navigation service or global key to handle navigation
    print('Notification type: $type');
    print('Notification data: $data');

    // Example navigation based on notification type
    switch (type) {
      case 'payment_success':
      // Navigate to wallet screen
        break;
      case 'tournament_result':
      // Navigate to tournament results
        break;
      case 'room_credentials':
      // Navigate to tournament room
        break;
      case 'withdrawal_approved':
      // Navigate to wallet screen
        break;
      case 'tournament_reminder':
      // Navigate to tournament details
        break;
      case 'admin_notification':
      // Navigate to notifications screen
        break;
      default:
      // Navigate to general notifications
        break;
    }
  }

  // Subscribe to topics
  static Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  // Unsubscribe from topics
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }

  // Get initial notification stream
  static Stream<RemoteMessage> get onMessageOpenedApp {
    return FirebaseMessaging.onMessageOpenedApp;
  }

  // Get foreground message stream
  static Stream<RemoteMessage> get onMessage {
    return FirebaseMessaging.onMessage;
  }
}