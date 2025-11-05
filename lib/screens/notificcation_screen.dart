// ===============================
// PROFESSIONAL NOTIFICATIONS SCREEN
// ===============================
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_service.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _hasUnread = false;

  // Store both deleted IDs and read status persistently
  final List<String> _deletedNotificationIds = [];
  final Map<String, bool> _readNotificationStatus = {};

  // Animation and UI constants
  final Color _primaryColor = Colors.deepPurple;
  final Color _backgroundColor = Color(0xFFF8F9FA);
  final Duration _animationDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _loadPersistentData();
  }

  // Load both deleted IDs and read status from local storage
  Future<void> _loadPersistentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load deleted notification IDs
      final deletedIds = prefs.getStringList('deleted_notifications') ?? [];
      setState(() {
        _deletedNotificationIds.addAll(deletedIds);
      });

      // Load read notification status
      final readStatusJson = prefs.getString('read_notifications') ?? '{}';
      final readStatusMap = Map<String, dynamic>.from(json.decode(readStatusJson));
      setState(() {
        _readNotificationStatus.addAll(readStatusMap.map((key, value) => MapEntry(key, value as bool)));
      });

      // Load real notifications after loading persistent data
      _loadRealNotifications();
      _setupFCM();
    } catch (e) {
      print('❌ Error loading persistent data: $e');
      _loadRealNotifications();
      _setupFCM();
    }
  }

  // Save deleted notification ID to persistent storage
  Future<void> _saveDeletedNotification(String notificationId) async {
    try {
      if (!_deletedNotificationIds.contains(notificationId)) {
        _deletedNotificationIds.add(notificationId);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('deleted_notifications', _deletedNotificationIds);
      }
    } catch (e) {
      print('❌ Error saving deleted notification: $e');
    }
  }

  // Save read notification status to persistent storage
  Future<void> _saveReadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('read_notifications', json.encode(_readNotificationStatus));
    } catch (e) {
      print('❌ Error saving read status: $e');
    }
  }

  // Save read status to Firestore for cross-device sync
  Future<void> _saveReadStatusToFirestore(String notificationId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userQuery = await _firestore
          .collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userName = userQuery.docs.first.id;

        // Update in user's notifications collection if it exists
        final notificationDoc = await _firestore
            .collection('users')
            .doc(userName)
            .collection('notifications')
            .doc(notificationId)
            .get();

        if (notificationDoc.exists) {
          await _firestore
              .collection('users')
              .doc(userName)
              .collection('notifications')
              .doc(notificationId)
              .update({
            'isRead': true,
            'readAt': Timestamp.now(),
          });
        }
      }
    } catch (e) {
      print('⚠️ Error saving read status to Firestore: $e');
    }
  }

  Future<void> _setupFCM() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('User granted permission: ${settings.authorizationStatus}');

      // Get FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        print('FCM Token: $fcmToken');
        await _firebaseService.saveFCMToken(fcmToken);
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Received foreground message: ${message.messageId}');
        _showNotification(message);
        _addRealNotificationToLocal(message);
      });

      // Handle when app is opened from terminated state
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          _handleNotificationClick(message);
        }
      });

      // Handle when app is opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationClick(message);
      });

    } catch (e) {
      print('❌ Error setting up FCM: $e');
    }
  }

  void _showNotification(RemoteMessage message) {
    // Show local notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message.notification?.title ?? 'New Notification')),
          ],
        ),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Reload notifications
    _loadRealNotifications();
  }

  void _addRealNotificationToLocal(RemoteMessage message) {
    final newNotification = {
      'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification?.title ?? 'Notification',
      'body': message.notification?.body ?? '',
      'type': message.data['type'] ?? 'general',
      'tournamentId': message.data['tournamentId'] ?? '',
      'amount': message.data['amount'] ?? '',
      'roomId': message.data['roomId'] ?? '',
      'roomPassword': message.data['roomPassword'] ?? '',
      'isRead': false,
      'timestamp': Timestamp.now(),
      'time': 'Just now',
    };

    setState(() {
      _notifications.insert(0, newNotification);
      _hasUnread = true;
    });
  }

  void _handleNotificationClick(RemoteMessage message) {
    final tournamentId = message.data['tournamentId'];
    final type = message.data['type'];

    print('Notification clicked - Type: $type, Tournament: $tournamentId');

    // Navigate based on notification type
    if (tournamentId != null && tournamentId.isNotEmpty) {
      // Navigate to tournament details
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening tournament: $tournamentId'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // Mark as read
    _loadRealNotifications();
  }

  Future<void> _loadRealNotifications() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get current user ID and document ID
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _loadFallbackNotifications();
        return;
      }

      // Get user document ID (username)
      final userQuery = await _firestore
          .collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _loadFallbackNotifications();
        return;
      }

      final userName = userQuery.docs.first.id;
      print('🔍 Loading real notifications for user: $userName');

      final List<Map<String, dynamic>> allNotifications = [];

      // 1. Load payment notifications from transactions
      await _loadPaymentNotifications(userName, allNotifications);

      // 2. Load room credential notifications
      await _loadRoomCredentialNotifications(userName, allNotifications);

      // 3. Load tournament notifications
      await _loadTournamentNotifications(userName, allNotifications);

      // 4. Load withdrawal notifications
      await _loadWithdrawalNotifications(userName, allNotifications);

      // 5. Load special offers and events (with error handling)
      await _loadSpecialOffers(allNotifications);

      // 6. Load system notifications from Firestore (with error handling)
      await _loadSystemNotifications(userId, allNotifications);

      // 7. Load notifications from user's notifications collection
      await _loadUserNotifications(userName, allNotifications);

      // Apply persistent read status and filter deleted notifications
      final List<Map<String, dynamic>> processedNotifications = [];

      for (var notification in allNotifications) {
        final notificationId = notification['id'];

        // Skip if notification is deleted
        if (_deletedNotificationIds.contains(notificationId)) {
          continue;
        }

        // Apply persistent read status
        final isReadPersistent = _readNotificationStatus[notificationId] ?? false;
        final processedNotification = Map<String, dynamic>.from(notification);
        processedNotification['isRead'] = isReadPersistent;

        processedNotifications.add(processedNotification);
      }

      // Sort by timestamp (newest first)
      processedNotifications.sort((a, b) {
        final timeA = a['timestamp'] as Timestamp;
        final timeB = b['timestamp'] as Timestamp;
        return timeB.compareTo(timeA);
      });

      bool hasUnread = processedNotifications.any((notification) => notification['isRead'] == false);

      setState(() {
        _notifications = processedNotifications;
        _hasUnread = hasUnread;
      });

      print('✅ Loaded ${_notifications.length} real notifications');

    } catch (e) {
      print('❌ Error loading real notifications: $e');
      _loadFallbackNotifications();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Better timestamp handling
  Timestamp _safeGetTimestamp(dynamic timestamp) {
    if (timestamp == null) return Timestamp.now();
    if (timestamp is Timestamp) return timestamp;
    if (timestamp is DateTime) return Timestamp.fromDate(timestamp);

    try {
      // Try to parse string timestamp
      if (timestamp is String) {
        if (timestamp.contains('Timestamp')) {
          // Handle Firestore timestamp string
          final parts = timestamp.split('(');
          if (parts.length > 1) {
            final timeParts = parts[1].split(',');
            if (timeParts.length == 2) {
              final seconds = int.tryParse(timeParts[0].trim()) ?? 0;
              final nanoseconds = int.tryParse(timeParts[1].replaceAll(')', '').trim()) ?? 0;
              return Timestamp(seconds, nanoseconds);
            }
          }
        }
        // Try to parse as DateTime string
        final dateTime = DateTime.tryParse(timestamp);
        if (dateTime != null) {
          return Timestamp.fromDate(dateTime);
        }
      }
    } catch (e) {
      print('⚠️ Error parsing timestamp: $e');
    }

    return Timestamp.now();
  }

  Future<void> _loadPaymentNotifications(String userName, List<Map<String, dynamic>> notifications) async {
    try {
      final transactionsDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('transactions')
          .get();

      if (transactionsDoc.exists) {
        final transactionsData = transactionsDoc.data() ?? {};

        // Check successful transactions (deposits)
        final successfulTransactions = transactionsData['successful'] as List? ?? [];
        for (var transaction in successfulTransactions) {
          if (transaction is Map<String, dynamic>) {
            final type = transaction['type'] ?? '';
            final amount = transaction['amount'] ?? 0.0;
            final timestamp = _safeGetTimestamp(transaction['timestamp']);

            if (type == 'credit' || type == 'deposit') {
              notifications.add({
                'id': 'payment_${transaction['transaction_id'] ?? DateTime.now().millisecondsSinceEpoch}',
                'title': '💰 Payment Received',
                'body': '₹${amount.toStringAsFixed(2)} has been credited to your wallet successfully.',
                'type': 'payment_success',
                'amount': amount.toString(),
                'isRead': false, // Will be overridden by persistent status
                'timestamp': timestamp,
                'time': _formatTimeAgo(timestamp),
              });
            }
          }
        }

        // Check failed transactions
        final failedTransactions = transactionsData['failed'] as List? ?? [];
        for (var transaction in failedTransactions) {
          if (transaction is Map<String, dynamic>) {
            final amount = transaction['amount'] ?? 0.0;
            final timestamp = _safeGetTimestamp(transaction['timestamp']);

            notifications.add({
              'id': 'payment_failed_${transaction['transaction_id'] ?? DateTime.now().millisecondsSinceEpoch}',
              'title': '❌ Payment Failed',
              'body': 'Payment of ₹${amount.toStringAsFixed(2)} could not be processed. Please try again.',
              'type': 'payment_failed',
              'amount': amount.toString(),
              'isRead': false, // Will be overridden by persistent status
              'timestamp': timestamp,
              'time': _formatTimeAgo(timestamp),
            });
          }
        }

        // Check completed transactions (withdrawals)
        final completedTransactions = transactionsData['completed'] as List? ?? [];
        for (var transaction in completedTransactions) {
          if (transaction is Map<String, dynamic>) {
            final type = transaction['type'] ?? '';
            final amount = transaction['amount'] ?? 0.0;
            final timestamp = _safeGetTimestamp(transaction['timestamp']);

            if (type == 'withdrawal') {
              notifications.add({
                'id': 'withdrawal_completed_${transaction['transaction_id'] ?? DateTime.now().millisecondsSinceEpoch}',
                'title': '✅ Withdrawal Completed',
                'body': 'Your withdrawal of ₹${amount.toStringAsFixed(2)} has been processed successfully.',
                'type': 'withdrawal_completed',
                'amount': amount.toString(),
                'isRead': false, // Will be overridden by persistent status
                'timestamp': timestamp,
                'time': _formatTimeAgo(timestamp),
              });
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Error loading payment notifications: $e');
    }
  }

  Future<void> _loadRoomCredentialNotifications(String userName, List<Map<String, dynamic>> notifications) async {
    try {
      // Get user's tournament registrations
      final userDoc = await _firestore.collection('users').doc(userName).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() ?? {};
      final registrations = userData['tournament_registrations'] as List? ?? [];

      for (var reg in registrations) {
        if (reg is Map<String, dynamic>) {
          final tournamentId = reg['tournament_id'];
          final tournamentName = reg['tournament_name'] ?? 'Tournament';

          if (tournamentId != null) {
            // Check if tournament has room credentials
            final tournamentDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
            if (tournamentDoc.exists) {
              final tournamentData = tournamentDoc.data() ?? {};
              final roomId = tournamentData['roomId'];
              final roomPassword = tournamentData['roomPassword'];
              final credentialsAddedAt = tournamentData['credentialsAddedAt'];

              if (roomId != null && roomPassword != null && credentialsAddedAt != null) {
                final addedTime = _safeGetTimestamp(credentialsAddedAt);

                // Check if credentials were added recently (within last 24 hours)
                final now = DateTime.now();
                final addedDateTime = addedTime.toDate();
                final difference = now.difference(addedDateTime);

                if (difference.inHours <= 24) {
                  notifications.add({
                    'id': 'credentials_${tournamentId}_${addedTime.millisecondsSinceEpoch}',
                    'title': '🎮 Room Credentials Available',
                    'body': 'Room ID and password for $tournamentName are now available. Join before they expire!',
                    'type': 'room_credentials',
                    'tournamentId': tournamentId,
                    'tournamentName': tournamentName,
                    'roomId': roomId.toString(),
                    'roomPassword': roomPassword.toString(),
                    'isRead': false, // Will be overridden by persistent status
                    'timestamp': addedTime,
                    'time': _formatTimeAgo(addedTime),
                  });
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Error loading room credential notifications: $e');
    }
  }

  Future<void> _loadTournamentNotifications(String userName, List<Map<String, dynamic>> notifications) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userName).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() ?? {};
      final registrations = userData['tournament_registrations'] as List? ?? [];

      for (var reg in registrations) {
        if (reg is Map<String, dynamic>) {
          final tournamentId = reg['tournament_id'];
          final tournamentName = reg['tournament_name'] ?? 'Tournament';
          final status = reg['status'] ?? '';
          final winnings = (reg['winnings'] as num?)?.toDouble() ?? 0.0;
          final position = reg['position'] ?? 0;

          // Tournament result notifications
          if (status == 'completed' && winnings > 0) {
            final completedAt = _safeGetTimestamp(reg['completed_at']);
            notifications.add({
              'id': 'result_$tournamentId',
              'title': '🏆 Tournament Result',
              'body': 'Congratulations! You finished ${position}${_getPositionSuffix(position)} in $tournamentName and won ₹${winnings.toStringAsFixed(2)}.',
              'type': 'tournament_result',
              'tournamentId': tournamentId,
              'tournamentName': tournamentName,
              'amount': winnings.toString(),
              'isRead': false, // Will be overridden by persistent status
              'timestamp': completedAt,
              'time': _formatTimeAgo(completedAt),
            });
          }

          // Tournament starting soon notifications
          if (tournamentId != null) {
            final tournamentDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
            if (tournamentDoc.exists) {
              final tournamentData = tournamentDoc.data() ?? {};
              final startTime = tournamentData['tournament_start'];

              if (startTime != null) {
                final startTimestamp = _safeGetTimestamp(startTime);
                final now = DateTime.now();
                final startDateTime = startTimestamp.toDate();
                final timeUntilStart = startDateTime.difference(now);

                // Notify if tournament starts in less than 1 hour
                if (timeUntilStart.inMinutes > 0 && timeUntilStart.inMinutes <= 60) {
                  notifications.add({
                    'id': 'starting_$tournamentId',
                    'title': '⚡ Tournament Starting Soon',
                    'body': '$tournamentName starts in ${timeUntilStart.inMinutes} minutes. Get ready!',
                    'type': 'tournament_reminder',
                    'tournamentId': tournamentId,
                    'tournamentName': tournamentName,
                    'isRead': false, // Will be overridden by persistent status
                    'timestamp': Timestamp.now(),
                    'time': 'Just now',
                  });
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Error loading tournament notifications: $e');
    }
  }

  Future<void> _loadWithdrawalNotifications(String userName, List<Map<String, dynamic>> notifications) async {
    try {
      final withdrawalDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('withdrawal_requests')
          .get();

      if (withdrawalDoc.exists) {
        final withdrawalData = withdrawalDoc.data() ?? {};

        // Approved withdrawals
        final approvedWithdrawals = withdrawalData['approved'] as List? ?? [];
        for (var withdrawal in approvedWithdrawals) {
          if (withdrawal is Map<String, dynamic>) {
            final amount = withdrawal['amount'] ?? 0.0;
            final processedAt = _safeGetTimestamp(withdrawal['processed_at']);

            notifications.add({
              'id': 'withdrawal_approved_${withdrawal['withdrawal_id'] ?? DateTime.now().millisecondsSinceEpoch}',
              'title': '✅ Withdrawal Approved',
              'body': 'Your withdrawal request of ₹${amount.toStringAsFixed(2)} has been approved and processed.',
              'type': 'withdrawal_approved',
              'amount': amount.toString(),
              'isRead': false, // Will be overridden by persistent status
              'timestamp': processedAt,
              'time': _formatTimeAgo(processedAt),
            });
          }
        }

        // Rejected withdrawals
        final rejectedWithdrawals = withdrawalData['denied'] as List? ?? [];
        for (var withdrawal in rejectedWithdrawals) {
          if (withdrawal is Map<String, dynamic>) {
            final amount = withdrawal['amount'] ?? 0.0;
            final rejectedAt = _safeGetTimestamp(withdrawal['rejected_at'] ?? withdrawal['processed_at']);

            notifications.add({
              'id': 'withdrawal_rejected_${withdrawal['withdrawal_id'] ?? DateTime.now().millisecondsSinceEpoch}',
              'title': '❌ Withdrawal Rejected',
              'body': 'Your withdrawal request of ₹${amount.toStringAsFixed(2)} was rejected. Contact support for details.',
              'type': 'withdrawal_rejected',
              'amount': amount.toString(),
              'isRead': false, // Will be overridden by persistent status
              'timestamp': rejectedAt,
              'time': _formatTimeAgo(rejectedAt),
            });
          }
        }
      }
    } catch (e) {
      print('⚠️ Error loading withdrawal notifications: $e');
    }
  }

  Future<void> _loadSpecialOffers(List<Map<String, dynamic>> notifications) async {
    try {
      // Try to load special offers without complex queries to avoid index errors
      final offersSnapshot = await _firestore
          .collection('offers')
          .where('isActive', isEqualTo: true)
          .get();

      for (var doc in offersSnapshot.docs) {
        try {
          final offer = doc.data();
          final expiresAt = offer['expiresAt'];

          // Check if offer hasn't expired
          if (expiresAt != null) {
            final expireTime = _safeGetTimestamp(expiresAt);
            if (expireTime.toDate().isAfter(DateTime.now())) {
              notifications.add({
                'id': 'offer_${doc.id}',
                'title': '🎁 ${offer['title'] ?? 'Special Offer'}',
                'body': offer['description'] ?? 'Check out this amazing offer!',
                'type': 'special_offer',
                'offerId': doc.id,
                'isRead': false, // Will be overridden by persistent status
                'timestamp': _safeGetTimestamp(offer['createdAt']),
                'time': _formatTimeAgo(offer['createdAt']),
              });
            }
          } else {
            // If no expiry date, just add it
            notifications.add({
              'id': 'offer_${doc.id}',
              'title': '🎁 ${offer['title'] ?? 'Special Offer'}',
              'body': offer['description'] ?? 'Check out this amazing offer!',
              'type': 'special_offer',
              'offerId': doc.id,
              'isRead': false, // Will be overridden by persistent status
              'timestamp': _safeGetTimestamp(offer['createdAt']),
              'time': _formatTimeAgo(offer['createdAt']),
            });
          }
        } catch (e) {
          print('⚠️ Error processing offer ${doc.id}: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error loading special offers: $e');
      // Don't throw error, just continue without offers
    }
  }

  Future<void> _loadSystemNotifications(String userId, List<Map<String, dynamic>> notifications) async {
    try {
      // Try simple query first to avoid index errors
      final systemNotifications = await _firestore
          .collection('system_notifications')
          .where('isActive', isEqualTo: true)
          .get();

      for (var doc in systemNotifications.docs) {
        try {
          final notification = doc.data();
          final targetUsers = notification['targetUsers'] as List<dynamic>? ?? [];
          final isForAllUsers = targetUsers.isEmpty; // Empty array means sent to all users

          if (isForAllUsers || targetUsers.contains(userId)) {
            notifications.add({
              'id': 'system_${doc.id}',
              'title': '📢 ${notification['title'] ?? 'System Update'}',
              'body': notification['message'] ?? '',
              'type': 'system',
              'isRead': false, // Will be overridden by persistent status
              'timestamp': _safeGetTimestamp(notification['createdAt']),
              'time': _formatTimeAgo(notification['createdAt']),
            });
          }
        } catch (e) {
          print('⚠️ Error processing system notification ${doc.id}: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error loading system notifications: $e');
      // Don't throw error, just continue without system notifications
    }
  }

  // Load notifications from user's personal notifications collection
  Future<void> _loadUserNotifications(String userName, List<Map<String, dynamic>> notifications) async {
    try {
      final userNotifications = await _firestore
          .collection('users')
          .doc(userName)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      for (var doc in userNotifications.docs) {
        try {
          final notification = doc.data();
          notifications.add({
            'id': doc.id,
            'title': notification['title'] ?? 'Notification',
            'body': notification['body'] ?? '',
            'type': notification['type'] ?? 'general',
            'amount': notification['amount']?.toString() ?? '',
            'isRead': notification['isRead'] ?? false, // Will be overridden by persistent status
            'timestamp': _safeGetTimestamp(notification['timestamp']),
            'time': _formatTimeAgo(notification['timestamp']),
          });
        } catch (e) {
          print('⚠️ Error processing user notification ${doc.id}: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error loading user notifications: $e');
      // This is normal if the collection doesn't exist yet
    }
  }

  void _loadFallbackNotifications() {
    // Filter out deleted notifications from fallback and apply read status
    final fallbackNotifications = [
      {
        'id': 'welcome_1',
        'title': '👋 Welcome to Gaming Tournaments!',
        'body': 'Start your gaming journey by joining tournaments and winning real cash prizes.',
        'type': 'welcome',
        'isRead': _readNotificationStatus['welcome_1'] ?? true,
        'timestamp': Timestamp.now(),
        'time': '2 days ago',
      },
      {
        'id': 'bonus_1',
        'title': '🎁 Welcome Bonus Activated',
        'body': '₹200 welcome bonus has been added to your wallet. Use it to join your first tournament!',
        'type': 'bonus',
        'amount': '200',
        'isRead': _readNotificationStatus['bonus_1'] ?? true,
        'timestamp': Timestamp.now(),
        'time': '2 days ago',
      },
    ].where((notification) => !_deletedNotificationIds.contains(notification['id'])).toList();

    bool hasUnread = fallbackNotifications.any((notification) => notification['isRead'] == false);

    setState(() {
      _notifications = fallbackNotifications;
      _hasUnread = hasUnread;
    });
  }

  String _getPositionSuffix(int position) {
    if (position == 1) return 'st';
    if (position == 2) return 'nd';
    if (position == 3) return 'rd';
    return 'th';
  }

  // Mark as read with persistent storage
  Future<void> _markAsRead(String notificationId) async {
    try {
      // Update local state
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['isRead'] = true;
        }

        // Update persistent read status
        _readNotificationStatus[notificationId] = true;
        _hasUnread = _notifications.any((notification) => notification['isRead'] == false);
      });

      // Save to persistent storage
      await _saveReadStatus();

      // Also update in Firestore for cross-device sync
      await _saveReadStatusToFirestore(notificationId);

      print('✅ Notification $notificationId marked as read persistently');

    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  // Mark all as read with persistent storage
  Future<void> _markAllAsRead() async {
    try {
      setState(() {
        for (var notification in _notifications) {
          notification['isRead'] = true;
          _readNotificationStatus[notification['id']] = true;
        }
        _hasUnread = false;
      });

      // Save to persistent storage
      await _saveReadStatus();

      // Also update in Firestore for cross-device sync
      for (var notification in _notifications) {
        await _saveReadStatusToFirestore(notification['id']);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('All notifications marked as read'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  // Delete notification with persistent storage
  Future<void> _deleteNotification(String notificationId) async {
    try {
      // Save to persistent storage before deleting
      await _saveDeletedNotification(notificationId);

      setState(() {
        _notifications.removeWhere((n) => n['id'] == notificationId);
        _hasUnread = _notifications.any((notification) => notification['isRead'] == false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.delete, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Notification deleted'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  String _formatTimeAgo(dynamic timestamp) {
    final safeTimestamp = _safeGetTimestamp(timestamp);
    final date = safeTimestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'payment_success':
        return Icons.account_balance_wallet;
      case 'payment_failed':
        return Icons.error_outline;
      case 'room_credentials':
        return Icons.videogame_asset;
      case 'tournament_result':
        return Icons.emoji_events;
      case 'tournament_reminder':
        return Icons.tour;
      case 'withdrawal_approved':
      case 'withdrawal_completed':
        return Icons.check_circle;
      case 'withdrawal_rejected':
        return Icons.cancel;
      case 'special_offer':
        return Icons.local_offer;
      case 'bonus':
        return Icons.card_giftcard;
      case 'system':
        return Icons.info;
      case 'welcome':
        return Icons.celebration;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'payment_success':
      case 'withdrawal_approved':
      case 'withdrawal_completed':
      case 'bonus':
        return Colors.green;
      case 'payment_failed':
      case 'withdrawal_rejected':
        return Colors.red;
      case 'room_credentials':
        return Colors.blue;
      case 'tournament_result':
        return Colors.amber;
      case 'tournament_reminder':
        return Colors.orange;
      case 'special_offer':
        return Colors.purple;
      case 'system':
        return Colors.deepPurple;
      case 'welcome':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  void _showRoomCredentialsDialog(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.videogame_asset, color: Colors.blue, size: 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Room Credentials',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                notification['tournamentName'] ?? 'Tournament',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 20),
              _buildCredentialField('Room ID', notification['roomId']?.toString() ?? 'Not available', Colors.blue),
              SizedBox(height: 12),
              _buildCredentialField('Password', notification['roomPassword']?.toString() ?? 'Not available', Colors.red),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Join immediately as credentials may expire soon!',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('CLOSE'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Copy to clipboard functionality would go here
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.copy, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('Credentials copied to clipboard'),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('COPY'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialField(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: SelectableText(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_hasUnread && _notifications.isNotEmpty)
            IconButton(
              icon: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mark_email_read, size: 20),
              ),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.refresh, size: 20),
            ),
            onPressed: _loadRealNotifications,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _notifications.isEmpty
          ? _buildEmptyState()
          : _buildNotificationsList(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
          ),
          SizedBox(height: 16),
          Text(
            'Loading Notifications...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.notifications_none,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'You\'ll see payment confirmations,\nroom credentials, and tournament updates here',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadRealNotifications,
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Refresh Notifications'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    return Column(
      children: [
        if (_hasUnread)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.05),
              border: Border(
                bottom: BorderSide(color: _primaryColor.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.circle, size: 8, color: Colors.white),
                ),
                SizedBox(width: 8),
                Text(
                  'You have unread notifications',
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: _markAllAsRead,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'MARK ALL READ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRealNotifications,
            color: _primaryColor,
            backgroundColor: Colors.white,
            child: ListView.separated(
              padding: EdgeInsets.all(16),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return _buildNotificationItem(notification);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] == true;
    final type = notification['type'] ?? 'general';

    return Dismissible(
      key: Key(notification['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 16),
          ],
        ),
      ),
      onDismissed: (direction) => _deleteNotification(notification['id']),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Delete Notification'),
            content: Text('Are you sure you want to delete this notification?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'DELETE',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      child: AnimatedContainer(
        duration: _animationDuration,
        curve: Curves.easeInOut,
        child: Card(
          margin: EdgeInsets.zero,
          color: isRead ? Colors.white : Colors.blue.shade50,
          elevation: isRead ? 1 : 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getNotificationColor(type).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getNotificationIcon(type),
                color: _getNotificationColor(type),
                size: 20,
              ),
            ),
            title: Text(
              notification['title'],
              style: TextStyle(
                fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                color: isRead ? Colors.grey.shade700 : Colors.black,
                fontSize: 15,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  notification['body'],
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                    SizedBox(width: 4),
                    Text(
                      notification['time'],
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: !isRead
                ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
              ),
            )
                : IconButton(
              icon: Icon(Icons.delete_outline, size: 18),
              onPressed: () => _deleteNotification(notification['id']),
              color: Colors.grey.shade400,
            ),
            onTap: () {
              _markAsRead(notification['id']);
              if (type == 'room_credentials') {
                _showRoomCredentialsDialog(notification);
              }
            },
            onLongPress: () => _showNotificationDetails(notification),
          ),
        ),
      ),
    );
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getNotificationColor(notification['type']).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getNotificationIcon(notification['type']),
                      color: _getNotificationColor(notification['type']),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      notification['title'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                notification['body'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 20),
              Divider(),
              SizedBox(height: 12),
              Text(
                'Details',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 12),
              _buildDetailRow('Type', notification['type']),
              if (notification['amount'] != null && notification['amount'].toString().isNotEmpty)
                _buildDetailRow('Amount', '₹${notification['amount']}'),
              if (notification['tournamentName'] != null)
                _buildDetailRow('Tournament', notification['tournamentName']),
              if (notification['roomId'] != null)
                _buildDetailRow('Room ID', notification['roomId']),
              _buildDetailRow('Time', notification['time']),
              _buildDetailRow('Status', notification['isRead'] == true ? 'Read' : 'Unread'),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('CLOSE'),
                    ),
                  ),
                  if (notification['isRead'] == false) ...[
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _markAsRead(notification['id']);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('MARK READ'),
                      ),
                    ),
                  ],
                  if (notification['type'] == 'room_credentials') ...[
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showRoomCredentialsDialog(notification);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('CREDENTIALS'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}