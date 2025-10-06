import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modles/tournament_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== USER PROFILE METHODS ==========
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        print('✅ User profile loaded: ${doc.data()}');
        return doc.data();
      } else {
        print('⚠️ User profile not found, creating one...');
        // Create user profile if it doesn't exist
        await saveUserProfile(
          userId: userId,
          name: _auth.currentUser?.displayName ?? 'User',
          email: _auth.currentUser?.email ?? '',
          phone: '',
        );
        final newDoc = await _firestore.collection('users').doc(userId).get();
        return newDoc.data();
      }
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return null;
    }
  }

  Future<void> saveUserProfile({
    required String userId,
    required String name,
    required String email,
    required String phone,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'userId': userId,
        'name': name,
        'email': email,
        'phone': phone,
        'walletBalance': 200.0, // Welcome bonus
        'totalWinnings': 0.0,
        'matchesPlayed': 0,
        'matchesWon': 0,
        'joinedAt': FieldValue.serverTimestamp(),
        'fcmToken': '',
        'role': 'user', // Add role field
      }, SetOptions(merge: true));
      print('✅ User profile saved/updated for: $userId');
    } catch (e) {
      print('❌ Error saving user profile: $e');
      throw e;
    }
  }

  // ========== WALLET & PAYMENT METHODS ==========
  Future<bool> deductFromWallet(double amount) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      // First check current balance
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final currentBalance = (userDoc.data()?['walletBalance'] ?? 0.0).toDouble();

      if (currentBalance < amount) {
        print('❌ Insufficient balance: $currentBalance, required: $amount');
        return false;
      }

      await _firestore.collection('users').doc(userId).update({
        'walletBalance': FieldValue.increment(-amount)
      });

      // Record transaction
      await _firestore.collection('transactions').add({
        'userId': userId,
        'amount': amount,
        'type': 'debit',
        'description': 'Tournament registration fee',
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ Deducted ₹$amount from wallet');
      return true;
    } catch (e) {
      print('❌ Error deducting from wallet: $e');
      return false;
    }
  }

  Future<void> addMoney(double amount, String paymentId) async {
    try {
      final userId = _auth.currentUser!.uid;

      await _firestore.collection('users').doc(userId).update({
        'walletBalance': FieldValue.increment(amount),
      });

      await _firestore.collection('transactions').add({
        'userId': userId,
        'amount': amount,
        'type': 'credit',
        'description': 'Money Added via Razorpay',
        'status': 'completed',
        'paymentId': paymentId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ Money added successfully: $amount, Payment ID: $paymentId');
    } catch (e) {
      print('❌ Error adding money: $e');
      throw e;
    }
  }

  // ========== TOURNAMENT REGISTRATION METHODS ==========
  Future<bool> hasUserRegisteredForTournament(String tournamentId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final doc = await _firestore
          .collection('user_registrations')
          .doc('${userId}_$tournamentId')
          .get();

      final isRegistered = doc.exists;
      print('📝 Registration check - User: $userId, Tournament: $tournamentId, Registered: $isRegistered');
      return isRegistered;
    } catch (e) {
      print('❌ Error checking registration: $e');
      return false;
    }
  }

  Future<bool> saveTournamentRegistration({
    required String tournamentId,
    required String tournamentName,
    required String gameName,
    required String playerName,
    required String playerId,
    required double entryFee,
    required String paymentId,
  }) async {
    try {
      final userId = _auth.currentUser!.uid;
      final docId = '${userId}_$tournamentId';

      print('💾 Saving tournament registration:');
      print('   User: $userId');
      print('   Tournament: $tournamentName');
      print('   Payment ID: $paymentId');

      // 1. Save registration
      await _firestore.collection('user_registrations').doc(docId).set({
        'userId': userId,
        'tournamentId': tournamentId,
        'tournamentName': tournamentName,
        'gameName': gameName,
        'playerName': playerName,
        'playerId': playerId,
        'entryFee': entryFee,
        'paymentId': paymentId,
        'registeredAt': FieldValue.serverTimestamp(),
        'status': 'registered',
      });

      // 2. Update tournament player count
      await updateTournamentPlayerCount(tournamentId);

      // 3. Record transaction
      await _firestore.collection('transactions').add({
        'userId': userId,
        'amount': entryFee,
        'type': 'debit',
        'description': 'Tournament Entry: $tournamentName',
        'status': 'completed',
        'paymentId': paymentId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ Tournament registration saved successfully!');
      return true;
    } catch (e) {
      print('❌ Error saving tournament registration: $e');
      return false;
    }
  }

  Future<bool> updateTournamentPlayerCount(String tournamentId) async {
    try {
      await _firestore.collection('tournaments').doc(tournamentId).update({
        'registeredPlayers': FieldValue.increment(1),
      });
      print('✅ Updated player count for tournament: $tournamentId');
      return true;
    } catch (e) {
      print('❌ Error updating tournament player count: $e');
      return false;
    }
  }

  // ========== TOURNAMENT METHODS ==========
  Future<List<Tournament>> getTournamentsByGame(String gameName) async {
    try {
      final snapshot = await _firestore
          .collection('tournaments')
          .where('gameName', isEqualTo: gameName)
          .get();

      final tournaments = snapshot.docs.map((doc) {
        final data = doc.data();
        return Tournament.fromMap({...data, 'id': doc.id});
      }).toList();

      print('✅ Loaded ${tournaments.length} tournaments for $gameName');
      return tournaments;
    } catch (e) {
      print('❌ Error getting tournaments: $e');
      return [];
    }
  }

  Future<List<Tournament>> getAllTournaments() async {
    try {
      final snapshot = await _firestore.collection('tournaments').get();
      return snapshot.docs.map((doc) {
        return Tournament.fromMap({...doc.data(), 'id': doc.id});
      }).toList();
    } catch (e) {
      print('Error getting all tournaments: $e');
      return [];
    }
  }

  // ========== TRANSACTION METHODS ==========
  Future<List<Map<String, dynamic>>> getCurrentUserTransactions() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final transactions = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'amount': data['amount'] ?? 0.0,
          'type': data['type'] ?? 'unknown',
          'description': data['description'] ?? 'No description',
          'date': _formatDate(data['timestamp']),
          'status': data['status'] ?? 'unknown',
          'paymentId': data['paymentId'],
        };
      }).toList();

      print('✅ Loaded ${transactions.length} transactions');
      return transactions;
    } catch (e) {
      print('❌ Error getting transactions: $e');
      return [];
    }
  }

  // ========== ADMIN METHODS ==========
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'User',
          'email': data['email'] ?? '',
          'walletBalance': (data['walletBalance'] ?? 0.0).toDouble(),
          'role': data['role'] ?? 'user',
          'joinedAt': data['joinedAt'],
        };
      }).toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  // ========== HELPER METHODS ==========
  String _formatDate(dynamic date) {
    if (date == null) return 'Recently';
    if (date is Timestamp) {
      final datetime = date.toDate();
      return '${datetime.day}/${datetime.month}/${datetime.year}';
    }
    return date.toString();
  }

  // ========== OTHER METHODS ==========
  Future<void> addWelcomeBonus(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'walletBalance': FieldValue.increment(200.0),
      });

      await _firestore.collection('transactions').add({
        'userId': userId,
        'amount': 200.0,
        'type': 'credit',
        'description': 'Welcome Bonus',
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding welcome bonus: $e');
      throw e;
    }
  }

  Future<void> withdrawMoney(double amount) async {
    try {
      final userId = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(userId).update({
        'walletBalance': FieldValue.increment(-amount),
      });

      await _firestore.collection('transactions').add({
        'userId': userId,
        'amount': amount,
        'type': 'debit',
        'description': 'Withdrawal Request',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error withdrawing money: $e');
      throw e;
    }
  }

  Future<void> seedSampleTournaments() async {
    try {
      final sampleTournaments = [
        {
          'gameName': 'BGMI',
          'tournamentName': 'BGMI Championship Season 1',
          'entryFee': 50.0,
          'totalSlots': 100,
          'registeredPlayers': 0,
          'registrationEnd': Timestamp.fromDate(DateTime.now().add(Duration(days: 2, hours: 5))),
          'tournamentStart': Timestamp.fromDate(DateTime.now().add(Duration(days: 3))),
          'imageUrl': 'https://w0.peakpx.com/wallpaper/742/631/HD-wallpaper-bgmi-trending-pubg-bgmi-iammsa-pubg.jpg',
          'tournamentId': 'BGMI001',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'gameName': 'Free Fire',
          'tournamentName': 'Free Fire Masters',
          'entryFee': 25.0,
          'totalSlots': 80,
          'registeredPlayers': 0,
          'registrationEnd': Timestamp.fromDate(DateTime.now().add(Duration(days: 3, hours: 6))),
          'tournamentStart': Timestamp.fromDate(DateTime.now().add(Duration(days: 4))),
          'imageUrl': 'https://wallpapers.com/images/high/free-fire-logo-armed-woman-fdsbmr41d528ty45.webp',
          'tournamentId': 'FF001',
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      for (final tournament in sampleTournaments) {
        await _firestore.collection('tournaments').add(tournament);
      }

      print('✅ Sample tournaments seeded successfully');
    } catch (e) {
      print('❌ Error seeding sample tournaments: $e');
      throw e;
    }
  }

  // Keep your existing methods for matches, leaderboard, notifications, etc.
  Future<List<Map<String, dynamic>>> getUserMatches() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      return [
        {
          'tournamentName': 'BGMI Championship',
          'gameName': 'BGMI',
          'result': 'Won',
          'kills': 12,
          'position': 1,
          'prize': 500.0,
          'date': '15/12/2023',
        },
      ];
    } catch (e) {
      print('Error getting matches: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopPlayers() async {
    try {
      return [
        {
          'name': 'ProPlayer1',
          'matchesWon': 15,
          'totalWinnings': 5000.0,
        },
      ];
    } catch (e) {
      print('Error getting top players: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserNotifications() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      return [
        {
          'title': 'Welcome to Game Tournaments!',
          'body': 'You have received ₹200 welcome bonus in your wallet.',
          'time': '2 hours ago',
        },
      ];
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  Future<void> saveFCMToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
        });
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }
}