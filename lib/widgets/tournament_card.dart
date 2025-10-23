import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../modles/tournament_model.dart';
import 'countdown_timer.dart';

class TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final VoidCallback onJoinPressed;
  final VoidCallback? onCredentialsTap;

  const TournamentCard({
    Key? key,
    required this.tournament,
    required this.onJoinPressed,
    this.onCredentialsTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tournament Name and Entry Fee
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tournament.tournamentName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Text(
                    '₹${tournament.entryFee}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Match Credentials Section - FIXED
            if (tournament.hasCredentials || tournament.credentialsComingSoon)
              _buildCredentialsSection(context),

            if (tournament.hasCredentials || tournament.credentialsComingSoon)
              SizedBox(height: 12),

            // Prize Information
            _buildInfoItem(
              icon: Icons.emoji_events,
              color: Colors.amber,
              text: 'Prize: ₹${tournament.winningPrize}',
            ),
            SizedBox(height: 8),

            // Players and Slots
            Row(
              children: [
                _buildInfoItem(
                  icon: Icons.people,
                  color: Colors.blue,
                  text: '${tournament.registeredPlayers}/${tournament.totalSlots} Players',
                ),
                SizedBox(width: 16),
                _buildInfoItem(
                  icon: Icons.event_seat,
                  color: Colors.orange,
                  text: '${tournament.slotsLeft} Slots Left',
                ),
              ],
            ),
            SizedBox(height: 12),

            // Tournament Type and Map
            Row(
              children: [
                _buildInfoItem(
                  icon: Icons.games,
                  color: Colors.purple,
                  text: tournament.tournamentType,
                ),
                SizedBox(width: 16),
                _buildInfoItem(
                  icon: Icons.map,
                  color: Colors.green,
                  text: tournament.map,
                ),
              ],
            ),
            SizedBox(height: 12),

            // Registration Timer
            _buildTimerSection(
              icon: Icons.timer,
              color: Colors.red,
              label: 'Registration ends in:',
              targetDate: tournament.registrationEnd.toDate(),
            ),
            SizedBox(height: 8),

            // Tournament Start Timer
            _buildTimerSection(
              icon: Icons.calendar_today,
              color: Colors.purple,
              label: 'Tournament starts in:',
              targetDate: tournament.tournamentStart.toDate(),
            ),
            SizedBox(height: 16),

            // Status Badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(tournament.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tournament.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 12),

            // Join Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: tournament.isRegistrationOpen ? onJoinPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  tournament.isRegistrationOpen ? 'JOIN NOW' : 'REGISTRATION CLOSED',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIXED: Build credentials section
  Widget _buildCredentialsSection(BuildContext context) {
    final shouldShowCredentials = tournament.shouldShowCredentials;
    final credentialsComingSoon = tournament.credentialsComingSoon;

    return GestureDetector(
      onTap: shouldShowCredentials ? (onCredentialsTap ?? () {
        _showCredentialsDialog(context);
      }) : null,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: shouldShowCredentials ? Colors.indigo[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: shouldShowCredentials ? Colors.indigo : Colors.grey,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  shouldShowCredentials ? Icons.lock_open : Icons.lock_clock,
                  color: shouldShowCredentials ? Colors.indigo : Colors.grey,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  shouldShowCredentials
                      ? 'Match Credentials Available'
                      : 'Credentials Coming Soon',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: shouldShowCredentials ? Colors.indigo : Colors.grey,
                  ),
                ),
                if (shouldShowCredentials) ...[
                  SizedBox(width: 8),
                  Icon(Icons.visibility, color: Colors.indigo, size: 16),
                ],
              ],
            ),
            SizedBox(height: 8),
            if (shouldShowCredentials)
              _buildAvailableCredentialsContent()
            else
              _buildComingSoonCredentialsContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableCredentialsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Room ID and password are ready. Tap to view match details.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.indigo[700],
          ),
        ),
        SizedBox(height: 4),
        if (tournament.credentialsMatchTime != null)
          Text(
            'Match Time: ${_formatMatchTime(tournament.credentialsMatchTime!)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.indigo[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        // Show when credentials were added (if available)
        if (tournament.credentialsAddedAt != null)
          Text(
            'Updated: ${_formatTimeAgo(tournament.credentialsAddedAt!.toDate())}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.indigo[500],
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildComingSoonCredentialsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Match room credentials will be available 30 minutes before the match starts.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 4),
        if (tournament.credentialsAvailabilityTime.isNotEmpty)
          Text(
            'Available at: ${tournament.credentialsAvailabilityTime}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        SizedBox(height: 4),
        if (tournament.credentialsMatchTime != null)
          Text(
            'Match starts at: ${_formatMatchTime(tournament.credentialsMatchTime!)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        // Countdown timer for credentials availability
        _buildCredentialsCountdown(),
      ],
    );
  }

  Widget _buildCredentialsCountdown() {
    return StreamBuilder(
      stream: Stream.periodic(Duration(seconds: 1)),
      builder: (context, snapshot) {
        final timeLeft = tournament.timeUntilCredentialsAvailable;

        if (timeLeft.isNegative) {
          return SizedBox.shrink();
        }

        return Container(
          margin: EdgeInsets.only(top: 4),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.orange),
          ),
          child: Text(
            'Credentials in: ${_formatDuration(timeLeft)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.orange[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  // FIXED: Show appropriate dialog based on availability
  void _showCredentialsDialog(BuildContext context) {
    if (!tournament.shouldShowCredentials) {
      _showComingSoonDialog(context);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_open, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Match Credentials'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tournament.tournamentName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              SizedBox(height: 16),
              _buildCredentialDetailItem('Room ID', tournament.roomId ?? 'Not available'),
              SizedBox(height: 12),
              _buildCredentialDetailItem('Room Password', tournament.roomPassword ?? 'Not available'),
              SizedBox(height: 12),
              if (tournament.credentialsMatchTime != null)
                _buildCredentialDetailItem(
                    'Match Time',
                    _formatMatchTime(tournament.credentialsMatchTime!)
                ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Important:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Please join the room 15 minutes before match time\n• Keep your credentials secure\n• Do not share with others',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE'),
          ),
          ElevatedButton(
            onPressed: () {
              _copyCredentialsToClipboard(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
            ),
            child: Text('COPY DETAILS'),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Credentials Coming Soon'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match room credentials will be available:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Column(
                children: [
                  Text(
                    '30 minutes before match starts',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  if (tournament.credentialsAvailabilityTime.isNotEmpty)
                    Text(
                      'Available at: ${tournament.credentialsAvailabilityTime}',
                      style: TextStyle(
                        color: Colors.blue[800],
                      ),
                    ),
                  if (tournament.credentialsMatchTime != null)
                    Text(
                      'Match starts at: ${_formatMatchTime(tournament.credentialsMatchTime!)}',
                      style: TextStyle(
                        color: Colors.blue[800],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Please check back later to get your room ID and password.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.indigo[800],
            ),
          ),
        ),
      ],
    );
  }

  void _copyCredentialsToClipboard(BuildContext context) {
    final credentials = '''
Tournament: ${tournament.tournamentName}
Room ID: ${tournament.roomId}
Password: ${tournament.roomPassword}
Match Time: ${tournament.credentialsMatchTime != null ? _formatMatchTime(tournament.credentialsMatchTime!) : 'Not specified'}
''';

    // You can use clipboard package here
    // Clipboard.setData(ClipboardData(text: credentials));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Credentials copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatMatchTime(Timestamp matchTime) {
    final date = matchTime.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildTimerSection({
    required IconData icon,
    required Color color,
    required String label,
    required DateTime targetDate,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(width: 6),
        CountdownTimer(
          targetDate: targetDate,
          textStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
        return Colors.blue;
      case 'live':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}