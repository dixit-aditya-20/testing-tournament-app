// models/tournament_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Tournament {
  final String id;
  final String gameName;
  final String tournamentName;
  final double entryFee;
  final int totalSlots;
  final int registeredPlayers;
  final DateTime registrationEnd;
  final DateTime tournamentStart;
  final String imageUrl;
  final String tournamentId;
  final String status;
  final String tournamentType;
  final double prizePool;
  final String platform;
  final String region;

  Tournament({
    required this.id,
    required this.gameName,
    required this.tournamentName,
    required this.entryFee,
    required this.totalSlots,
    required this.registeredPlayers,
    required this.registrationEnd,
    required this.tournamentStart,
    required this.imageUrl,
    required this.tournamentId,
    required this.status,
    required this.tournamentType,
    required this.prizePool,
    required this.platform,
    required this.region,
  });

  // Helper method to check if registration is still open
  bool get isRegistrationOpen =>
      registrationEnd.isAfter(DateTime.now()) &&
          status == 'upcoming' &&
          !isFull;

  // Helper method to get available slots
  int get availableSlots => totalSlots - registeredPlayers;

  // Helper method to check if tournament is full
  bool get isFull => availableSlots <= 0;

  // Add this getter - it's the same as availableSlots but named slotsLeft
  int get slotsLeft => totalSlots - registeredPlayers;

  // Check if tournament is starting soon (within 1 hour)
  bool get isStartingSoon =>
      tournamentStart.difference(DateTime.now()).inMinutes <= 60;

  // Get time until registration ends
  Duration get timeUntilRegistrationEnds => registrationEnd.difference(DateTime.now());

  factory Tournament.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final basicInfo = data['basicInfo'] ?? {};
    final schedule = data['schedule'] ?? {};

    return Tournament(
      id: doc.id,
      gameName: basicInfo['gameName'] ?? '',
      tournamentName: basicInfo['tournamentName'] ?? '',
      entryFee: (basicInfo['entryFee'] ?? 0).toDouble(),
      totalSlots: basicInfo['maxPlayers'] ?? 0,
      registeredPlayers: basicInfo['registeredPlayers'] ?? 0,
      registrationEnd: (schedule['registrationEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tournamentStart: (schedule['tournamentStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'] ?? '',
      tournamentId: basicInfo['tournamentId'] ?? doc.id,
      status: basicInfo['status'] ?? 'upcoming',
      tournamentType: basicInfo['tournamentType'] ?? 'solo',
      prizePool: (basicInfo['prizePool'] ?? 0).toDouble(),
      platform: basicInfo['platform'] ?? 'mobile',
      region: basicInfo['region'] ?? 'global',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gameName': gameName,
      'tournamentName': tournamentName,
      'entryFee': entryFee,
      'totalSlots': totalSlots,
      'registeredPlayers': registeredPlayers,
      'registrationEnd': registrationEnd.millisecondsSinceEpoch,
      'tournamentStart': tournamentStart.millisecondsSinceEpoch,
      'imageUrl': imageUrl,
      'tournamentId': tournamentId,
      'status': status,
      'tournamentType': tournamentType,
      'prizePool': prizePool,
      'platform': platform,
      'region': region,
    };
  }

  factory Tournament.fromMap(Map<String, dynamic> map) {
    return Tournament(
      id: map['id'],
      gameName: map['gameName'],
      tournamentName: map['tournamentName'],
      entryFee: map['entryFee'].toDouble(),
      totalSlots: map['totalSlots'],
      registeredPlayers: map['registeredPlayers'],
      registrationEnd: DateTime.fromMillisecondsSinceEpoch(map['registrationEnd']),
      tournamentStart: DateTime.fromMillisecondsSinceEpoch(map['tournamentStart']),
      tournamentId: map['tournamentId'],
      imageUrl: map['imageUrl'] ?? '',
      status: map['status'] ?? 'upcoming',
      tournamentType: map['tournamentType'] ?? 'solo',
      prizePool: map['prizePool']?.toDouble() ?? 0.0,
      platform: map['platform'] ?? 'mobile',
      region: map['region'] ?? 'global',
    );
  }
}