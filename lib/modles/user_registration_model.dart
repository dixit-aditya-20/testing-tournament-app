import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String userId;
  final String email;
  final String name;
  final String phone;
  final String fcmToken;
  final double totalWinning;
  final double totalBalance;
  final DateTime createdAt;
  final DateTime lastLogin;
  final Map<String, dynamic> tournaments;
  final Map<String, dynamic> matches;
  final List<dynamic> withdrawRequests;
  final List<dynamic> transactions;
  final List<dynamic> tournamentRegistrations;
  final String role; // ADD THIS FIELD

  AppUser({
    required this.userId,
    required this.email,
    required this.name,
    required this.phone,
    required this.fcmToken,
    required this.totalWinning,
    required this.totalBalance,
    required this.createdAt,
    required this.lastLogin,
    required this.tournaments,
    required this.matches,
    required this.withdrawRequests,
    required this.transactions,
    required this.tournamentRegistrations,
    required this.role, // ADD THIS PARAMETER
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};

      final Timestamp? createdAtTimestamp = data['createdAt'] as Timestamp?;
      final Timestamp? lastLoginTimestamp = data['last_login'] as Timestamp?;

      final wallet = data['wallet'] as Map<String, dynamic>? ?? {};

      return AppUser(
        userId: doc.id,
        email: (data['email'] as String?) ?? '',
        name: (data['name'] as String?) ?? 'User',
        phone: (data['phone'] as String?) ?? '',
        fcmToken: (data['fcmToken'] as String?) ?? '',
        totalWinning: (wallet['total_winning'] as num?)?.toDouble() ?? 0.0,
        totalBalance: (wallet['total_balance'] as num?)?.toDouble() ?? 0.0,
        createdAt: createdAtTimestamp?.toDate() ?? DateTime.now(),
        lastLogin: lastLoginTimestamp?.toDate() ?? DateTime.now(),
        tournaments: (data['tournaments'] as Map<String, dynamic>?) ?? {},
        matches: (data['matches'] as Map<String, dynamic>?) ?? {},
        withdrawRequests: (data['withdraw_request'] as List<dynamic>?) ?? [],
        transactions: (data['transactions'] as List<dynamic>?) ?? [],
        tournamentRegistrations: (data['tournament_registrations'] as List<dynamic>?) ?? [],
        role: (data['role'] as String?) ?? 'user', // ADD THIS
      );
    } catch (e, stackTrace) {
      print('❌ Error parsing AppUser from Firestore: $e');
      print('📝 Stack trace: $stackTrace');
      print('📄 Document data: ${doc.data()}');

      return AppUser(
        userId: doc.id,
        email: 'error@example.com',
        name: 'Error User',
        phone: '',
        fcmToken: '',
        totalWinning: 0.0,
        totalBalance: 0.0,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        tournaments: {},
        matches: {},
        withdrawRequests: [],
        transactions: [],
        tournamentRegistrations: [],
        role: 'user', // ADD THIS
      );
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'fcmToken': fcmToken,
      'userID': userId,
      'role': role, // ADD THIS
      'wallet': {
        'total_winning': totalWinning,
        'total_balance': totalBalance,
        'last_updated': FieldValue.serverTimestamp(),
      },
      'withdraw_request': withdrawRequests,
      'transactions': transactions,
      'tournaments': tournaments,
      'tournament_registrations': tournamentRegistrations,
      'matches': matches,
      'user_all_match_details': _getMatchesList('recent_match'),
      'user_won_match_details': _getMatchesList('won_match'),
      'user_loss_match_details': _getMatchesList('loss_match'),
      'updated_at': FieldValue.serverTimestamp(),
      'last_login': FieldValue.serverTimestamp(),
    };
  }

  List<dynamic> _getMatchesList(String key) {
    final matchesList = matches[key];
    return matchesList is List ? matchesList : [];
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'phone': phone,
      'fcmToken': fcmToken,
      'totalWinning': totalWinning,
      'totalBalance': totalBalance,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLogin': lastLogin.millisecondsSinceEpoch,
      'tournaments': tournaments,
      'matches': matches,
      'withdrawRequests': withdrawRequests,
      'transactions': transactions,
      'tournamentRegistrations': tournamentRegistrations,
      'role': role, // ADD THIS
    };
  }

  // Tournament registration helper methods
  List<Map<String, dynamic>> get activeRegistrations {
    final List<Map<String, dynamic>> result = [];
    for (var reg in tournamentRegistrations) {
      if (reg is Map<String, dynamic> && reg['status'] == 'registered') {
        result.add(reg);
      }
    }
    return result;
  }

  List<Map<String, dynamic>> get completedTournaments {
    final List<Map<String, dynamic>> result = [];
    for (var reg in tournamentRegistrations) {
      if (reg is Map<String, dynamic> && reg['status'] == 'completed') {
        result.add(reg);
      }
    }
    return result;
  }

  List<Map<String, dynamic>> get wonTournaments {
    final List<Map<String, dynamic>> result = [];
    for (var reg in tournamentRegistrations) {
      if (reg is Map<String, dynamic> && reg['result'] == 'won') {
        result.add(reg);
      }
    }
    return result;
  }

  List<Map<String, dynamic>> get pendingTournaments {
    return activeRegistrations;
  }

  List<Map<String, dynamic>> get cancelledTournaments {
    final List<Map<String, dynamic>> result = [];
    for (var reg in tournamentRegistrations) {
      if (reg is Map<String, dynamic> && reg['status'] == 'cancelled') {
        result.add(reg);
      }
    }
    return result;
  }

  int get totalTournamentsJoined => tournamentRegistrations.length;
  int get tournamentsWon => wonTournaments.length;
  int get activeTournaments => activeRegistrations.length;
  int get completedTournamentsCount => completedTournaments.length;

  double get totalTournamentWinnings {
    double total = 0.0;
    for (var reg in tournamentRegistrations) {
      if (reg is Map<String, dynamic>) {
        total += (reg['winnings'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return total;
  }

  double get totalEntryFeesPaid {
    double total = 0.0;
    for (var reg in tournamentRegistrations) {
      if (reg is Map<String, dynamic>) {
        total += (reg['entry_fee'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return total;
  }

  double get netTournamentProfit {
    return totalTournamentWinnings - totalEntryFeesPaid;
  }

  double get tournamentWinRate {
    return completedTournamentsCount > 0 ? (tournamentsWon / completedTournamentsCount * 100) : 0.0;
  }

  // Game profile helper methods
  Map<String, dynamic>? getBGMIProfile() {
    final bgmi = tournaments['BGMI'];
    return bgmi is Map<String, dynamic> ? bgmi : null;
  }

  Map<String, dynamic>? getFreeFireProfile() {
    final freeFire = tournaments['FREEFIRE'];
    return freeFire is Map<String, dynamic> ? freeFire : null;
  }

  Map<String, dynamic>? getValorantProfile() {
    final valorant = tournaments['VALORANT'];
    return valorant is Map<String, dynamic> ? valorant : null;
  }

  Map<String, dynamic>? getCODMobileProfile() {
    final codMobile = tournaments['COD_MOBILE'];
    return codMobile is Map<String, dynamic> ? codMobile : null;
  }

  String getBGMIName() {
    return getBGMIProfile()?['BGMI_NAME'] as String? ?? '';
  }

  String getBGMIId() {
    return getBGMIProfile()?['BGMI_ID'] as String? ?? '';
  }

  String getFreeFireName() {
    return getFreeFireProfile()?['FREEFIRE_NAME'] as String? ?? '';
  }

  String getFreeFireId() {
    return getFreeFireProfile()?['FREEFIRE_ID'] as String? ?? '';
  }

  String getValorantName() {
    return getValorantProfile()?['VALORANT_NAME'] as String? ?? '';
  }

  String getValorantId() {
    return getValorantProfile()?['VALORANT_ID'] as String? ?? '';
  }

  String getCODMobileName() {
    return getCODMobileProfile()?['COD_MOBILE_NAME'] as String? ?? '';
  }

  String getCODMobileId() {
    return getCODMobileProfile()?['COD_MOBILE_ID'] as String? ?? '';
  }

  // Match statistics helper methods
  int get totalMatches {
    final recentMatches = matches['recent_match'];
    return recentMatches is List ? recentMatches.length : 0;
  }

  int get wonMatches {
    final wonMatchesList = matches['won_match'];
    return wonMatchesList is List ? wonMatchesList.length : 0;
  }

  int get lostMatches {
    final lostMatchesList = matches['loss_match'];
    return lostMatchesList is List ? lostMatchesList.length : 0;
  }

  double get winRate {
    return totalMatches > 0 ? (wonMatches / totalMatches * 100) : 0.0;
  }

  double get totalMatchWinnings {
    double total = 0.0;
    final recentMatches = matches['recent_match'];
    if (recentMatches is List) {
      for (var match in recentMatches) {
        if (match is Map<String, dynamic>) {
          total += (match['winnings'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }
    return total;
  }

  // Wallet helper methods
  bool get hasSufficientBalance {
    return totalBalance > 0;
  }

  bool canAffordTournament(double entryFee) {
    return totalBalance >= entryFee;
  }

  // Tournament registration status checkers
  bool isRegisteredForTournament(String tournamentId) {
    for (var reg in tournamentRegistrations) {
      if (reg is Map<String, dynamic> &&
          reg['tournament_id'] == tournamentId &&
          reg['status'] == 'registered') {
        return true;
      }
    }
    return false;
  }

  bool hasCompletedTournament(String tournamentId) {
    for (var reg in tournamentRegistrations) {
      if (reg is Map<String, dynamic> &&
          reg['tournament_id'] == tournamentId &&
          reg['status'] == 'completed') {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic>? getTournamentRegistration(String tournamentId) {
    try {
      for (var reg in tournamentRegistrations) {
        if (reg is Map<String, dynamic> && reg['tournament_id'] == tournamentId) {
          return reg;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Admin check
  bool get isAdmin => role == 'admin';

  // Recent activity
  List<Map<String, dynamic>> get recentActivity {
    final List<Map<String, dynamic>> allActivities = [];

    // Add recent matches
    final recentMatches = matches['recent_match'];
    if (recentMatches is List) {
      for (var match in recentMatches) {
        if (match is Map<String, dynamic>) {
          allActivities.add({
            ...match,
            'type': 'match',
            'activity_time': match['timestamp'],
          });
        }
      }
    }

    // Add recent tournament registrations
    final List<Map<String, dynamic>> validRegistrations = [];
    for (var reg in tournamentRegistrations) {
      if (reg is Map<String, dynamic> && reg['registration_date'] != null) {
        validRegistrations.add(reg);
      }
    }

    validRegistrations.sort((a, b) {
      final timeA = a['registration_date'] as Timestamp? ?? Timestamp.now();
      final timeB = b['registration_date'] as Timestamp? ?? Timestamp.now();
      return timeB.compareTo(timeA);
    });

    for (var reg in validRegistrations.take(10)) {
      allActivities.add({
        ...reg,
        'type': 'tournament_registration',
        'activity_time': reg['registration_date'],
      });
    }

    // Sort all activities by time
    allActivities.sort((a, b) {
      final timeA = a['activity_time'] as Timestamp? ?? Timestamp.now();
      final timeB = b['activity_time'] as Timestamp? ?? Timestamp.now();
      return timeB.compareTo(timeA);
    });

    return allActivities.take(20).toList();
  }

  @override
  String toString() {
    return 'AppUser{userId: $userId, name: $name, email: $email, role: $role, totalBalance: $totalBalance, totalWinning: $totalWinning, tournamentsJoined: $totalTournamentsJoined, tournamentsWon: $tournamentsWon}';
  }
}