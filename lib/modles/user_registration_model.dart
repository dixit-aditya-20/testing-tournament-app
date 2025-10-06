class UserRegistration {
  final String id;
  final String userId;
  final String tournamentId;
  final String gameName;
  final String playerName;
  final String playerId;
  final double entryFee;
  final DateTime registrationDate;
  final bool paymentCompleted;

  UserRegistration({
    required this.id,
    required this.userId,
    required this.tournamentId,
    required this.gameName,
    required this.playerName,
    required this.playerId,
    required this.entryFee,
    required this.registrationDate,
    required this.paymentCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'tournamentId': tournamentId,
      'gameName': gameName,
      'playerName': playerName,
      'playerId': playerId,
      'entryFee': entryFee,
      'registrationDate': registrationDate.millisecondsSinceEpoch,
      'paymentCompleted': paymentCompleted,
    };
  }

  factory UserRegistration.fromMap(Map<String, dynamic> map) {
    return UserRegistration(
      id: map['id'],
      userId: map['userId'],
      tournamentId: map['tournamentId'],
      gameName: map['gameName'],
      playerName: map['playerName'],
      playerId: map['playerId'],
      entryFee: map['entryFee'].toDouble(),
      registrationDate: DateTime.fromMillisecondsSinceEpoch(map['registrationDate']),
      paymentCompleted: map['paymentCompleted'],
    );
  }
}