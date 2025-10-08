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
      final matches = await _firebaseService.getUserMatches();
      setState(() {
        _matches = matches;
      });
    } catch (e) {
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
          Icon(Icons.sports_esports, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'No matches played yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Join tournaments to see your match history here',
              style: TextStyle(color: Colors.grey),
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
    return Column(
      children: [
        // Summary card
        Padding(
          padding: EdgeInsets.all(16),
          child: Card(
            color: Colors.deepPurple[50],
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Total', _matches.length.toString()),
                  _buildSummaryItem('Won', _matches.where((m) => m['result'] == 'Won').length.toString()),
                  _buildSummaryItem('Win Rate', '${(_matches.where((m) => m['result'] == 'Won').length / _matches.length * 100).toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ),
        ),

        // Matches list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _matches.length,
            itemBuilder: (context, index) {
              final match = _matches[index];
              return _buildMatchCard(match);
            },
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
                Expanded(
                  child: Text(
                    match['tournamentName'] ?? 'Unknown Tournament',
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
                    color: match['result'] == 'Won'
                        ? Colors.green
                        : match['result'] == 'Played'
                        ? Colors.orange
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    match['result']?.toString().toUpperCase() ?? 'PLAYED',
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
              'Game: ${match['gameName'] ?? 'Unknown Game'}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildMatchStat('Kills', match['kills']?.toString() ?? '0'),
                _buildMatchStat('Position', '#${match['position']?.toString() ?? 'N/A'}'),
                _buildMatchStat('Prize', '₹${(match['winnings'] ?? 0.0).toStringAsFixed(2)}'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Played on: ${match['date'] ?? 'Recently'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                if (match['entryFee'] != null && match['entryFee'] > 0)
                  Text(
                    'Entry: ₹${match['entryFee']?.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
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