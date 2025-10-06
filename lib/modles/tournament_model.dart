// models/tournament_model.dart
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
  });

  // Helper method to check if registration is still open
  bool get isRegistrationOpen => registrationEnd.isAfter(DateTime.now());

  // Helper method to get available slots
  int get availableSlots => totalSlots - registeredPlayers;

  // Helper method to check if tournament is full
  bool get isFull => availableSlots <= 0;

  // Add this getter - it's the same as availableSlots but named slotsLeft
  int get slotsLeft => totalSlots - registeredPlayers;


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
      imageUrl: map['imageUrl'],
      tournamentId: map['tournamentId'],
    );
  }
}