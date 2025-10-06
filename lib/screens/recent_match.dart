// ===============================
// RECENT MATCHES SCREEN
// ===============================
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class RecentMatchesScreen extends StatefulWidget {
  @override
  _RecentMatchesScreenState createState() => _RecentMatchesScreenState();
}

class _RecentMatchesScreenState extends State<RecentMatchesScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _matches = [];

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    final matches = await _firebaseService.getUserMatches();
    setState(() {
      _matches = matches;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _matches.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_esports, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'No matches played yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              'Join tournaments to see your match history here',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _matches.length,
        itemBuilder: (context, index) {
          final match = _matches[index];
          return _buildMatchCard(match);
        },
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  match['tournamentName'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: match['result'] == 'Won' ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    match['result'],
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Game: ${match['gameName']}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                _buildMatchStat('Kills', match['kills'].toString()),
                _buildMatchStat('Position', '#${match['position']}'),
                _buildMatchStat('Prize', '₹${match['prize']}'),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Played on: ${match['date']}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}