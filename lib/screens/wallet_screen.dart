import 'dart:async';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();

  late Razorpay _razorpay;
  double _walletBalance = 0.0;
  double _totalWinning = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _withdrawRequests = [];
  bool _isProcessing = false;
  bool _isLoadingTransactions = true;
  bool _isRefreshing = false;
  StreamSubscription<DocumentSnapshot>? _walletSubscription;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadInitialData().then((_) {
      _setupRealTimeListeners();
      _cleanupDuplicateWithdrawals(); // Clean up any existing duplicates
    });
  }

  // Get current user name from users collection
  Future<String?> _getCurrentUserName() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final userQuery = await _firestore.collection('users')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return null;

      final userDoc = userQuery.docs.first;
      return userDoc.id;
    } catch (e) {
      print('❌ Error getting current user name: $e');
      return null;
    }
  }

  // Load wallet balance
  Future<void> _loadWalletBalance() async {
    try {
      final userName = await _getCurrentUserName();
      if (userName == null) return;

      print('🔍 Loading wallet for user: $userName');

      final walletDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('wallet_data')
          .get();

      if (walletDoc.exists) {
        final walletData = walletDoc.data() ?? {};
        final newBalance = (walletData['total_balance'] as num?)?.toDouble() ?? 0.0;
        final newWinning = (walletData['total_winning'] as num?)?.toDouble() ?? 0.0;

        if (mounted) {
          setState(() {
            _walletBalance = newBalance;
            _totalWinning = newWinning;
          });
        }
        print('💰 Wallet balance loaded: $_walletBalance, winnings: $_totalWinning');
      } else {
        print('❌ Wallet data document does not exist for user: $userName');
        if (mounted) {
          setState(() {
            _walletBalance = 0.0;
            _totalWinning = 0.0;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading wallet balance: $e');
    }
  }

  // Get user transactions - EXCLUDING WITHDRAWAL REQUESTS
  Future<void> _loadTransactions() async {
    try {
      final userName = await _getCurrentUserName();
      if (userName == null) {
        print('❌ No user name found for transactions');
        return;
      }

      final transactionsDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('transactions')
          .get();

      if (transactionsDoc.exists) {
        final transactionsData = transactionsDoc.data() ?? {};
        final List<Map<String, dynamic>> allTransactions = [];

        // Combine all transaction types according to your structure
        final successful = transactionsData['successful'] as List? ?? [];
        final pending = transactionsData['pending'] as List? ?? [];
        final failed = transactionsData['failed'] as List? ?? [];
        final completed = transactionsData['completed'] as List? ?? [];

        print('📊 Transactions found:');
        print('  - Successful: ${successful.length}');
        print('  - Pending: ${pending.length}');
        print('  - Failed: ${failed.length}');
        print('  - Completed: ${completed.length}');

        // Process successful transactions - EXCLUDE WITHDRAWAL REQUESTS
        for (var transaction in successful) {
          if (transaction is Map<String, dynamic>) {
            // Skip withdrawal transactions - they should only appear in withdrawal_requests
            if (transaction['type'] != 'withdrawal') {
              allTransactions.add({...transaction, 'status': 'success'});
            } else {
              print('🚫 Filtered out withdrawal transaction from successful: ${transaction['transaction_id']}');
            }
          }
        }

        // Process pending transactions - EXCLUDE WITHDRAWAL REQUESTS
        for (var transaction in pending) {
          if (transaction is Map<String, dynamic>) {
            // Skip withdrawal transactions - they should only appear in withdrawal_requests
            if (transaction['type'] != 'withdrawal') {
              allTransactions.add({...transaction, 'status': 'pending'});
            } else {
              print('🚫 Filtered out withdrawal transaction from pending: ${transaction['transaction_id']}');
            }
          }
        }

        // Process failed transactions - EXCLUDE WITHDRAWAL REQUESTS
        for (var transaction in failed) {
          if (transaction is Map<String, dynamic>) {
            // Skip withdrawal transactions - they should only appear in withdrawal_requests
            if (transaction['type'] != 'withdrawal') {
              allTransactions.add({...transaction, 'status': 'failed'});
            } else {
              print('🚫 Filtered out withdrawal transaction from failed: ${transaction['transaction_id']}');
            }
          }
        }

        // Process completed transactions - EXCLUDE WITHDRAWAL REQUESTS
        for (var transaction in completed) {
          if (transaction is Map<String, dynamic>) {
            // Skip withdrawal transactions - they should only appear in withdrawal_requests
            if (transaction['type'] != 'withdrawal') {
              allTransactions.add({...transaction, 'status': 'completed'});
            } else {
              print('🚫 Filtered out withdrawal transaction from completed: ${transaction['transaction_id']}');
            }
          }
        }

        // Sort by timestamp (newest first)
        allTransactions.sort((a, b) {
          final timeA = _parseTimestamp(a['timestamp']);
          final timeB = _parseTimestamp(b['timestamp']);
          return timeB.compareTo(timeA);
        });

        if (mounted) {
          setState(() {
            _transactions = allTransactions;
          });
        }
        print('✅ Transactions loaded (excluding withdrawals): ${allTransactions.length}');

        // Debug: Print first few transactions
        if (allTransactions.isNotEmpty) {
          for (int i = 0; i < allTransactions.length && i < 3; i++) {
            print('🔍 Transaction ${i + 1}: ${allTransactions[i]['type']} - ₹${allTransactions[i]['amount']}');
          }
        }
      } else {
        print('❌ Transactions document does not exist for user: $userName');
        if (mounted) {
          setState(() {
            _transactions = [];
          });
        }
      }
    } catch (e) {
      print('❌ Error loading transactions: $e');
      if (mounted) {
        setState(() {
          _transactions = [];
        });
      }
    }
  }

  // Get withdrawal requests - ENHANCED WITH BETTER LOGGING
  Future<void> _loadWithdrawRequests() async {
    try {
      final userName = await _getCurrentUserName();
      if (userName == null) {
        print('❌ No user name found for withdrawal requests');
        return;
      }

      final withdrawalDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('withdrawal_requests')
          .get();

      if (withdrawalDoc.exists) {
        final withdrawalData = withdrawalDoc.data() ?? {};
        final List<Map<String, dynamic>> allRequests = [];

        final pending = withdrawalData['pending'] as List? ?? [];
        final approved = withdrawalData['approved'] as List? ?? [];
        final denied = withdrawalData['denied'] as List? ?? [];
        final failed = withdrawalData['failed'] as List? ?? [];
        final completed = withdrawalData['completed'] as List? ?? [];

        print('📊 Withdrawal requests found:');
        print('  - Pending: ${pending.length}');
        print('  - Approved: ${approved.length}');
        print('  - Denied: ${denied.length}');
        print('  - Failed: ${failed.length}');
        print('  - Completed: ${completed.length}');

        // Process pending requests
        for (var request in pending) {
          if (request is Map<String, dynamic>) {
            allRequests.add({...request, 'status': 'pending'});
          }
        }

        // Process approved requests
        for (var request in approved) {
          if (request is Map<String, dynamic>) {
            allRequests.add({...request, 'status': 'approved'});
          }
        }

        // Process denied requests
        for (var request in denied) {
          if (request is Map<String, dynamic>) {
            allRequests.add({...request, 'status': 'denied'});
          }
        }

        // Process failed requests
        for (var request in failed) {
          if (request is Map<String, dynamic>) {
            allRequests.add({...request, 'status': 'failed'});
          }
        }

        // Process completed requests
        for (var request in completed) {
          if (request is Map<String, dynamic>) {
            allRequests.add({...request, 'status': 'completed'});
          }
        }

        // Sort by date (newest first)
        allRequests.sort((a, b) {
          final timeA = _parseTimestamp(a['requested_at'] ?? a['processed_at'] ?? a['timestamp']);
          final timeB = _parseTimestamp(b['requested_at'] ?? b['processed_at'] ?? b['timestamp']);
          return timeB.compareTo(timeA);
        });

        if (mounted) {
          setState(() {
            _withdrawRequests = allRequests;
          });
        }
        print('✅ Withdrawal requests loaded: ${allRequests.length}');

        // Debug: Print first few requests
        if (allRequests.isNotEmpty) {
          for (int i = 0; i < allRequests.length && i < 3; i++) {
            print('🔍 Withdrawal ${i + 1}: ${allRequests[i]['status']} - ₹${allRequests[i]['amount']}');
          }
        }
      } else {
        print('❌ Withdrawal requests document does not exist for user: $userName');
        if (mounted) {
          setState(() {
            _withdrawRequests = [];
          });
        }
      }
    } catch (e) {
      print('❌ Error loading withdrawal requests: $e');
      if (mounted) {
        setState(() {
          _withdrawRequests = [];
        });
      }
    }
  }

  // Clean up duplicate withdrawal entries from transactions
  Future<void> _cleanupDuplicateWithdrawals() async {
    try {
      final userName = await _getCurrentUserName();
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
            final isWithdrawal = transaction['type'] == 'withdrawal';
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

        // Reload transactions after cleanup
        await _loadTransactions();
      } else {
        print('✅ No duplicate withdrawal transactions found');
      }
    } catch (e) {
      print('❌ Error cleaning up duplicate withdrawals: $e');
    }
  }

  // Add money to wallet
  Future<bool> _addMoneyToWallet(double amount, String paymentId, String paymentMethod) async {
    try {
      final success = await _firebaseService.addMoney(amount, paymentId, paymentMethod);
      if (success) {
        // Reload data to reflect changes
        await _loadWalletBalance();
        await _loadTransactions();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error adding money via FirebaseService: $e');
      return false;
    }
  }

  // Request withdrawal
  Future<bool> _requestWithdrawal(double amount, String upiId) async {
    try {
      final success = await _firebaseService.requestWithdrawal(amount: amount, upiId: upiId);
      if (success) {
        // Reload data to reflect changes
        await _loadWalletBalance();
        await _loadWithdrawRequests(); // Only load withdrawal requests, not transactions
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error requesting withdrawal via FirebaseService: $e');
      return false;
    }
  }

  // Helper method to parse timestamp
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

  void _setupRealTimeListeners() async {
    final userName = await _getCurrentUserName();
    if (userName == null) {
      print('❌ No user name found for real-time listeners');
      return;
    }

    print('🔄 Setting up real-time listeners for user: $userName');
    setState(() {
      _userName = userName;
    });

    // Listen to wallet data changes
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
        final newWinning = (walletData['total_winning'] as num?)?.toDouble() ?? 0.0;

        print('💰 Real-time balance update: $newBalance, winnings: $newWinning');

        setState(() {
          _walletBalance = newBalance;
          _totalWinning = newWinning;
        });
      } else {
        print('❌ Wallet data document does not exist in listener');
      }
    }, onError: (error) {
      print('❌ Wallet listener error: $error');
    });

    // Listen to transactions changes
    _firestore
        .collection('wallet')
        .doc('users')
        .collection(userName)
        .doc('transactions')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        print('🔄 Transactions document changed, reloading transactions...');
        if (snapshot.exists) {
          print('📄 Transactions data keys: ${snapshot.data()?.keys}');
        }
        _loadTransactions();
      }
    }, onError: (error) {
      print('❌ Transactions listener error: $error');
    });

    // Listen to withdrawal requests changes with detailed logging
    _firestore
        .collection('wallet')
        .doc('users')
        .collection(userName)
        .doc('withdrawal_requests')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        print('🔄 Withdrawal requests document changed, reloading withdrawal requests...');
        if (snapshot.exists) {
          final data = snapshot.data() ?? {};
          print('📄 Withdrawal data structure:');
          data.keys.forEach((key) {
            if (data[key] is List) {
              print('   - $key: ${(data[key] as List).length} items');
            }
          });
        }
        _loadWithdrawRequests();
      }
    }, onError: (error) {
      print('❌ Withdrawal requests listener error: $error');
    });
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoadingTransactions = true;
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
          _isLoadingTransactions = false;
          _isRefreshing = false;
        });
      }
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Recently';

    if (date is Timestamp) {
      final datetime = date.toDate();
      return '${datetime.day}/${datetime.month}/${datetime.year} ${datetime.hour}:${datetime.minute.toString().padLeft(2, '0')}';
    }

    if (date is String) {
      try {
        final datetime = DateTime.parse(date);
        return '${datetime.day}/${datetime.month}/${datetime.year} ${datetime.hour}:${datetime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return 'Recently';
      }
    }

    return 'Recently';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
      case 'success':
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'denied':
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'success':
      case 'completed':
        return 'Success';
      case 'pending':
        return 'Pending';
      case 'denied':
        return 'Denied';
      case 'failed':
        return 'Failed';
      default:
        return 'Unknown';
    }
  }

  void _addMoney() {
    if (_isProcessing) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Money'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Minimum amount: ₹100',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              'Available balance: ₹${_walletBalance.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: _isProcessing
                ? null
                : () {
              if (_amountController.text.isNotEmpty) {
                final amount = double.tryParse(_amountController.text) ?? 0.0;
                if (amount >= 100) {
                  _processRazorpayPayment(amount);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Minimum amount is ₹100'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: _isProcessing
                ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text('PROCEED TO PAY'),
          ),
        ],
      ),
    );
  }

  void _processRazorpayPayment(double amount) {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    var options = {
      'key': 'rzp_test_1DP5mmOlF5G5ag',
      'amount': (amount * 100).toInt(),
      'name': 'Game Tournaments',
      'description': 'Add Money to Wallet',
      'prefill': {
        'contact': '8888888888',
        'email': FirebaseAuth.instance.currentUser?.email ?? 'user@example.com',
      },
      'external': {
        'wallets': ['paytm', 'phonepe', 'gpay']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print('Razorpay Error: $e');
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening payment gateway: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print('🔄 Payment Success Handler Started');
    print('✅ Payment Success: ${response.paymentId}');
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    try {
      final success = await _addMoneyToWallet(amount, response.paymentId!, 'razorpay');

      if (success) {
        _amountController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment Successful! ₹$amount added to your wallet.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Failed to add money to wallet');
      }
    } catch (e) {
      print('❌ Error in payment success: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding money to wallet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message ?? "Unknown error"}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External Wallet Selected: ${response.walletName}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _withdrawMoney() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Withdraw Money'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _upiController,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'UPI ID',
                border: OutlineInputBorder(),
                hintText: 'yourname@upi',
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Available balance: ₹${_walletBalance.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              'Minimum withdrawal: ₹100',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
              final amount = double.tryParse(_amountController.text) ?? 0.0;
              final upi = _upiController.text.trim();

              if (amount <= 0 || amount > _walletBalance || amount < 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Invalid amount. Must be ≥ ₹100 and ≤ wallet balance.'),
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

              try {
                final success = await _requestWithdrawal(amount, upi);

                if (success) {
                  _amountController.clear();
                  _upiController.clear();
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Withdrawal request submitted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  throw Exception('Failed to submit withdrawal request');
                }
              } catch (e) {
                print('❌ Error submitting withdrawal: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error submitting withdrawal request: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('WITHDRAW'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshWallet() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _loadInitialData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wallet refreshed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing wallet: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    _razorpay.clear();
    _amountController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Wallet'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Icon(Icons.refresh),
            onPressed: _refreshWallet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Balance Card
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Wallet Balance',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              '₹${_walletBalance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total Winnings',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              '₹${_totalWinning.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _addMoney,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: _isProcessing
                                ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : Text('ADD MONEY'),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _walletBalance >= 100 ? _withdrawMoney : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                            child: Text('WITHDRAW'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Withdrawal Requests Section
            if (_withdrawRequests.isNotEmpty) ...[
              Text(
                'Withdrawal Requests',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              ..._withdrawRequests.map(
                    (request) => Card(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getStatusColor(request['status']).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: _getStatusColor(request['status']),
                      ),
                    ),
                    title: Text(
                      'Withdrawal - ₹${(request['amount'] ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('UPI: ${request['upi_id'] ?? 'N/A'}'),
                        Text('${_formatDate(request['requested_at'] ?? request['processed_at'])} • ${_getStatusText(request['status'])}'),
                      ],
                    ),
                    trailing: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(request['status']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(request['status']),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],

            // Transaction History
            Text(
              'Transaction History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),

            if (_isLoadingTransactions)
              Center(
                child: CircularProgressIndicator(),
              )
            else if (_transactions.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 60, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      'No transactions yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Add money to see your first transaction!',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ..._transactions.map(
                    (transaction) => Card(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: transaction['type'] == 'credit'
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        transaction['type'] == 'credit'
                            ? Icons.add_circle
                            : Icons.remove_circle,
                        color: transaction['type'] == 'credit' ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(
                      transaction['description'] ?? 'Transaction',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${_formatDate(transaction['timestamp'])} • ${_getStatusText(transaction['status'])}',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      '${transaction['type'] == 'credit' ? '+' : '-'}₹${(transaction['amount'] ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: transaction['type'] == 'credit' ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}