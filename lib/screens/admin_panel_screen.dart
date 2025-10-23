import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../modles/user_registration_model.dart';
import '../services/firebase_service.dart';

class AdminPanelScreen extends StatefulWidget {
  @override
  _AdminPanelScreenState createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _tournaments = [];
  List<AppUser> _users = [];
  List<Map<String, dynamic>> _withdrawRequests = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _matchCredentials = [];

  bool _isLoading = true;
  bool _isAdmin = false;
  int _currentIndex = 0;

  // Statistics
  int _totalUsers = 0;
  int _totalTournaments = 0;
  int _pendingWithdrawals = 0;
  double _totalRevenue = 0.0;
  int _activeTournaments = 0;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showAccessDenied();
        return;
      }

      print('🔐 Checking admin access for UID: ${user.uid}');

      // Find user by UID in users collection
      final userQuery = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userDoc = userQuery.docs.first;
        final userData = userDoc.data();
        final role = userData['role'] as String? ?? 'user';

        print('✅ User found: ${userDoc.id}');
        print('🎯 User role: $role');

        if (role == 'admin') {
          setState(() {
            _isAdmin = true;
          });
          _loadData();
        } else {
          print('❌ Access denied: User role is $role, expected admin');
          _showAccessDenied();
        }
      } else {
        print('❌ User document not found for UID: ${user.uid}');
        _showAccessDenied();
      }
    } catch (e) {
      print('❌ Error checking admin access: $e');
      _showAccessDenied();
    }
  }

  void _showAccessDenied() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Access Denied'),
          content: Text('You do not have permission to access the admin panel.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _loadData() async {
    try {
      await Future.wait([
        _loadUsers(),
        _loadTournaments(),
        _loadWithdrawRequests(),
        _loadTransactions(),
        _loadMatchCredentials(),
        _loadStatistics(),
      ]);
      print('✅ All data loaded successfully');
    } catch (e) {
      print('❌ Error loading admin data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    try {
      print('👥 Loading users...');
      final usersSnapshot = await _firestore.collection('users').get();

      List<AppUser> loadedUsers = [];

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userName = userDoc.id;

        double totalBalance = 0.0;
        double totalWinning = 0.0;

        try {
          // Get wallet data from new structure
          final walletDataDoc = await _firestore
              .collection('wallet')
              .doc('users')
              .collection(userName)
              .doc('wallet_data')
              .get();

          if (walletDataDoc.exists) {
            final walletData = walletDataDoc.data();
            totalBalance = (walletData?['total_balance'] as num?)?.toDouble() ?? 0.0;
            totalWinning = (walletData?['total_winning'] as num?)?.toDouble() ?? 0.0;
          }
        } catch (e) {
          print('⚠️ Error loading wallet for user $userName: $e');
        }

        loadedUsers.add(AppUser(
          userId: userData['uid'] ?? userDoc.id,
          email: userData['email'] ?? 'No Email',
          name: userData['name'] ?? userName,
          phone: userData['phone'] ?? '',
          fcmToken: userData['fcmToken'] ?? '',
          totalWinning: totalWinning,
          totalBalance: totalBalance,
          createdAt: (userData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastLogin: (userData['last_login'] as Timestamp?)?.toDate() ?? DateTime.now(),
          tournaments: userData['tournaments'] ?? {},
          matches: userData['matches'] ?? {},
          withdrawRequests: [],
          transactions: [],
          tournamentRegistrations: userData['tournament_registrations'] ?? [],
          role: userData['role'] ?? 'user',
        ));
      }

      setState(() {
        _users = loadedUsers;
      });
      print('✅ Users loaded: ${_users.length}');
    } catch (e) {
      print('❌ Error loading users: $e');
    }
  }

  Future<void> _loadTournaments() async {
    try {
      print('🏆 Loading tournaments...');
      final snapshot = await _firestore.collection('tournaments').get();

      setState(() {
        _tournaments = snapshot.docs.map((doc) {
          final data = doc.data();
          final totalSlots = (data['total_slots'] as num?)?.toInt() ?? 0;
          final registeredPlayers = (data['registered_players'] as num?)?.toInt() ?? 0;

          return {
            'id': doc.id,
            ...data,
            'slots_left': totalSlots - registeredPlayers,
            'tournament_name': data['tournament_name'] ?? 'Unnamed Tournament',
            'game_name': data['game_name'] ?? 'Unknown Game',
            'entry_fee': (data['entry_fee'] as num?)?.toDouble() ?? 0.0,
            'status': data['status'] ?? 'unknown',
          };
        }).toList();
      });
      print('✅ Tournaments loaded: ${_tournaments.length}');
    } catch (e) {
      print('❌ Error loading tournaments: $e');
      setState(() {
        _tournaments = [];
      });
    }
  }

  Future<void> _loadWithdrawRequests() async {
    try {
      print('💰 Loading withdrawal requests...');
      final List<Map<String, dynamic>> allWithdrawRequests = [];

      final usersSnapshot = await _firestore.collection('users').get();

      for (var userDoc in usersSnapshot.docs) {
        final userName = userDoc.id;
        final userData = userDoc.data();

        try {
          final withdrawSnapshot = await _firestore
              .collection('wallet')
              .doc('users')
              .collection(userName)
              .doc('withdrawal_requests')
              .get();

          if (withdrawSnapshot.exists) {
            final withdrawData = withdrawSnapshot.data() ?? {};
            final pendingRequests = withdrawData['pending'] as List<dynamic>? ?? [];

            for (var request in pendingRequests) {
              if (request is Map<String, dynamic>) {
                allWithdrawRequests.add({
                  'id': request['withdrawal_id'] ?? '${DateTime.now().millisecondsSinceEpoch}',
                  'userId': userName,
                  'userEmail': userData['email'] ?? 'No Email',
                  'userName': userData['name'] ?? userName,
                  'amount': (request['amount'] as num?)?.toDouble() ?? 0.0,
                  'payment_method': request['payment_method'] ?? 'No Method',
                  'account_details': request['account_details'] ?? 'No Details',
                  'status': 'pending',
                  'requested_at': request['requested_at'] ?? Timestamp.now(),
                  'timestamp': request['timestamp'] ?? Timestamp.now(),
                });
              }
            }
          }
        } catch (e) {
          print('⚠️ Error loading withdrawals for user $userName: $e');
        }
      }

      allWithdrawRequests.sort((a, b) {
        final timeA = a['timestamp'] as Timestamp;
        final timeB = b['timestamp'] as Timestamp;
        return timeB.compareTo(timeA);
      });

      setState(() {
        _withdrawRequests = allWithdrawRequests;
      });
      print('✅ Withdrawal requests loaded: ${_withdrawRequests.length}');
    } catch (e) {
      print('❌ Error loading withdraw requests: $e');
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final List<Map<String, dynamic>> allTransactions = [];
      final usersSnapshot = await _firestore.collection('users').get();

      for (var userDoc in usersSnapshot.docs) {
        final userName = userDoc.id;
        final userData = userDoc.data();

        try {
          final transactionsSnapshot = await _firestore
              .collection('wallet')
              .doc('users')
              .collection(userName)
              .doc('transactions')
              .get();

          if (transactionsSnapshot.exists) {
            final transactionsData = transactionsSnapshot.data() ?? {};
            final statusTypes = ['successful', 'pending', 'failed'];

            for (var status in statusTypes) {
              final transactions = transactionsData[status] as List<dynamic>? ?? [];

              for (var transaction in transactions) {
                if (transaction is Map<String, dynamic>) {
                  allTransactions.add({
                    'id': transaction['transaction_id'] ?? 'unknown',
                    'userId': userName,
                    'userName': userData['name'] ?? userName,
                    'amount': (transaction['amount'] as num?)?.toDouble() ?? 0.0,
                    'type': transaction['type'] ?? 'unknown',
                    'description': transaction['description'] ?? 'No Description',
                    'status': status,
                    'payment_method': transaction['payment_method'] ?? 'No Method',
                    'timestamp': transaction['timestamp'] ?? Timestamp.now(),
                  });
                }
              }
            }
          }
        } catch (e) {
          print('⚠️ Error loading transactions for user $userName: $e');
        }
      }

      allTransactions.sort((a, b) {
        final timeA = a['timestamp'] as Timestamp;
        final timeB = b['timestamp'] as Timestamp;
        return timeB.compareTo(timeA);
      });

      setState(() {
        _transactions = allTransactions;
      });
      print('✅ Transactions loaded: ${_transactions.length}');
    } catch (e) {
      print('❌ Error loading transactions: $e');
    }
  }

  Future<void> _loadMatchCredentials() async {
    try {
      final snapshot = await _firestore
          .collection('matchCredentials')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _matchCredentials = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'tournamentId': data['tournamentId'],
            'tournamentName': _getTournamentName(data['tournamentId']),
            'roomId': data['roomId'],
            'roomPassword': data['roomPassword'],
            'matchTime': data['matchTime'],
            'credentialsAddedAt': data['credentialsAddedAt'],
            'status': data['status'] ?? 'active',
            'participants': (data['participants'] as List?)?.length ?? 0,
            'createdAt': data['createdAt'],
          };
        }).toList();
      });
      print('✅ Match credentials loaded: ${_matchCredentials.length}');
    } catch (e) {
      print('❌ Error loading match credentials: $e');
    }
  }

  String _getTournamentName(String tournamentId) {
    final tournament = _tournaments.firstWhere(
          (t) => t['id'] == tournamentId,
      orElse: () => {'tournament_name': 'Unknown Tournament'},
    );
    return tournament['tournament_name'];
  }

  Future<void> _loadStatistics() async {
    try {
      print('📈 Loading statistics...');

      final usersSnapshot = await _firestore.collection('users').get();
      final tournamentsSnapshot = await _firestore.collection('tournaments').get();

      double totalRevenue = 0.0;
      for (var tournament in _tournaments) {
        final entryFee = (tournament['entry_fee'] as num?)?.toDouble() ?? 0.0;
        final registeredPlayers = (tournament['registered_players'] as num?)?.toInt() ?? 0;
        totalRevenue += entryFee * registeredPlayers;
      }

      setState(() {
        _totalUsers = usersSnapshot.docs.length;
        _totalTournaments = tournamentsSnapshot.docs.length;
        _activeTournaments = _tournaments.where((t) => t['status'] == 'upcoming').length;
        _pendingWithdrawals = _withdrawRequests.length;
        _totalRevenue = totalRevenue;
      });

      print('''
      📊 Statistics Loaded:
      - Users: $_totalUsers
      - Tournaments: $_totalTournaments
      - Active Tournaments: $_activeTournaments
      - Pending Withdrawals: $_pendingWithdrawals
      - Total Revenue: $_totalRevenue
      ''');
    } catch (e) {
      print('❌ Error loading statistics: $e');
    }
  }

  // FIXED: Completely rewritten withdrawal status update method
  Future<void> _updateWithdrawStatus(String requestId, String status) async {
    try {
      final request = _withdrawRequests.firstWhere((req) => req['id'] == requestId);
      final userName = request['userId'];
      final amount = request['amount'] as double;

      if (userName == null) {
        throw Exception('User name not found in withdrawal request');
      }

      print('🔄 Processing withdrawal $status for user: $userName, amount: $amount');

      final withdrawRef = _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('withdrawal_requests');

      final withdrawSnapshot = await withdrawRef.get();

      if (!withdrawSnapshot.exists) {
        throw Exception('Withdrawal document not found for user: $userName');
      }

      final withdrawData = withdrawSnapshot.data() ?? {};
      final pendingRequests = withdrawData['pending'] as List<dynamic>? ?? [];

      // Find the request to update
      final requestIndex = pendingRequests.indexWhere((req) {
        if (req is Map<String, dynamic>) {
          final reqId = req['withdrawal_id'] ?? req['id'];
          return reqId == requestId;
        }
        return false;
      });

      if (requestIndex == -1) {
        throw Exception('Withdrawal request not found in pending list');
      }

      final requestToUpdate = Map<String, dynamic>.from(pendingRequests[requestIndex] as Map<String, dynamic>);

      // Remove from pending
      final updatedPending = List<dynamic>.from(pendingRequests);
      updatedPending.removeAt(requestIndex);

      // Prepare update data
      final updateData = <String, dynamic>{
        'pending': updatedPending,
      };

      if (status == 'approved') {
        // Add to approved list
        final approvedRequests = withdrawData['approved'] as List<dynamic>? ?? [];
        requestToUpdate['status'] = 'approved';
        requestToUpdate['processed_at'] = Timestamp.now();

        updateData['approved'] = FieldValue.arrayUnion([requestToUpdate]);

        print('✅ Withdrawal approved, moving to approved list');

      } else if (status == 'denied') {
        // Add to denied list and refund balance
        final deniedRequests = withdrawData['denied'] as List<dynamic>? ?? [];
        requestToUpdate['status'] = 'denied';
        requestToUpdate['processed_at'] = Timestamp.now();

        updateData['denied'] = FieldValue.arrayUnion([requestToUpdate]);

        // Refund the amount back to user's wallet
        final balanceRef = _firestore
            .collection('wallet')
            .doc('users')
            .collection(userName)
            .doc('wallet_data');

        final balanceSnapshot = await balanceRef.get();
        if (balanceSnapshot.exists) {
          await balanceRef.update({
            'total_balance': FieldValue.increment(amount),
            'updatedAt': Timestamp.now(),
          });
          print('💰 Amount refunded to user wallet: ₹$amount');
        }

        print('❌ Withdrawal denied, moving to denied list and refunding amount');
      }

      // Update the withdrawal requests document
      await withdrawRef.update(updateData);

      // Add transaction record
      final transactionsRef = _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('transactions');

      final transactionData = {
        'transaction_id': 'withdraw_${DateTime.now().millisecondsSinceEpoch}',
        'amount': amount,
        'type': 'withdrawal',
        'description': status == 'approved' ? 'Withdrawal Approved' : 'Withdrawal Rejected',
        'status': status == 'approved' ? 'completed' : 'failed',
        'payment_method': request['payment_method'],
        'timestamp': Timestamp.now(),
      };

      await transactionsRef.set({
        status == 'approved' ? 'completed' : 'failed': FieldValue.arrayUnion([transactionData])
      }, SetOptions(merge: true));

      // Send notification to user
      await _sendPaymentNotification(
        userName: userName,
        title: status == 'approved' ? 'Withdrawal Approved' : 'Withdrawal Rejected',
        body: status == 'approved'
            ? 'Your withdrawal of ₹$amount has been approved and processed.'
            : 'Your withdrawal of ₹$amount was rejected. Amount has been refunded to your wallet.',
        type: 'withdrawal_approved',
        amount: amount,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Withdrawal $status successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload data
      await _loadWithdrawRequests();
      await _loadStatistics();

    } catch (e) {
      print('❌ Error updating withdrawal status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating withdrawal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addMatchCredentials(String tournamentId) async {
    try {
      final roomId = 'ROOM${DateTime.now().millisecondsSinceEpoch}';
      final roomPassword = 'PASS${DateTime.now().millisecondsSinceEpoch ~/ 1000}';

      final tournamentDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
      if (!tournamentDoc.exists) {
        throw Exception('Tournament not found');
      }

      final tournamentData = tournamentDoc.data()!;
      final tournamentStart = tournamentData['tournament_start'] as Timestamp;

      await _firestore.collection('tournaments').doc(tournamentId).update({
        'roomId': roomId,
        'roomPassword': roomPassword,
        'credentialsMatchTime': tournamentStart,
        'credentialsAddedAt': Timestamp.now(),
        'updated_at': Timestamp.now(),
      });

      await _firestore.collection('matchCredentials').add({
        'tournamentId': tournamentId,
        'tournamentName': tournamentData['tournament_name'],
        'roomId': roomId,
        'roomPassword': roomPassword,
        'matchTime': tournamentStart,
        'releasedAt': Timestamp.now(),
        'status': 'active',
        'createdAt': Timestamp.now(),
      });

      // Send notification to all registered users
      await _sendCredentialsNotification({
        'tournamentId': tournamentId,
        'tournamentName': tournamentData['tournament_name'],
        'roomId': roomId,
        'roomPassword': roomPassword,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Match credentials added successfully! They will be available 30 minutes before match time.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadTournaments();
      await _loadMatchCredentials();
    } catch (e) {
      print('❌ Error adding match credentials: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding match credentials: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // UPDATED: Send push notification using HTTP v1 API
  Future<void> _sendPushNotification({
    required String title,
    required String body,
    required String fcmToken,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Replace with your actual project ID
      final String projectId = 'your-project-id'; // Get from Firebase Console > Project Settings

      // For testing, you can use legacy server key temporarily
      // Get from Firebase Console > Project Settings > Cloud Messaging > Server Key
      const String serverKey = 'YOUR_LEGACY_SERVER_KEY_HERE';

      if (fcmToken.isEmpty || fcmToken == 'null') {
        print('❌ Invalid FCM token');
        return;
      }

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode(<String, dynamic>{
          'notification': <String, dynamic>{
            'title': title,
            'body': body,
            'sound': 'default',
          },
          'data': data ?? <String, dynamic>{},
          'to': fcmToken,
          'priority': 'high',
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Notification sent successfully to token: ${fcmToken.substring(0, 20)}...');
        print('Response: ${response.body}');
      } else {
        print('❌ Failed to send notification. Status code: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending push notification: $e');
    }
  }

  // NEW: Send payment notification to specific user
  Future<void> _sendPaymentNotification({
    required String userName,
    required String title,
    required String body,
    required String type,
    double? amount,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userName).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final fcmToken = userData['fcmToken'] as String?;

        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _sendPushNotification(
            title: title,
            body: body,
            fcmToken: fcmToken,
            data: {
              'type': type,
              'amount': amount?.toString() ?? '',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
            },
          );

          // Also save notification to user's document for persistence
          await _saveUserNotification(
            userName: userName,
            title: title,
            body: body,
            type: type,
            amount: amount,
          );
        } else {
          print('⚠️ No FCM token found for user: $userName');
        }
      }
    } catch (e) {
      print('❌ Error sending payment notification: $e');
    }
  }

  // NEW: Save notification to user's document
  Future<void> _saveUserNotification({
    required String userName,
    required String title,
    required String body,
    required String type,
    double? amount,
  }) async {
    try {
      final notificationData = {
        'id': 'notif_${DateTime.now().millisecondsSinceEpoch}',
        'title': title,
        'body': body,
        'type': type,
        'amount': amount,
        'isRead': false,
        'timestamp': Timestamp.now(),
        'createdAt': Timestamp.now(),
      };

      await _firestore
          .collection('users')
          .doc(userName)
          .collection('notifications')
          .add(notificationData);

      print('✅ Notification saved to user document: $userName');
    } catch (e) {
      print('❌ Error saving notification to user document: $e');
    }
  }

  // NEW: Send notification to all users
  Future<void> _sendNotificationToAllUsers() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController bodyController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Notification to All Users'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Notification Title',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: bodyController,
              decoration: InputDecoration(
                labelText: 'Notification Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty || bodyController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter both title and message'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _sendBulkNotification(
                title: titleController.text,
                body: bodyController.text,
              );
            },
            child: Text('SEND'),
          ),
        ],
      ),
    );
  }

  // NEW: Send bulk notification
  Future<void> _sendBulkNotification({required String title, required String body}) async {
    try {
      // Get all user FCM tokens
      final usersSnapshot = await _firestore.collection('users').get();
      int successCount = 0;
      int totalCount = 0;

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final fcmToken = userData['fcmToken'] as String?;

        if (fcmToken != null && fcmToken.isNotEmpty) {
          totalCount++;
          await _sendPushNotification(
            title: title,
            body: body,
            fcmToken: fcmToken,
            data: {
              'type': 'admin_notification',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
          );
          successCount++;

          // Add delay to avoid rate limiting
          await Future.delayed(Duration(milliseconds: 100));
        }
      }

      // Save notification to Firestore for persistence
      await _firestore.collection('system_notifications').add({
        'title': title,
        'message': body,
        'sentTo': successCount,
        'totalUsers': totalCount,
        'sentAt': Timestamp.now(),
        'isActive': true,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification sent to $successCount/$totalCount users'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error sending bulk notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // UPDATED: Send credentials notification with actual FCM
  Future<void> _sendCredentialsNotification(Map<String, dynamic> credential) async {
    try {
      final tournamentId = credential['tournamentId'];
      final tournamentName = credential['tournamentName'];
      final roomId = credential['roomId'];
      final roomPassword = credential['roomPassword'];

      final usersSnapshot = await _firestore.collection('users').get();
      int notificationCount = 0;

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userName = userDoc.id;

        final registrations = userData['tournament_registrations'] as List<dynamic>? ?? [];
        final isRegistered = registrations.any((reg) =>
        reg is Map<String, dynamic> &&
            reg['tournament_id'] == tournamentId &&
            reg['status'] == 'registered'
        );

        if (isRegistered) {
          final fcmToken = userData['fcmToken'] as String?;
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await _sendPushNotification(
              title: '🎮 Room Credentials Available - $tournamentName',
              body: 'Room ID and password are now available. Join before they expire!',
              fcmToken: fcmToken,
              data: {
                'type': 'room_credentials',
                'tournamentId': tournamentId,
                'tournamentName': tournamentName,
                'roomId': roomId,
                'roomPassword': roomPassword,
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
            );

            notificationCount++;

            // Add delay to avoid rate limiting
            await Future.delayed(Duration(milliseconds: 100));
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Room credentials notification sent to $notificationCount participants'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error sending credentials notifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending notifications: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // NEW: Manual method to send payment success notification
  Future<void> _sendManualPaymentNotification(String userName, double amount) async {
    try {
      await _sendPaymentNotification(
        userName: userName,
        title: '💰 Payment Successful',
        body: '₹$amount has been credited to your wallet successfully.',
        type: 'payment_success',
        amount: amount,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment notification sent to $userName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error sending manual payment notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // NEW: Show dialog to send manual payment notification
  void _showManualPaymentDialog() {
    final TextEditingController userNameController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Payment Notification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userNameController,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Enter username from users list',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (userNameController.text.isEmpty || amountController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter both username and amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final amount = double.tryParse(amountController.text);
              if (amount == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _sendManualPaymentNotification(userNameController.text.trim(), amount);
            },
            child: Text('SEND NOTIFICATION'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTournament(String tournamentId) async {
    try {
      await _firestore.collection('tournaments').doc(tournamentId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tournament deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadTournaments();
      await _loadStatistics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting tournament: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateTournamentStatus(String tournamentId, String status) async {
    try {
      await _firestore.collection('tournaments').doc(tournamentId).update({
        'status': status,
        'updated_at': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tournament status updated to $status'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadTournaments();
      await _loadStatistics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating tournament: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteMatchCredentials(String credentialId) async {
    try {
      await _firestore.collection('matchCredentials').doc(credentialId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Match credentials deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadMatchCredentials();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting credentials: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateMatchCredentials(String credentialId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('matchCredentials').doc(credentialId).update(updates);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Match credentials updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadMatchCredentials();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating credentials: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddTournamentDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddTournamentDialog(
        onTournamentAdded: () {
          _loadTournaments();
          _loadStatistics();
        },
      ),
    );
  }

  void _showEditTournamentDialog(Map<String, dynamic> tournament) {
    showDialog(
      context: context,
      builder: (context) => _AddTournamentDialog(
        tournament: tournament,
        onTournamentAdded: () {
          _loadTournaments();
          _loadStatistics();
        },
      ),
    );
  }

  void _showEditCredentialsDialog(Map<String, dynamic> credential) {
    showDialog(
      context: context,
      builder: (context) => _AddCredentialsDialog(
        credential: credential,
        tournaments: _tournaments,
        onCredentialsAdded: _loadMatchCredentials,
      ),
    );
  }

  void _showUserDetails(AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${user.name}'),
              Text('Email: ${user.email}'),
              Text('Phone: ${user.phone}'),
              Text('Wallet Balance: ₹${user.totalBalance.toStringAsFixed(2)}'),
              Text('Total Winnings: ₹${user.totalWinning.toStringAsFixed(2)}'),
              Text('Joined: ${_formatDate(user.createdAt)}'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _showManualPaymentDialog(),
                child: Text('Send Payment Notification'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (date is DateTime) {
      return '${date.day}/${date.month}/${date.year}';
    } else {
      return 'Unknown Date';
    }
  }

  String _getTimeLeft(Timestamp targetTime) {
    final now = DateTime.now();
    final target = targetTime.toDate();
    final difference = target.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours.remainder(24)}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes.remainder(60)}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ${difference.inSeconds.remainder(60)}s';
    } else {
      return 'Ended';
    }
  }

  String _getUserInitials(String name) {
    if (name.isEmpty || name == 'No Name') return '?';
    final parts = name.split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    } else {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    }
  }

  void _navigateToTab(int tabIndex) {
    setState(() {
      _currentIndex = tabIndex;
    });
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildTournamentsTab();
      case 2:
        return _buildUsersTab();
      case 3:
        return _buildWithdrawalsTab();
      case 4:
        return _buildMatchCredentialsTab();
      default:
        return _buildDashboardTab();
    }
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              GestureDetector(
                onTap: () => _navigateToTab(2),
                child: _buildStatCard(
                  'Total Users',
                  _totalUsers.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToTab(1),
                child: _buildStatCard(
                  'Tournaments',
                  _totalTournaments.toString(),
                  Icons.tour,
                  Colors.green,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToTab(3),
                child: _buildStatCard(
                  'Pending Withdrawals',
                  _pendingWithdrawals.toString(),
                  Icons.money_off,
                  Colors.orange,
                ),
              ),
              _buildStatCard(
                'Total Revenue',
                '₹${_totalRevenue.toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.purple,
              ),
              GestureDetector(
                onTap: () => _navigateToTab(1),
                child: _buildStatCard(
                  'Active Tournaments',
                  _activeTournaments.toString(),
                  Icons.event_available,
                  Colors.teal,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToTab(4),
                child: _buildStatCard(
                  'Match Credentials',
                  _matchCredentials.length.toString(),
                  Icons.lock,
                  Colors.indigo,
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ActionChip(
                        avatar: Icon(Icons.add, size: 20, color: Colors.white),
                        label: Text('Add Tournament', style: TextStyle(color: Colors.white)),
                        onPressed: _showAddTournamentDialog,
                        backgroundColor: Colors.deepPurple,
                      ),
                      ActionChip(
                        avatar: Icon(Icons.notifications, size: 20, color: Colors.white),
                        label: Text('Send Notification', style: TextStyle(color: Colors.white)),
                        onPressed: _sendNotificationToAllUsers,
                        backgroundColor: Colors.orange,
                      ),
                      ActionChip(
                        avatar: Icon(Icons.payment, size: 20, color: Colors.white),
                        label: Text('Payment Notify', style: TextStyle(color: Colors.white)),
                        onPressed: _showManualPaymentDialog,
                        backgroundColor: Colors.green,
                      ),
                      ActionChip(
                        avatar: Icon(Icons.refresh, size: 20),
                        label: Text('Refresh Data'),
                        onPressed: _loadData,
                      ),
                      ActionChip(
                        avatar: Icon(Icons.lock, size: 20, color: Colors.white),
                        label: Text('Add Credentials', style: TextStyle(color: Colors.white)),
                        onPressed: _showAddCredentialsDialog,
                        backgroundColor: Colors.indigo,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentsTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tournaments (${_tournaments.length})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.deepPurple,
                ),
                child: TextButton.icon(
                  onPressed: _showAddTournamentDialog,
                  icon: Icon(Icons.add, color: Colors.white, size: 20),
                  label: Text('Add Tournament', style: TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _tournaments.isEmpty
              ? _buildEmptyState('No Tournaments', Icons.tour, 'No tournaments found. Add some tournaments to get started.')
              : RefreshIndicator(
            onRefresh: _loadTournaments,
            child: ListView.builder(
              itemCount: _tournaments.length,
              itemBuilder: (context, index) {
                final tournament = _tournaments[index];
                final registrationEnd = tournament['registration_end'] as Timestamp?;
                final tournamentStart = tournament['tournament_start'] as Timestamp?;

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tournament['tournament_name'] as String? ?? 'Unknown Tournament',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(tournament['status']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _getStatusColor(tournament['status'])),
                              ),
                              child: Text(
                                (tournament['status'] as String? ?? 'unknown').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(tournament['status']),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('Game: ${tournament['game_name'] ?? 'Unknown'}'),
                        Text('Entry: ₹${(tournament['entry_fee'] as num?)?.toDouble() ?? 0} • Slots: ${tournament['slots_left']}/${tournament['total_slots']}'),
                        if (registrationEnd != null)
                          Text('Registration ends in: ${_getTimeLeft(registrationEnd)}'),
                        if (tournamentStart != null)
                          Text('Tournament starts in: ${_getTimeLeft(tournamentStart)}'),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showEditTournamentDialog(tournament),
                                icon: Icon(Icons.edit, size: 18),
                                label: Text('Edit'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _addMatchCredentials(tournament['id'] as String),
                                icon: Icon(Icons.lock, size: 18),
                                label: Text('Credentials'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.indigo,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showDeleteConfirmation(tournament),
                                icon: Icon(Icons.delete, size: 18),
                                label: Text('Delete'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text('Users (${_users.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: _users.isEmpty
              ? _buildEmptyState('No Users', Icons.people, 'No users found in the system.')
              : RefreshIndicator(
            onRefresh: _loadUsers,
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Text(_getUserInitials(user.name), style: TextStyle(color: Colors.white)),
                    ),
                    title: Text(user.name),
                    subtitle: Text('${user.email} • ₹${user.totalBalance.toStringAsFixed(2)}'),
                    trailing: Chip(
                      label: Text('USER'),
                      backgroundColor: Colors.grey,
                      labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    onTap: () => _showUserDetails(user),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawalsTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text('Withdrawal Requests (${_withdrawRequests.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: _withdrawRequests.isEmpty
              ? _buildEmptyState('No Withdrawal Requests', Icons.money_off, 'No pending withdrawal requests.')
              : RefreshIndicator(
            onRefresh: _loadWithdrawRequests,
            child: ListView.builder(
              itemCount: _withdrawRequests.length,
              itemBuilder: (context, index) {
                final request = _withdrawRequests[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: Icon(Icons.account_balance_wallet, color: _getStatusColor(request['status']), size: 30),
                    title: Text('₹${(request['amount'] as double).toStringAsFixed(2)}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Method: ${request['payment_method']}'),
                        Text('User: ${request['userName']} (${request['userEmail']})'),
                        Text('Status: ${request['status']}'),
                        if (request['requested_at'] != null)
                          Text('Date: ${_formatDate(request['requested_at'])}'),
                      ],
                    ),
                    trailing: request['status'] == 'pending'
                        ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () => _updateWithdrawStatus(request['id'], 'approved'),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () => _updateWithdrawStatus(request['id'], 'denied'),
                        ),
                      ],
                    )
                        : Chip(
                      label: Text(request['status']),
                      backgroundColor: _getStatusColor(request['status']),
                      labelStyle: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCredentialsTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Match Credentials (${_matchCredentials.length})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.indigo,
                ),
                child: TextButton.icon(
                  onPressed: _showAddCredentialsDialog,
                  icon: Icon(Icons.add, color: Colors.white, size: 20),
                  label: Text('Add Credentials', style: TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _matchCredentials.isEmpty
              ? _buildEmptyState('No Match Credentials', Icons.lock, 'No match credentials found.')
              : RefreshIndicator(
            onRefresh: _loadMatchCredentials,
            child: ListView.builder(
              itemCount: _matchCredentials.length,
              itemBuilder: (context, index) {
                final credential = _matchCredentials[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                credential['tournamentName'] ?? 'Unknown Tournament',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Chip(
                              label: Text(credential['status'] ?? 'active'),
                              backgroundColor: _getStatusColor(credential['status']),
                              labelStyle: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('Room ID: ${credential['roomId']}'),
                        Text('Password: ${credential['roomPassword']}'),
                        Text('Participants: ${credential['participants']}'),
                        if (credential['matchTime'] != null)
                          Text('Match Time: ${_formatDate(credential['matchTime'])}'),
                        if (credential['credentialsAddedAt'] != null)
                          Text('Added: ${_formatDate(credential['credentialsAddedAt'])}'),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showEditCredentialsDialog(credential),
                                icon: Icon(Icons.edit, size: 18),
                                label: Text('Edit'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _sendCredentialsNotification(credential),
                                icon: Icon(Icons.notifications, size: 18),
                                label: Text('Notify'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showDeleteCredentialsConfirmation(credential),
                                icon: Icon(Icons.delete, size: 18),
                                label: Text('Delete'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.white),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 40, color: color),
          SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, String description) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          SizedBox(height: 8),
          Text(description, style: TextStyle(fontSize: 14, color: Colors.grey[500]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
      case 'active':
        return Colors.green;
      case 'denied':
      case 'failed':
      case 'expired':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> tournament) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Tournament'),
        content: Text('Are you sure you want to delete "${tournament['tournament_name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTournament(tournament['id'] as String);
            },
            child: Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteCredentialsConfirmation(Map<String, dynamic> credential) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Credentials'),
        content: Text('Are you sure you want to delete credentials for "${credential['tournamentName']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMatchCredentials(credential['id'] as String);
            },
            child: Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddCredentialsDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddCredentialsDialog(
        tournaments: _tournaments,
        onCredentialsAdded: _loadMatchCredentials,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text('Admin Panel'), backgroundColor: Colors.deepPurple),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Checking permissions...'),
        ])),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: _sendNotificationToAllUsers,
            tooltip: 'Send Notification',
          ),
          IconButton(
            icon: Icon(Icons.payment),
            onPressed: _showManualPaymentDialog,
            tooltip: 'Send Payment Notification',
          ),
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Refresh Data'),
        ],
      ),
      body: _isLoading ? Center(child: CircularProgressIndicator()) : _buildCurrentTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.tour), label: 'Tournaments'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.money_off), label: 'Withdrawals'),
          BottomNavigationBarItem(icon: Icon(Icons.lock), label: 'Credentials'),
        ],
      ),
    );
  }
}

// Add/Edit Tournament Dialog
class _AddTournamentDialog extends StatefulWidget {
  final VoidCallback onTournamentAdded;
  final Map<String, dynamic>? tournament;

  const _AddTournamentDialog({
    required this.onTournamentAdded,
    this.tournament,
  });

  @override
  _AddTournamentDialogState createState() => _AddTournamentDialogState();
}

class _AddTournamentDialogState extends State<_AddTournamentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gameNameController = TextEditingController();
  final TextEditingController _entryFeeController = TextEditingController();
  final TextEditingController _totalSlotsController = TextEditingController();
  final TextEditingController _prizePoolController = TextEditingController();
  final TextEditingController _gameIdController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _mapController = TextEditingController();
  final TextEditingController _modeController = TextEditingController();

  DateTime _registrationEnd = DateTime.now().add(Duration(days: 1));
  DateTime _tournamentStart = DateTime.now().add(Duration(days: 2));
  String _tournamentType = 'Solo';
  String _status = 'upcoming';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.tournament != null) {
      _loadTournamentData();
    }
  }

  void _loadTournamentData() {
    final tournament = widget.tournament!;
    _nameController.text = tournament['tournament_name'] ?? '';
    _gameNameController.text = tournament['game_name'] ?? '';
    _gameIdController.text = tournament['game_id'] ?? '';
    _entryFeeController.text = (tournament['entry_fee'] as num?)?.toString() ?? '';
    _prizePoolController.text = (tournament['winning_prize'] as num?)?.toString() ?? '';
    _totalSlotsController.text = (tournament['total_slots'] as num?)?.toString() ?? '';
    _descriptionController.text = tournament['description'] ?? '';
    _mapController.text = tournament['map'] ?? '';
    _modeController.text = tournament['mode'] ?? '';
    _tournamentType = tournament['tournament_type'] ?? 'Solo';
    _status = tournament['status'] ?? 'upcoming';

    if (tournament['registration_end'] != null) {
      _registrationEnd = (tournament['registration_end'] as Timestamp).toDate();
    }
    if (tournament['tournament_start'] != null) {
      _tournamentStart = (tournament['tournament_start'] as Timestamp).toDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tournament == null ? 'Add New Tournament' : 'Edit Tournament'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _gameNameController.text.isEmpty ? null : _gameNameController.text,
                decoration: InputDecoration(labelText: 'Game Name*', border: OutlineInputBorder()),
                items: ['BGMI', 'Free Fire', 'Valorant', 'COD Mobile'].map((game) => DropdownMenuItem(value: game, child: Text(game))).toList(),
                onChanged: (value) => setState(() => _gameNameController.text = value!),
                validator: (value) => value == null ? 'Please select game name' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Tournament Name*', border: OutlineInputBorder()),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter tournament name' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _gameIdController,
                decoration: InputDecoration(labelText: 'Game ID*', border: OutlineInputBorder()),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter game ID' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _entryFeeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Entry Fee*', border: OutlineInputBorder(), prefixText: '₹ '),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter entry fee';
                  if (double.tryParse(value!) == null) return 'Please enter valid amount';
                  return null;
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _prizePoolController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Prize Pool*', border: OutlineInputBorder(), prefixText: '₹ '),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter prize pool';
                  if (double.tryParse(value!) == null) return 'Please enter valid amount';
                  return null;
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _totalSlotsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Total Slots*', border: OutlineInputBorder()),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter total slots';
                  if (int.tryParse(value!) == null) return 'Please enter valid number';
                  return null;
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _mapController,
                decoration: InputDecoration(labelText: 'Map', border: OutlineInputBorder()),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _modeController,
                decoration: InputDecoration(labelText: 'Mode', border: OutlineInputBorder()),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _tournamentType,
                decoration: InputDecoration(labelText: 'Tournament Type', border: OutlineInputBorder()),
                items: ['Solo', 'Duo', 'Squad', 'Team'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (value) => setState(() => _tournamentType = value!),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: ['upcoming', 'live', 'completed', 'cancelled'].map((status) => DropdownMenuItem(value: status, child: Text(status.toUpperCase()))).toList(),
                onChanged: (value) => setState(() => _status = value!),
              ),
              SizedBox(height: 12),
              ListTile(
                title: Text('Registration Ends'),
                subtitle: Text('${_registrationEnd.toString().split(' ')[0]} ${_registrationEnd.hour}:${_registrationEnd.minute.toString().padLeft(2, '0')}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectRegistrationEndDate(),
              ),
              SizedBox(height: 12),
              ListTile(
                title: Text('Tournament Starts'),
                subtitle: Text('${_tournamentStart.toString().split(' ')[0]} ${_tournamentStart.hour}:${_tournamentStart.minute.toString().padLeft(2, '0')}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectTournamentStartDate(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: Text('CANCEL')),
        ElevatedButton(
          onPressed: _isLoading ? null : _addTournament,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
          child: _isLoading ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.tournament == null ? 'ADD TOURNAMENT' : 'UPDATE TOURNAMENT'),
        ),
      ],
    );
  }

  Future<void> _selectRegistrationEndDate() async {
    final DateTime? pickedDate = await showDatePicker(context: context, initialDate: _registrationEnd, firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_registrationEnd));
      if (pickedTime != null) {
        setState(() {
          _registrationEnd = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
      }
    }
  }

  Future<void> _selectTournamentStartDate() async {
    final DateTime? pickedDate = await showDatePicker(context: context, initialDate: _tournamentStart, firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_tournamentStart));
      if (pickedTime != null) {
        setState(() {
          _tournamentStart = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
      }
    }
  }

  Future<void> _addTournament() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final tournamentData = {
        'tournament_name': _nameController.text.trim(),
        'game_name': _gameNameController.text.trim(),
        'game_id': _gameIdController.text.trim(),
        'entry_fee': double.parse(_entryFeeController.text),
        'winning_prize': double.parse(_prizePoolController.text),
        'total_slots': int.parse(_totalSlotsController.text),
        'registered_players': 0,
        'slots_left': int.parse(_totalSlotsController.text),
        'tournament_type': _tournamentType,
        'match_time': _tournamentStart.toString(),
        'map': _mapController.text.trim(),
        'mode': _modeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'status': _status,
        'registration_start': Timestamp.now(),
        'registration_end': Timestamp.fromDate(_registrationEnd),
        'tournament_start': Timestamp.fromDate(_tournamentStart),
        'updated_at': Timestamp.now(),
      };

      if (widget.tournament == null) {
        tournamentData['created_at'] = Timestamp.now();
        tournamentData['joined_players'] = [];
        await FirebaseFirestore.instance.collection('tournaments').add(tournamentData);
      } else {
        await FirebaseFirestore.instance.collection('tournaments').doc(widget.tournament!['id']).update(tournamentData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.tournament == null ? 'Tournament added successfully!' : 'Tournament updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onTournamentAdded();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ${widget.tournament == null ? 'adding' : 'updating'} tournament: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// Add/Edit Credentials Dialog
class _AddCredentialsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> tournaments;
  final VoidCallback onCredentialsAdded;
  final Map<String, dynamic>? credential;

  const _AddCredentialsDialog({
    required this.tournaments,
    required this.onCredentialsAdded,
    this.credential,
  });

  @override
  __AddCredentialsDialogState createState() => __AddCredentialsDialogState();
}

class __AddCredentialsDialogState extends State<_AddCredentialsDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _roomPasswordController = TextEditingController();

  String? _selectedTournamentId;
  DateTime _matchTime = DateTime.now().add(Duration(hours: 1));
  String _status = 'active';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.credential == null) {
      _generateCredentials();
    } else {
      _loadCredentialData();
    }
  }

  void _loadCredentialData() {
    final credential = widget.credential!;
    _roomIdController.text = credential['roomId'] ?? '';
    _roomPasswordController.text = credential['roomPassword'] ?? '';
    _selectedTournamentId = credential['tournamentId'];
    _status = credential['status'] ?? 'active';
    if (credential['matchTime'] != null) {
      _matchTime = (credential['matchTime'] as Timestamp).toDate();
    }
  }

  void _generateCredentials() {
    final roomId = 'ROOM${DateTime.now().millisecondsSinceEpoch}';
    final roomPassword = 'PASS${DateTime.now().millisecondsSinceEpoch ~/ 1000}';

    setState(() {
      _roomIdController.text = roomId;
      _roomPasswordController.text = roomPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.credential == null ? 'Add Match Credentials' : 'Edit Match Credentials'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedTournamentId,
              decoration: InputDecoration(
                labelText: 'Select Tournament*',
                border: OutlineInputBorder(),
              ),
              items: widget.tournaments.map((tournament) {
                return DropdownMenuItem(
                  value: tournament['id'] as String,
                  child: Text(
                    '${tournament['tournament_name']} - ${tournament['game_name']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTournamentId = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a tournament';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _roomIdController,
              decoration: InputDecoration(
                labelText: 'Room ID*',
                border: OutlineInputBorder(),
                suffixIcon: widget.credential == null ? IconButton(
                  icon: Icon(Icons.autorenew),
                  onPressed: _generateCredentials,
                ) : null,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter room ID';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _roomPasswordController,
              decoration: InputDecoration(
                labelText: 'Room Password*',
                border: OutlineInputBorder(),
                suffixIcon: widget.credential == null ? IconButton(
                  icon: Icon(Icons.autorenew),
                  onPressed: _generateCredentials,
                ) : null,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter room password';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: ['active', 'inactive', 'completed'].map((status) => DropdownMenuItem(value: status, child: Text(status.toUpperCase()))).toList(),
              onChanged: (value) => setState(() => _status = value!),
            ),
            SizedBox(height: 16),
            ListTile(
              title: Text('Match Time'),
              subtitle: Text('${_matchTime.toString().split(' ')[0]} ${_matchTime.hour}:${_matchTime.minute.toString().padLeft(2, '0')}'),
              trailing: Icon(Icons.calendar_today),
              onTap: _selectMatchTime,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addCredentials,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
          ),
          child: _isLoading
              ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text(widget.credential == null ? 'ADD CREDENTIALS' : 'UPDATE CREDENTIALS'),
        ),
      ],
    );
  }

  Future<void> _selectMatchTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _matchTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_matchTime),
      );

      if (pickedTime != null) {
        setState(() {
          _matchTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _addCredentials() async {
    if (_selectedTournamentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a tournament'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_roomIdController.text.isEmpty || _roomPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter room ID and password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final tournamentDoc = await _firestore.collection('tournaments').doc(_selectedTournamentId).get();
      if (!tournamentDoc.exists) {
        throw Exception('Tournament not found');
      }

      final tournamentData = tournamentDoc.data()!;
      final usersSnapshot = await _firestore.collection('users').get();
      final List<String> participantIds = [];

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final registrations = userData['tournament_registrations'] as List<dynamic>? ?? [];

        for (var reg in registrations) {
          if (reg is Map<String, dynamic> &&
              reg['tournament_id'] == _selectedTournamentId &&
              reg['status'] == 'registered') {
            participantIds.add(userDoc.id);
            break;
          }
        }
      }

      final credentialData = {
        'tournamentId': _selectedTournamentId,
        'tournamentName': tournamentData['tournament_name'],
        'roomId': _roomIdController.text.trim(),
        'roomPassword': _roomPasswordController.text.trim(),
        'matchTime': Timestamp.fromDate(_matchTime),
        'status': _status,
        'participants': participantIds,
        'participantCount': participantIds.length,
        'updatedAt': Timestamp.now(),
        'credentialsAddedAt': Timestamp.now(),
      };

      await _firestore.collection('tournaments').doc(_selectedTournamentId).update({
        'roomId': _roomIdController.text.trim(),
        'roomPassword': _roomPasswordController.text.trim(),
        'credentialsMatchTime': Timestamp.fromDate(_matchTime),
        'credentialsAddedAt': Timestamp.now(),
        'updated_at': Timestamp.now(),
      });

      if (widget.credential == null) {
        credentialData['createdAt'] = Timestamp.now();
        credentialData['releasedAt'] = Timestamp.now();
        await _firestore.collection('matchCredentials').add(credentialData);
      } else {
        await _firestore.collection('matchCredentials').doc(widget.credential!['id']).update(credentialData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.credential == null ?
          'Match credentials added successfully!' :
          'Match credentials updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onCredentialsAdded();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ${widget.credential == null ? 'adding' : 'updating'} credentials: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}