// services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late FlutterLocalNotificationsPlugin _localNotifications;

  // Initialize notifications
  Future<void> initialize() async {
    await _setupLocalNotifications();
    await _setupFirebaseMessaging();
    await _getFCMToken();
  }

  // Setup local notifications for foreground
  Future<void> _setupLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);
  }

  // Setup Firebase Messaging
  Future<void> _setupFirebaseMessaging() async {
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('Notification permission: ${settings.authorizationStatus}');

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when app is opened from background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Get initial message when app is opened from terminated state
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message received: ${message.messageId}');

    // Save notification to Firestore
    await _saveNotificationToFirestore(message);

    // Show local notification
    await _showLocalNotification(message);
  }

  // Handle background messages
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Background message received: ${message.messageId}');

    // Save notification to Firestore
    await _saveNotificationToFirestore(message);

    // Navigate to relevant screen based on notification type
    _handleNotificationNavigation(message);
  }

  // Save notification to user's Firestore collection
  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get username from users collection
      final userQuery = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return;

      final userName = userQuery.docs.first.id;
      final notificationData = _parseNotificationData(message);

      // Save to user's notifications collection
      await _firestore
          .collection('users')
          .doc(userName)
          .collection('notifications')
          .add(notificationData);

      print('✅ Notification saved to Firestore for user: $userName');
    } catch (e) {
      print('❌ Error saving notification to Firestore: $e');
    }
  }

  // Parse notification data from FCM message
  Map<String, dynamic> _parseNotificationData(RemoteMessage message) {
    return {
      'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification?.title ?? 'Notification',
      'body': message.notification?.body ?? '',
      'type': message.data['type'] ?? 'general',
      'subType': message.data['subType'] ?? '',
      'tournamentId': message.data['tournamentId'] ?? '',
      'tournamentName': message.data['tournamentName'] ?? '',
      'matchId': message.data['matchId'] ?? '',
      'roomId': message.data['roomId'] ?? '',
      'roomPassword': message.data['roomPassword'] ?? '',
      'amount': message.data['amount'] ?? '',
      'transactionId': message.data['transactionId'] ?? '',
      'position': message.data['position'] ?? '',
      'winnings': message.data['winnings'] ?? '',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tournament_channel',
      'Tournament Notifications',
      channelDescription: 'Notifications for tournaments, payments, and matches',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title,
      message.notification?.body,
      details,
    );
  }

  // Handle navigation when notification is clicked
  void _handleNotificationNavigation(RemoteMessage message) {
    final type = message.data['type'];
    final tournamentId = message.data['tournamentId'];
    final matchId = message.data['matchId'];

    // You can implement navigation logic here based on notification type
    print('Navigate to: $type, Tournament: $tournamentId, Match: $matchId');
  }

  // Get FCM token and save to user profile
  Future<void> _getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        await _saveFCMTokenToUserProfile(token);
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  // Save FCM token to user profile
  Future<void> _saveFCMTokenToUserProfile(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userQuery = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userName = userQuery.docs.first.id;
        await _firestore
            .collection('users')
            .doc(userName)
            .update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token saved to user profile');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  // Subscribe to topics (optional)
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  // Unsubscribe from topics
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }
}