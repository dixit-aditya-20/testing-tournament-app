import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../modles/tournament_model.dart';
import '../modles/user_registration_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== DASHBOARD METHODS ==========
  Future<List<Map<String, dynamic>>> getTopPlayers({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'user')
          .orderBy('stats.totalEarnings', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final basicInfo = data['basicInfo'] ?? {};
        final stats = data['stats'] ?? {};
        final wallet = data['wallet'] ?? {};

        return {
          'id': doc.id,
          'name': basicInfo['name'] ?? 'Player',
          'email': basicInfo['email'] ?? '',
          'matchesWon': stats['totalMatchesWon'] ?? 0,
          'totalWinnings': (wallet['totalWinnings'] ?? stats['totalEarnings'] ?? 0.0).toDouble(),
          'winRate': stats['winRate'] ?? 0.0,
          'profileImage': basicInfo['profileImage'] ?? '',
          'rank': stats['rank'] ?? 'Beginner',
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting top players: $e');
      return [];
    }
  }

  // Alternative method if you want to use a separate leaderboard collection
  Future<List<Map<String, dynamic>>> getTopPlayersFromLeaderboard({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('leaderboard')
          .orderBy('totalWinnings', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['playerName'] ?? 'Player',
          'matchesWon': data['matchesWon'] ?? 0,
          'totalWinnings': (data['totalWinnings'] ?? 0.0).toDouble(),
          'winRate': data['winRate'] ?? 0.0,
          'profileImage': data['profileImage'] ?? '',
          'rank': data['rank'] ?? 'Unranked',
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting top players from leaderboard: $e');
      return _getMockTopPlayers(); // Fallback to mock data
    }
  }

  // Mock data fallback
  List<Map<String, dynamic>> _getMockTopPlayers() {
    return [
      {
        'name': 'Pro Player',
        'matchesWon': 45,
        'totalWinnings': 12500.00,
        'winRate': 68.2,
        'profileImage': '',
        'rank': 'Diamond',
      },
      {
        'name': 'Game Master',
        'matchesWon': 32,
        'totalWinnings': 8900.00,
        'winRate': 59.8,
        'profileImage': '',
        'rank': 'Platinum',
      },
      {
        'name': 'Battle Legend',
        'matchesWon': 28,
        'totalWinnings': 6700.00,
        'winRate': 52.4,
        'profileImage': '',
        'rank': 'Gold',
      },
      {
        'name': 'Ace Shooter',
        'matchesWon': 21,
        'totalWinnings': 4500.00,
        'winRate': 48.7,
        'profileImage': '',
        'rank': 'Silver',
      },
      {
        'name': 'Rookie Star',
        'matchesWon': 15,
        'totalWinnings': 2800.00,
        'winRate': 42.3,
        'profileImage': '',
        'rank': 'Bronze',
      },
    ];
  }

  // Get user dashboard stats
  Future<Map<String, dynamic>> getUserDashboardStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return {};

      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return {};

      final data = doc.data()!;
      final stats = data['stats'] ?? {};
      final wallet = data['wallet'] ?? {};

      final totalMatches = stats['totalMatchesPlayed'] ?? 0;
      final matchesWon = stats['totalMatchesWon'] ?? 0;
      final winRate = totalMatches > 0 ? (matchesWon / totalMatches * 100) : 0;

      return {
        'totalMatches': totalMatches,
        'matchesWon': matchesWon,
        'totalWinnings': (wallet['totalWinnings'] ?? 0.0).toDouble(),
        'winRate': winRate,
        'currentBalance': (wallet['balance'] ?? 0.0).toDouble(),
        'tournamentsJoined': stats['totalTournamentsJoined'] ?? 0,
        'rank': stats['rank'] ?? 'Beginner',
        'experiencePoints': stats['experiencePoints'] ?? 0,
      };
    } catch (e) {
      print('❌ Error getting user dashboard stats: $e');
      return {
        'totalMatches': 0,
        'matchesWon': 0,
        'totalWinnings': 0.0,
        'winRate': 0.0,
        'currentBalance': 0.0,
        'tournamentsJoined': 0,
        'rank': 'Beginner',
        'experiencePoints': 0,
      };
    }
  }

  // ========== USER MANAGEMENT ==========
  Future<AppUser?> getCurrentUser() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        print('✅ User profile loaded: ${doc.id}');
        return AppUser.fromFirestore(doc);
      } else {
        print('⚠️ User profile not found, creating one...');
        return await _createUserProfile(userId);
      }
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return null;
    }
  }

  Future<AppUser?> _createUserProfile(String userId) async {
    try {
      final userData = {
        'basicInfo': {
          'userId': userId,
          'email': _auth.currentUser?.email ?? '',
          'name': _auth.currentUser?.displayName ?? 'User',
          'phone': _auth.currentUser?.phoneNumber ?? '',
          'profileImage': '',
          'country': 'India',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'isActive': true,
          'isEmailVerified': _auth.currentUser?.emailVerified ?? false,
          'isPhoneVerified': _auth.currentUser?.phoneNumber != null,
        },
        'wallet': {
          'balance': 200.0, // Welcome bonus
          'totalDeposited': 0.0,
          'totalWithdrawn': 0.0,
          'totalWinnings': 0.0,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        'stats': {
          'totalMatchesPlayed': 0,
          'totalMatchesWon': 0,
          'totalTournamentsJoined': 0,
          'totalEarnings': 0.0,
          'winRate': 0.0,
          'favoriteGame': '',
          'rank': 'Beginner',
          'experiencePoints': 0,
        },
        'preferences': {
          'notifications': {
            'tournamentReminders': true,
            'matchAlerts': true,
            'promotional': false,
            'results': true,
          },
          'language': 'en',
          'theme': 'system',
          'currency': 'INR',
        },
        'role': 'user',
        'fcmToken': '',
      };

      await _firestore.collection('users').doc(userId).set(userData);
      print('✅ User profile created for: $userId');

      final newDoc = await _firestore.collection('users').doc(userId).get();
      return AppUser.fromFirestore(newDoc);
    } catch (e) {
      print('❌ Error creating user profile: $e');
      return null;
    }
  }

  // ========== TOURNAMENT REGISTRATION METHODS ==========
  Future<bool> hasUserRegisteredForTournament(String tournamentId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('registrations')
          .where('tournamentId', isEqualTo: tournamentId)
          .limit(1)
          .get();

      final isRegistered = query.docs.isNotEmpty;
      print('📝 Registration check - User: $userId, Tournament: $tournamentId, Registered: $isRegistered');
      return isRegistered;
    } catch (e) {
      print('❌ Error checking registration: $e');
      return false;
    }
  }

  Future<bool> registerForTournament({
    required Tournament tournament,
    required String playerName,
    required String playerId,
    required String paymentId,
    required String paymentMethod,
  }) async {
    try {
      final userId = _auth.currentUser!.uid;
      final userEmail = _auth.currentUser!.email ?? '';

      print('🧩 Starting tournament registration for user: $userId');

      return await _firestore.runTransaction((transaction) async {
        // Step 1: Check if user already registered
        final registrationQuery = await _firestore
            .collection('users')
            .doc(userId)
            .collection('registrations')
            .where('tournamentId', isEqualTo: tournament.id)
            .limit(1)
            .get();

        if (registrationQuery.docs.isNotEmpty) {
          throw Exception('You are already registered for this tournament');
        }

        // Step 2: Get and validate tournament
        final tournamentDoc = await transaction.get(
            _firestore.collection('tournaments').doc(tournament.id));

        if (!tournamentDoc.exists) {
          throw Exception('Tournament not found');
        }

        final tournamentData = tournamentDoc.data()!;
        final basicInfo = tournamentData['basicInfo'] ?? {};
        final registeredPlayers = (basicInfo['registeredPlayers'] ?? 0).toInt();
        final maxPlayers = (basicInfo['maxPlayers'] ?? 0).toInt();

        if (registeredPlayers >= maxPlayers) {
          throw Exception('Tournament is full');
        }

        // Step 3: If using wallet, check balance and deduct
        if (paymentMethod == 'wallet') {
          final userDoc = await transaction.get(_firestore.collection('users').doc(userId));
          final userData = userDoc.data();
          final wallet = userData?['wallet'] ?? {};
          final currentBalance = (wallet['balance'] ?? 0.0).toDouble();

          if (currentBalance < tournament.entryFee) {
            throw Exception('Insufficient wallet balance');
          }

          // Deduct from wallet
          transaction.update(_firestore.collection('users').doc(userId), {
            'wallet.balance': FieldValue.increment(-tournament.entryFee),
            'wallet.totalWithdrawn': FieldValue.increment(tournament.entryFee),
            'wallet.lastUpdated': FieldValue.serverTimestamp(),
          });
        }

        // Step 4: Create registration
        final registrationId = 'reg_${DateTime.now().millisecondsSinceEpoch}';
        final registrationRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('registrations')
            .doc(registrationId);

        final registrationData = {
          'registrationId': registrationId,
          'tournamentId': tournament.id,
          'tournamentName': tournament.tournamentName,
          'gameName': tournament.gameName,
          'playerName': playerName,
          'playerId': playerId,
          'userId': userId,
          'userEmail': userEmail,
          'entryFee': tournament.entryFee,
          'paymentId': paymentId,
          'paymentMethod': paymentMethod,
          'status': 'registered',
          'joinedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        transaction.set(registrationRef, registrationData);

        // Step 5: Update tournament player count
        transaction.update(_firestore.collection('tournaments').doc(tournament.id), {
          'basicInfo.registeredPlayers': FieldValue.increment(1),
          'metadata.updatedAt': FieldValue.serverTimestamp(),
        });

        // Step 6: Create transaction record
        final transactionRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .doc();

        transaction.set(transactionRef, {
          'id': transactionRef.id,
          'userId': userId,
          'type': paymentMethod == 'wallet' ? 'debit' : 'tournament_entry',
          'amount': tournament.entryFee,
          'currency': 'INR',
          'status': 'completed',
          'paymentGateway': paymentMethod,
          'paymentId': paymentId,
          'description': 'Tournament Entry: ${tournament.tournamentName}',
          'metadata': {
            'tournamentId': tournament.id,
            'tournamentName': tournament.tournamentName,
            'playerName': playerName,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'processedAt': FieldValue.serverTimestamp(),
        });

        // Step 7: Update user stats
        transaction.update(_firestore.collection('users').doc(userId), {
          'stats.totalTournamentsJoined': FieldValue.increment(1),
          'stats.updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Tournament registration completed successfully');
        return true;
      });
    } catch (e, st) {
      print('❌ Error in tournament registration: $e');
      print('🧾 Stack trace:\n$st');
      return false;
    }
  }


  // ========== GAME PROFILES MANAGEMENT ==========
  Future<bool> saveUserGameProfile({
    required String gameId,
    required String gameName,
    required String playerName,
    required String playerId,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final gameProfileData = {
        'gameId': gameId,
        'gameName': gameName,
        'playerName': playerName,
        'playerId': playerId,
        'level': 1,
        'rank': 'Bronze',
        'stats': {
          'kills': 0,
          'deaths': 0,
          'wins': 0,
          'matchesPlayed': 0,
          'kdRatio': 0.0,
        },
        'isVerified': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('gameProfiles')
          .doc(gameId)
          .set(gameProfileData);

      print('✅ Game profile saved for $gameName');
      return true;
    } catch (e) {
      print('❌ Error saving game profile: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getGameProfile(String gameId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('gameProfiles')
          .doc(gameId)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('❌ Error getting game profile: $e');
      return null;
    }
  }

  // ========== WALLET & PAYMENT METHODS ==========
  Future<bool> deductFromWallet(double amount) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      // Use transaction for atomic operations
      return await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(_firestore.collection('users').doc(userId));
        final userData = userDoc.data();

        if (userData == null) return false;

        final wallet = userData['wallet'] ?? {};
        final currentBalance = (wallet['balance'] ?? 0.0).toDouble();
        if (currentBalance < amount) {
          print('❌ Insufficient balance: $currentBalance, required: $amount');
          return false;
        }

        // Update wallet
        transaction.update(_firestore.collection('users').doc(userId), {
          'wallet.balance': FieldValue.increment(-amount),
          'wallet.totalWithdrawn': FieldValue.increment(amount),
          'wallet.lastUpdated': FieldValue.serverTimestamp(),
        });

        // Create transaction record
        final transactionRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .doc();

        transaction.set(transactionRef, {
          'type': 'debit',
          'amount': amount,
          'currency': 'INR',
          'status': 'completed',
          'paymentGateway': 'wallet',
          'description': 'Tournament registration fee',
          'metadata': {},
          'createdAt': FieldValue.serverTimestamp(),
          'processedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('❌ Error deducting from wallet: $e');
      return false;
    }
  }

  Future<void> addMoney(double amount, String paymentId, String gateway) async {
    try {
      final userId = _auth.currentUser!.uid;

      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(userId);
      final transactionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc();

      // Update wallet
      batch.update(userRef, {
        'wallet.balance': FieldValue.increment(amount),
        'wallet.totalDeposited': FieldValue.increment(amount),
        'wallet.lastUpdated': FieldValue.serverTimestamp(),
      });

      // Create transaction record
      batch.set(transactionRef, {
        'type': 'credit',
        'amount': amount,
        'currency': 'INR',
        'status': 'completed',
        'paymentGateway': gateway,
        'paymentId': paymentId,
        'description': 'Money Added via $gateway',
        'metadata': {'gateway_response': paymentId},
        'createdAt': FieldValue.serverTimestamp(),
        'processedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      print('✅ Money added successfully: $amount, Payment ID: $paymentId');
    } catch (e) {
      print('❌ Error adding money: $e');
      throw e;
    }
  }

  // ========== TOURNAMENT METHODS ==========
  Future<List<Tournament>> getTournamentsByGame(String gameName) async {
    try {
      final snapshot = await _firestore
          .collection('tournaments')
          .where('basicInfo.gameName', isEqualTo: gameName)
          .where('basicInfo.status', whereIn: ['upcoming', 'live'])
          .orderBy('schedule.tournamentStart')
          .limit(50)
          .get();

      final tournaments = snapshot.docs.map((doc) {
        return Tournament.fromFirestore(doc);
      }).toList();

      print('✅ Loaded ${tournaments.length} tournaments for $gameName');
      return tournaments;
    } catch (e) {
      print('❌ Error getting tournaments: $e');
      return [];
    }
  }

  Future<List<Tournament>> getUpcomingTournaments() async {
    try {
      final snapshot = await _firestore
          .collection('tournaments')
          .where('basicInfo.status', isEqualTo: 'upcoming')
          .where('schedule.registrationEnd', isGreaterThan: Timestamp.now())
          .orderBy('schedule.registrationEnd')
          .limit(20)
          .get();

      return snapshot.docs.map((doc) => Tournament.fromFirestore(doc)).toList();
    } catch (e) {
      print('❌ Error getting upcoming tournaments: $e');
      return [];
    }
  }

  Future<Tournament?> getTournamentById(String tournamentId) async {
    try {
      final doc = await _firestore.collection('tournaments').doc(tournamentId).get();
      return doc.exists ? Tournament.fromFirestore(doc) : null;
    } catch (e) {
      print('❌ Error getting tournament: $e');
      return null;
    }
  }

  // ========== MATCH CREDENTIALS ==========
  Future<Map<String, dynamic>?> getMatchCredentials(String tournamentId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final query = await _firestore
          .collection('matchCredentials')
          .where('tournamentId', isEqualTo: tournamentId)
          .where('participants', arrayContains: userId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty ? query.docs.first.data() : null;
    } catch (e) {
      print('❌ Error getting match credentials: $e');
      return null;
    }
  }

  // ========== TRANSACTION METHODS ==========
  Future<List<Map<String, dynamic>>> getUserTransactions() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'date': _formatDate(data['createdAt']),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting transactions: $e');
      return [];
    }
  }

  // ========== USER REGISTRATIONS ==========
  Future<List<Map<String, dynamic>>> getUserRegistrations() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('registrations')
          .orderBy('joinedAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'joinedDate': _formatDate(data['joinedAt']),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting user registrations: $e');
      return [];
    }
  }

  // ========== ADMIN METHODS ==========
  // In FirebaseService - Fix the getAllUsers method
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .limit(100)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final basicInfo = data['basicInfo'] ?? {};
        final wallet = data['wallet'] ?? {};
        final stats = data['stats'] ?? {};

        return {
          'id': doc.id,
          'name': basicInfo['name'] ?? 'User',
          'email': basicInfo['email'] ?? '',
          'walletBalance': (wallet['balance'] ?? 0.0).toDouble(),
          'totalMatches': stats['totalMatchesPlayed'] ?? 0,
          'totalWinnings': (wallet['totalWinnings'] ?? stats['totalEarnings'] ?? 0.0).toDouble(),
          'joinedAt': basicInfo['createdAt'],
          'role': data['role'] ?? 'user', // Add this line
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting all users: $e');
      return [];
    }
  }

  // Admin methods for bulk operations
  Future<void> addWelcomeBonusToAllUsers() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();

      for (var doc in usersSnapshot.docs) {
        final userData = doc.data();
        final wallet = userData['wallet'] ?? {};
        final currentBalance = (wallet['balance'] ?? 0.0).toDouble();

        if (currentBalance < 200.0) {
          batch.update(doc.reference, {
            'wallet.balance': FieldValue.increment(200.0 - currentBalance),
            'wallet.lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      print('✅ Welcome bonus added to all eligible users');
    } catch (e) {
      print('❌ Error adding welcome bonus: $e');
      throw e;
    }
  }

  // Get all transactions across all users (admin view)
  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    try {
      final snapshot = await _firestore
          .collectionGroup('transactions')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'date': _formatDate(data['createdAt']),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting all transactions: $e');
      return [];
    }
  }

  // Get user by ID for admin
  Future<AppUser?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists ? AppUser.fromFirestore(doc) : null;
    } catch (e) {
      print('❌ Error getting user by ID: $e');
      return null;
    }
  }

  // Update user role
  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
        'basicInfo.updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ User role updated to: $newRole');
    } catch (e) {
      print('❌ Error updating user role: $e');
      throw e;
    }
  }

  // ========== NOTIFICATION METHODS ==========
  Future<void> saveFCMToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
        });
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserNotifications() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'time': _formatTimeAgo(data['createdAt']),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting notifications: $e');
      return [];
    }
  }

  // ========== HELPER METHODS ==========
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return timestamp.toString();
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp is! Timestamp) return 'Recently';

    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }
  // Add this method to your FirebaseService class

// ========== MATCH HISTORY METHODS ==========
  Future<List<Map<String, dynamic>>> getUserMatches() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      // Get user registrations which contain match history
      final registrations = await _firestore
          .collection('users')
          .doc(userId)
          .collection('registrations')
          .where('status', whereIn: ['completed', 'checked-in'])
          .orderBy('completedAt', descending: true)
          .limit(20)
          .get();

      return registrations.docs.map((doc) {
        final data = doc.data();

        // Determine result based on position and winnings
        String result = 'Played';
        if (data['position'] != null && data['position'] <= 3) {
          result = 'Won';
        } else if (data['winnings'] != null && data['winnings'] > 0) {
          result = 'Won';
        }

        return {
          'id': doc.id,
          'tournamentName': data['tournamentName'] ?? 'Unknown Tournament',
          'gameName': data['gameName'] ?? 'Unknown Game',
          'position': data['position'] ?? 'N/A',
          'kills': data['kills'] ?? 0,
          'winnings': (data['winnings'] ?? 0.0).toDouble(),
          'result': result,
          'date': _formatDate(data['completedAt'] ?? data['joinedAt']),
          'entryFee': data['entryFee'] ?? 0.0,
          'playerName': data['playerName'] ?? 'Player',
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting user matches: $e');
      return _getMockMatches(); // Fallback to mock data
    }
  }

// Alternative: Get matches from a dedicated matches collection
  Future<List<Map<String, dynamic>>> getUserMatchesFromMatchesCollection() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final matches = await _firestore
          .collection('matches')
          .where('players', arrayContains: userId)
          .orderBy('matchDate', descending: true)
          .limit(20)
          .get();

      return matches.docs.map((doc) {
        final data = doc.data();
        final playerData = _getPlayerMatchData(data, userId);

        return {
          'id': doc.id,
          'tournamentName': data['tournamentName'] ?? 'Unknown Tournament',
          'gameName': data['gameName'] ?? 'Unknown Game',
          'position': playerData['position'] ?? 'N/A',
          'kills': playerData['kills'] ?? 0,
          'winnings': (playerData['winnings'] ?? 0.0).toDouble(),
          'result': playerData['result'] ?? 'Played',
          'date': _formatDate(data['matchDate']),
          'entryFee': data['entryFee'] ?? 0.0,
          'matchType': data['matchType'] ?? 'Tournament',
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting matches from collection: $e');
      return _getMockMatches();
    }
  }

  Map<String, dynamic> _getPlayerMatchData(Map<String, dynamic> matchData, String userId) {
    try {
      final players = matchData['players'] ?? [];
      final results = matchData['results'] ?? [];

      for (var player in players) {
        if (player['userId'] == userId) {
          return {
            'position': player['position'],
            'kills': player['kills'] ?? 0,
            'winnings': player['winnings'] ?? 0.0,
            'result': player['position'] <= 3 ? 'Won' : 'Played',
          };
        }
      }

      // Fallback if player data not found
      final playerResult = results.firstWhere(
              (result) => result['userId'] == userId,
          orElse: () => {'position': 'N/A', 'kills': 0, 'winnings': 0.0}
      );

      return {
        'position': playerResult['position'] ?? 'N/A',
        'kills': playerResult['kills'] ?? 0,
        'winnings': playerResult['winnings'] ?? 0.0,
        'result': (playerResult['position'] != null && playerResult['position'] <= 3) ? 'Won' : 'Played',
      };
    } catch (e) {
      return {'position': 'N/A', 'kills': 0, 'winnings': 0.0, 'result': 'Played'};
    }
  }

// Mock data for testing
  List<Map<String, dynamic>> _getMockMatches() {
    return [
      {
        'tournamentName': 'BGMI Championship Season 1',
        'gameName': 'BGMI',
        'position': 2,
        'kills': 12,
        'winnings': 1500.00,
        'result': 'Won',
        'date': '15/12/2023',
        'entryFee': 50.0,
      },
      {
        'tournamentName': 'Weekly BGMI Showdown',
        'gameName': 'BGMI',
        'position': 8,
        'kills': 7,
        'winnings': 0.0,
        'result': 'Played',
        'date': '12/12/2023',
        'entryFee': 30.0,
      },
      {
        'tournamentName': 'Free Fire Masters',
        'gameName': 'Free Fire',
        'position': 1,
        'kills': 15,
        'winnings': 2000.00,
        'result': 'Won',
        'date': '10/12/2023',
        'entryFee': 25.0,
      },
      {
        'tournamentName': 'COD Mobile Championship',
        'gameName': 'COD Mobile',
        'position': 5,
        'kills': 18,
        'winnings': 250.00,
        'result': 'Played',
        'date': '08/12/2023',
        'entryFee': 40.0,
      },
      {
        'tournamentName': 'Valorant Pro Series',
        'gameName': 'Valorant',
        'position': 3,
        'kills': 25,
        'winnings': 800.00,
        'result': 'Won',
        'date': '05/12/2023',
        'entryFee': 80.0,
      },
    ];
  }

  // ========== SAMPLE DATA SEEDING ==========
  Future<void> seedSampleTournaments() async {
    try {
      final sampleTournaments = [
        {
          'basicInfo': {
            'tournamentId': 'BGMI_001',
            'tournamentName': 'BGMI Championship Season 1',
            'gameName': 'BGMI',
            'gameId': 'bgmi',
            'tournamentType': 'solo',
            'entryFee': 50.0,
            'prizePool': 5000.0,
            'maxPlayers': 100,
            'registeredPlayers': 0,
            'status': 'upcoming',
            'platform': 'mobile',
            'region': 'global',
          },
          'schedule': {
            'registrationStart': Timestamp.now(),
            'registrationEnd': Timestamp.fromDate(DateTime.now().add(Duration(days: 2, hours: 5))),
            'tournamentStart': Timestamp.fromDate(DateTime.now().add(Duration(days: 3))),
            'estimatedDuration': 180,
            'checkInTime': Timestamp.fromDate(DateTime.now().add(Duration(days: 3)).subtract(Duration(minutes: 30))),
          },
          'rules': {
            'maxKills': 99,
            'allowedDevices': ['mobile'],
            'streamingRequired': false,
            'screenshotRequired': true,
            'specificRules': {
              'map': 'Erangel',
              'perspective': 'TPP',
              'teamSize': 1,
            },
          },
          'prizes': {
            'distribution': [
              {'rank': 1, 'prize': 2500, 'percentage': 50},
              {'rank': 2, 'prize': 1500, 'percentage': 30},
              {'rank': 3, 'prize': 1000, 'percentage': 20},
            ],
          },
          'metadata': {
            'createdBy': 'admin',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'version': 1,
            'featured': true,
            'sponsored': false,
          },
        },
      ];

      for (final tournament in sampleTournaments) {
        await _firestore.collection('tournaments').add(tournament);
      }

      print('✅ Sample tournaments seeded successfully');
    } catch (e) {
      print('❌ Error seeding sample tournaments: $e');
    }
  }
}