import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== LEADERBOARD MANAGEMENT ==========
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('leader_board')
          .doc('current_leaderboard')
          .get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        final List<Map<String, dynamic>> leaderboard = [];

        for (int i = 1; i <= limit; i++) {
          final positionKey = 'position_$i';
          final userId = data[positionKey] as String?;
          if (userId != null) {
            leaderboard.add({
              'position': i,
              'user_id': userId,
            });
          }
        }

        final List<Map<String, dynamic>> usersData = [];
        for (var entry in leaderboard) {
          // Get user by UID query
          final userQuery = await _firestore.collection('users')
              .where('uid', isEqualTo: entry['user_id'])
              .limit(1)
              .get();

          if (userQuery.docs.isNotEmpty) {
            final userDoc = userQuery.docs.first;
            final userData = userDoc.data();
            final userName = userDoc.id;

            // Get wallet data
            final walletDoc = await _firestore
                .collection('wallet')
                .doc('users')
                .collection(userName)
                .doc('wallet_data')
                .get();

            final walletData = walletDoc.data() ?? {};

            usersData.add({
              'position': entry['position'],
              'user_id': entry['user_id'],
              'name': (userData?['name'] as String?) ?? 'Player',
              'total_winning': (walletData['total_winning'] as num?)?.toDouble() ?? 0.0,
              'total_balance': (walletData['total_balance'] as num?)?.toDouble() ?? 0.0,
            });
          }
        }

        return usersData;
      } else {
        return await _generateLeaderboardFromUsers(limit: limit);
      }
    } catch (e) {
      print('❌ Error getting leaderboard: $e');
      return await _generateLeaderboardFromUsers(limit: limit);
    }
  }

  Future<List<Map<String, dynamic>>> _generateLeaderboardFromUsers({int limit = 10}) async {
    try {
      final usersSnapshot = await _firestore.collection('users').limit(limit).get();

      final List<Map<String, dynamic>> leaderboard = [];
      for (var i = 0; i < usersSnapshot.docs.length; i++) {
        final doc = usersSnapshot.docs[i];
        final userData = doc.data();
        final userName = doc.id;

        // Get wallet data for each user
        final walletDoc = await _firestore
            .collection('wallet')
            .doc('users')
            .collection(userName)
            .doc('wallet_data')
            .get();

        final walletData = walletDoc.data() ?? {};

        leaderboard.add({
          'position': i + 1,
          'user_id': userData['uid'] ?? '',
          'name': (userData['name'] as String?) ?? 'Player',
          'total_winning': (walletData['total_winning'] as num?)?.toDouble() ?? 0.0,
          'total_balance': (walletData['total_balance'] as num?)?.toDouble() ?? 0.0,
        });
      }

      // Sort by total_winning
      leaderboard.sort((a, b) => (b['total_winning'] as double).compareTo(a['total_winning'] as double));

      return leaderboard;
    } catch (e) {
      print('❌ Error generating leaderboard from users: $e');
      return _getMockLeaderboard();
    }
  }

  List<Map<String, dynamic>> _getMockLeaderboard() {
    return [
      {
        'position': 1,
        'user_id': 'user_18',
        'name': 'Pro Player',
        'total_winning': 12500.0,
        'total_balance': 1500.0,
      },
      {
        'position': 2,
        'user_id': 'user_5',
        'name': 'Game Master',
        'total_winning': 8900.0,
        'total_balance': 1200.0,
      },
      {
        'position': 3,
        'user_id': 'user_200',
        'name': 'Battle Legend',
        'total_winning': 6700.0,
        'total_balance': 900.0,
      },
    ];
  }

  // ========== USER STATISTICS ==========
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final userName = await getCurrentUserDocumentId();
      if (userName == null) return {};

      // Get user document
      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: _auth.currentUser?.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return {};

      final userDoc = userQuery.docs.first;
      final data = userDoc.data();

      final matches = data?['matches'] as Map<String, dynamic>? ?? {};
      final recentMatches = matches['recent_match'] as List? ?? [];
      final wonMatches = matches['won_match'] as List? ?? [];
      final lostMatches = matches['loss_match'] as List? ?? [];

      final totalMatches = recentMatches.length;
      final matchesWon = wonMatches.length;
      final winRate = totalMatches > 0 ? (matchesWon / totalMatches * 100) : 0;

      // Get wallet balance
      final currentBalance = await getWalletBalance();

      // Get total winnings from wallet
      final walletDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('wallet_data')
          .get();

      final walletData = walletDoc.data() ?? {};
      final totalWinnings = (walletData['total_winning'] as num?)?.toDouble() ?? 0.0;

      return {
        'total_matches': totalMatches,
        'matches_won': matchesWon,
        'matches_lost': lostMatches.length,
        'win_rate': winRate,
        'total_winnings': totalWinnings,
        'current_balance': currentBalance,
        'total_withdrawals': await _getTotalWithdrawals(),
      };
    } catch (e) {
      print('❌ Error getting user stats: $e');
      return {
        'total_matches': 0,
        'matches_won': 0,
        'matches_lost': 0,
        'win_rate': 0.0,
        'total_winnings': 0.0,
        'current_balance': 0.0,
        'total_withdrawals': 0.0,
      };
    }
  }

  Future<double> _getTotalWithdrawals() async {
    try {
      final userName = await getCurrentUserDocumentId();
      if (userName == null) return 0.0;

      final withdrawalDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('withdrawal_requests')
          .get();

      if (withdrawalDoc.exists) {
        final withdrawalData = withdrawalDoc.data() ?? {};
        final approvedWithdrawals = withdrawalData['approved'] as List? ?? [];

        double total = 0.0;
        for (var withdrawal in approvedWithdrawals) {
          if (withdrawal is Map<String, dynamic>) {
            total += (withdrawal['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
        return total;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // ========== FCM TOKEN MANAGEMENT ==========
  Future<void> saveFCMToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        // Get user document by UID query
        final userQuery = await _firestore.collection('users')
            .where('uid', isEqualTo: userId)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          await _firestore.collection('users').doc(userQuery.docs.first.id).update({
            'fcmToken': token,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('✅ FCM token saved successfully');
        }
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  // ========== RECENT MATCHES ==========
  Future<List<Map<String, dynamic>>> getRecentMatches() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      // Get user document by UID query
      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return [];

      final userDoc = userQuery.docs.first;
      final data = userDoc.data();
      final matches = data?['matches'] as Map<String, dynamic>? ?? {};
      final recentMatches = matches['recent_match'] as List? ?? [];

      final List<Map<String, dynamic>> validMatches = [];
      for (var match in recentMatches) {
        if (match is Map<String, dynamic>) {
          validMatches.add(match);
        }
      }

      validMatches.sort((a, b) {
        final timeA = a['timestamp'] as Timestamp? ?? Timestamp.now();
        final timeB = b['timestamp'] as Timestamp? ?? Timestamp.now();
        return timeB.compareTo(timeA);
      });

      return validMatches;
    } catch (e) {
      print('❌ Error getting recent matches: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getWonMatches() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      // Get user document by UID query
      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return [];

      final userDoc = userQuery.docs.first;
      final data = userDoc.data();
      final matches = data?['matches'] as Map<String, dynamic>? ?? {};
      final wonMatches = matches['won_match'] as List? ?? [];

      final List<Map<String, dynamic>> validMatches = [];
      for (var match in wonMatches) {
        if (match is Map<String, dynamic>) {
          validMatches.add(match);
        }
      }

      return validMatches;
    } catch (e) {
      print('❌ Error getting won matches: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLostMatches() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      // Get user document by UID query
      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return [];

      final userDoc = userQuery.docs.first;
      final data = userDoc.data();
      final matches = data?['matches'] as Map<String, dynamic>? ?? {};
      final lostMatches = matches['loss_match'] as List? ?? [];

      final List<Map<String, dynamic>> validMatches = [];
      for (var match in lostMatches) {
        if (match is Map<String, dynamic>) {
          validMatches.add(match);
        }
      }

      return validMatches;
    } catch (e) {
      print('❌ Error getting lost matches: $e');
      return [];
    }
  }

  // ========== TOURNAMENT STATISTICS ==========
  Future<Map<String, dynamic>> getUserTournamentStats() async {
    try {
      final registrations = await getUserTournamentRegistrations();

      final totalTournaments = registrations.length;
      final completedTournaments = registrations.where((reg) => reg['status'] == 'completed').length;
      final wonTournaments = registrations.where((reg) => reg['result'] == 'won').length;
      final activeRegistrations = registrations.where((reg) => reg['status'] == 'registered').length;

      double totalWinnings = 0.0;
      double totalEntryFees = 0.0;

      for (var reg in registrations) {
        totalEntryFees += (reg['entry_fee'] as num?)?.toDouble() ?? 0.0;
        totalWinnings += (reg['winnings'] as num?)?.toDouble() ?? 0.0;
      }

      final netProfit = totalWinnings - totalEntryFees;
      final winRate = completedTournaments > 0 ? (wonTournaments / completedTournaments * 100) : 0.0;

      return {
        'total_tournaments': totalTournaments,
        'completed_tournaments': completedTournaments,
        'won_tournaments': wonTournaments,
        'active_registrations': activeRegistrations,
        'total_entry_fees': totalEntryFees,
        'total_winnings': totalWinnings,
        'net_profit': netProfit,
        'win_rate': winRate,
      };
    } catch (e) {
      print('❌ Error getting user tournament stats: $e');
      return {
        'total_tournaments': 0,
        'completed_tournaments': 0,
        'won_tournaments': 0,
        'active_registrations': 0,
        'total_entry_fees': 0.0,
        'total_winnings': 0.0,
        'net_profit': 0.0,
        'win_rate': 0.0,
      };
    }
  }

  // ========== MATCH MANAGEMENT ==========
  Future<bool> addMatchToHistory({
    required String tournamentName,
    required String gameName,
    required int position,
    required int kills,
    required double winnings,
    required bool isWin,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      // Get user document by UID query
      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return false;

      final matchData = <String, dynamic>{
        'tournament_name': tournamentName,
        'game_name': gameName,
        'position': position,
        'kills': kills,
        'winnings': winnings,
        'timestamp': DateTime.now().toIso8601String(),
        'match_id': 'match_${DateTime.now().millisecondsSinceEpoch}',
      };

      final matchType = isWin ? 'won_match' : 'loss_match';

      await _firestore.collection('users').doc(userQuery.docs.first.id).update({
        'matches.recent_match': FieldValue.arrayUnion([matchData]),
        'matches.$matchType': FieldValue.arrayUnion([matchData]),
        'user_all_match_details': FieldValue.arrayUnion([matchData]),
        'user_${isWin ? 'won' : 'loss'}_match_details': FieldValue.arrayUnion([matchData]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (winnings > 0) {
        await addToWinnings(winnings);
      }

      print('✅ Match added to history: $tournamentName');
      return true;
    } catch (e) {
      print('❌ Error adding match to history: $e');
      return false;
    }
  }

  // ========== USER MANAGEMENT ==========
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      // Find user document by UID
      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        return await _createNewUserStructure(userId);
      }

      final userDoc = userQuery.docs.first;
      return userDoc.data();
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return null;

      return userQuery.docs.first.data();
    } catch (e) {
      print('❌ Error getting current user: $e');
      return null;
    }
  }

  Future<String?> getCurrentUserName() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return null;

      final userData = userQuery.docs.first.data();
      return userData['name'] as String?;
    } catch (e) {
      print('❌ Error getting current user name: $e');
      return null;
    }
  }

  Future<String?> getCurrentUserDocumentId() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return null;

      return userQuery.docs.first.id;
    } catch (e) {
      print('❌ Error getting current user document ID: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _createNewUserStructure(String userId) async {
    try {
      final userName = _auth.currentUser?.displayName ?? 'User ${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().toIso8601String();

      final userData = {
        'uid': userId,
        'name': userName,
        'phone': _auth.currentUser?.phoneNumber ?? '',
        'email': _auth.currentUser?.email ?? '',
        'welcome_bonus': 200.0,
        'role': 'user',
        'fcmToken': '',
        'tournaments': {
          'BGMI': {
            'BGMI_NAME': '',
            'BGMI_ID': '',
          },
          'FREEFIRE': {
            'FREEFIRE_NAME': '',
            'FREEFIRE_ID': '',
          },
          'VALORANT': {
            'VALORANT_NAME': '',
            'VALORANT_ID': '',
          },
          'COD_MOBILE': {
            'COD_MOBILE_NAME': '',
            'COD_MOBILE_ID': '',
          },
        },
        'tournament_registrations': [],
        'matches': {
          'recent_match': [],
          'won_match': [],
          'loss_match': [],
        },
        'user_all_match_details': [],
        'user_won_match_details': [],
        'user_loss_match_details': [],
        'createdAt': now,
        'updatedAt': now,
        'last_login': now,
      };

      // Create user document with name as document ID
      await _firestore.collection('users').doc(userName).set(userData);

      // Create wallet structure for the user
      await _createUserWalletStructure(userName, userId);

      print('✅ New user structure created for: $userName');
      return userData;
    } catch (e) {
      print('❌ Error creating user structure: $e');
      rethrow;
    }
  }

  Future<void> _createUserWalletStructure(String userName, String userId) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Create wallet_data document
      await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('wallet_data')
          .set({
        'total_balance': 200.0, // Welcome bonus
        'total_winning': 0.0,
        'user_id': userId,
        'user_name': userName,
        'createdAt': now,
        'updatedAt': now,
      });

      // Initialize transactions document
      await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('transactions')
          .set({
        'successful': [],
        'failed': [],
        'pending': [],
      });

      // Initialize withdrawal_requests document
      await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('withdrawal_requests')
          .set({
        'approved': [],
        'denied': [],
        'failed': [],
        'pending': [],
      });

      print('✅ New wallet structure created for: $userName');
    } catch (e) {
      print('❌ Error creating wallet structure: $e');
    }
  }

  // ========== WALLET MANAGEMENT ==========
  Future<double> getWalletBalance() async {
    try {
      final userName = await getCurrentUserDocumentId();
      if (userName == null) return 0.0;

      final walletDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('wallet_data')
          .get();

      if (walletDoc.exists) {
        final walletData = walletDoc.data();
        return (walletData?['total_balance'] as num?)?.toDouble() ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      print('❌ Error getting wallet balance: $e');
      return 0.0;
    }
  }

  Future<double> getTotalWinnings() async {
    try {
      final userName = await getCurrentUserDocumentId();
      if (userName == null) return 0.0;

      final walletDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('wallet_data')
          .get();

      if (walletDoc.exists) {
        final walletData = walletDoc.data();
        return (walletData?['total_winning'] as num?)?.toDouble() ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      print('❌ Error getting total winnings: $e');
      return 0.0;
    }
  }

  Future<bool> addMoney(double amount, String paymentId, String paymentMethod) async {
    try {
      final userName = await getCurrentUserDocumentId();
      if (userName == null) return false;

      // Update wallet balance
      await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('wallet_data')
          .update({
        'total_balance': FieldValue.increment(amount),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Add transaction
      final transactionData = {
        'transaction_id': 'txn_${DateTime.now().millisecondsSinceEpoch}',
        'type': 'credit',
        'amount': amount,
        'status': 'successful',
        'description': 'Wallet recharge via $paymentMethod',
        'payment_method': paymentMethod,
        'payment_id': paymentId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('transactions')
          .update({
        'successful': FieldValue.arrayUnion([transactionData]),
      });

      print('✅ Money added to wallet: ₹$amount');
      return true;
    } catch (e) {
      print('❌ Error adding money: $e');
      return false;
    }
  }

  Future<bool> deductFromWallet(double amount) async {
    try {
      final userName = await getCurrentUserDocumentId();
      if (userName == null) return false;

      final currentBalance = await getWalletBalance();
      if (currentBalance < amount) {
        return false;
      }

      await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('wallet_data')
          .update({
        'total_balance': FieldValue.increment(-amount),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('❌ Error deducting from wallet: $e');
      return false;
    }
  }

  Future<bool> addToWinnings(double amount) async {
    try {
      final userName = await getCurrentUserDocumentId();
      if (userName == null) return false;

      await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('wallet_data')
          .update({
        'total_winning': FieldValue.increment(amount),
        'total_balance': FieldValue.increment(amount),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('❌ Error adding to winnings: $e');
      return false;
    }
  }

  // ========== TRANSACTIONS MANAGEMENT ==========
  Future<List<Map<String, dynamic>>> getUserTransactions() async {
    try {
      final userName = await getCurrentUserDocumentId();
      if (userName == null) return [];

      final transactionsDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('transactions')
          .get();

      if (transactionsDoc.exists) {
        final transactionsData = transactionsDoc.data() ?? {};
        final List<Map<String, dynamic>> allTransactions = [];

        // Combine all transaction types
        final successful = transactionsData['successful'] as List? ?? [];
        final pending = transactionsData['pending'] as List? ?? [];
        final failed = transactionsData['failed'] as List? ?? [];

        for (var transaction in successful) {
          if (transaction is Map<String, dynamic>) {
            allTransactions.add({...transaction, 'status': 'successful'});
          }
        }

        for (var transaction in pending) {
          if (transaction is Map<String, dynamic>) {
            allTransactions.add({...transaction, 'status': 'pending'});
          }
        }

        for (var transaction in failed) {
          if (transaction is Map<String, dynamic>) {
            allTransactions.add({...transaction, 'status': 'failed'});
          }
        }

        // Sort by timestamp (newest first)
        allTransactions.sort((a, b) {
          final timeA = _parseTimestamp(a['timestamp']);
          final timeB = _parseTimestamp(b['timestamp']);
          return timeB.compareTo(timeA);
        });

        return allTransactions;
      }
      return [];
    } catch (e) {
      print('❌ Error getting user transactions: $e');
      return [];
    }
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Future<bool> addTransaction({
    required String type,
    required double amount,
    required String status,
    required String description,
    required String paymentMethod,
  }) async {
    try {
      final userName = await getCurrentUserDocumentId();
      if (userName == null) return false;

      final transactionData = {
        'transaction_id': 'txn_${DateTime.now().millisecondsSinceEpoch}',
        'type': type,
        'amount': amount,
        'status': status,
        'description': description,
        'payment_method': paymentMethod,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('transactions')
          .update({
        status: FieldValue.arrayUnion([transactionData]),
      });

      print('✅ Transaction added: $description');
      return true;
    } catch (e) {
      print('❌ Error adding transaction: $e');
      return false;
    }
  }

  // ========== WITHDRAWAL MANAGEMENT ==========
  Future<bool> requestWithdrawal({
    required double amount,
    required String upiId,
  }) async {
    try {
      final userName = await getCurrentUserDocumentId();
      if (userName == null) return false;

      final currentBalance = await getWalletBalance();
      if (currentBalance < amount) {
        throw Exception('Insufficient balance for withdrawal');
      }

      final withdrawalId = 'wd_${DateTime.now().millisecondsSinceEpoch}';
      final withdrawalData = {
        'withdrawal_id': withdrawalId,
        'amount': amount,
        'upi_id': upiId,
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
        'user_id': _auth.currentUser?.uid,
        'user_name': userName,
      };

      print('🔄 Adding withdrawal request ONLY to withdrawal_requests collection');
      print('📝 Withdrawal details: ₹$amount to $upiId');

      // Add ONLY to withdrawal_requests (NOT to transactions)
      final withdrawalRef = _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('withdrawal_requests');

      await withdrawalRef.set({
        'pending': FieldValue.arrayUnion([withdrawalData])
      }, SetOptions(merge: true));

      print('✅ Withdrawal request added to withdrawal_requests/pending');

      // Update wallet balance (deduct the withdrawal amount)
      final walletRef = _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('wallet_data');

      await walletRef.update({
        'total_balance': FieldValue.increment(-amount),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      print('💰 Wallet balance updated: -₹$amount');

      // DO NOT ADD TO TRANSACTIONS COLLECTION - ONLY WITHDRAWAL_REQUESTS
      print('🚫 Withdrawal request NOT added to transactions collection');

      return true;
    } catch (e) {
      print('❌ Error requesting withdrawal: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getWithdrawalRequests() async {
    try {
      final userName = await getCurrentUserDocumentId();
      if (userName == null) return [];

      final withdrawalDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('withdrawal_requests')
          .get();

      if (withdrawalDoc.exists) {
        final withdrawalData = withdrawalDoc.data() ?? {};
        final List<Map<String, dynamic>> allRequests = [];

        // Check all possible status arrays
        final statusArrays = {
          'approved': 'approved',
          'denied': 'denied',
          'failed': 'failed',
          'pending': 'pending',
          'completed': 'completed',
        };

        for (var entry in statusArrays.entries) {
          final requests = withdrawalData[entry.key] as List? ?? [];
          print('📊 ${entry.key} withdrawal requests: ${requests.length}');

          for (var request in requests) {
            if (request is Map<String, dynamic>) {
              allRequests.add({
                ...request,
                'status': entry.value,
              });
            }
          }
        }

        // Sort by date (newest first)
        allRequests.sort((a, b) {
          final timeA = _parseTimestamp(a['requested_at'] ?? a['processed_at'] ?? a['timestamp']);
          final timeB = _parseTimestamp(b['requested_at'] ?? b['processed_at'] ?? b['timestamp']);
          return timeB.compareTo(timeA);
        });

        print('✅ Total withdrawal requests loaded: ${allRequests.length}');
        return allRequests;
      } else {
        print('❌ Withdrawal requests document does not exist');
        return [];
      }
    } catch (e) {
      print('❌ Error getting withdrawal requests: $e');
      return [];
    }
  }

  // Clean up duplicate withdrawal transactions
  Future<void> cleanupDuplicateWithdrawalTransactions() async {
    try {
      final userName = await getCurrentUserDocumentId();
      if (userName == null) return;

      final transactionsRef = _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('transactions');

      final transactionsDoc = await transactionsRef.get();
      if (!transactionsDoc.exists) return;

      final transactionsData = transactionsDoc.data() ?? {};

      // Remove withdrawal transactions from all status arrays
      final statusArrays = ['pending', 'successful', 'failed', 'completed'];
      final updates = <String, dynamic>{};
      int removedCount = 0;

      for (var status in statusArrays) {
        final transactions = transactionsData[status] as List? ?? [];
        final filteredTransactions = transactions.where((transaction) {
          if (transaction is Map<String, dynamic>) {
            final isWithdrawal = transaction['description']?.toString().toLowerCase().contains('withdrawal') ?? false;
            if (isWithdrawal) {
              removedCount++;
              print('🗑️ Removing withdrawal transaction from $status: ${transaction['transaction_id']}');
            }
            return !isWithdrawal;
          }
          return true;
        }).toList();

        updates[status] = filteredTransactions;
      }

      if (removedCount > 0) {
        await transactionsRef.update(updates);
        print('✅ Cleaned up $removedCount duplicate withdrawal transactions');
      } else {
        print('✅ No duplicate withdrawal transactions found');
      }
    } catch (e) {
      print('❌ Error cleaning up duplicate withdrawals: $e');
    }
  }

  // ========== TOURNAMENT REGISTRATION MANAGEMENT ==========
  Future<bool> registerForTournamentWithObject({
    required dynamic tournament,
    required String playerName,
    required String playerId,
    required String paymentId,
    required String paymentMethod,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final tournamentId = tournament.id?.toString() ?? '';
      final isRegistered = await isUserRegisteredForTournament(tournamentId);
      if (isRegistered) {
        throw Exception('You are already registered for this tournament');
      }

      final entryFee = (tournament.entryFee as num?)?.toDouble() ?? 0.0;
      final currentBalance = await getWalletBalance();
      if (currentBalance < entryFee && paymentMethod != 'razorpay') {
        throw Exception('Insufficient balance for tournament registration');
      }

      return await _firestore.runTransaction((transaction) async {
        final tournamentDoc = await transaction.get(
            _firestore.collection('tournaments').doc(tournamentId)
        );

        if (!tournamentDoc.exists) {
          throw Exception('Tournament not found');
        }

        final tournamentData = tournamentDoc.data()!;
        final currentRegisteredPlayers = (tournamentData['registered_players'] as num?)?.toInt() ?? 0;
        final totalSlots = (tournamentData['total_slots'] as num?)?.toInt() ?? 0;
        final slotsLeft = totalSlots - currentRegisteredPlayers;

        if (slotsLeft <= 0) {
          throw Exception('Tournament is full');
        }

        // Get user document ID (user name) for wallet operations
        final userQuery = await _firestore.collection('users')
            .where('uid', isEqualTo: userId)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) throw Exception('User document not found');
        final userDocRef = _firestore.collection('users').doc(userQuery.docs.first.id);
        final userName = userQuery.docs.first.id;

        // Deduct from wallet if using wallet payment
        if (paymentMethod == 'wallet') {
          final walletRef = _firestore
              .collection('wallet')
              .doc('users')
              .collection(userName)
              .doc('wallet_data');

          transaction.update(walletRef, {
            'total_balance': FieldValue.increment(-entryFee),
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }

        final registrationId = 'reg_${DateTime.now().millisecondsSinceEpoch}';
        final registrationData = <String, dynamic>{
          'registration_id': registrationId,
          'tournament_id': tournamentId,
          'tournament_name': tournament.tournamentName ?? '',
          'game_name': tournament.gameName ?? '',
          'game_id': tournament.gameId ?? '',
          'entry_fee': entryFee,
          'winning_prize': tournament.winningPrize ?? 0.0,
          'total_slots': totalSlots,
          'slots_left': slotsLeft - 1,
          'tournament_type': tournament.tournamentType ?? '',
          'match_time': tournament.matchTime ?? '',
          'map': tournament.map ?? '',
          'mode': tournament.mode ?? '',
          'description': tournament.description ?? '',
          'player_name': playerName,
          'player_id': playerId,
          'user_id': userId,
          'user_name': userName,
          'registration_date': DateTime.now().toIso8601String(),
          'status': 'registered',
          'position': null,
          'kills': 0,
          'winnings': 0.0,
          'result': 'pending',
          'payment_id': paymentId,
          'payment_method': paymentMethod,
        };

        transaction.update(userDocRef, {
          'tournament_registrations': FieldValue.arrayUnion([registrationData]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(_firestore.collection('tournaments').doc(tournamentId), {
          'registered_players': FieldValue.increment(1),
          'slots_left': FieldValue.increment(-1),
          'joined_players': FieldValue.arrayUnion([userId]),
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Add transaction record to wallet
        final transactionData = {
          'transaction_id': 'txn_${DateTime.now().millisecondsSinceEpoch}',
          'type': 'debit',
          'amount': entryFee,
          'status': paymentMethod == 'wallet' ? 'successful' : 'pending',
          'description': 'Tournament registration: ${tournament.tournamentName}',
          'payment_method': paymentMethod,
          'tournament_id': tournamentId,
          'tournament_name': tournament.tournamentName,
          'timestamp': DateTime.now().toIso8601String(),
        };

        final transactionsRef = _firestore
            .collection('wallet')
            .doc('users')
            .collection(userName)
            .doc('transactions');

        transaction.update(transactionsRef, {
          paymentMethod == 'wallet' ? 'successful' : 'pending': FieldValue.arrayUnion([transactionData]),
        });

        print('✅ Successfully registered for tournament: ${tournament.tournamentName}');
        return true;
      });
    } catch (e) {
      print('❌ Error registering for tournament: $e');
      return false;
    }
  }

  Future<bool> isUserRegisteredForTournament(String tournamentId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      // Get user document by UID query
      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return false;

      final userDoc = userQuery.docs.first;
      final data = userDoc.data() ?? {};
      final registrations = data['tournament_registrations'] as List? ?? [];

      for (var registration in registrations) {
        if (registration is Map<String, dynamic> &&
            registration['tournament_id'] == tournamentId &&
            registration['status'] != 'cancelled') {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error checking tournament registration: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getUserTournamentRegistrations() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      // Get user document by UID query
      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return [];

      final userDoc = userQuery.docs.first;
      final data = userDoc.data() ?? {};
      final registrations = data['tournament_registrations'] as List? ?? [];

      List<Map<String, dynamic>> sortedRegistrations = [];
      for (var reg in registrations) {
        if (reg is Map<String, dynamic>) {
          sortedRegistrations.add(reg);
        }
      }

      sortedRegistrations.sort((a, b) {
        final timeA = _parseTimestamp(a['registration_date']);
        final timeB = _parseTimestamp(b['registration_date']);
        return timeB.compareTo(timeA);
      });

      return sortedRegistrations;
    } catch (e) {
      print('❌ Error getting tournament registrations: $e');
      return [];
    }
  }

  // ========== ADMIN METHODS ==========
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').limit(100).get();

      final List<Map<String, dynamic>> users = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userName = doc.id;

        // Get wallet data for each user
        final walletDoc = await _firestore
            .collection('wallet')
            .doc('users')
            .collection(userName)
            .doc('wallet_data')
            .get();

        final walletData = walletDoc.data() ?? {};

        users.add({
          'id': doc.id,
          'name': (data['name'] as String?) ?? 'User',
          'email': (data['email'] as String?) ?? '',
          'phone': (data['phone'] as String?) ?? '',
          'wallet_balance': (walletData['total_balance'] as num?)?.toDouble() ?? 0.0,
          'total_winnings': (walletData['total_winning'] as num?)?.toDouble() ?? 0.0,
          'created_at': data['createdAt'],
          'last_login': data['last_login'],
          'role': data['role'] ?? 'user',
        });
      }

      return users;
    } catch (e) {
      print('❌ Error getting all users: $e');
      return [];
    }
  }

  // ========== GAME PROFILES MANAGEMENT ==========
  Future<bool> saveUserGameProfile({
    required String gameId,
    required String gameName,
    required String playerName,
    required String playerId,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      // Get user document by UID query
      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return false;

      final gameKey = gameName.toUpperCase().replaceAll(' ', '_');

      await _firestore.collection('users').doc(userQuery.docs.first.id).update({
        'tournaments.$gameKey.${gameKey}_NAME': playerName,
        'tournaments.$gameKey.${gameKey}_ID': playerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Game profile saved for $gameName');
      return true;
    } catch (e) {
      print('❌ Error saving game profile: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getGameProfile(String gameName) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      // Get user document by UID query
      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return null;

      final userDoc = userQuery.docs.first;
      final data = userDoc.data();
      final tournaments = data?['tournaments'] as Map<String, dynamic>? ?? {};
      final gameKey = gameName.toUpperCase().replaceAll(' ', '_');

      final profile = tournaments[gameKey];
      return profile is Map<String, dynamic> ? profile : null;
    } catch (e) {
      print('❌ Error getting game profile: $e');
      return null;
    }
  }

  String _getGameProfileValue(Map<String, dynamic>? gameProfile, String key) {
    if (gameProfile == null) return 'Player';
    final value = gameProfile[key];
    return value?.toString() ?? 'Player';
  }
}