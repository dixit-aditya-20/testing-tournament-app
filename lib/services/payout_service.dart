// ===============================
// TRANSACTION SERVICE
// ===============================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Map<String, dynamic>>> getUserTransactions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Get user document
      final userQuery = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return [];

      final userName = userQuery.docs.first.id;
      List<Map<String, dynamic>> allTransactions = [];

      // Check all possible transaction locations
      final locations = [
        _getWalletTransactions(userName),
        _getUserDocumentTransactions(userQuery.docs.first.data()),
        _getWithdrawalTransactions(userName),
      ];

      final results = await Future.wait(locations);
      for (var result in results) {
        allTransactions.addAll(result);
      }

      // Sort by timestamp
      allTransactions.sort((a, b) {
        final timeA = a['timestamp'] as Timestamp;
        final timeB = b['timestamp'] as Timestamp;
        return timeB.compareTo(timeA);
      });

      return allTransactions;
    } catch (e) {
      print('❌ Error in TransactionService: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getWalletTransactions(String userName) async {
    try {
      final doc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('transactions')
          .get();

      if (!doc.exists) return [];

      List<Map<String, dynamic>> transactions = [];
      final data = doc.data() ?? {};

      // Check all possible status keys
      final statusKeys = ['successful', 'pending', 'failed', 'completed', 'approved', 'denied'];

      for (var status in statusKeys) {
        final statusTransactions = data[status] as List<dynamic>? ?? [];
        for (var tx in statusTransactions) {
          if (tx is Map<String, dynamic>) {
            transactions.add(_parseTransaction(tx, status));
          }
        }
      }

      return transactions;
    } catch (e) {
      print('⚠️ Error getting wallet transactions: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getUserDocumentTransactions(Map<String, dynamic> userData) async {
    try {
      List<Map<String, dynamic>> transactions = [];
      final userTransactions = userData['transactions'] as List<dynamic>? ?? [];

      for (var tx in userTransactions) {
        if (tx is Map<String, dynamic>) {
          transactions.add(_parseTransaction(tx, tx['status'] ?? 'completed'));
        }
      }

      return transactions;
    } catch (e) {
      print('⚠️ Error getting user document transactions: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getWithdrawalTransactions(String userName) async {
    try {
      final doc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('withdrawal_requests')
          .get();

      if (!doc.exists) return [];

      List<Map<String, dynamic>> transactions = [];
      final data = doc.data() ?? {};

      // Process pending withdrawals
      final pending = data['pending'] as List<dynamic>? ?? [];
      for (var withdrawal in pending) {
        if (withdrawal is Map<String, dynamic>) {
          transactions.add({
            'id': withdrawal['withdrawal_id'] ?? 'withdrawal_${DateTime.now().millisecondsSinceEpoch}',
            'amount': (withdrawal['amount'] as num?)?.toDouble() ?? 0.0,
            'type': 'withdrawal',
            'description': 'Withdrawal Request - Pending',
            'status': 'pending',
            'payment_method': withdrawal['payment_method'] ?? 'No Method',
            'timestamp': withdrawal['requested_at'] ?? Timestamp.now(),
          });
        }
      }

      // Process approved withdrawals
      final approved = data['approved'] as List<dynamic>? ?? [];
      for (var withdrawal in approved) {
        if (withdrawal is Map<String, dynamic>) {
          transactions.add({
            'id': withdrawal['withdrawal_id'] ?? 'withdrawal_${DateTime.now().millisecondsSinceEpoch}',
            'amount': (withdrawal['amount'] as num?)?.toDouble() ?? 0.0,
            'type': 'withdrawal',
            'description': 'Withdrawal - Approved',
            'status': 'completed',
            'payment_method': withdrawal['payment_method'] ?? 'No Method',
            'timestamp': withdrawal['processed_at'] ?? Timestamp.now(),
          });
        }
      }

      return transactions;
    } catch (e) {
      print('⚠️ Error getting withdrawal transactions: $e');
      return [];
    }
  }

  Map<String, dynamic> _parseTransaction(Map<String, dynamic> tx, String status) {
    return {
      'id': tx['transaction_id'] ?? tx['id'] ?? 'tx_${DateTime.now().millisecondsSinceEpoch}',
      'amount': (tx['amount'] as num?)?.toDouble() ?? 0.0,
      'type': tx['type'] ?? 'unknown',
      'description': tx['description'] ?? tx['note'] ?? 'Transaction',
      'status': status,
      'payment_method': tx['payment_method'] ?? tx['method'] ?? 'No Method',
      'timestamp': tx['timestamp'] ?? tx['created_at'] ?? tx['date'] ?? Timestamp.now(),
    };
  }
}