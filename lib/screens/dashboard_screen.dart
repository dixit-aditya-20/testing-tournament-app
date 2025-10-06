// ===============================
// DASHBOARD SCREEN
// ===============================
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _topPlayers = [];

  @override
  void initState() {
    super.initState();
    _loadTopPlayers();
  }

  Future<void> _loadTopPlayers() async {
    final players = await _firebaseService.getTopPlayers();
    setState(() {
      _topPlayers = players;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Players',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          if (_topPlayers.isEmpty)
            Container(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No players data available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Container(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _topPlayers.length,
                itemBuilder: (context, index) {
                  final player = _topPlayers[index];
                  return _buildPlayerCard(player, index + 1);
                },
              ),
            ),
          SizedBox(height: 20),
          Text(
            'Player Statistics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          _buildStatsGrid(),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic> player, int rank) {
    return Container(
      width: 150,
      margin: EdgeInsets.only(right: 12),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: Colors.deepPurple,
                child: Text(
                  rank.toString(),
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 8),
              Text(
                player['name'] ?? 'Player',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                'Won: ${player['matchesWon'] ?? 0}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                '₹${player['totalWinnings']?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildStatCard('Total Matches', '15', Icons.sports_esports),
        _buildStatCard('Matches Won', '8', Icons.emoji_events),
        _buildStatCard('Total Winnings', '₹2,500', Icons.attach_money),
        _buildStatCard('Win Rate', '53%', Icons.trending_up),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.deepPurple),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}