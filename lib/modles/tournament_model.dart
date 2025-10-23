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

  // Match credentials fields - UPDATED
  final String? roomId;
  final String? roomPassword;
  final Timestamp? credentialsMatchTime;
  final Timestamp? credentialsAddedAt; // NEW FIELD
  final bool hasCredentials;

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
    this.credentialsAddedAt, // NEW FIELD
    this.hasCredentials = false,
  });

  bool get isRegistrationOpen {
    final now = DateTime.now();
    final registrationEndTime = registrationEnd.toDate();
    return now.isBefore(registrationEndTime);
  }

  // Credentials availability logic - UPDATED
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
      tournamentType: data['tournament_type'] ?? '',
      matchTime: data['match_time'] ?? '',
      map: data['map'] ?? '',
      mode: data['mode'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? 'upcoming',
      registrationStart: data['registration_start'] ?? Timestamp.now(),
      registrationEnd: data['registration_end'] ?? Timestamp.now(),
      tournamentStart: data['tournament_start'] ?? Timestamp.now(),
      // Add credentials fields
      roomId: data['roomId'],
      roomPassword: data['roomPassword'],
      credentialsMatchTime: data['credentialsMatchTime'] ?? data['tournament_start'],
      credentialsAddedAt: data['credentialsAddedAt'], // NEW FIELD
      hasCredentials: hasCredentials,
    );
  }

  // ADD THIS FACTORY METHOD FOR FIRESTORE
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
      // Include credentials in toMap if needed
      'roomId': roomId,
      'roomPassword': roomPassword,
      'credentialsMatchTime': credentialsMatchTime,
      'credentialsAddedAt': credentialsAddedAt, // NEW FIELD
      'hasCredentials': hasCredentials,
    };
  }

  @override
  String toString() {
    return 'Tournament{id: $id, tournamentName: $tournamentName, gameName: $gameName, entryFee: $entryFee, status: $status, hasCredentials: $hasCredentials, shouldShowCredentials: $shouldShowCredentials}';
  }
}