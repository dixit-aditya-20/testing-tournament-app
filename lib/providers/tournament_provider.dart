import 'package:flutter/material.dart';
import '../models/tournament.dart';

class TournamentProvider extends ChangeNotifier {
  List<Tournament> tournaments = [];

  void addTournament(Tournament tournament) {
    tournaments.add(tournament);
    notifyListeners();
  }

  void updateRoom(String gameName, String roomId, String roomPassword) {
    for (var t in tournaments) {
      if (t.gameName == gameName) {
        t.roomId = roomId;
        t.roomPassword = roomPassword;
        notifyListeners();
        break;
      }
    }
  }
}
