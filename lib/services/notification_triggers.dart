// utils/notification_triggers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationTriggers {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send payment notification
  Future<void> sendPaymentNotification({
    required String userName,
    required String type, // 'deposit_success', 'withdrawal_approved', etc.
    required double amount,
    required String transactionId,
    String? description,
  }) async {
    final notificationData = {
      'title': _getPaymentTitle(type, amount),
      'body': _getPaymentBody(type, amount, description),
      'type': 'payment',
      'subType': type,
      'amount': amount.toString(),
      'transactionId': transactionId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _saveUserNotification(userName, notificationData);
    await _sendPushNotification(userName, notificationData);
  }

  // Send tournament notification
  Future<void> sendTournamentNotification({
    required String userName,
    required String type, // 'registration', 'starting_soon', 'result', 'credentials'
    required String tournamentId,
    required String tournamentName,
    double? winnings,
    int? position,
    String? roomId,
    String? roomPassword,
  }) async {
    final notificationData = {
      'title': _getTournamentTitle(type, tournamentName),
      'body': _getTournamentBody(type, tournamentName, winnings, position),
      'type': 'tournament',
      'subType': type,
      'tournamentId': tournamentId,
      'tournamentName': tournamentName,
      'winnings': winnings?.toString(),
      'position': position?.toString(),
      'roomId': roomId,
      'roomPassword': roomPassword,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _saveUserNotification(userName, notificationData);
    await _sendPushNotification(userName, notificationData);
  }

  // Send match notification
  Future<void> sendMatchNotification({
    required String userName,
    required String type, // 'starting', 'result', 'room_update'
    required String matchId,
    required String tournamentName,
    String? roomId,
    String? roomPassword,
  }) async {
    final notificationData = {
      'title': _getMatchTitle(type, tournamentName),
      'body': _getMatchBody(type, tournamentName),
      'type': 'match',
      'subType': type,
      'matchId': matchId,
      'tournamentName': tournamentName,
      'roomId': roomId,
      'roomPassword': roomPassword,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _saveUserNotification(userName, notificationData);
    await _sendPushNotification(userName, notificationData);
  }

  // Send system notification
  Future<void> sendSystemNotification({
    required String userName,
    required String title,
    required String body,
    String? type, // 'announcement', 'offer', 'update'
  }) async {
    final notificationData = {
      'title': title,
      'body': body,
      'type': 'system',
      'subType': type ?? 'announcement',
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _saveUserNotification(userName, notificationData);
    await _sendPushNotification(userName, notificationData);
  }

  // Save notification to user's collection
  Future<void> _saveUserNotification(String userName, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(userName)
          .collection('notifications')
          .add({
        ...data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ Notification saved for user: $userName');
    } catch (e) {
      print('❌ Error saving notification: $e');
    }
  }

  // Send push notification via FCM
  Future<void> _sendPushNotification(String userName, Map<String, dynamic> data) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userName).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        print('⚠️ No FCM token for user: $userName');
        return;
      }

      // Replace with your FCM server key
      const String serverKey = 'YOUR_FCM_SERVER_KEY';

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode(<String, dynamic>{
          'notification': <String, dynamic>{
            'title': data['title'],
            'body': data['body'],
            'sound': 'default',
          },
          'data': data,
          'to': fcmToken,
          'priority': 'high',
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Push notification sent to: $userName');
      } else {
        print('❌ Failed to send push notification: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error sending push notification: $e');
    }
  }

  // Helper methods for notification content
  String _getPaymentTitle(String type, double amount) {
    switch (type) {
      case 'deposit_success':
        return '💰 Deposit Successful';
      case 'deposit_failed':
        return '❌ Deposit Failed';
      case 'withdrawal_approved':
        return '✅ Withdrawal Approved';
      case 'withdrawal_rejected':
        return '❌ Withdrawal Rejected';
      case 'tournament_winnings':
        return '🏆 Tournament Winnings';
      default:
        return 'Payment Update';
    }
  }

  String _getPaymentBody(String type, double amount, String? description) {
    switch (type) {
      case 'deposit_success':
        return '₹${amount.toStringAsFixed(2)} has been credited to your wallet.';
      case 'deposit_failed':
        return 'Deposit of ₹${amount.toStringAsFixed(2)} failed. Please try again.';
      case 'withdrawal_approved':
        return 'Your withdrawal of ₹${amount.toStringAsFixed(2)} has been approved.';
      case 'withdrawal_rejected':
        return 'Withdrawal of ₹${amount.toStringAsFixed(2)} was rejected. ${description ?? ''}';
      case 'tournament_winnings':
        return 'Congratulations! You won ₹${amount.toStringAsFixed(2)} from tournament.';
      default:
        return description ?? 'Payment processed successfully.';
    }
  }

  String _getTournamentTitle(String type, String tournamentName) {
    switch (type) {
      case 'registration':
        return '✅ Tournament Registered';
      case 'starting_soon':
        return '⚡ Starting Soon';
      case 'result':
        return '🏆 Tournament Result';
      case 'credentials':
        return '🎮 Room Credentials';
      default:
        return 'Tournament Update';
    }
  }

  String _getTournamentBody(String type, String tournamentName, double? winnings, int? position) {
    switch (type) {
      case 'registration':
        return 'You have successfully registered for $tournamentName';
      case 'starting_soon':
        return '$tournamentName starts in 30 minutes. Get ready!';
      case 'result':
        final positionSuffix = _getPositionSuffix(position ?? 0);
        return 'You finished ${position}$positionSuffix in $tournamentName and won ₹${winnings?.toStringAsFixed(2) ?? '0'}';
      case 'credentials':
        return 'Room ID and password for $tournamentName are available now!';
      default:
        return 'Update for $tournamentName';
    }
  }

  String _getMatchTitle(String type, String tournamentName) {
    switch (type) {
      case 'starting':
        return '🎯 Match Starting';
      case 'result':
        return '📊 Match Result';
      case 'room_update':
        return '🔄 Room Updated';
      default:
        return 'Match Update';
    }
  }

  String _getMatchBody(String type, String tournamentName) {
    switch (type) {
      case 'starting':
        return 'Your match in $tournamentName is starting now!';
      case 'result':
        return 'Match results for $tournamentName are available.';
      case 'room_update':
        return 'Room details for $tournamentName have been updated.';
      default:
        return 'Match update for $tournamentName';
    }
  }

  String _getPositionSuffix(int position) {
    if (position == 1) return 'st';
    if (position == 2) return 'nd';
    if (position == 3) return 'rd';
    return 'th';
  }
}