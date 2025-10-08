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

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadInitialData().then((_) => _setupRealTimeListeners());
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
        final wallet = data?['wallet'] ?? {};
        final newBalance = (wallet['balance'] ?? 0.0).toDouble();
        if (newBalance != _walletBalance) {
          setState(() {
            _walletBalance = newBalance;
          });
        }
      }
    });
  }

  Future<void> _loadInitialData() async {
    try {
      final currentUser = await _firebaseService.getCurrentUser();
      final transactions = await _firebaseService.getUserTransactions();

      if (mounted) {
        setState(() {
          _walletBalance = currentUser?.walletBalance ?? 0.0;
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
                final amount = double.tryParse(_amountController.text) ?? 0.0;
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
    print('Payment Success: ${response.paymentId}');
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    try {
      await _firebaseService.addMoney(amount, response.paymentId!, 'razorpay');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding money to wallet: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                final userId = FirebaseAuth.instance.currentUser!.uid;
                final user = await _firebaseService.getCurrentUser();

                // ✅ FIXED: Using correct collection name 'withdraw_requests'
                await FirebaseFirestore.instance
                    .collection('withdraw_requests')
                    .add({
                  'userId': userId,
                  'userEmail': user?.email ?? 'No Email',
                  'userName': user?.name ?? 'Unknown User',
                  'amount': amount,
                  'upi': upi, // ✅ Also fixed field name from 'upiId' to 'upi'
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                });

                _amountController.clear();
                _upiController.clear();
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Withdrawal request submitted successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
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
                    Text(
                      'Wallet Balance',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
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
                      transaction['description'],
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${transaction['date']} • ${transaction['status']}',
                      style: TextStyle(fontSize: 12),
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}