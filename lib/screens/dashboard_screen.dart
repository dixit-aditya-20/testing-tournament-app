// ===============================
// DASHBOARD SCREEN WITH ADD MONEY FUNCTIONALITY
// ===============================
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/firebase_service.dart';
import 'notificcation_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add Razorpay integration
  late Razorpay _razorpay;
  final TextEditingController _amountController = TextEditingController();
  bool _isProcessing = false;

  List<Map<String, dynamic>> _topPlayers = [];
  List<Map<String, dynamic>> _recentMatches = [];
  List<Map<String, dynamic>> _recentTransactions = [];
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _userProfile = {};
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Initialize Razorpay
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _loadDashboardData();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _amountController.dispose();
    super.dispose();
  }

  // Add Money Methods
  void _showAddMoneyDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddMoneyBottomSheet(
        amountController: _amountController,
        walletBalance: _userStats['current_balance'] ?? 0.0,
        onProceed: _processRazorpayPayment,
        isProcessing: _isProcessing,
      ),
    );
  }

  void _processRazorpayPayment(double amount) {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    var options = {
      'key': 'rzp_test_1DP5mmOlF5G5ag', // Replace with your Razorpay key
      'amount': (amount * 100).toInt(),
      'name': 'Game Tournaments',
      'description': 'Add Money to Wallet',
      'prefill': {
        'contact': '8888888888',
        'email': _auth.currentUser?.email ?? 'user@example.com',
      },
      'theme': {'color': Colors.deepPurple.value},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print('Razorpay Error: $e');
      setState(() {
        _isProcessing = false;
      });
      _showErrorSnackBar('Error opening payment gateway');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    try {
      final success = await _firebaseService.addMoney(amount, response.paymentId!, 'razorpay');

      if (success) {
        _amountController.clear();
        _showSuccessSnackBar('₹${amount.toStringAsFixed(2)} added to your wallet!');
        // Refresh dashboard data to update balance
        _refreshData();
      } else {
        throw Exception('Failed to add money to wallet');
      }
    } catch (e) {
      print('❌ Error in payment success: $e');
      _showErrorSnackBar('Error adding money to wallet');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      _isProcessing = false;
    });
    _showErrorSnackBar('Payment Failed: ${response.message ?? "Unknown error"}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showInfoSnackBar('External Wallet Selected: ${response.walletName}');
  }

  // Snackbar helpers
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      _showSnackBar('Failed to load dashboard data');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _loadDashboardData();
    setState(() => _isRefreshing = false);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.deepPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userQuery = await _firestore
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          setState(() {
            _userProfile = userDoc.data()!;
            _userProfile['documentId'] = userDoc.id;
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
      final userName = userDoc.id;

      print('🔍 Loading wallet data for user: $userName');

      double totalWinnings = 0.0;
      double currentBalance = 0.0;

      // METHOD 1: Try wallet_data document
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
        }
      } catch (e) {
        print('⚠️ Error checking wallet_data: $e');
      }

      // METHOD 2: Try balance document
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
          }
        } catch (e) {
          print('⚠️ Error checking balance document: $e');
        }
      }

      // METHOD 3: Check user document wallet
      if (currentBalance == 0.0) {
        final userWallet = userData['wallet'] as Map<String, dynamic>?;
        if (userWallet != null) {
          totalWinnings = (userWallet['total_winning'] as num?)?.toDouble() ?? 0.0;
          currentBalance = (userWallet['total_balance'] as num?)?.toDouble() ?? 0.0;
          print('💰 Wallet data found in user document: balance=$currentBalance, winning=$totalWinnings');
        }
      }

      // Calculate match statistics
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
          'current_streak': 0,
          'best_streak': 0,
        };
      });

      print('📊 User stats loaded successfully');

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
          'current_streak': 0,
          'best_streak': 0,
        };
      });
    }
  }

  Future<void> _loadTopPlayers() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      List<Map<String, dynamic>> players = [];

      if (usersSnapshot.docs.length == 1) {
        final userDoc = usersSnapshot.docs.first;
        final userData = userDoc.data();
        final userName = userDoc.id;

        double totalWinning = 0.0;
        double totalBalance = 0.0;

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
          print('⚠️ Error loading wallet for user $userName: $e');
        }

        players.add({
          'userId': userData['uid'] ?? userName,
          'name': userData['name'] ?? 'Unknown Player',
          'total_winning': totalWinning,
          'total_balance': totalBalance,
          'email': userData['email'] ?? '',
          'is_only_player': true,
          'avatar': userData['avatar'] ?? '',
        });
      } else {
        for (var userDoc in usersSnapshot.docs) {
          final userData = userDoc.data();
          final userName = userDoc.id;

          double totalWinning = 0.0;
          double totalBalance = 0.0;

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
            print('⚠️ Error loading wallet for user $userName: $e');
          }

          players.add({
            'userId': userData['uid'] ?? userName,
            'name': userData['name'] ?? 'Unknown Player',
            'total_winning': totalWinning,
            'total_balance': totalBalance,
            'email': userData['email'] ?? '',
            'is_only_player': false,
            'avatar': userData['avatar'] ?? '',
          });
        }
      }

      players.sort((a, b) => (b['total_winning'] as double).compareTo(a['total_winning'] as double));

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

          try {
            final tournamentDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
            if (tournamentDoc.exists) {
              final tournamentData = tournamentDoc.data()!;

              matches.add({
                'tournament_id': tournamentId,
                'tournament_name': tournamentData['tournament_name'] ?? 'Unknown Tournament',
                'game_name': tournamentData['game_name'] ?? 'Unknown Game',
                'entry_fee': (tournamentData['entry_fee'] as num?)?.toDouble() ?? 0.0,
                'prize_pool': (tournamentData['prize_pool'] as num?)?.toDouble() ?? 0.0,
                'status': status,
                'position': reg['position'] ?? 0,
                'is_winner': reg['is_winner'] ?? false,
                'registered_at': reg['registered_at'],
                'match_time': tournamentData['tournament_start'],
                'players_joined': tournamentData['players_joined'] ?? 0,
              });
            }
          } catch (e) {
            print('⚠️ Error loading tournament $tournamentId: $e');
          }
        }
      }

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

      // METHOD 1: Check transactions document
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
                  'reference_id': transaction['reference_id'] ?? '',
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

      // METHOD 2: Check user document transactions
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
                'reference_id': transaction['reference_id'] ?? '',
              });
            }
          }
        } catch (e) {
          print('⚠️ Error loading transactions from user document: $e');
        }
      }

      // METHOD 3: Check withdrawal requests
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
                'reference_id': withdrawal['reference_id'] ?? '',
              });
            }
          }

          final approvedWithdrawals = withdrawData['approved'] as List<dynamic>? ?? [];
          for (var withdrawal in approvedWithdrawals) {
            if (withdrawal is Map<String, dynamic>) {
              transactions.add({
                'id': withdrawal['withdrawal_id'] ?? 'withdrawal_${DateTime.now().millisecondsSinceEpoch}',
                'amount': (withdrawal['amount'] as num?)?.toDouble() ?? 0.0,
                'type': 'withdrawal',
                'description': 'Withdrawal Approved',
                'status': 'completed',
                'payment_method': withdrawal['payment_method'] ?? 'No Method',
                'timestamp': withdrawal['processed_at'] ?? withdrawal['approved_at'] ?? Timestamp.now(),
                'reference_id': withdrawal['reference_id'] ?? '',
              });
            }
          }

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
                'reference_id': withdrawal['reference_id'] ?? '',
              });
            }
          }
        } else {
          print('❌ No withdrawal_requests document found');
        }
      } catch (e) {
        print('⚠️ Error loading withdrawal requests: $e');
      }

      // METHOD 4: Check tournament registrations
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
                  'reference_id': reg['tournament_id'] ?? '',
                });
              }

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
                  'reference_id': reg['tournament_id'] ?? '',
                });
              }
            }
          }
        } catch (e) {
          print('⚠️ Error loading tournament transactions: $e');
        }
      }

      // Sort by timestamp
      transactions.sort((a, b) {
        final timeA = a['timestamp'] as Timestamp;
        final timeB = b['timestamp'] as Timestamp;
        return timeB.compareTo(timeA);
      });

      setState(() {
        _recentTransactions = transactions.take(5).toList();
      });

      print('💳 Final transactions loaded: ${_recentTransactions.length}');

    } catch (e) {
      print('❌ Error loading recent transactions: $e');
      setState(() {
        _recentTransactions = [];
      });
    }
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

  String _formatDate(Timestamp timestamp) {
    return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
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
      case 'bonus':
        return '🎁';
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
      case 'bonus':
        return Colors.green;
      case 'withdrawal':
      case 'tournament_entry':
      case 'debit':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  void _handleViewAllMatches() {
    print('Navigate to all matches screen');
  }

  void _handleViewAllTransactions() {
    print('Navigate to all transactions screen');
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? _buildLoadingScreen()
        : Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.deepPurple,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildWelcomeSection()),
            SliverToBoxAdapter(child: _buildQuickStatsSection()),
            SliverToBoxAdapter(child: _buildTopPlayersSection()),
            SliverToBoxAdapter(child: _buildRecentMatchesSection()),
            SliverToBoxAdapter(child: _buildRecentTransactionsSection()),
            SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
            SizedBox(height: 16),
            Text(
              'Loading Your Dashboard...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final userName = _userProfile['name'] ?? 'Player';
    final userEmail = _userProfile['email'] ?? '';
    final currentBalance = _userStats['current_balance'] ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple, Colors.purple.shade700],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.all(16), // Reduced from 20
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22, // Reduced from 24
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(
                      Icons.person,
                      size: 22, // Reduced from 24
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10), // Reduced from 12
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13, // Reduced from 14
                          ),
                        ),
                        Text(
                          userName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16, // Reduced from 18
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.notifications_outlined, color: Colors.white, size: 20), // Reduced size
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: 16), // Reduced from 20
              Container(
                padding: EdgeInsets.all(14), // Reduced from 16
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14), // Reduced from 16
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.white, size: 22), // Reduced from 24
                    SizedBox(width: 10), // Reduced from 12
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Balance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13, // Reduced from 14
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '₹${currentBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20, // Reduced from 24
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _showAddMoneyDialog,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6), // Reduced padding
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18), // Reduced from 20
                        ),
                        child: Text(
                          'Add Money',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 13, // Reduced from 14
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    return Padding(
      padding: EdgeInsets.all(14), // Reduced from 16
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Statistics',
            style: TextStyle(
              fontSize: 18, // Reduced from 20
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 14), // Reduced from 16
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10, // Reduced from 12
            mainAxisSpacing: 10, // Reduced from 12
            childAspectRatio: 1.1, // Reduced from 1.2
            children: [
              _buildStatCard(
                'Total Matches',
                '${_userStats['total_matches'] ?? 0}',
                Icons.sports_esports,
                Colors.blue,
                'All tournaments played',
              ),
              _buildStatCard(
                'Matches Won',
                '${_userStats['matches_won'] ?? 0}',
                Icons.emoji_events,
                Colors.green,
                'Victorious matches',
              ),
              _buildStatCard(
                'Total Winnings',
                '₹${(_userStats['total_winnings'] ?? 0.0).toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.orange,
                'Total earnings',
              ),
              _buildStatCard(
                'Win Rate',
                '${(_userStats['win_rate'] ?? 0.0).toStringAsFixed(1)}%',
                Icons.trending_up,
                Colors.purple,
                'Success ratio',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopPlayersSection() {
    return Padding(
      padding: EdgeInsets.all(14), // Reduced from 16
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Top Players',
                style: TextStyle(
                  fontSize: 18, // Reduced from 20
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.deepPurple, size: 20), // Reduced size
                onPressed: _loadTopPlayers,
                tooltip: 'Refresh Leaderboard',
              ),
            ],
          ),
          SizedBox(height: 10), // Reduced from 12
          if (_topPlayers.isEmpty)
            _buildEmptyState(
              'No Players Data',
              Icons.leaderboard_outlined,
              'Play tournaments to appear on leaderboard',
            )
          else
            SizedBox(
              height: 160, // Reduced from 180
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
      ),
    );
  }

  Widget _buildRecentMatchesSection() {
    return Padding(
      padding: EdgeInsets.all(14), // Reduced from 16
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent Matches',
                style: TextStyle(
                  fontSize: 18, // Reduced from 20
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              TextButton(
                onPressed: _handleViewAllMatches,
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 14, // Added font size
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10), // Reduced from 12
          if (_recentMatches.isEmpty)
            _buildEmptyState(
              'No Recent Matches',
              Icons.sports_esports_outlined,
              'Join tournaments to see your matches here',
            )
          else
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14), // Reduced from 16
              ),
              child: Padding(
                padding: EdgeInsets.all(14), // Reduced from 16
                child: Column(
                  children: _recentMatches.map((match) {
                    return Column(
                      children: [
                        _buildMatchItem(match),
                        if (_recentMatches.indexOf(match) != _recentMatches.length - 1)
                          Divider(height: 16), // Reduced from 20
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsSection() {
    return Padding(
      padding: EdgeInsets.all(14), // Reduced from 16
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 18, // Reduced from 20
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              TextButton(
                onPressed: _handleViewAllTransactions,
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 14, // Added font size
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10), // Reduced from 12
          if (_recentTransactions.isEmpty)
            _buildEmptyState(
              'No Transactions',
              Icons.account_balance_wallet_outlined,
              'Your transactions will appear here',
            )
          else
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14), // Reduced from 16
              ),
              child: Padding(
                padding: EdgeInsets.all(14), // Reduced from 16
                child: Column(
                  children: _recentTransactions.map((transaction) {
                    return Column(
                      children: [
                        _buildTransactionItem(transaction),
                        if (_recentTransactions.indexOf(transaction) != _recentTransactions.length - 1)
                          Divider(height: 16), // Reduced from 20
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
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
    final avatar = player['avatar'];

    return Container(
      width: 130,
      margin: EdgeInsets.only(right: 10),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Avatar
                  if (avatar != null && avatar.isNotEmpty)
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: NetworkImage(avatar),
                    )
                  else
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey[200],
                      child: Icon(Icons.person, color: Colors.grey[400], size: 20),
                    ),

                  // Rank Badge - Positioned properly at bottom right
                  Positioned(
                    bottom: -2, // Adjusted position
                    right: -2,  // Adjusted position
                    child: Container(
                      width: 24, // Slightly larger for better visibility
                      height: 24,
                      decoration: BoxDecoration(
                        color: medalColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          rank.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12, // Slightly larger font
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8), // Increased spacing
              Text(
                player['name'] ?? 'Player',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                '₹${totalWinning.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: totalWinning > 0 ? Colors.green : Colors.grey,
                ),
              ),
              SizedBox(height: 4),
              Text(
                isOnlyPlayer ? 'Only Player' : 'Top Earner',
                style: TextStyle(
                  fontSize: 9,
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
    final prizePool = match['prize_pool'] ?? 0.0;
    final playersJoined = match['players_joined'] ?? 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40, // Reduced from 44
        height: 40, // Reduced from 44
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade200],
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            _getMatchStatusIcon(status, isWinner),
            style: TextStyle(fontSize: 16), // Reduced from 18
          ),
        ),
      ),
      title: Text(
        match['tournament_name'] ?? 'Unknown Tournament',
        style: TextStyle(
          fontSize: 14, // Reduced from 15
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 4),
          Text(
            '${match['game_name'] ?? 'Game'} • ₹${(match['entry_fee'] ?? 0.0).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12, // Reduced from 13
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Reduced padding
                decoration: BoxDecoration(
                  color: _getMatchStatusColor(status, isWinner).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6), // Reduced from 8
                ),
                child: Text(
                  _getMatchStatusText(status, isWinner, position),
                  style: TextStyle(
                    fontSize: 10, // Reduced from 11
                    color: _getMatchStatusColor(status, isWinner),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (playersJoined > 0) ...[
                SizedBox(width: 6), // Reduced from 8
                Text(
                  '$playersJoined players',
                  style: TextStyle(
                    fontSize: 10, // Reduced from 11
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTimeAgo(match['registered_at'] as Timestamp? ?? Timestamp.now()),
            style: TextStyle(
              fontSize: 11, // Reduced from 12
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (prizePool > 0) ...[
            SizedBox(height: 4),
            Text(
              '₹${prizePool.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 10, // Reduced from 11
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final type = transaction['type'] ?? 'unknown';
    final amount = transaction['amount'] ?? 0.0;
    final status = transaction['status'] ?? 'unknown';
    final referenceId = transaction['reference_id'];

    bool isPositive;
    String sign;
    Color color;

    if (type == 'credit' || type == 'debit') {
      isPositive = type == 'credit';
      sign = isPositive ? '+' : '-';
      color = isPositive ? Colors.green : Colors.red;
    } else if (type.toLowerCase() == 'deposit' ||
        type.toLowerCase() == 'winning' ||
        type.toLowerCase() == 'refund' ||
        type.toLowerCase() == 'bonus') {
      isPositive = true;
      sign = '+';
      color = Colors.green;
    } else if (type.toLowerCase() == 'withdrawal' ||
        type.toLowerCase() == 'tournament_entry') {
      isPositive = false;
      sign = '-';
      color = Colors.red;
    } else {
      isPositive = amount >= 0;
      sign = isPositive ? '+' : '-';
      color = isPositive ? Colors.green : Colors.red;
    }

    final displayAmount = amount.abs();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40, // Reduced from 44
        height: 40, // Reduced from 44
        decoration: BoxDecoration(
          color: _getTransactionColor(type).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            _getTransactionIcon(type),
            style: TextStyle(fontSize: 16), // Reduced from 18
          ),
        ),
      ),
      title: Text(
        _formatTransactionType(type),
        style: TextStyle(
          fontSize: 14, // Reduced from 15
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 2),
          Text(
            transaction['description'] ?? 'No description',
            style: TextStyle(
              fontSize: 12, // Reduced from 13
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (referenceId != null && referenceId.isNotEmpty) ...[
            SizedBox(height: 2),
            Text(
              'Ref: $referenceId',
              style: TextStyle(
                fontSize: 10, // Reduced from 11
                color: Colors.grey[500],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$sign₹${displayAmount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14, // Reduced from 15
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Reduced padding
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6), // Reduced from 8
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 9, // Reduced from 10
                color: _getStatusColor(status),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), // Reduced from 12
      ),
      child: Padding(
        padding: EdgeInsets.all(14), // Reduced from 16
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44, // Reduced from 48
              height: 44, // Reduced from 48
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: color), // Reduced from 24
            ),
            SizedBox(height: 6), // Reduced from 8
            Text(
              value,
              style: TextStyle(
                fontSize: 16, // Reduced from 18
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11, // Reduced from 12
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9, // Reduced from 10
                color: Colors.grey[500],
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
      padding: EdgeInsets.all(24), // Reduced from 32
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10), // Reduced from 12
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 42, // Reduced from 48
              color: Colors.grey[400],
            ),
            SizedBox(height: 10), // Reduced from 12
            Text(
              title,
              style: TextStyle(
                fontSize: 15, // Reduced from 16
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6), // Reduced from 8
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13, // Reduced from 14
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
      case 'bonus':
        return 'Bonus Credit';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }
}

// Add Money Bottom Sheet
class AddMoneyBottomSheet extends StatelessWidget {
  final TextEditingController amountController;
  final double walletBalance;
  final Function(double) onProceed;
  final bool isProcessing;

  const AddMoneyBottomSheet({
    Key? key,
    required this.amountController,
    required this.walletBalance,
    required this.onProceed,
    required this.isProcessing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)), // Reduced from 20
      ),
      padding: EdgeInsets.all(16), // Reduced from 20
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, // Reduced from 40
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16), // Reduced from 20
          Text(
            'Add Money',
            style: TextStyle(
              fontSize: 20, // Reduced from 22
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 14), // Reduced from 16
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), // Reduced from 12
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14), // Adjusted padding
            ),
          ),
          SizedBox(height: 6), // Reduced from 8
          Text(
            'Minimum amount: ₹100',
            style: TextStyle(
              fontSize: 11, // Reduced from 12
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 14), // Reduced from 16
          Container(
            padding: EdgeInsets.all(10), // Reduced from 12
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10), // Reduced from 12
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: Colors.green, size: 14), // Reduced from 16
                SizedBox(width: 6), // Reduced from 8
                Text(
                  'Available balance: ₹${walletBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w500,
                    fontSize: 13, // Added font size
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16), // Reduced from 20
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14), // Reduced from 16
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10), // Reduced from 12
                    ),
                  ),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(fontSize: 14), // Added font size
                  ),
                ),
              ),
              SizedBox(width: 10), // Reduced from 12
              Expanded(
                child: ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () {
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    if (amount >= 100) {
                      onProceed(amount);
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Minimum amount is ₹100'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: EdgeInsets.symmetric(vertical: 14), // Reduced from 16
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10), // Reduced from 12
                    ),
                  ),
                  child: isProcessing
                      ? SizedBox(
                    height: 18, // Reduced from 20
                    width: 18, // Reduced from 20
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    'PROCEED TO PAY',
                    style: TextStyle(fontSize: 14), // Added font size
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}