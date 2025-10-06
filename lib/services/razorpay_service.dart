import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/material.dart';

class RazorpayService {
  late Razorpay _razorpay;
  final Function(String) onSuccess;
  final Function(String) onFailure;

  RazorpayService({required this.onSuccess, required this.onFailure}) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    onSuccess(response.paymentId!);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    onFailure(response.message!);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Do something when an external wallet is selected
  }

  void openCheckout({
    required double amount,
    required String name,
    required String description,
    String prefillEmail = '',
    String prefillContact = '',
  }) {
    var options = {
      'key': 'YOUR_RAZORPAY_KEY', // Replace with your Razorpay key
      'amount': (amount * 100).toInt(), // Amount in paise
      'name': name,
      'description': description,
      'prefill': {'contact': prefillContact, 'email': prefillEmail},
      'external': {
        'wallets': ['paytm', 'phonepe', 'gpay']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}