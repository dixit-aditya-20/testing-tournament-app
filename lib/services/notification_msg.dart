// services/notification_msg.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationMessage {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Replace with your FCM server key from Firebase Console
  static const String _serverKey = 'YOUR_FCM_SERVER_KEY_HERE';

  // Send notification to specific user
  Future<void> sendToUser({
    required String userName,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userName).get();
      if (!userDoc.exists) {
        print('❌ User not found: $userName');
        return;
      }

      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        print('⚠️ No FCM token for user: $userName');
        return;
      }

      // Send FCM notification
      await _sendFCMNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: {
          'type': type,
          ...?data,
        },
      );

      // Save to user's notifications collection
      await _saveToUserNotifications(
        userName: userName,
        title: title,
        body: body,
        type: type,
        data: data,
      );

      print('✅ Notification sent to user: $userName');
    } catch (e) {
      print('❌ Error sending notification to user: $e');
    }
  }

  // Send notification to all users
  Future<void> sendToAllUsers({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      int successCount = 0;

      for (var userDoc in usersSnapshot.docs) {
        final userName = userDoc.id;
        final userData = userDoc.data();
        final fcmToken = userData['fcmToken'] as String?;

        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _sendFCMNotification(
            token: fcmToken,
            title: title,
            body: body,
            data: {
              'type': type,
              ...?data,
            },
          );

          // Save to user's notifications
          await _saveToUserNotifications(
            userName: userName,
            title: title,
            body: body,
            type: type,
            data: data,
          );

          successCount++;

          // Add small delay to avoid rate limiting
          await Future.delayed(Duration(milliseconds: 50));
        }
      }

      print('✅ Notification sent to $successCount/${usersSnapshot.docs.length} users');
    } catch (e) {
      print('❌ Error sending notification to all users: $e');
    }
  }

  // Send notification to tournament participants
  Future<void> sendToTournamentParticipants({
    required String tournamentId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      int successCount = 0;

      for (var userDoc in usersSnapshot.docs) {
        final userName = userDoc.id;
        final userData = userDoc.data();
        final registrations = userData['tournament_registrations'] as List<dynamic>? ?? [];

        // Check if user is registered for this tournament
        final isRegistered = registrations.any((reg) =>
        reg is Map<String, dynamic> &&
            reg['tournament_id'] == tournamentId &&
            reg['status'] == 'registered'
        );

        if (isRegistered) {
          final fcmToken = userData['fcmToken'] as String?;
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await _sendFCMNotification(
              token: fcmToken,
              title: title,
              body: body,
              data: {
                'type': type,
                'tournamentId': tournamentId,
                ...?data,
              },
            );

            await _saveToUserNotifications(
              userName: userName,
              title: title,
              body: body,
              type: type,
              data: {
                'tournamentId': tournamentId,
                ...?data,
              },
            );

            successCount++;
            await Future.delayed(Duration(milliseconds: 50));
          }
        }
      }

      print('✅ Notification sent to $successCount tournament participants');
    } catch (e) {
      print('❌ Error sending notification to tournament participants: $e');
    }
  }

  // Send FCM notification using HTTP
  Future<void> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode(<String, dynamic>{
          'notification': <String, dynamic>{
            'title': title,
            'body': body,
            'sound': 'default',
          },
          'data': data ?? <String, dynamic>{},
          'to': token,
          'priority': 'high',
        }),
      );

      if (response.statusCode == 200) {
        print('📤 FCM notification sent successfully');
      } else {
        print('❌ FCM error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ FCM send error: $e');
    }
  }

  // Save notification to user's Firestore collection
  Future<void> _saveToUserNotifications({
    required String userName,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notificationData = {
        'id': 'notif_${DateTime.now().millisecondsSinceEpoch}',
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        ...?data,
      };

      await _firestore
          .collection('users')
          .doc(userName)
          .collection('notifications')
          .add(notificationData);
    } catch (e) {
      print('❌ Error saving notification to Firestore: $e');
    }
  }

  // Pre-built notification templates
  Future<void> sendPaymentSuccess({
    required String userName,
    required double amount,
    required String transactionId,
  }) async {
    await sendToUser(
      userName: userName,
      title: '💰 Payment Successful',
      body: '₹${amount.toStringAsFixed(2)} has been credited to your wallet.',
      type: 'payment_success',
      data: {
        'amount': amount.toString(),
        'transactionId': transactionId,
      },
    );
  }

  Future<void> sendTournamentResult({
    required String userName,
    required String tournamentName,
    required int position,
    required double winnings,
  }) async {
    final suffix = _getPositionSuffix(position);

    await sendToUser(
      userName: userName,
      title: '🏆 Tournament Result',
      body: 'You finished ${position}$suffix in $tournamentName and won ₹${winnings.toStringAsFixed(2)}!',
      type: 'tournament_result',
      data: {
        'position': position.toString(),
        'winnings': winnings.toString(),
        'tournamentName': tournamentName,
      },
    );
  }

  Future<void> sendRoomCredentials({
    required String userName,
    required String tournamentName,
    required String roomId,
    required String roomPassword,
  }) async {
    await sendToUser(
      userName: userName,
      title: '🎮 Room Credentials Available',
      body: 'Room ID and password for $tournamentName are now available!',
      type: 'room_credentials',
      data: {
        'roomId': roomId,
        'roomPassword': roomPassword,
        'tournamentName': tournamentName,
      },
    );
  }

  Future<void> sendWithdrawalApproved({
    required String userName,
    required double amount,
  }) async {
    await sendToUser(
      userName: userName,
      title: '✅ Withdrawal Approved',
      body: 'Your withdrawal of ₹${amount.toStringAsFixed(2)} has been approved and processed.',
      type: 'withdrawal_approved',
      data: {
        'amount': amount.toString(),
      },
    );
  }

  Future<void> sendTournamentStarting({
    required String tournamentId,
    required String tournamentName,
    required int minutesLeft,
  }) async {
    await sendToTournamentParticipants(
      tournamentId: tournamentId,
      title: '⚡ Tournament Starting Soon',
      body: '$tournamentName starts in $minutesLeft minutes. Get ready!',
      type: 'tournament_reminder',
      data: {
        'tournamentId': tournamentId,
        'tournamentName': tournamentName,
        'minutesLeft': minutesLeft.toString(),
      },
    );
  }

  Future<void> sendWelcomeBonus({
    required String userName,
    required double bonusAmount,
  }) async {
    await sendToUser(
      userName: userName,
      title: '🎁 Welcome Bonus!',
      body: '₹${bonusAmount.toStringAsFixed(2)} welcome bonus has been added to your wallet!',
      type: 'welcome_bonus',
      data: {
        'amount': bonusAmount.toString(),
      },
    );
  }

  String _getPositionSuffix(int position) {
    if (position == 1) return 'st';
    if (position == 2) return 'nd';
    if (position == 3) return 'rd';
    return 'th';
  }
}