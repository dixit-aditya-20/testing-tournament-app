import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize FCM and get token
  Future<String?> initializeFCM() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission for notifications');
      }

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');

      if (token != null) {
        await _saveTokenToFirestore(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('FCM Token refreshed: $newToken');
        _saveTokenToFirestore(newToken);
      });

      return token;
    } catch (e) {
      print('Error initializing FCM: $e');
      return null;
    }
  }

  // Save token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Get user data to find the document ID (using name)
        final userQuery = await _firestore
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          final userName = userDoc.id; // Document ID is the user's name

          await _firestore.collection('users').doc(userName).update({
            'fcm_tokens': FieldValue.arrayUnion([token]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('FCM token saved to Firestore for user: $userName');
        }
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Remove token when user logs out
  Future<void> removeToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userQuery = await _firestore
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          final userName = userDoc.id;

          await _firestore.collection('users').doc(userName).update({
            'fcm_tokens': FieldValue.arrayRemove([token]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('FCM token removed from Firestore');
        }
      }
    } catch (e) {
      print('Error removing FCM token: $e');
    }
  }
}