// ===============================
// RECENT MATCHES SCREEN
// ===============================
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final matches = await _firebaseService.getRecentMatches();
      setState(() {
        _matches = matches;
      });
    } catch (e) {
      print('❌ Error loading matches: $e');
      setState(() {
        _errorMessage = 'Failed to load matches: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recent Matches'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadMatches,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingIndicator()
          : _errorMessage.isNotEmpty
          ? _buildErrorWidget()
          : _matches.isEmpty
          ? _buildEmptyState()
          : _buildMatchesList(),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading your matches...'),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Error Loading Matches',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadMatches,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_esports, size: 80, color: Colors.grey[400]),
          SizedBox(height: 20),
          Text(
            'No matches played yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Join tournaments to see your match history here',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Go back to previous screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            child: Text('Browse Tournaments'),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesList() {
    final wonMatches = _matches.where((match) => _isWonMatch(match)).length;
    final winRate = _matches.isNotEmpty ? (wonMatches / _matches.length * 100) : 0;

    return Column(
      children: [
        // Summary card
        Padding(
          padding: EdgeInsets.all(16),
          child: Card(
            color: Colors.deepPurple[50],
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Total', _matches.length.toString()),
                  _buildSummaryItem('Won', wonMatches.toString()),
                  _buildSummaryItem('Win Rate', '${winRate.toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ),
        ),

        // Matches list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadMatches,
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _matches.length,
              itemBuilder: (context, index) {
                final match = _matches[index];
                return _buildMatchCard(match);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final tournamentName = match['tournament_name'] as String? ?? 'Unknown Tournament';
    final gameName = match['game_name'] as String? ?? 'Unknown Game';
    final position = match['position'] as int? ?? 0;
    final kills = match['kills'] as int? ?? 0;
    final winnings = (match['winnings'] as num?)?.toDouble() ?? 0.0;
    final timestamp = match['timestamp'] as Timestamp?;
    final isWon = _isWonMatch(match);

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with tournament name and result badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tournamentName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isWon ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isWon ? 'WON' : 'PLAYED',
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

            // Game name
            Text(
              'Game: $gameName',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),

            SizedBox(height: 12),

            // Match stats
            Row(
              children: [
                _buildMatchStat('Kills', kills.toString()),
                _buildMatchStat('Position', '#$position'),
                _buildMatchStat('Prize', '₹${winnings.toStringAsFixed(2)}'),
              ],
            ),

            SizedBox(height: 8),

            // Footer with date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatMatchDate(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                if (isWon)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.emoji_events, size: 12, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'Won ₹${winnings.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
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
          SizedBox(height: 2),
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

  bool _isWonMatch(Map<String, dynamic> match) {
    final position = match['position'] as int? ?? 0;
    final winnings = (match['winnings'] as num?)?.toDouble() ?? 0.0;

    // Consider it a win if position is 1-3 or winnings > 0
    return position <= 3 || winnings > 0;
  }

  String _formatMatchDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Recently';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }
}