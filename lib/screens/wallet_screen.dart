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
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();

  late Razorpay _razorpay;
  double _walletBalance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isProcessing = false;
  bool _isLoadingTransactions = true;
  bool _isRefreshing = false;
  StreamSubscription<DocumentSnapshot>? _walletSubscription;
  StreamSubscription<QuerySnapshot>? _transactionsSubscription;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _checkAndCreateUserProfile();
    _loadInitialData().then((_) => _setupRealTimeListeners());
  }

  Future<void> _checkAndCreateUserProfile() async {
    try {
      final profile = await _firebaseService.getUserProfile();
      if (profile == null) {
        final userId = FirebaseAuth.instance.currentUser!.uid;
        await _firebaseService.saveUserProfile(
          userId: userId,
          name: FirebaseAuth.instance.currentUser!.displayName ?? 'User',
          email: FirebaseAuth.instance.currentUser!.email ?? '',
          phone: '',
        );
      }
    } catch (e) {
      print('Error checking user profile: $e');
    }
  }

  void _setupRealTimeListeners() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _walletSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        final newBalance = (data?['walletBalance'] ?? 0.0).toDouble();
        if (newBalance != _walletBalance) {
          setState(() {
            _walletBalance = newBalance;
          });
        }
      }
    });

    _transactionsSubscription = FirebaseFirestore.instance
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _updateTransactionsList(snapshot.docs);
      }
    });
  }

  void _updateTransactionsList(List<QueryDocumentSnapshot> docs) {
    try {
      print('Processing ${docs.length} transaction documents');

      final newTransactions = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        print('Processing transaction: ${doc.id} - $data');

        return {
          'id': doc.id,
          'amount': (data['amount'] ?? 0.0).toDouble(),
          'type': data['type'] ?? 'credit',
          'description': data['description'] ?? 'Transaction',
          'date': _formatDate(data['timestamp'] ?? data['date']),
          'status': data['status'] ?? 'completed',
          'paymentId': data['paymentId'],
        };
      }).toList();

      print('Successfully processed ${newTransactions.length} transactions');

      setState(() {
        _transactions = newTransactions;
        _isLoadingTransactions = false;
        _isRefreshing = false;
      });
    } catch (e, stackTrace) {
      print('Error updating transactions list: $e');
      print('Stack trace: $stackTrace');

      setState(() {
        _isLoadingTransactions = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final profile = await _firebaseService.getUserProfile();
      final transactions = await _firebaseService.getCurrentUserTransactions();

      if (mounted) {
        setState(() {
          _walletBalance = (profile?['walletBalance'] ?? 0.0).toDouble();
          _transactions = transactions;
          _isLoadingTransactions = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      print('Error loading initial data: $e');
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
    return date.toString();
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
              'Minimum amount: ₹10',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
                final amount =
                    double.tryParse(_amountController.text) ?? 0.0;
                if (amount >= 10) {
                  _processRazorpayPayment(amount);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Minimum amount is ₹10'),
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
              child:
              CircularProgressIndicator(strokeWidth: 2),
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
        'email':
        FirebaseAuth.instance.currentUser?.email ?? 'user@example.com',
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
    print('Payment Success: ${response.paymentId}');
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    try {
      await _firebaseService.addMoney(amount, response.paymentId!);
      _amountController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Successful! ₹$amount added to your wallet.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error in payment success: $e');
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
        content:
        Text('Payment Failed: ${response.message ?? "Unknown error"}'),
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
                labelText: 'UPI ID / Bank Account',
                border: OutlineInputBorder(),
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
              child: Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final amount =
                  double.tryParse(_amountController.text) ?? 0.0;
              final upi = _upiController.text.trim();

              if (amount <= 0 ||
                  amount > _walletBalance ||
                  amount < 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Invalid amount. Must be ≥ ₹100 and ≤ wallet balance.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (upi.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter UPI/Bank details'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final userId = FirebaseAuth.instance.currentUser!.uid;
                // Save withdrawal request to Firestore (pending)
                await FirebaseFirestore.instance
                    .collection('withdraw_requests')
                    .add({
                  'userId': userId,
                  'amount': amount,
                  'upi': upi,
                  'status': 'pending',
                  'timestamp': FieldValue.serverTimestamp(),
                });

                // Deduct wallet balance locally
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({
                  'walletBalance': FieldValue.increment(-amount)
                });

                _amountController.clear();
                _upiController.clear();
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Withdrawal request submitted! Status: Pending.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error submitting withdrawal: $e'),
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
      _isLoadingTransactions = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔐 User ID: ${user.uid}');
      print('📧 User email: ${user.email}');

      // Get fresh wallet balance from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      print('📄 User document exists: ${userDoc.exists}');

      if (userDoc.exists) {
        final userData = userDoc.data();
        print('💰 User data: $userData');

        final newBalance = (userData?['walletBalance'] ?? 0.0).toDouble();
        print('💳 New balance: $newBalance');

        setState(() {
          _walletBalance = newBalance;
        });
      } else {
        print('⚠️ User document not found, creating one...');
        // Create user document if it doesn't exist
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'walletBalance': 0.0,
          'email': user.email,
          'name': user.displayName ?? 'User',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Get fresh transactions
      print('🔄 Fetching transactions...');
      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      print('📋 Found ${transactionsSnapshot.docs.length} transactions');

      if (transactionsSnapshot.docs.isNotEmpty) {
        print('Sample transaction: ${transactionsSnapshot.docs.first.data()}');
      }

      _updateTransactionsList(transactionsSnapshot.docs);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Wallet refreshed successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e, stackTrace) {
      print('❌ Error refreshing wallet: $e');
      print('📝 Stack trace: $stackTrace');

      String errorMessage = 'Error refreshing wallet';

      if (e is FirebaseException) {
        errorMessage = 'Firebase Error: ${e.message}';
        print('🔥 Firebase error code: ${e.code}');
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    _transactionsSubscription?.cancel();
    _razorpay.clear();
    _amountController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
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
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Wallet Balance',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            IconButton(
                              icon: _isRefreshing
                                  ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                                  : Icon(Icons.refresh),
                              onPressed: _refreshWallet,
                              tooltip: 'Refresh Balance',
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          '₹${_walletBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                _isProcessing ? null : _addMoney,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: _isProcessing
                                    ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation<
                                        Color>(Colors.white),
                                  ),
                                )
                                    : Text('ADD MONEY'),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _walletBalance > 0
                                    ? _withdrawMoney
                                    : null,
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
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text('Loading transactions...'),
                      ],
                    ),
                  )
                else if (_transactions.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long,
                            size: 60, color: Colors.grey[400]),
                        SizedBox(height: 10),
                        Text(
                          'No transactions yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  ..._transactions.map(
                        (transaction) => _buildTransactionItem(transaction),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    return Card(
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
            color:
            transaction['type'] == 'credit' ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          transaction['description'],
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${transaction['date']} • ${transaction['status']}',
              style: TextStyle(fontSize: 12),
            ),
            if (transaction['paymentId'] != null)
              Text(
                'ID: ${transaction['paymentId']?.toString().substring(0, 8)}...',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        trailing: Text(
          '${transaction['type'] == 'credit' ? '+' : '-'}₹${transaction['amount']}',
          style: TextStyle(
            color: transaction['type'] == 'credit' ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}