import 'package:firebase_messaging/firebase_messaging.dart';

// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase in background if needed
  // await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");
  print('Background notification data: ${message.data}');

  // You can process background data here
  // For example: update local database, schedule tasks, etc.

  // Note: You cannot show UI in background handlers
  // Local notifications will be shown automatically by Firebase
}

// Setup background handler
Future<void> setupBackgroundHandler() async {
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print('Background message handler setup successfully');
  } catch (e) {
    print('Error setting up background handler: $e');
  }
}