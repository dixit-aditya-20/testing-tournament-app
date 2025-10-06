import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../modles/tournament_model.dart';
import '../services/firebase_service.dart';

class PaymentScreen extends StatefulWidget {
  final Tournament tournament;
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
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Razorpay _razorpay;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    print('🎮 PaymentScreen initialized for: ${widget.tournament.tournamentName}');
    _initializeRazorpay();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    print('✅ Razorpay initialized successfully');
  }

  void _openRazorpayCheckout() {
    if (_isProcessing) return;

    print('💳 Opening Razorpay checkout...');
    setState(() {
      _isProcessing = true;
    });

    try {
      var options = {
        'key': 'rzp_test_1DP5mmOlF5G5ag',
        'amount': (widget.tournament.entryFee * 100).toInt(),
        'name': 'Game Tournaments',
        'description': 'Entry fee for ${widget.tournament.tournamentName}',
        'prefill': {
          'contact': '8888888888',
          'email': _auth.currentUser?.email ?? 'user@example.com',
        },
        'external': {
          'wallets': ['paytm', 'phonepe', 'gpay']
        }
      };

      print('💰 Razorpay options: $options');
      _razorpay.open(options);

    } catch (e) {
      print('❌ Error opening Razorpay: $e');
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
    print('✅ Payment Success: ${response.paymentId}');

    try {
      // Use the CORRECT method name: saveTournamentRegistration
      final success = await _firebaseService.saveTournamentRegistration(
        tournamentId: widget.tournament.id,
        tournamentName: widget.tournament.tournamentName,
        gameName: widget.gameName,
        playerName: widget.playerName ?? "Unknown Player",
        playerId: widget.playerId ?? "UnknownID",
        entryFee: widget.tournament.entryFee,
        paymentId: response.paymentId!,
      );

      if (success) {
        print('🎉 Registration saved to Firebase successfully!');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment successful! Registered for ${widget.tournament.tournamentName}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.pop(context);

      } else {
        throw Exception('Failed to save registration to Firebase');
      }
    } catch (e) {
      print('❌ Error saving registration: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment successful but registration failed. Please contact support.'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('❌ Payment Error: ${response.message}');
    setState(() {
      _isProcessing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message ?? "Unknown error"}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('👛 External Wallet: ${response.walletName}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet selected: ${response.walletName}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _processWalletPayment() async {
    if (_isProcessing) return;

    print('💼 Processing wallet payment...');
    setState(() {
      _isProcessing = true;
    });

    try {
      final userProfile = await _firebaseService.getUserProfile();
      final walletBalance = userProfile?['walletBalance'] ?? 0.0;

      if (walletBalance >= widget.tournament.entryFee) {
        final paymentId = 'WALLET_${DateTime.now().millisecondsSinceEpoch}';

        // Use the CORRECT method name: saveTournamentRegistration
        final success = await _firebaseService.saveTournamentRegistration(
          tournamentId: widget.tournament.id,
          tournamentName: widget.tournament.tournamentName,
          gameName: widget.gameName,
          playerName: widget.playerName ?? "Unknown Player",
          playerId: widget.playerId ?? "UnknownID",
          entryFee: widget.tournament.entryFee,
          paymentId: paymentId,
        );

        if (success) {
          await _firebaseService.deductFromWallet(widget.tournament.entryFee);

          print('🎉 Wallet payment successful!');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully registered using wallet balance!'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pop(context);
        } else {
          throw Exception('Failed to save registration');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient wallet balance. Please use Razorpay.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Wallet payment error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wallet payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isProcessing
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Processing Payment...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      )
          : Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tournament Details Card
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tournament.tournamentName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildDetailRow('Game', widget.gameName),
                    _buildDetailRow('Tournament ID', widget.tournament.tournamentId),
                    _buildDetailRow('Entry Fee', '₹${widget.tournament.entryFee}'),
                    if (widget.playerName != null)
                      _buildDetailRow('Player Name', widget.playerName!),
                    if (widget.playerId != null)
                      _buildDetailRow('Game ID', widget.playerId!),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Payment Amount
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Amount to Pay',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '₹${widget.tournament.entryFee}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Payment Methods
            Text(
              'Select Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // Wallet Payment
            Card(
              child: ListTile(
                leading: Icon(Icons.account_balance_wallet, color: Colors.blue),
                title: Text('Pay with Wallet'),
                subtitle: Text('Use your wallet balance'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _processWalletPayment,
              ),
            ),
            SizedBox(height: 10),

            // Razorpay Payment
            Card(
              child: ListTile(
                leading: Icon(Icons.credit_card, color: Colors.green),
                title: Text('Pay with Razorpay'),
                subtitle: Text('Credit/Debit card, UPI, Netbanking'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _openRazorpayCheckout,
              ),
            ),

            Spacer(),

            // Security Note
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your payment is secure. Tournament entry fee is non-refundable.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[800],
                      ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(value),
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