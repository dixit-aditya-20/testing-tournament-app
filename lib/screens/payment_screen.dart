import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> tournament;
  final String? playerName;
  final String? playerId;
  final String gameName;

  const PaymentScreen({
    Key? key,
    required this.tournament,
    this.playerName,
    this.playerId,
    required this.gameName,
  }) : super(key: key);

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Razorpay _razorpay;
  bool _isProcessing = false;
  double _walletBalance = 0.0;
  String? _userName;

  @override
  void initState() {
    super.initState();
    print('🎮 PaymentScreen initialized for: ${widget.tournament['tournament_name']}');
    _initializeRazorpay();
    _loadUserData();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    print('✅ Razorpay initialized successfully');
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Find user document by uid to get the username (document ID)
        final userQuery = await _firestore
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          _userName = userDoc.id; // This is the username (document ID)
          print('👤 User name found: $_userName');

          // Load wallet balance from your Firebase structure
          await _loadWalletBalance();
        }
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
    }
  }

  Future<void> _loadWalletBalance() async {
    try {
      if (_userName != null) {
        final walletDataDoc = await _firestore
            .collection('wallet')
            .doc('users')
            .collection(_userName!)
            .doc('wallet_data')
            .get();

        if (walletDataDoc.exists) {
          final walletData = walletDataDoc.data();
          setState(() {
            _walletBalance = (walletData?['total_balance'] as num?)?.toDouble() ?? 0.0;
          });
          print('💰 Wallet balance loaded: $_walletBalance');
        } else {
          print('⚠️ Wallet data not found, initializing...');
          await _initializeWallet();
        }
      }
    } catch (e) {
      print('❌ Error loading wallet balance: $e');
    }
  }

  Future<void> _initializeWallet() async {
    try {
      final user = _auth.currentUser;
      if (_userName != null && user != null) {
        await _firestore
            .collection('wallet')
            .doc('users')
            .collection(_userName!)
            .doc('wallet_data')
            .set({
          'total_balance': 0.0,
          'total_winning': 0.0,
          'user_id': user.uid,
          'user_name': _userName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _walletBalance = 0.0;
        });
        print('✅ Wallet initialized with zero balance');
      }
    } catch (e) {
      print('❌ Error initializing wallet: $e');
    }
  }

  void _openRazorpayCheckout() {
    if (_isProcessing) return;

    print('💳 Opening Razorpay checkout...');
    setState(() {
      _isProcessing = true;
    });

    try {
      final entryFee = (widget.tournament['entry_fee'] as num?)?.toDouble() ?? 0.0;
      final user = _auth.currentUser;

      var options = {
        'key': 'rzp_test_RQDq0jH1TAHe1P', // Replace with your actual Razorpay key
        'amount': (entryFee * 100).toInt(),
        'currency': 'INR',
        'name': 'Game Tournaments',
        'description': 'Entry fee for ${widget.tournament['tournament_name']}',
        'prefill': {
          'contact': '8888888888',
          'email': user?.email ?? 'user@example.com',
          'name': widget.playerName ?? 'Player',
        },
        'external': {
          'wallets': ['paytm', 'phonepe', 'gpay']
        },
        'theme': {
          'color': '#6A0DAD'
        }
      };

      print('💰 Razorpay options: $options');

      // Clear and reinitialize to prevent duplicate listeners
      _razorpay.clear();
      _initializeRazorpay();

      _razorpay.open(options);

    } catch (e) {
      print('❌ Error opening Razorpay: $e');
      setState(() {
        _isProcessing = false;
      });
      _showError('Error opening payment gateway: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print('✅ Payment Success: ${response.paymentId}');

    // IMPORTANT: Clear Razorpay immediately to prevent duplicate screens
    _razorpay.clear();

    try {
      await _saveRazorpayPaymentRecord(response);
      await _registerForTournament(response.paymentId!, 'razorpay');

      _showSuccess('Payment successful! Registered for ${widget.tournament['tournament_name']}');

      // Navigate back to home screen
      Navigator.popUntil(context, (route) => route.isFirst);

    } catch (e) {
      print('❌ Error processing payment success: $e');
      _showError('Payment successful but registration failed. Please contact support.');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveRazorpayPaymentRecord(PaymentSuccessResponse response) async {
    if (_userName == null) return;

    try {
      final entryFee = (widget.tournament['entry_fee'] as num?)?.toDouble() ?? 0.0;

      await _firestore
          .collection('wallet')
          .doc('users')
          .collection(_userName!)
          .doc('transactions')
          .collection('successful')
          .doc(response.paymentId)
          .set({
        'paymentId': response.paymentId,
        'orderId': response.orderId,
        'signature': response.signature,
        'amount': entryFee,
        'type': 'debit',
        'description': 'Tournament Registration - ${widget.tournament['tournament_name']}',
        'tournamentId': widget.tournament['id'],
        'tournamentName': widget.tournament['tournament_name'],
        'gameName': widget.gameName,
        'playerName': widget.playerName,
        'playerId': widget.playerId,
        'paymentMethod': 'razorpay',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      print('💾 Razorpay payment record saved');
    } catch (e) {
      print('❌ Error saving payment record: $e');
      throw e;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('❌ Payment Error: ${response.message}');

    // IMPORTANT: Clear Razorpay on error too
    _razorpay.clear();

    _saveFailedPaymentRecord(response);

    setState(() {
      _isProcessing = false;
    });

    _showError('Payment failed: ${response.message ?? "Unknown error"}');
  }

  Future<void> _saveFailedPaymentRecord(PaymentFailureResponse response) async {
    if (_userName == null) return;

    try {
      final entryFee = (widget.tournament['entry_fee'] as num?)?.toDouble() ?? 0.0;

      await _firestore
          .collection('wallet')
          .doc('users')
          .collection(_userName!)
          .doc('transactions')
          .collection('failed')
          .doc()
          .set({
        'error_code': response.code,
        'error_message': response.message,
        'amount': entryFee,
        'description': 'Failed Tournament Registration - ${widget.tournament['tournament_name']}',
        'tournamentId': widget.tournament['id'],
        'tournamentName': widget.tournament['tournament_name'],
        'gameName': widget.gameName,
        'playerName': widget.playerName,
        'playerId': widget.playerId,
        'paymentMethod': 'razorpay',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'failed',
      });

      print('💾 Failed payment record saved');
    } catch (e) {
      print('❌ Error saving failed payment record: $e');
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('👛 External Wallet: ${response.walletName}');

    // Clear Razorpay for external wallet too
    _razorpay.clear();

    _showInfo('External wallet selected: ${response.walletName}');
  }

  void _processWalletPayment() async {
    if (_isProcessing) return;

    print('💼 Processing wallet payment...');
    setState(() {
      _isProcessing = true;
    });

    try {
      final entryFee = (widget.tournament['entry_fee'] as num?)?.toDouble() ?? 0.0;

      if (_walletBalance >= entryFee) {
        // Deduct from wallet and register for tournament
        await _deductFromWallet(entryFee);
        await _registerForTournament('wallet_${DateTime.now().millisecondsSinceEpoch}', 'wallet');

        _showSuccess('Successfully registered using wallet balance!');

        // Navigate back to home screen
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        _showError('Insufficient wallet balance. Please use Razorpay.');
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      print('❌ Wallet payment error: $e');
      _showError('Wallet payment failed: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _deductFromWallet(double amount) async {
    if (_userName == null) throw Exception('User not found');

    final batch = _firestore.batch();

    // Update wallet balance
    final walletDataRef = _firestore
        .collection('wallet')
        .doc('users')
        .collection(_userName!)
        .doc('wallet_data');
    batch.update(walletDataRef, {
      'total_balance': FieldValue.increment(-amount),
    });

    // Add transaction record
    final transactionRef = _firestore
        .collection('wallet')
        .doc('users')
        .collection(_userName!)
        .doc('transactions')
        .collection('successful')
        .doc();
    batch.set(transactionRef, {
      'amount': amount,
      'type': 'debit',
      'description': 'Tournament Registration - ${widget.tournament['tournament_name']}',
      'tournamentId': widget.tournament['id'],
      'tournamentName': widget.tournament['tournament_name'],
      'gameName': widget.gameName,
      'playerName': widget.playerName,
      'playerId': widget.playerId,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'completed',
      'paymentMethod': 'wallet',
    });

    await batch.commit();

    // Update local balance
    setState(() {
      _walletBalance -= amount;
    });

    print('✅ Wallet deduction successful');
  }

  Future<void> _registerForTournament(String paymentId, String paymentMethod) async {
    try {
      final user = _auth.currentUser;
      if (user == null || _userName == null) throw Exception('User not found');

      final entryFee = (widget.tournament['entry_fee'] as num?)?.toDouble() ?? 0.0;
      final winningPrize = (widget.tournament['winning_prize'] as num?)?.toDouble() ?? 0.0;
      final totalSlots = (widget.tournament['total_slots'] as num?)?.toInt() ?? 0;

      final batch = _firestore.batch();

      // Register for tournament
      final registrationRef = _firestore.collection('tournament_registrations').doc();
      batch.set(registrationRef, {
        'userId': user.uid,
        'userName': _userName,
        'tournamentId': widget.tournament['id'],
        'tournamentName': widget.tournament['tournament_name'],
        'gameName': widget.gameName,
        'playerName': widget.playerName,
        'playerId': widget.playerId,
        'entryFee': entryFee,
        'paymentId': paymentId,
        'paymentMethod': paymentMethod,
        'registeredAt': FieldValue.serverTimestamp(),
        'status': 'registered',
      });

      // Update tournament registered players count
      final tournamentRef = _firestore.collection('tournaments').doc(widget.tournament['id']);
      batch.update(tournamentRef, {
        'registered_players': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      print('🎉 Tournament registration saved successfully!');

    } catch (e) {
      print('❌ Error registering for tournament: $e');
      throw e;
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entryFee = (widget.tournament['entry_fee'] as num?)?.toDouble() ?? 0.0;
    final tournamentName = widget.tournament['tournament_name'] as String? ?? 'Unknown Tournament';
    final gameId = widget.tournament['game_id'] as String? ?? '';
    final tournamentType = widget.tournament['tournament_type'] as String? ?? 'Solo';

    return Scaffold(
      appBar: AppBar(
        title: Text('Payment'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isProcessing
          ? _buildLoadingScreen()
          : _buildPaymentScreen(entryFee, tournamentName, gameId, tournamentType),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Processing Payment...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Please do not close the app',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentScreen(double entryFee, String tournamentName, String gameId, String tournamentType) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tournament Details Card
          Card(
            elevation: 4,
            margin: EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tournamentName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildDetailRow('Game', widget.gameName),
                  _buildDetailRow('Tournament ID', gameId),
                  _buildDetailRow('Tournament Type', tournamentType),
                  _buildDetailRow('Entry Fee', '₹$entryFee'),
                  if (widget.playerName != null)
                    _buildDetailRow('Player Name', widget.playerName!),
                  if (widget.playerId != null)
                    _buildDetailRow('Game ID', widget.playerId!),
                  _buildDetailRow('Wallet Balance', '₹${_walletBalance.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),

          // Payment Amount
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: Column(
              children: [
                Text(
                  'Total Amount to Pay',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '₹$entryFee',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
          ),

          // Payment Methods
          Text(
            'Select Payment Method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),

          // Wallet Payment
          _buildPaymentMethodCard(
            icon: Icons.account_balance_wallet,
            title: 'Pay with Wallet',
            subtitle: 'Balance: ₹${_walletBalance.toStringAsFixed(2)}',
            color: _walletBalance >= entryFee ? Colors.blue : Colors.grey,
            enabled: _walletBalance >= entryFee,
            onTap: _processWalletPayment,
            insufficientBalance: _walletBalance < entryFee,
          ),

          SizedBox(height: 12),

          // Razorpay Payment
          _buildPaymentMethodCard(
            icon: Icons.credit_card,
            title: 'Pay with Razorpay',
            subtitle: 'Credit/Debit card, UPI, Netbanking',
            color: Colors.green,
            enabled: true,
            onTap: _openRazorpayCheckout,
          ),

          SizedBox(height: 30),

          // Security Note
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.security, color: Colors.orange, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your payment is secure and encrypted. Tournament entry fee is non-refundable once paid.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
    bool insufficientBalance = false,
  }) {
    return Card(
      elevation: 2,
      color: enabled ? Colors.white : Colors.grey[100],
      child: ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.grey[800] : Colors.grey[500],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: TextStyle(
                color: enabled ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
            if (insufficientBalance)
              Text(
                'Insufficient balance',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: enabled ? Colors.grey[600] : Colors.grey[400],
        ),
        onTap: enabled ? onTap : null,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }
}