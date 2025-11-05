import 'package:cloud_firestore/cloud_firestore.dart';

class Tournament {
  final String id;
  final String tournamentName;
  final String gameName;
  final String gameId;
  final double entryFee;
  final double winningPrize;
  final int totalSlots;
  final int registeredPlayers;
  final int slotsLeft;
  final String tournamentType;
  final String matchTime;
  final String map;
  final String mode;
  final String description;
  final String status;
  final Timestamp registrationStart;
  final Timestamp registrationEnd;
  final Timestamp tournamentStart;

  // Match credentials fields
  final String? roomId;
  final String? roomPassword;
  final Timestamp? credentialsMatchTime;
  final Timestamp? credentialsAddedAt;
  final bool hasCredentials;

  // Prize distribution field
  final Map<String, double> prizeDistribution;

  Tournament({
    required this.id,
    required this.tournamentName,
    required this.gameName,
    required this.gameId,
    required this.entryFee,
    required this.winningPrize,
    required this.totalSlots,
    required this.registeredPlayers,
    required this.slotsLeft,
    required this.tournamentType,
    required this.matchTime,
    required this.map,
    required this.mode,
    required this.description,
    required this.status,
    required this.registrationStart,
    required this.registrationEnd,
    required this.tournamentStart,
    this.roomId,
    this.roomPassword,
    this.credentialsMatchTime,
    this.credentialsAddedAt,
    this.hasCredentials = false,
    required this.prizeDistribution,
  });

  bool get isRegistrationOpen {
    final now = DateTime.now();
    final registrationEndTime = registrationEnd.toDate();
    return now.isBefore(registrationEndTime);
  }

  bool get shouldShowCredentials {
    if (!hasCredentials) return false;

    final now = DateTime.now();
    final matchTime = credentialsMatchTime ?? tournamentStart;
    final thirtyMinutesBefore = matchTime.toDate().subtract(Duration(minutes: 30));

    return now.isAfter(thirtyMinutesBefore);
  }

  bool get credentialsComingSoon {
    if (!hasCredentials) return false;

    final now = DateTime.now();
    final matchTime = credentialsMatchTime ?? tournamentStart;
    final thirtyMinutesBefore = matchTime.toDate().subtract(Duration(minutes: 30));

    return now.isBefore(thirtyMinutesBefore);
  }

  String get credentialsAvailabilityTime {
    if (!hasCredentials) return '';

    final matchTime = credentialsMatchTime ?? tournamentStart;
    final thirtyMinutesBefore = matchTime.toDate().subtract(Duration(minutes: 30));

    return _formatTime(thirtyMinutesBefore);
  }

  Duration get timeUntilCredentialsAvailable {
    if (!hasCredentials) return Duration.zero;

    final now = DateTime.now();
    final matchTime = credentialsMatchTime ?? tournamentStart;
    final thirtyMinutesBefore = matchTime.toDate().subtract(Duration(minutes: 30));

    return thirtyMinutesBefore.difference(now);
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  factory Tournament.fromMap(Map<String, dynamic> data, String id) {
    // Calculate slots left if not provided
    final totalSlots = (data['total_slots'] as num?)?.toInt() ?? 0;
    final registeredPlayers = (data['registered_players'] as num?)?.toInt() ?? 0;
    final slotsLeft = (data['slots_left'] as num?)?.toInt() ?? (totalSlots - registeredPlayers);

    // Check if credentials exist
    final hasCredentials = data['roomId'] != null &&
        data['roomId'].toString().isNotEmpty &&
        data['roomPassword'] != null &&
        data['roomPassword'].toString().isNotEmpty;

    // Handle prize distribution
    Map<String, double> prizeDistribution = {};

    if (data['prize_distribution'] != null && data['prize_distribution'] is Map) {
      // Convert Map<dynamic, dynamic> to Map<String, double>
      final prizeMap = data['prize_distribution'] as Map;
      prizeMap.forEach((key, value) {
        if (value is num) {
          prizeDistribution[key.toString()] = value.toDouble();
        }
      });
    } else {
      // Fallback: create default prize distribution if not provided
      final totalPrize = (data['winning_prize'] as num?)?.toDouble() ?? 0.0;
      prizeDistribution = _createDefaultPrizeDistribution(totalPrize);
    }

    return Tournament(
      id: id,
      tournamentName: data['tournament_name'] ?? '',
      gameName: data['game_name'] ?? '',
      gameId: data['game_id'] ?? '',
      entryFee: (data['entry_fee'] as num?)?.toDouble() ?? 0.0,
      winningPrize: (data['winning_prize'] as num?)?.toDouble() ?? 0.0,
      totalSlots: totalSlots,
      registeredPlayers: registeredPlayers,
      slotsLeft: slotsLeft,
      tournamentType: data['tournament_type'] ?? 'solo',
      matchTime: data['match_time'] ?? '',
      map: data['map'] ?? '',
      mode: data['mode'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? 'upcoming',
      registrationStart: data['registration_start'] ?? Timestamp.now(),
      registrationEnd: data['registration_end'] ?? Timestamp.now(),
      tournamentStart: data['tournament_start'] ?? Timestamp.now(),
      roomId: data['roomId'],
      roomPassword: data['roomPassword'],
      credentialsMatchTime: data['credentialsMatchTime'] ?? data['tournament_start'],
      credentialsAddedAt: data['credentialsAddedAt'],
      hasCredentials: hasCredentials,
      prizeDistribution: prizeDistribution,
    );
  }

  // Helper method to create default prize distribution
  static Map<String, double> _createDefaultPrizeDistribution(double totalPrize) {
    if (totalPrize <= 0) return {};

    // Default distribution based on common tournament structures
    if (totalPrize < 1000) {
      // Small tournaments: Winner takes all or simple split
      return {
        '1': totalPrize * 1.0,
      };
    } else if (totalPrize < 5000) {
      // Medium tournaments: Standard 3-position split
      return {
        '1': totalPrize * 0.60,
        '2': totalPrize * 0.30,
        '3': totalPrize * 0.10,
      };
    } else {
      // Large tournaments: Extended prize distribution
      return {
        '1': totalPrize * 0.50,
        '2': totalPrize * 0.25,
        '3': totalPrize * 0.15,
        '4': totalPrize * 0.10,
      };
    }
  }

  factory Tournament.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tournament.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tournament_name': tournamentName,
      'game_name': gameName,
      'game_id': gameId,
      'entry_fee': entryFee,
      'winning_prize': winningPrize,
      'total_slots': totalSlots,
      'registered_players': registeredPlayers,
      'slots_left': slotsLeft,
      'tournament_type': tournamentType,
      'match_time': matchTime,
      'map': map,
      'mode': mode,
      'description': description,
      'status': status,
      'registration_start': registrationStart,
      'registration_end': registrationEnd,
      'tournament_start': tournamentStart,
      'roomId': roomId,
      'roomPassword': roomPassword,
      'credentialsMatchTime': credentialsMatchTime,
      'credentialsAddedAt': credentialsAddedAt,
      'hasCredentials': hasCredentials,
      'prize_distribution': prizeDistribution,
    };
  }

  // Get formatted prize distribution for display
  String getFormattedPrizeDistribution() {
    if (prizeDistribution.isEmpty) return 'No prize distribution set';

    final sortedEntries = prizeDistribution.entries.toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

    return sortedEntries.map((entry) {
      final position = entry.key;
      final prize = entry.value;
      String positionText;

      switch (position) {
        case '1':
          positionText = '🥇 1st';
          break;
        case '2':
          positionText = '🥈 2nd';
          break;
        case '3':
          positionText = '🥉 3rd';
          break;
        default:
          positionText = '${position}th';
      }

      return '$positionText: ₹${prize.toStringAsFixed(0)}';
    }).join('\n');
  }

  // Get top 3 prizes for quick display
  Map<String, double> get topThreePrizes {
    final sortedEntries = prizeDistribution.entries.toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

    return Map.fromEntries(sortedEntries.take(3));
  }

  // Get total number of prize positions
  int get prizePositionsCount {
    return prizeDistribution.length;
  }

  // Check if tournament has prize distribution
  bool get hasPrizeDistribution {
    return prizeDistribution.isNotEmpty;
  }

  // Get the highest prize amount
  double get highestPrize {
    if (prizeDistribution.isEmpty) return 0.0;
    return prizeDistribution.values.reduce((a, b) => a > b ? a : b);
  }

  // Get the lowest prize amount
  double get lowestPrize {
    if (prizeDistribution.isEmpty) return 0.0;
    return prizeDistribution.values.reduce((a, b) => a < b ? a : b);
  }

  // Get prize for a specific position
  double? getPrizeForPosition(String position) {
    return prizeDistribution[position];
  }

  // Get formatted time until tournament starts
  String get timeUntilStart {
    final now = DateTime.now();
    final start = tournamentStart.toDate();
    final difference = start.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Starting now';
    }
  }

  // Get formatted tournament start time
  String get formattedStartTime {
    final date = tournamentStart.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Get formatted registration end time
  String get formattedRegistrationEndTime {
    final date = registrationEnd.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Check if tournament is about to start (within 1 hour)
  bool get isStartingSoon {
    final now = DateTime.now();
    final start = tournamentStart.toDate();
    final difference = start.difference(now);
    return difference.inMinutes <= 60 && difference.inMinutes > 0;
  }

  // Check if tournament has started
  bool get hasStarted {
    final now = DateTime.now();
    final start = tournamentStart.toDate();
    return now.isAfter(start);
  }

  // Check if tournament is completed
  bool get isCompleted {
    return status == 'completed';
  }

  // Check if tournament is live
  bool get isLive {
    return status == 'live';
  }

  // Check if tournament is upcoming
  bool get isUpcoming {
    return status == 'upcoming';
  }

  // Get registration progress percentage
  double get registrationProgress {
    if (totalSlots == 0) return 0.0;
    return registeredPlayers / totalSlots;
  }

  // Get formatted progress text
  String get progressText {
    return '$registeredPlayers/$totalSlots';
  }

  // Check if user can join (has slots and registration open)
  bool get canJoin {
    return isRegistrationOpen && slotsLeft > 0;
  }

  // Get join button text based on status
  String get joinButtonText {
    if (!isRegistrationOpen) {
      return 'Registration Closed';
    } else if (slotsLeft <= 0) {
      return 'Tournament Full';
    } else {
      return 'Join Now';
    }
  }

  // Get join button color based on status
  String get joinButtonColor {
    if (!isRegistrationOpen) {
      return 'grey';
    } else if (slotsLeft <= 0) {
      return 'red';
    } else {
      return 'green';
    }
  }

  @override
  String toString() {
    return 'Tournament{id: $id, tournamentName: $tournamentName, gameName: $gameName, entryFee: $entryFee, winningPrize: $winningPrize, status: $status}';
  }

  // Copy with method for updating tournament
  Tournament copyWith({
    String? id,
    String? tournamentName,
    String? gameName,
    String? gameId,
    double? entryFee,
    double? winningPrize,
    int? totalSlots,
    int? registeredPlayers,
    int? slotsLeft,
    String? tournamentType,
    String? matchTime,
    String? map,
    String? mode,
    String? description,
    String? status,
    Timestamp? registrationStart,
    Timestamp? registrationEnd,
    Timestamp? tournamentStart,
    String? roomId,
    String? roomPassword,
    Timestamp? credentialsMatchTime,
    Timestamp? credentialsAddedAt,
    bool? hasCredentials,
    Map<String, double>? prizeDistribution,
  }) {
    return Tournament(
      id: id ?? this.id,
      tournamentName: tournamentName ?? this.tournamentName,
      gameName: gameName ?? this.gameName,
      gameId: gameId ?? this.gameId,
      entryFee: entryFee ?? this.entryFee,
      winningPrize: winningPrize ?? this.winningPrize,
      totalSlots: totalSlots ?? this.totalSlots,
      registeredPlayers: registeredPlayers ?? this.registeredPlayers,
      slotsLeft: slotsLeft ?? this.slotsLeft,
      tournamentType: tournamentType ?? this.tournamentType,
      matchTime: matchTime ?? this.matchTime,
      map: map ?? this.map,
      mode: mode ?? this.mode,
      description: description ?? this.description,
      status: status ?? this.status,
      registrationStart: registrationStart ?? this.registrationStart,
      registrationEnd: registrationEnd ?? this.registrationEnd,
      tournamentStart: tournamentStart ?? this.tournamentStart,
      roomId: roomId ?? this.roomId,
      roomPassword: roomPassword ?? this.roomPassword,
      credentialsMatchTime: credentialsMatchTime ?? this.credentialsMatchTime,
      credentialsAddedAt: credentialsAddedAt ?? this.credentialsAddedAt,
      hasCredentials: hasCredentials ?? this.hasCredentials,
      prizeDistribution: prizeDistribution ?? this.prizeDistribution,
    );
  }

  // Equality check
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tournament && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}