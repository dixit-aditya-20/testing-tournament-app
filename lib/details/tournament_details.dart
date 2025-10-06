import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TournamentScreen extends StatelessWidget {
  final String gameName;
  final String gameImage;

  TournamentScreen({required this.gameName, required this.gameImage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$gameName Tournaments"),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .doc(gameName) // <- Important: use gameName here
            .collection('tournaments')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No tournaments available",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            );
          }

          final tournaments = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tournaments.length,
            itemBuilder: (context, index) {
              final data = tournaments[index].data() as Map<String, dynamic>;
              return TournamentCard(
                matchName: tournaments[index].id,
                entryFee: data['entry fee'] ?? 0,
                playersJoined: data['players Joined'] ?? 0,
                playersLeft: data['players Left'] ?? 0,
                startTime: data['starting time'] ?? "",
                type: data['type'] ?? "",
              );
            },
          );
        },
      ),
    );
  }
}

class TournamentCard extends StatelessWidget {
  final String matchName;
  final int entryFee;
  final int playersJoined;
  final int playersLeft;
  final String startTime;
  final String type;

  TournamentCard({
    required this.matchName,
    required this.entryFee,
    required this.playersJoined,
    required this.playersLeft,
    required this.startTime,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(matchName,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Type: $type"),
            Text("Entry Fee: ₹$entryFee"),
            Text("Players Joined: $playersJoined"),
            Text("Players Left: $playersLeft"),
            Text("Start Time: $startTime"),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // Handle register / play button
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: Text("Register"),
            ),
          ],
        ),
      ),
    );
  }
}
