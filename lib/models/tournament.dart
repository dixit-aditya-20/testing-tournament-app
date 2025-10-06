class Tournament {
  final String gameName;
  final DateTime startTime;
  String? roomId;
  String? roomPassword;

  Tournament({required this.gameName, required this.startTime, this.roomId, this.roomPassword});
}
