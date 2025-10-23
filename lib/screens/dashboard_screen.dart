// ===============================
// DASHBOARD SCREEN WITH COMPLETE FIXES
// ===============================
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _topPlayers = [];
  List<Map<String, dynamic>> _recentMatches = [];
  List<Map<String, dynamic>> _recentTransactions = [];
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _userProfile = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      await Future.wait([
        _loadUserProfile(),
        _loadUserStats(),
        _loadTopPlayers(),
        _loadRecentMatches(),
        _loadRecentTransactions(),
      ]);
    } catch (e) {
      print('❌ Error loading dashboard data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Get user document by querying with UID
        final userQuery = await _firestore
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          setState(() {
            _userProfile = userDoc.data()!;
            _userProfile['documentId'] = userDoc.id; // Store the actual document ID
          });
          print('✅ User profile loaded: ${_userProfile['name']}');
        } else {
          print('❌ User document not found for UID: ${user.uid}');
        }
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get user document to find the actual document ID
      final userQuery = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        print('❌ User document not found');
        return;
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();
      final userName = userDoc.id; // This is the actual document ID

      print('🔍 Loading wallet data for user: $userName');

      // Try multiple wallet locations
      double totalWinnings = 0.0;
      double currentBalance = 0.0;

      // METHOD 1: Try wallet_data document (most common)
      try {
        final walletDataDoc = await _firestore
            .collection('wallet')
            .doc('users')
            .collection(userName)
            .doc('wallet_data')
            .get();

        if (walletDataDoc.exists) {
          final walletData = walletDataDoc.data();
          totalWinnings = (walletData?['total_winning'] as num?)?.toDouble() ?? 0.0;
          currentBalance = (walletData?['total_balance'] as num?)?.toDouble() ?? 0.0;
          print('💰 Wallet data found in wallet_data: balance=$currentBalance, winning=$totalWinnings');
        } else {
          print('❌ No wallet_data document found');
        }
      } catch (e) {
        print('⚠️ Error checking wallet_data: $e');
      }

      // METHOD 2: Try balance document (alternative location)
      if (currentBalance == 0.0) {
        try {
          final balanceDoc = await _firestore
              .collection('wallet')
              .doc('users')
              .collection(userName)
              .doc('balance')
              .get();

          if (balanceDoc.exists) {
            final balanceData = balanceDoc.data();
            totalWinnings = (balanceData?['total_winning'] as num?)?.toDouble() ?? 0.0;
            currentBalance = (balanceData?['total_balance'] as num?)?.toDouble() ?? 0.0;
            print('💰 Wallet data found in balance: balance=$currentBalance, winning=$totalWinnings');
          } else {
            print('❌ No balance document found');
          }
        } catch (e) {
          print('⚠️ Error checking balance document: $e');
        }
      }

      // METHOD 3: Check if wallet data is in user document itself
      if (currentBalance == 0.0) {
        final userWallet = userData['wallet'] as Map<String, dynamic>?;
        if (userWallet != null) {
          totalWinnings = (userWallet['total_winning'] as num?)?.toDouble() ?? 0.0;
          currentBalance = (userWallet['total_balance'] as num?)?.toDouble() ?? 0.0;
          print('💰 Wallet data found in user document: balance=$currentBalance, winning=$totalWinnings');
        } else {
          print('❌ No wallet data in user document');
        }
      }

      // Get tournament registrations to calculate stats
      final registrations = userData['tournament_registrations'] as List<dynamic>? ?? [];

      int totalMatches = registrations.length;
      int matchesWon = registrations.where((reg) =>
      reg is Map<String, dynamic> &&
          reg['status'] == 'completed' &&
          (reg['position'] == 1 || reg['is_winner'] == true)).length;

      double winRate = totalMatches > 0 ? (matchesWon / totalMatches * 100) : 0.0;

      setState(() {
        _userStats = {
          'total_matches': totalMatches,
          'matches_won': matchesWon,
          'matches_lost': totalMatches - matchesWon,
          'total_winnings': totalWinnings,
          'current_balance': currentBalance,
          'win_rate': winRate,
          'tournaments_played': totalMatches,
        };
      });

      print('📊 User stats loaded:');
      print('   - Balance: ₹$currentBalance');
      print('   - Winnings: ₹$totalWinnings');
      print('   - Matches: $totalMatches');
      print('   - Won: $matchesWon');
      print('   - Win Rate: $winRate%');

    } catch (e) {
      print('❌ Error loading user stats: $e');
      setState(() {
        _userStats = {
          'total_matches': 0,
          'matches_won': 0,
          'matches_lost': 0,
          'total_winnings': 0.0,
          'current_balance': 0.0,
          'win_rate': 0.0,
          'tournaments_played': 0,
        };
      });
    }
  }

  Future<void> _loadTopPlayers() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      List<Map<String, dynamic>> players = [];

      // If there's only one user in the system, show them as top player regardless of winnings
      if (usersSnapshot.docs.length == 1) {
        final userDoc = usersSnapshot.docs.first;
        final userData = userDoc.data();
        final userName = userDoc.id;

        double totalWinning = 0.0;
        double totalBalance = 0.0;

        // Try to get wallet data
        try {
          final walletDoc = await _firestore
              .collection('wallet')
              .doc('users')
              .collection(userName)
              .doc('wallet_data')
              .get();

          if (walletDoc.exists) {
            final walletData = walletDoc.data() ?? {};
            totalWinning = (walletData['total_winning'] as num?)?.toDouble() ?? 0.0;
            totalBalance = (walletData['total_balance'] as num?)?.toDouble() ?? 0.0;
          }
        } catch (e) {
          // Try balance document as fallback
          try {
            final balanceDoc = await _firestore
                .collection('wallet')
                .doc('users')
                .collection(userName)
                .doc('balance')
                .get();

            if (balanceDoc.exists) {
              final balanceData = balanceDoc.data() ?? {};
              totalWinning = (balanceData['total_winning'] as num?)?.toDouble() ?? 0.0;
              totalBalance = (balanceData['total_balance'] as num?)?.toDouble() ?? 0.0;
            }
          } catch (e) {
            print('⚠️ Error loading wallet for user $userName: $e');
          }
        }

        players.add({
          'userId': userData['uid'] ?? userName,
          'name': userData['name'] ?? 'Unknown Player',
          'total_winning': totalWinning,
          'total_balance': totalBalance,
          'email': userData['email'] ?? '',
          'is_only_player': true, // Flag to indicate this is the only player
        });
      } else {
        // Multiple users - process normally
        for (var userDoc in usersSnapshot.docs) {
          final userData = userDoc.data();
          final userName = userDoc.id;

          // Get wallet data for each user from multiple locations
          double totalWinning = 0.0;
          double totalBalance = 0.0;

          // Try wallet_data first
          try {
            final walletDoc = await _firestore
                .collection('wallet')
                .doc('users')
                .collection(userName)
                .doc('wallet_data')
                .get();

            if (walletDoc.exists) {
              final walletData = walletDoc.data() ?? {};
              totalWinning = (walletData['total_winning'] as num?)?.toDouble() ?? 0.0;
              totalBalance = (walletData['total_balance'] as num?)?.toDouble() ?? 0.0;
            }
          } catch (e) {
            // Try balance document as fallback
            try {
              final balanceDoc = await _firestore
                  .collection('wallet')
                  .doc('users')
                  .collection(userName)
                  .doc('balance')
                  .get();

              if (balanceDoc.exists) {
                final balanceData = balanceDoc.data() ?? {};
                totalWinning = (balanceData['total_winning'] as num?)?.toDouble() ?? 0.0;
                totalBalance = (balanceData['total_balance'] as num?)?.toDouble() ?? 0.0;
              }
            } catch (e) {
              print('⚠️ Error loading wallet for user $userName: $e');
            }
          }

          // Include players even if winnings are zero (show all players)
          players.add({
            'userId': userData['uid'] ?? userName,
            'name': userData['name'] ?? 'Unknown Player',
            'total_winning': totalWinning,
            'total_balance': totalBalance,
            'email': userData['email'] ?? '',
            'is_only_player': false,
          });
        }
      }

      // Sort by total winnings (descending) - players with zero winnings will be at the bottom
      players.sort((a, b) => (b['total_winning'] as double).compareTo(a['total_winning'] as double));

      // Take top 10 or all players if less than 10
      setState(() {
        _topPlayers = players.take(10).toList();
      });
      print('🏆 Top players loaded: ${_topPlayers.length}');
    } catch (e) {
      print('❌ Error loading top players: $e');
      setState(() {
        _topPlayers = [];
      });
    }
  }

  Future<void> _loadRecentMatches() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userQuery = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return;

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data() ?? {};
      final registrations = userData['tournament_registrations'] as List<dynamic>? ?? [];

      List<Map<String, dynamic>> matches = [];

      for (var reg in registrations) {
        if (reg is Map<String, dynamic>) {
          final tournamentId = reg['tournament_id'];
          final status = reg['status'] ?? 'registered';

          // Get tournament details
          try {
            final tournamentDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
            if (tournamentDoc.exists) {
              final tournamentData = tournamentDoc.data()!;

              matches.add({
                'tournament_id': tournamentId,
                'tournament_name': tournamentData['tournament_name'] ?? 'Unknown Tournament',
                'game_name': tournamentData['game_name'] ?? 'Unknown Game',
                'entry_fee': (tournamentData['entry_fee'] as num?)?.toDouble() ?? 0.0,
                'status': status,
                'position': reg['position'] ?? 0,
                'is_winner': reg['is_winner'] ?? false,
                'registered_at': reg['registered_at'],
                'match_time': tournamentData['tournament_start'],
              });
            }
          } catch (e) {
            print('⚠️ Error loading tournament $tournamentId: $e');
          }
        }
      }

      // Sort by registration time (most recent first)
      matches.sort((a, b) {
        final timeA = a['registered_at'] as Timestamp? ?? Timestamp.now();
        final timeB = b['registered_at'] as Timestamp? ?? Timestamp.now();
        return timeB.compareTo(timeA);
      });

      setState(() {
        _recentMatches = matches.take(5).toList();
      });
      print('🎮 Recent matches loaded: ${_recentMatches.length}');
    } catch (e) {
      print('❌ Error loading recent matches: $e');
      setState(() {
        _recentMatches = [];
      });
    }
  }

  Future<void> _loadRecentTransactions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get user document ID first
      final userQuery = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        print('❌ User document not found for transactions');
        return;
      }

      final userName = userQuery.docs.first.id;
      print('🔍 Loading transactions for user: $userName');

      List<Map<String, dynamic>> transactions = [];

      // METHOD 1: Check transactions document in wallet collection
      try {
        final transactionsDoc = await _firestore
            .collection('wallet')
            .doc('users')
            .collection(userName)
            .doc('transactions')
            .get();

        if (transactionsDoc.exists) {
          final transactionsData = transactionsDoc.data() ?? {};
          print('📄 Transactions document data found');

          // Check different transaction status structures
          final statusTypes = ['successful', 'pending', 'failed', 'completed', 'approved', 'denied'];

          for (var status in statusTypes) {
            final statusTransactions = transactionsData[status] as List<dynamic>? ?? [];
            print('💳 $status transactions: ${statusTransactions.length}');

            for (var transaction in statusTransactions) {
              if (transaction is Map<String, dynamic>) {
                final timestamp = transaction['timestamp'] ??
                    transaction['created_at'] ??
                    transaction['date'] ??
                    Timestamp.now();

                transactions.add({
                  'id': transaction['transaction_id'] ??
                      transaction['id'] ??
                      '${DateTime.now().millisecondsSinceEpoch}',
                  'amount': (transaction['amount'] as num?)?.toDouble() ?? 0.0,
                  'type': transaction['type'] ?? 'unknown',
                  'description': transaction['description'] ??
                      transaction['note'] ??
                      'No Description',
                  'status': status,
                  'payment_method': transaction['payment_method'] ??
                      transaction['method'] ??
                      'No Method',
                  'timestamp': timestamp is Timestamp ? timestamp : Timestamp.now(),
                });
              }
            }
          }
        } else {
          print('❌ No transactions document found at wallet/users/$userName/transactions');
        }
      } catch (e) {
        print('⚠️ Error loading transactions from wallet: $e');
      }

      // METHOD 2: Check if transactions are in user document directly
      if (transactions.isEmpty) {
        try {
          final userData = userQuery.docs.first.data();
          final userTransactions = userData['transactions'] as List<dynamic>? ?? [];
          print('📄 User document transactions: ${userTransactions.length}');

          for (var transaction in userTransactions) {
            if (transaction is Map<String, dynamic>) {
              final timestamp = transaction['timestamp'] ??
                  transaction['created_at'] ??
                  transaction['date'] ??
                  Timestamp.now();

              transactions.add({
                'id': transaction['transaction_id'] ??
                    transaction['id'] ??
                    '${DateTime.now().millisecondsSinceEpoch}',
                'amount': (transaction['amount'] as num?)?.toDouble() ?? 0.0,
                'type': transaction['type'] ?? 'unknown',
                'description': transaction['description'] ??
                    transaction['note'] ??
                    'No Description',
                'status': transaction['status'] ?? 'completed',
                'payment_method': transaction['payment_method'] ??
                    transaction['method'] ??
                    'No Method',
                'timestamp': timestamp is Timestamp ? timestamp : Timestamp.now(),
              });
            }
          }
        } catch (e) {
          print('⚠️ Error loading transactions from user document: $e');
        }
      }

      // METHOD 3: Check withdrawal requests as transactions - FIXED STATUS ISSUE
      try {
        final withdrawDoc = await _firestore
            .collection('wallet')
            .doc('users')
            .collection(userName)
            .doc('withdrawal_requests')
            .get();

        if (withdrawDoc.exists) {
          final withdrawData = withdrawDoc.data() ?? {};
          print('💰 Withdrawal data found');

          // Check pending withdrawals
          final pendingWithdrawals = withdrawData['pending'] as List<dynamic>? ?? [];
          for (var withdrawal in pendingWithdrawals) {
            if (withdrawal is Map<String, dynamic>) {
              transactions.add({
                'id': withdrawal['withdrawal_id'] ?? 'withdrawal_${DateTime.now().millisecondsSinceEpoch}',
                'amount': (withdrawal['amount'] as num?)?.toDouble() ?? 0.0,
                'type': 'withdrawal',
                'description': 'Withdrawal Request',
                'status': 'pending',
                'payment_method': withdrawal['payment_method'] ?? 'No Method',
                'timestamp': withdrawal['requested_at'] ?? Timestamp.now(),
              });
            }
          }

          // Check approved withdrawals
          final approvedWithdrawals = withdrawData['approved'] as List<dynamic>? ?? [];
          for (var withdrawal in approvedWithdrawals) {
            if (withdrawal is Map<String, dynamic>) {
              transactions.add({
                'id': withdrawal['withdrawal_id'] ?? 'withdrawal_${DateTime.now().millisecondsSinceEpoch}',
                'amount': (withdrawal['amount'] as num?)?.toDouble() ?? 0.0,
                'type': 'withdrawal',
                'description': 'Withdrawal Approved',
                'status': 'completed', // FIXED: Changed from 'approved' to 'completed'
                'payment_method': withdrawal['payment_method'] ?? 'No Method',
                'timestamp': withdrawal['processed_at'] ?? withdrawal['approved_at'] ?? Timestamp.now(),
              });
            }
          }

          // Check rejected withdrawals
          final rejectedWithdrawals = withdrawData['rejected'] as List<dynamic>? ?? [];
          for (var withdrawal in rejectedWithdrawals) {
            if (withdrawal is Map<String, dynamic>) {
              transactions.add({
                'id': withdrawal['withdrawal_id'] ?? 'withdrawal_${DateTime.now().millisecondsSinceEpoch}',
                'amount': (withdrawal['amount'] as num?)?.toDouble() ?? 0.0,
                'type': 'withdrawal',
                'description': 'Withdrawal Rejected',
                'status': 'failed',
                'payment_method': withdrawal['payment_method'] ?? 'No Method',
                'timestamp': withdrawal['rejected_at'] ?? Timestamp.now(),
              });
            }
          }
        } else {
          print('❌ No withdrawal_requests document found');
        }
      } catch (e) {
        print('⚠️ Error loading withdrawal requests: $e');
      }

      // METHOD 4: Check tournament registrations as transactions
      if (transactions.isEmpty) {
        try {
          final userData = userQuery.docs.first.data();
          final registrations = userData['tournament_registrations'] as List<dynamic>? ?? [];

          for (var reg in registrations) {
            if (reg is Map<String, dynamic>) {
              final entryFee = (reg['entry_fee'] as num?)?.toDouble() ?? 0.0;
              if (entryFee > 0) {
                transactions.add({
                  'id': 'tournament_${reg['tournament_id']}',
                  'amount': entryFee,
                  'type': 'tournament_entry',
                  'description': 'Tournament Entry Fee',
                  'status': 'completed',
                  'payment_method': 'Wallet',
                  'timestamp': reg['registered_at'] ?? Timestamp.now(),
                });
              }

              // Add winnings as transactions
              final winnings = (reg['winnings'] as num?)?.toDouble() ?? 0.0;
              if (winnings > 0) {
                transactions.add({
                  'id': 'winning_${reg['tournament_id']}',
                  'amount': winnings,
                  'type': 'winning',
                  'description': 'Tournament Winning',
                  'status': 'completed',
                  'payment_method': 'System',
                  'timestamp': reg['completed_at'] ?? Timestamp.now(),
                });
              }
            }
          }
        } catch (e) {
          print('⚠️ Error loading tournament transactions: $e');
        }
      }

      // METHOD 5: Generate sample transactions for testing if still empty
      if (transactions.isEmpty) {
        print('⚠️ No transactions found ');
        // transactions = _generateSampleTransactions();
      }

      // Sort by timestamp (most recent first)
      transactions.sort((a, b) {
        final timeA = a['timestamp'] as Timestamp;
        final timeB = b['timestamp'] as Timestamp;
        return timeB.compareTo(timeA);
      });

      setState(() {
        _recentTransactions = transactions.take(5).toList();
      });

      print('💳 Final transactions loaded: ${_recentTransactions.length}');
      for (var tx in _recentTransactions) {
        print('   - ${tx['type']}: ₹${tx['amount']} (${tx['status']}) - ${tx['description']}');
      }

    } catch (e) {
      print('❌ Error loading recent transactions: $e');
      // Generate sample data on error
      setState(() {
        _recentTransactions = [];
      });
    }
  }

  List<Map<String, dynamic>> _generateSampleTransactions() {
    return [
      {
        'id': 'sample_1',
        'amount': 500.0,
        'type': 'deposit',
        'description': 'Wallet Recharge via UPI',
        'status': 'completed',
        'payment_method': 'UPI',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 1))),
      },
      {
        'id': 'sample_2',
        'amount': 100.0,
        'type': 'tournament_entry',
        'description': 'BGMI Championship Entry',
        'status': 'completed',
        'payment_method': 'Wallet',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 3))),
      },
      {
        'id': 'sample_3',
        'amount': 250.0,
        'type': 'winning',
        'description': 'Tournament Prize Money',
        'status': 'completed',
        'payment_method': 'System',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1))),
      },
      {
        'id': 'sample_4',
        'amount': 50.0,
        'type': 'tournament_entry',
        'description': 'Free Fire Tournament',
        'status': 'completed',
        'payment_method': 'Wallet',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 2))),
      },
      {
        'id': 'sample_5',
        'amount': 150.0,
        'type': 'withdrawal',
        'description': 'Withdrawal to Bank Account',
        'status': 'pending',
        'payment_method': 'Bank Transfer',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1))),
      },
    ];
  }

  String _formatTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _getMatchStatusIcon(String status, bool isWinner) {
    switch (status) {
      case 'completed':
        return isWinner ? '🏆' : '❌';
      case 'ongoing':
        return '⚡';
      case 'registered':
        return '⏰';
      case 'cancelled':
        return '🚫';
      default:
        return '❓';
    }
  }

  String _getTransactionIcon(String type) {
    switch (type.toLowerCase()) {
      case 'deposit':
      case 'credit':
        return '💰';
      case 'withdrawal':
      case 'debit':
        return '💸';
      case 'tournament_entry':
        return '🎮';
      case 'winning':
        return '🏆';
      case 'refund':
        return '↩️';
      default:
        return '💳';
    }
  }

  Color _getTransactionColor(String type) {
    switch (type.toLowerCase()) {
      case 'deposit':
      case 'winning':
      case 'refund':
      case 'credit':
        return Colors.green;
      case 'withdrawal':
      case 'tournament_entry':
      case 'debit':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Center(child: CircularProgressIndicator())
        : RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeSection(),
            SizedBox(height: 24),

            // Quick Stats Section
            _buildQuickStatsSection(),
            SizedBox(height: 24),

            // Top Players Section
            _buildTopPlayersSection(),
            SizedBox(height: 24),

            // Recent Matches Section
            _buildRecentMatchesSection(),
            SizedBox(height: 24),

            // Recent Transactions Section
            _buildRecentTransactionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final userName = _userProfile['name'] ?? 'Player';
    final userEmail = _userProfile['email'] ?? '';
    final currentBalance = _userStats['current_balance'] ?? 0.0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.deepPurple,
              child: Icon(
                Icons.person,
                size: 30,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $userName!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_balance_wallet, size: 16, color: Colors.deepPurple),
                        SizedBox(width: 4),
                        Text(
                          '₹${currentBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Statistics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildStatCard(
              'Total Matches',
              '${_userStats['total_matches'] ?? 0}',
              Icons.sports_esports,
              Colors.blue,
            ),
            _buildStatCard(
              'Matches Won',
              '${_userStats['matches_won'] ?? 0}',
              Icons.emoji_events,
              Colors.green,
            ),
            _buildStatCard(
              'Total Winnings',
              '₹${(_userStats['total_winnings'] ?? 0.0).toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.orange,
            ),
            _buildStatCard(
              'Win Rate',
              '${(_userStats['win_rate'] ?? 0.0).toStringAsFixed(1)}%',
              Icons.trending_up,
              Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopPlayersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Top Players',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadTopPlayers,
              tooltip: 'Refresh Leaderboard',
            ),
          ],
        ),
        SizedBox(height: 12),
        if (_topPlayers.isEmpty)
          _buildEmptyState(
            'No Players Data',
            Icons.leaderboard,
            'Play tournaments to appear on leaderboard',
          )
        else
          Container(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _topPlayers.length,
              itemBuilder: (context, index) {
                final player = _topPlayers[index];
                return _buildPlayerCard(player, index + 1);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRecentMatchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent Matches',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            TextButton(
              onPressed: _loadRecentMatches,
              child: Text(
                'View All',
                style: TextStyle(color: Colors.deepPurple),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        if (_recentMatches.isEmpty)
          _buildEmptyState(
            'No Recent Matches',
            Icons.sports_esports,
            'Join tournaments to see your matches here',
          )
        else
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: _recentMatches.map((match) {
                  return Column(
                    children: [
                      _buildMatchItem(match),
                      if (_recentMatches.indexOf(match) != _recentMatches.length - 1)
                        Divider(),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            TextButton(
              onPressed: _loadRecentTransactions,
              child: Text(
                'View All',
                style: TextStyle(color: Colors.deepPurple),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        if (_recentTransactions.isEmpty)
          _buildEmptyState(
            'No Transactions',
            Icons.account_balance_wallet,
            'Your transactions will appear here',
          )
        else
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: _recentTransactions.map((transaction) {
                  return Column(
                    children: [
                      _buildTransactionItem(transaction),
                      if (_recentTransactions.indexOf(transaction) != _recentTransactions.length - 1)
                        Divider(),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic> player, int rank) {
    final medalColor = rank == 1
        ? Colors.amber
        : rank == 2
        ? Colors.grey
        : rank == 3
        ? Colors.orange
        : Colors.deepPurple;

    final isOnlyPlayer = player['is_only_player'] ?? false;
    final totalWinning = player['total_winning'] ?? 0.0;

    return Container(
      width: 150,
      margin: EdgeInsets.only(right: 12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: medalColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    rank.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                player['name'] ?? 'Player',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                '₹${totalWinning.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: totalWinning > 0 ? Colors.green : Colors.grey,
                ),
              ),
              SizedBox(height: 4),
              Text(
                isOnlyPlayer ? 'Only Player' : 'Top Earner',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchItem(Map<String, dynamic> match) {
    final status = match['status'] ?? 'registered';
    final isWinner = match['is_winner'] ?? false;
    final position = match['position'] ?? 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Text(
          _getMatchStatusIcon(status, isWinner),
          style: TextStyle(fontSize: 16),
        ),
      ),
      title: Text(
        match['tournament_name'] ?? 'Unknown Tournament',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${match['game_name'] ?? 'Game'} • ₹${(match['entry_fee'] ?? 0.0).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 2),
          Text(
            _getMatchStatusText(status, isWinner, position),
            style: TextStyle(
              fontSize: 11,
              color: _getMatchStatusColor(status, isWinner),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing: Text(
        match['registered_at'] != null
            ? _formatTimeAgo(match['registered_at'] as Timestamp)
            : 'N/A',
        style: TextStyle(
          fontSize: 10,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final type = transaction['type'] ?? 'unknown';
    final amount = transaction['amount'] ?? 0.0;
    final status = transaction['status'] ?? 'unknown';

    // FIXED: Unified logic for all transaction types
    bool isPositive;
    String sign;
    Color color;

    // Check if using credit/debit system
    if (type == 'credit' || type == 'debit') {
      isPositive = type == 'credit';
      sign = isPositive ? '+' : '-';
      color = isPositive ? Colors.green : Colors.red;
    }
    // Check deposit/winning/refund types
    else if (type.toLowerCase() == 'deposit' ||
        type.toLowerCase() == 'winning' ||
        type.toLowerCase() == 'refund') {
      isPositive = true;
      sign = '+';
      color = Colors.green;
    }
    // Check withdrawal/debit types
    else if (type.toLowerCase() == 'withdrawal' ||
        type.toLowerCase() == 'tournament_entry') {
      isPositive = false;
      sign = '-';
      color = Colors.red;
    }
    // Default case - use amount to determine
    else {
      isPositive = amount >= 0;
      sign = isPositive ? '+' : '-';
      color = isPositive ? Colors.green : Colors.red;
    }

    // Ensure amount is positive for display
    final displayAmount = amount.abs();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getTransactionColor(type).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Text(
          _getTransactionIcon(type),
          style: TextStyle(fontSize: 16),
        ),
      ),
      title: Text(
        _formatTransactionType(type),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        transaction['description'] ?? 'No description',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$sign₹${displayAmount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                color: _getStatusColor(status),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, IconData icon, String message) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 50,
              color: Colors.grey[400],
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getMatchStatusText(String status, bool isWinner, int position) {
    switch (status) {
      case 'completed':
        return isWinner ? 'Winner 🏆' : 'Position: ${position > 0 ? position : 'N/A'}';
      case 'ongoing':
        return 'Live Now';
      case 'registered':
        return 'Upcoming';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color _getMatchStatusColor(String status, bool isWinner) {
    switch (status) {
      case 'completed':
        return isWinner ? Colors.green : Colors.orange;
      case 'ongoing':
        return Colors.blue;
      case 'registered':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'successful':
      case 'completed':
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
      case 'cancelled':
      case 'denied':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTransactionType(String type) {
    switch (type.toLowerCase()) {
      case 'deposit':
      case 'credit':
        return 'Money Added';
      case 'withdrawal':
      case 'debit':
        return 'Withdrawal';
      case 'tournament_entry':
        return 'Tournament Entry';
      case 'winning':
        return 'Tournament Winning';
      case 'refund':
        return 'Refund';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }
}