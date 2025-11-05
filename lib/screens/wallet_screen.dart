import 'dart:async';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();

  late Razorpay _razorpay;
  double _walletBalance = 0.0;
  double _totalWinnings = 0.0;
  List<TransactionModel> _transactions = [];
  List<WithdrawalRequest> _withdrawRequests = [];
  bool _isProcessing = false;
  bool _isLoading = true;
  bool _isRefreshing = false;
  StreamSubscription<DocumentSnapshot>? _walletSubscription;
  String? _userName;
  late TabController _tabController;

  // Color scheme
  final Color _primaryColor = Colors.deepPurple;
  final Color _successColor = Color(0xFF00B894);
  final Color _warningColor = Color(0xFFFDCB6E);
  final Color _errorColor = Color(0xFFE84347);
  final Color _backgroundColor = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _tabController = TabController(length: 2, vsync: this);

    _loadInitialData().then((_) {
      _setupRealTimeListeners();
    });
  }

  Future<String?> _getCurrentUserName() async {
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
      print('❌ Error getting current user name: $e');
      return null;
    }
  }

  Future<void> _loadWalletBalance() async {
    try {
      final userName = await _getCurrentUserName();
      if (userName == null) return;

      final walletDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('wallet_data')
          .get();

      if (walletDoc.exists) {
        final walletData = walletDoc.data() ?? {};
        final newBalance = (walletData['total_balance'] as num?)?.toDouble() ?? 0.0;
        final newWinnings = (walletData['total_winning'] as num?)?.toDouble() ?? 0.0;

        if (mounted) {
          setState(() {
            _walletBalance = newBalance;
            _totalWinnings = newWinnings;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading wallet balance: $e');
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final userName = await _getCurrentUserName();
      if (userName == null) return;

      final transactionsDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('transactions')
          .get();

      if (transactionsDoc.exists) {
        final transactionsData = transactionsDoc.data() ?? {};
        final List<TransactionModel> allTransactions = [];

        // Process all transaction types
        final successful = transactionsData['successful'] as List? ?? [];
        final pending = transactionsData['pending'] as List? ?? [];
        final failed = transactionsData['failed'] as List? ?? [];
        final completed = transactionsData['completed'] as List? ?? [];

        // Helper function to process transactions
        void processTransactionList(List<dynamic> transactions, String status) {
          for (var transaction in transactions) {
            if (transaction is Map<String, dynamic>) {
              // Skip withdrawal transactions
              if (transaction['type'] != 'withdrawal') {
                allTransactions.add(TransactionModel.fromMap(transaction, status));
              }
            }
          }
        }

        processTransactionList(successful, 'success');
        processTransactionList(pending, 'pending');
        processTransactionList(failed, 'failed');
        processTransactionList(completed, 'completed');

        // Sort by timestamp (newest first)
        allTransactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (mounted) {
          setState(() {
            _transactions = allTransactions;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading transactions: $e');
    }
  }

  Future<void> _loadWithdrawRequests() async {
    try {
      final userName = await _getCurrentUserName();
      if (userName == null) return;

      final withdrawalDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('withdrawal_requests')
          .get();

      if (withdrawalDoc.exists) {
        final withdrawalData = withdrawalDoc.data() ?? {};
        final List<WithdrawalRequest> allRequests = [];

        // Process all withdrawal status types
        final pending = withdrawalData['pending'] as List? ?? [];
        final approved = withdrawalData['approved'] as List? ?? [];
        final denied = withdrawalData['denied'] as List? ?? [];
        final failed = withdrawalData['failed'] as List? ?? [];
        final completed = withdrawalData['completed'] as List? ?? [];

        void processWithdrawalList(List<dynamic> requests, String status) {
          for (var request in requests) {
            if (request is Map<String, dynamic>) {
              allRequests.add(WithdrawalRequest.fromMap(request, status));
            }
          }
        }

        processWithdrawalList(pending, 'pending');
        processWithdrawalList(approved, 'approved');
        processWithdrawalList(denied, 'denied');
        processWithdrawalList(failed, 'failed');
        processWithdrawalList(completed, 'completed');

        // Sort by date (newest first)
        allRequests.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

        if (mounted) {
          setState(() {
            _withdrawRequests = allRequests;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading withdrawal requests: $e');
    }
  }

  void _setupRealTimeListeners() async {
    final userName = await _getCurrentUserName();
    if (userName == null) return;

    setState(() {
      _userName = userName;
    });

    // Wallet balance listener
    _walletSubscription = _firestore
        .collection('wallet')
        .doc('users')
        .collection(userName)
        .doc('wallet_data')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final walletData = snapshot.data() ?? {};
        final newBalance = (walletData['total_balance'] as num?)?.toDouble() ?? 0.0;
        final newWinnings = (walletData['total_winning'] as num?)?.toDouble() ?? 0.0;

        setState(() {
          _walletBalance = newBalance;
          _totalWinnings = newWinnings;
        });
      }
    });

    // Transactions listener
    _firestore
        .collection('wallet')
        .doc('users')
        .collection(userName)
        .doc('transactions')
        .snapshots()
        .listen((_) {
      if (mounted) _loadTransactions();
    });

    // Withdrawal requests listener
    _firestore
        .collection('wallet')
        .doc('users')
        .collection(userName)
        .doc('withdrawal_requests')
        .snapshots()
        .listen((_) {
      if (mounted) _loadWithdrawRequests();
    });
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await Future.wait([
        _loadWalletBalance(),
        _loadTransactions(),
        _loadWithdrawRequests(),
      ]);
    } catch (e) {
      print('❌ Error loading initial data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  // Payment Methods
  void _showAddMoneyDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddMoneyBottomSheet(
        amountController: _amountController,
        walletBalance: _walletBalance,
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
      'theme': {'color': _primaryColor.value},
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

  // Withdrawal Methods
  void _showWithdrawDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WithdrawBottomSheet(
        amountController: _amountController,
        upiController: _upiController,
        walletBalance: _walletBalance,
        onWithdraw: _processWithdrawal,
      ),
    );
  }

  Future<void> _processWithdrawal(double amount, String upiId) async {
    try {
      final success = await _firebaseService.requestWithdrawal(amount: amount, upiId: upiId);

      if (success) {
        _amountController.clear();
        _upiController.clear();
        Navigator.pop(context);
        _showSuccessSnackBar('Withdrawal request submitted successfully!');
      } else {
        throw Exception('Failed to submit withdrawal request');
      }
    } catch (e) {
      print('❌ Error submitting withdrawal: $e');
      _showErrorSnackBar('Error submitting withdrawal request');
    }
  }

  // Helper Methods
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: _successColor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
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
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
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
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _loadInitialData();
      _showSuccessSnackBar('Wallet refreshed successfully!');
    } catch (e) {
      _showErrorSnackBar('Error refreshing wallet');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // Date Formatting Methods
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    // If less than 24 hours, show relative time
    if (difference.inHours < 24) {
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
    // If more than 24 hours but same year, show date without year
    else if (date.year == now.year) {
      return DateFormat('MMM dd • hh:mm a').format(date);
    }
    // If different year, show full date with year
    else {
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    }
  }

  String _formatDateTimeFull(DateTime date) {
    final now = DateTime.now();

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      // Same day: show time only
      return DateFormat('hh:mm a').format(date);
    } else if (date.year == now.year) {
      // Same year: show date and time without year
      return DateFormat('MMM dd • hh:mm a').format(date);
    } else {
      // Different year: show full date with year
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    }
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    _razorpay.clear();
    _tabController.dispose();
    _amountController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: _isLoading
          ? _buildLoadingState()
          : SafeArea(
        child: NestedScrollView(
          physics: ClampingScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 200,
                collapsedHeight: 70,
                floating: true,
                pinned: true,
                backgroundColor: _primaryColor,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: _buildWalletHeader(),
                  title: Text(
                    'Wallet',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  titlePadding: EdgeInsets.only(left: 16, bottom: 16),
                ),
                actions: [
                  IconButton(
                    icon: _isRefreshing
                        ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                    onPressed: _refreshData,
                  ),
                ],
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: _primaryColor,
                      unselectedLabelColor: Colors.grey.shade600,
                      indicatorColor: _primaryColor,
                      indicatorWeight: 3,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      tabs: [
                        Tab(
                          icon: Icon(Icons.receipt_long_rounded, size: 18),
                          text: 'Transactions',
                        ),
                        Tab(
                          icon: Icon(Icons.payments_rounded, size: 18),
                          text: 'Withdrawals',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildTransactionsTab(),
              _buildWithdrawalsTab(),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLoadingState() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'Loading Wallet...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _primaryColor,
            Color(0xFF6A4C93),
          ],
        ),
      ),
      padding: EdgeInsets.only(
        top: 10,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Wallet Balance',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            '₹${_walletBalance.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Available for withdrawal',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
          SizedBox(height: 10),
          _buildCompactStatsCards(),
        ],
      ),
    );
  }

  Widget _buildCompactStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildCompactStatCard(
            'Winnings',
            '₹${_totalWinnings.toStringAsFixed(2)}',
            Icons.emoji_events_rounded,
            Colors.amber.shade300,
          ),
        ),
        SizedBox(width: 6),
        Expanded(
          child: _buildCompactStatCard(
            'Withdrawable',
            '₹${_walletBalance.toStringAsFixed(2)}',
            Icons.account_balance_wallet_rounded,
            Colors.green.shade300,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 12,
                  color: color,
                ),
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No Transactions',
        message: 'Your transaction history will appear here',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(12),
      physics: ClampingScrollPhysics(),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final transaction = _transactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildWithdrawalsTab() {
    if (_withdrawRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.payments_rounded,
        title: 'No Withdrawal Requests',
        message: 'Your withdrawal requests will appear here',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(12),
      physics: ClampingScrollPhysics(),
      itemCount: _withdrawRequests.length,
      itemBuilder: (context, index) {
        final request = _withdrawRequests[index];
        return _buildWithdrawalCard(request);
      },
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: EdgeInsets.all(12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: transaction.type == 'credit'
                ? _successColor.withOpacity(0.1)
                : _errorColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            transaction.type == 'credit'
                ? Icons.add_rounded
                : Icons.remove_rounded,
            color: transaction.type == 'credit' ? _successColor : _errorColor,
            size: 18,
          ),
        ),
        title: Text(
          transaction.description,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 2),
            Text(
              _formatDate(transaction.timestamp),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
            SizedBox(height: 2),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _getStatusColor(transaction.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getStatusText(transaction.status),
                style: TextStyle(
                  color: _getStatusColor(transaction.status),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${transaction.type == 'credit' ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: transaction.type == 'credit' ? _successColor : _errorColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (transaction.paymentMethod != null && transaction.paymentMethod!.isNotEmpty) ...[
              SizedBox(height: 2),
              Text(
                transaction.paymentMethod!,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalCard(WithdrawalRequest request) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: EdgeInsets.all(12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getStatusColor(request.status).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getWithdrawalIcon(request.status),
            color: _getStatusColor(request.status),
            size: 18,
          ),
        ),
        title: Text(
          'Withdrawal Request',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 2),
            Text(
              'UPI: ${request.upiId}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Text(
              _formatDate(request.requestedAt),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${request.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 2),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(request.status),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _getStatusText(request.status),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String message}) {
    return SingleChildScrollView(
      physics: ClampingScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 40, color: Colors.grey.shade400),
                ),
                SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: FloatingActionButton.extended(
              onPressed: _isProcessing ? null : _showAddMoneyDialog,
              backgroundColor: _successColor,
              foregroundColor: Colors.white,
              icon: _isProcessing
                  ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Icon(Icons.add_rounded, size: 18),
              label: Text(
                'ADD MONEY',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: FloatingActionButton.extended(
              onPressed: _walletBalance >= 100 ? _showWithdrawDialog : null,
              backgroundColor: _walletBalance >= 100 ? _primaryColor : Colors.grey.shade400,
              foregroundColor: Colors.white,
              icon: Icon(Icons.arrow_upward_rounded, size: 18),
              label: Text(
                'WITHDRAW',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
      case 'success':
      case 'completed':
        return _successColor;
      case 'pending':
        return _warningColor;
      case 'denied':
      case 'failed':
        return _errorColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getWithdrawalIcon(String status) {
    switch (status) {
      case 'approved':
      case 'completed':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.pending_rounded;
      case 'denied':
      case 'failed':
        return Icons.cancel_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  String _getStatusText(String status) {
    return status.toUpperCase();
  }
}

// Custom Classes for Type Safety
class TransactionModel {
  final String id;
  final String type; // 'credit' or 'debit'
  final double amount;
  final String description;
  final String status;
  final DateTime timestamp;
  final String? paymentMethod;
  final String? transactionId;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.status,
    required this.timestamp,
    this.paymentMethod,
    this.transactionId,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map, String status) {
    DateTime timestamp;

    // Parse timestamp from various formats
    if (map['timestamp'] is Timestamp) {
      timestamp = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(map['timestamp']);
    } else if (map['timestamp'] is String) {
      timestamp = DateTime.tryParse(map['timestamp']) ?? DateTime.now();
    } else if (map['created_at'] is Timestamp) {
      timestamp = (map['created_at'] as Timestamp).toDate();
    } else if (map['created_at'] is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(map['created_at']);
    } else if (map['created_at'] is String) {
      timestamp = DateTime.tryParse(map['created_at']) ?? DateTime.now();
    } else if (map['date'] is Timestamp) {
      timestamp = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(map['date']);
    } else if (map['date'] is String) {
      timestamp = DateTime.tryParse(map['date']) ?? DateTime.now();
    } else {
      timestamp = DateTime.now();
    }

    return TransactionModel(
      id: map['transaction_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: map['type']?.toString() ?? 'credit',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      description: map['description']?.toString() ?? 'Transaction',
      status: status,
      timestamp: timestamp,
      paymentMethod: map['payment_method']?.toString(),
      transactionId: map['transaction_id']?.toString(),
    );
  }
}

class WithdrawalRequest {
  final String id;
  final double amount;
  final String upiId;
  final String status;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? reason;

  WithdrawalRequest({
    required this.id,
    required this.amount,
    required this.upiId,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.reason,
  });

  factory WithdrawalRequest.fromMap(Map<String, dynamic> map, String status) {
    DateTime requestedAt;

    // Parse requested_at from various formats
    if (map['requested_at'] is Timestamp) {
      requestedAt = (map['requested_at'] as Timestamp).toDate();
    } else if (map['requested_at'] is int) {
      requestedAt = DateTime.fromMillisecondsSinceEpoch(map['requested_at']);
    } else if (map['requested_at'] is String) {
      requestedAt = DateTime.tryParse(map['requested_at']) ?? DateTime.now();
    } else if (map['created_at'] is Timestamp) {
      requestedAt = (map['created_at'] as Timestamp).toDate();
    } else if (map['created_at'] is int) {
      requestedAt = DateTime.fromMillisecondsSinceEpoch(map['created_at']);
    } else if (map['created_at'] is String) {
      requestedAt = DateTime.tryParse(map['created_at']) ?? DateTime.now();
    } else if (map['date'] is Timestamp) {
      requestedAt = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is int) {
      requestedAt = DateTime.fromMillisecondsSinceEpoch(map['date']);
    } else if (map['date'] is String) {
      requestedAt = DateTime.tryParse(map['date']) ?? DateTime.now();
    } else {
      requestedAt = DateTime.now();
    }

    return WithdrawalRequest(
      id: map['request_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      upiId: map['upi_id']?.toString() ?? 'N/A',
      status: status,
      requestedAt: requestedAt,
      processedAt: map['processed_at'] is Timestamp
          ? (map['processed_at'] as Timestamp).toDate()
          : null,
      reason: map['reason']?.toString(),
    );
  }
}

// Custom Sliver App Bar Delegate
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverAppBarDelegate(this.child);

  @override
  double get minExtent => 46;
  @override
  double get maxExtent => 46;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

// Bottom Sheets
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Add Money',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Minimum amount: ₹200',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: Colors.green, size: 14),
                SizedBox(width: 6),
                Text(
                  'Available balance: ₹${walletBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(fontSize: 14, color: Colors.deepPurpleAccent),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () {
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    if (amount >= 200) {
                      onProceed(amount);
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Minimum amount is ₹200'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isProcessing
                      ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    'PROCEED TO PAY',
                    style: TextStyle(fontSize: 14, color: Colors.white),
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

class WithdrawBottomSheet extends StatelessWidget {
  final TextEditingController amountController;
  final TextEditingController upiController;
  final double walletBalance;
  final Function(double, String) onWithdraw;

  const WithdrawBottomSheet({
    Key? key,
    required this.amountController,
    required this.upiController,
    required this.walletBalance,
    required this.onWithdraw,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Withdraw Money',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: upiController,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: 'UPI ID',
              hintText: 'yourname@upi',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.blue, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Withdrawal Information',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '• Available balance: ₹${walletBalance.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                Text(
                  '• Minimum withdrawal: ₹300',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                Text(
                  '• Processing time: 24-48 hours',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(fontSize: 14, color: Colors.deepPurpleAccent),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    final upi = upiController.text.trim();

                    if (amount <= 0 || amount > walletBalance || amount < 300) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Invalid amount. Must be ≥ ₹300 and ≤ wallet balance.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (upi.isEmpty || !upi.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter a valid UPI ID (e.g., name@upi)'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    onWithdraw(amount, upi);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'WITHDRAW',
                    style: TextStyle(fontSize: 14, color: Colors.white),
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