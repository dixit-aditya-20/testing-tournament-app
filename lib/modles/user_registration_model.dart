// models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String userId;
  final String email;
  final String name;
  final String phone;
  final String profileImage;
  final String country;
  final DateTime createdAt;
  final DateTime lastLogin;
  final bool isActive;
  final double walletBalance;
  final double totalWinnings;
  final int totalMatchesPlayed;
  final int totalMatchesWon;
  final int totalTournamentsJoined;
  final double winRate;
  final String rank;
  final String role;

  AppUser({
    required this.userId,
    required this.email,
    required this.name,
    required this.phone,
    required this.profileImage,
    required this.country,
    required this.createdAt,
    required this.lastLogin,
    required this.isActive,
    required this.walletBalance,
    required this.totalWinnings,
    required this.totalMatchesPlayed,
    required this.totalMatchesWon,
    required this.totalTournamentsJoined,
    required this.winRate,
    required this.rank,
    required this.role,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final basicInfo = data['basicInfo'] as Map<String, dynamic>? ?? {};
      final wallet = data['wallet'] as Map<String, dynamic>? ?? {};
      final stats = data['stats'] as Map<String, dynamic>? ?? {};

      // Safe timestamp conversion
      Timestamp? createdAtTimestamp = basicInfo['createdAt'] as Timestamp?;
      Timestamp? lastLoginTimestamp = basicInfo['lastLogin'] as Timestamp?;

      return AppUser(
        userId: doc.id,
        email: basicInfo['email']?.toString() ?? '',
        name: basicInfo['name']?.toString() ?? 'User',
        phone: basicInfo['phone']?.toString() ?? '',
        profileImage: basicInfo['profileImage']?.toString() ?? '',
        country: basicInfo['country']?.toString() ?? 'India',
        createdAt: createdAtTimestamp?.toDate() ?? DateTime.now(),
        lastLogin: lastLoginTimestamp?.toDate() ?? DateTime.now(),
        isActive: basicInfo['isActive'] as bool? ?? true,
        walletBalance: (wallet['balance'] as num?)?.toDouble() ?? 0.0,
        totalWinnings: (wallet['totalWinnings'] as num?)?.toDouble() ?? 0.0,
        totalMatchesPlayed: (stats['totalMatchesPlayed'] as int?) ?? 0,
        totalMatchesWon: (stats['totalMatchesWon'] as int?) ?? 0,
        totalTournamentsJoined: (stats['totalTournamentsJoined'] as int?) ?? 0,
        winRate: (stats['winRate'] as num?)?.toDouble() ?? 0.0,
        rank: stats['rank']?.toString() ?? 'Beginner',
        role: data['role']?.toString() ?? 'user',
      );
    } catch (e, stackTrace) {
      print('❌ Error parsing AppUser from Firestore: $e');
      print('📝 Stack trace: $stackTrace');
      print('📄 Document data: ${doc.data()}');

      // Return a default user instead of crashing
      return AppUser(
        userId: doc.id,
        email: 'error@example.com',
        name: 'Error User',
        phone: '',
        profileImage: '',
        country: 'India',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        isActive: false,
        walletBalance: 0.0,
        totalWinnings: 0.0,
        totalMatchesPlayed: 0,
        totalMatchesWon: 0,
        totalTournamentsJoined: 0,
        winRate: 0.0,
        rank: 'Beginner',
        role: 'user',
      );
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'basicInfo': {
        'userId': userId,
        'email': email,
        'name': name,
        'phone': phone,
        'profileImage': profileImage,
        'country': country,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'lastLogin': Timestamp.fromDate(lastLogin),
        'isActive': isActive,
        'isEmailVerified': email.isNotEmpty,
        'isPhoneVerified': phone.isNotEmpty,
      },
      'wallet': {
        'balance': walletBalance,
        'totalDeposited': 0.0,
        'totalWithdrawn': 0.0,
        'totalWinnings': totalWinnings,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      },
      'stats': {
        'totalMatchesPlayed': totalMatchesPlayed,
        'totalMatchesWon': totalMatchesWon,
        'totalTournamentsJoined': totalTournamentsJoined,
        'totalEarnings': totalWinnings,
        'winRate': winRate,
        'favoriteGame': '',
        'rank': rank,
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
      'role': role,
      'fcmToken': '',
    };
  }

  // Keep your existing toMap for other uses
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'phone': phone,
      'profileImage': profileImage,
      'country': country,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLogin': lastLogin.millisecondsSinceEpoch,
      'isActive': isActive,
      'walletBalance': walletBalance,
      'totalWinnings': totalWinnings,
      'totalMatchesPlayed': totalMatchesPlayed,
      'totalMatchesWon': totalMatchesWon,
      'totalTournamentsJoined': totalTournamentsJoined,
      'winRate': winRate,
      'rank': rank,
      'role': role,
    };
  }

  @override
  String toString() {
    return 'AppUser{userId: $userId, name: $name, email: $email, walletBalance: $walletBalance}';
  }
}