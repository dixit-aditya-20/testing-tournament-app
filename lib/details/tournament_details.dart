// screens/tournament_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../modles/tournament_model.dart';

class TournamentDetailsScreen extends StatefulWidget {
  final Tournament tournament;
  final String playerName;
  final String playerId;

  const TournamentDetailsScreen({
    Key? key,
    required this.tournament,
    required this.playerName,
    required this.playerId,
  }) : super(key: key);

  @override
  _TournamentDetailsScreenState createState() => _TournamentDetailsScreenState();
}

class _TournamentDetailsScreenState extends State<TournamentDetailsScreen> {
  Map<String, dynamic>? _matchCredentials;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMatchCredentials();
  }

  Future<void> _loadMatchCredentials() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Check if match credentials are available
      final query = await FirebaseFirestore.instance
          .collection('match_credentials')
          .where('tournamentId', isEqualTo: widget.tournament.id)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        setState(() {
          _matchCredentials = query.docs.first.data();
        });
      }
    } catch (e) {
      print('Error loading match credentials: $e');
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
        title: Text('Tournament Details'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tournament Header
            _buildTournamentHeader(),

            SizedBox(height: 24),

            // Player Details Card
            _buildPlayerDetailsCard(),

            SizedBox(height: 24),

            // Match Credentials Section
            _buildMatchCredentialsSection(),

            SizedBox(height: 24),

            // Tournament Info Card
            _buildTournamentInfoCard(),

            SizedBox(height: 24),

            // Countdown Timer
            _buildCountdownTimer(),

            SizedBox(height: 24),

            // Rules and Guidelines
            _buildRulesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentHeader() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              widget.tournament.tournamentName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              widget.tournament.gameName,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Registered Successfully',
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerDetailsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Registration Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, color: Colors.deepPurple),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Player Name', style: TextStyle(color: Colors.grey)),
                      Text(widget.playerName, style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.videogame_asset, color: Colors.deepPurple),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Game ID', style: TextStyle(color: Colors.grey)),
                      Text(widget.playerId, style: TextStyle(fontSize: 16)),
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

  Widget _buildMatchCredentialsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Match Room Credentials',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            if (_matchCredentials == null) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  children: [
                    Icon(Icons.schedule, size: 40, color: Colors.orange),
                    SizedBox(height: 8),
                    Text(
                      'Room ID and Password will be available 30 minutes before the match starts',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please check back later',
                      style: TextStyle(color: Colors.orange[600]),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Room ID
              _buildCredentialField(
                'Room ID',
                _matchCredentials!['roomId'] ?? 'Not Available',
                Icons.meeting_room,
              ),
              SizedBox(height: 12),

              // Room Password
              _buildCredentialField(
                'Room Password',
                _matchCredentials!['roomPassword'] ?? 'Not Available',
                Icons.password,
              ),

              SizedBox(height: 16),

              // Copy Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _copyToClipboard(_matchCredentials!['roomId']?.toString() ?? ''),
                      icon: Icon(Icons.content_copy),
                      label: Text('Copy Room ID'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _copyToClipboard(_matchCredentials!['roomPassword']?.toString() ?? ''),
                      icon: Icon(Icons.content_copy),
                      label: Text('Copy Password'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 8),
              Text(
                'Match will start at: ${_formatTime(_matchCredentials!['matchTime'])}',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialField(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tournament Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            _buildInfoRow('Entry Fee', '₹${widget.tournament.entryFee}'),
            _buildInfoRow('Total Slots', '${widget.tournament.totalSlots}'),
            _buildInfoRow('Registered Players', '${widget.tournament.registeredPlayers}'),
            _buildInfoRow('Slots Left', '${widget.tournament.totalSlots - widget.tournament.registeredPlayers}'),
            _buildInfoRow('Registration Ends', _formatDate(widget.tournament.registrationEnd.toDate())), // Fixed: .toDate()
            _buildInfoRow('Tournament Starts', _formatDate(widget.tournament.tournamentStart.toDate())), // Fixed: .toDate()
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCountdownTimer() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Tournament Starts In',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: StreamBuilder<DateTime>(
                stream: Stream.periodic(Duration(seconds: 1), (i) => DateTime.now()),
                builder: (context, snapshot) {
                  final now = DateTime.now();
                  final tournamentStart = widget.tournament.tournamentStart.toDate(); // Fixed: .toDate()
                  final difference = tournamentStart.difference(now);

                  if (difference.isNegative) {
                    return Column(
                      children: [
                        Icon(Icons.play_arrow, size: 40, color: Colors.green),
                        SizedBox(height: 8),
                        Text(
                          'Tournament Started!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTimeUnit(difference.inDays, 'Days'),
                      _buildTimeUnit(difference.inHours.remainder(24), 'Hours'),
                      _buildTimeUnit(difference.inMinutes.remainder(60), 'Minutes'),
                      _buildTimeUnit(difference.inSeconds.remainder(60), 'Seconds'),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeUnit(int value, String label) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRulesSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Important Rules & Guidelines',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            _buildRuleItem('Join the match room 15 minutes before start time'),
            _buildRuleItem('Have stable internet connection during the match'),
            _buildRuleItem('No cheating or use of third-party apps'),
            _buildRuleItem('Respect other players and follow fair play'),
            _buildRuleItem('Screenshots of results might be required'),
            _buildRuleItem('Contact support if you face any issues'),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_forward_ios, size: 12, color: Colors.deepPurple),
          SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    // You'll need to add clipboard functionality
    // For now, show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard: $text'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (timestamp is DateTime) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
    return 'Not set';
  }
}