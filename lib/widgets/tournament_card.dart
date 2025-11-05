import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../modles/tournament_model.dart';
import 'countdown_timer.dart';

class TournamentCard extends StatefulWidget {
  final Tournament tournament;
  final VoidCallback onJoinPressed;
  final VoidCallback? onCredentialsTap;
  final bool isUserRegistered;

  const TournamentCard({
    Key? key,
    required this.tournament,
    required this.onJoinPressed,
    this.onCredentialsTap,
    required this.isUserRegistered,
  }) : super(key: key);

  @override
  State<TournamentCard> createState() => _TournamentCardState();
}

class _TournamentCardState extends State<TournamentCard> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(
        vertical: 8,
        horizontal: isSmallScreen ? 8 : 16,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tournament Name and Entry Fee
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.tournament.tournamentName,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 12,
                    vertical: isSmallScreen ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Text(
                    '₹${widget.tournament.entryFee}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),

            // User Registration Status Badge
            if (widget.isUserRegistered)
              _buildRegistrationStatusBadge(isSmallScreen),

            if (widget.isUserRegistered)
              SizedBox(height: isSmallScreen ? 8 : 12),

            // Match Credentials Section
            if (widget.isUserRegistered && (widget.tournament.hasCredentials || widget.tournament.credentialsComingSoon))
              _buildCredentialsSection(context, isSmallScreen),

            if (widget.isUserRegistered && (widget.tournament.hasCredentials || widget.tournament.credentialsComingSoon))
              SizedBox(height: isSmallScreen ? 8 : 12),

            // Prize Information
            _buildInfoItem(
              icon: Icons.emoji_events,
              color: Colors.amber,
              text: 'Prize: ₹${widget.tournament.winningPrize}',
              isSmallScreen: isSmallScreen,
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),

            // Prize Distribution Preview
            if (widget.tournament.hasPrizeDistribution && widget.tournament.prizePositionsCount > 0)
              _buildPrizePreview(isSmallScreen),
            if (widget.tournament.hasPrizeDistribution && widget.tournament.prizePositionsCount > 0)
              SizedBox(height: isSmallScreen ? 6 : 8),

            // Players and Slots
            _buildPlayersAndSlotsSection(isSmallScreen),
            SizedBox(height: isSmallScreen ? 8 : 12),

            // Tournament Type and Map
            _buildTypeAndMapSection(isSmallScreen),
            SizedBox(height: isSmallScreen ? 8 : 12),

            // Registration Timer
            _buildTimerSection(
              icon: Icons.timer,
              color: Colors.red,
              label: 'Registration ends:',
              targetDate: widget.tournament.registrationEnd.toDate(),
              isSmallScreen: isSmallScreen,
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),

            // Tournament Start Timer
            _buildTimerSection(
              icon: Icons.calendar_today,
              color: Colors.purple,
              label: 'Tournament starts:',
              targetDate: widget.tournament.tournamentStart.toDate(),
              isSmallScreen: isSmallScreen,
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),

            // Status Badge
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 8 : 12,
                vertical: isSmallScreen ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: _getStatusColor(widget.tournament.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.tournament.status.toUpperCase(),
                style: TextStyle(
                  fontSize: isSmallScreen ? 10 : 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),

            // Action Button
            _buildActionButton(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationStatusBadge(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 12,
        vertical: isSmallScreen ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: isSmallScreen ? 14 : 16),
          SizedBox(width: 4),
          Text(
            'Registered',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizePreview(bool isSmallScreen) {
    final topThree = widget.tournament.topThreePrizes;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration, color: Colors.amber[700], size: isSmallScreen ? 14 : 16),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prize Distribution',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _getPrizePreviewText(topThree),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 12,
                    color: Colors.amber[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPrizePreviewText(Map<String, double> topThree) {
    if (topThree.isEmpty) return 'No prizes set';

    final entries = topThree.entries.toList();
    entries.sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

    return entries.map((entry) {
      final position = entry.key;
      final prize = entry.value;

      switch (position) {
        case '1': return '1st: ₹${prize.toStringAsFixed(0)}';
        case '2': return '2nd: ₹${prize.toStringAsFixed(0)}';
        case '3': return '3rd: ₹${prize.toStringAsFixed(0)}';
        default: return '${position}th: ₹${prize.toStringAsFixed(0)}';
      }
    }).join(' • ');
  }

  Widget _buildCredentialsSection(BuildContext context, bool isSmallScreen) {
    final shouldShowCredentials = widget.tournament.shouldShowCredentials;
    final credentialsComingSoon = widget.tournament.credentialsComingSoon;

    return GestureDetector(
      onTap: shouldShowCredentials ? (widget.onCredentialsTap ?? () {
        _showCredentialsDialog(context);
      }) : null,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
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
                  size: isSmallScreen ? 18 : 20,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    shouldShowCredentials
                        ? 'Match Credentials Available'
                        : 'Credentials Coming Soon',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: shouldShowCredentials ? Colors.indigo : Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (shouldShowCredentials) ...[
                  SizedBox(width: 6),
                  Icon(Icons.visibility, color: Colors.indigo, size: isSmallScreen ? 14 : 16),
                ],
              ],
            ),
            SizedBox(height: 6),
            if (shouldShowCredentials)
              _buildAvailableCredentialsContent(isSmallScreen)
            else
              _buildComingSoonCredentialsContent(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isSmallScreen) {
    if (widget.isUserRegistered) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: widget.onCredentialsTap ?? () {
            _showTournamentDetailsDialog(context);
          },
          icon: Icon(
            widget.tournament.shouldShowCredentials ? Icons.lock_open_rounded : Icons.visibility_rounded,
            size: isSmallScreen ? 16 : 18,
          ),
          label: Text(
            widget.tournament.shouldShowCredentials ? 'VIEW CREDENTIALS' : 'VIEW DETAILS',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.tournament.shouldShowCredentials ? Colors.green : Colors.blue,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: widget.tournament.isRegistrationOpen ? widget.onJoinPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            widget.tournament.isRegistrationOpen ? 'JOIN NOW' : 'REGISTRATION CLOSED',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildAvailableCredentialsContent(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Room ID and password are ready. Tap to view match details.',
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            color: Colors.indigo[700],
          ),
        ),
        SizedBox(height: 4),
        if (widget.tournament.credentialsMatchTime != null)
          Text(
            'Match Time: ${_formatMatchTime(widget.tournament.credentialsMatchTime!)}',
            style: TextStyle(
              fontSize: isSmallScreen ? 10 : 12,
              color: Colors.indigo[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        if (widget.tournament.credentialsAddedAt != null)
          Text(
            'Updated: ${_formatTimeAgo(widget.tournament.credentialsAddedAt!.toDate())}',
            style: TextStyle(
              fontSize: isSmallScreen ? 9 : 10,
              color: Colors.indigo[500],
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildComingSoonCredentialsContent(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Match room credentials will be available 30 minutes before the match starts.',
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 4),
        if (widget.tournament.credentialsAvailabilityTime.isNotEmpty)
          Text(
            'Available at: ${widget.tournament.credentialsAvailabilityTime}',
            style: TextStyle(
              fontSize: isSmallScreen ? 10 : 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        SizedBox(height: 4),
        if (widget.tournament.credentialsMatchTime != null)
          Text(
            'Match starts at: ${_formatMatchTime(widget.tournament.credentialsMatchTime!)}',
            style: TextStyle(
              fontSize: isSmallScreen ? 10 : 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        _buildCredentialsCountdown(isSmallScreen),
      ],
    );
  }

  Widget _buildCredentialsCountdown(bool isSmallScreen) {
    return StreamBuilder(
      stream: Stream.periodic(Duration(seconds: 1)),
      builder: (context, snapshot) {
        final timeLeft = widget.tournament.timeUntilCredentialsAvailable;

        if (timeLeft.isNegative) {
          return SizedBox.shrink();
        }

        return Container(
          margin: EdgeInsets.only(top: 4),
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.orange),
          ),
          child: Text(
            'Credentials in: ${_formatDuration(timeLeft)}',
            style: TextStyle(
              fontSize: isSmallScreen ? 9 : 10,
              color: Colors.orange[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayersAndSlotsSection(bool isSmallScreen) {
    if (isSmallScreen) {
      return Column(
        children: [
          _buildInfoItem(
            icon: Icons.people,
            color: Colors.blue,
            text: '${widget.tournament.registeredPlayers}/${widget.tournament.totalSlots} Players',
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(height: 6),
          _buildInfoItem(
            icon: Icons.event_seat,
            color: Colors.orange,
            text: '${widget.tournament.slotsLeft} Slots Left',
            isSmallScreen: isSmallScreen,
          ),
        ],
      );
    } else {
      return Row(
        children: [
          _buildInfoItem(
            icon: Icons.people,
            color: Colors.blue,
            text: '${widget.tournament.registeredPlayers}/${widget.tournament.totalSlots} Players',
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(width: 16),
          _buildInfoItem(
            icon: Icons.event_seat,
            color: Colors.orange,
            text: '${widget.tournament.slotsLeft} Slots Left',
            isSmallScreen: isSmallScreen,
          ),
        ],
      );
    }
  }

  Widget _buildTypeAndMapSection(bool isSmallScreen) {
    if (isSmallScreen) {
      return Column(
        children: [
          _buildInfoItem(
            icon: Icons.games,
            color: Colors.purple,
            text: widget.tournament.tournamentType,
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(height: 6),
          _buildInfoItem(
            icon: Icons.map,
            color: Colors.green,
            text: widget.tournament.map,
            isSmallScreen: isSmallScreen,
          ),
        ],
      );
    } else {
      return Row(
        children: [
          _buildInfoItem(
            icon: Icons.games,
            color: Colors.purple,
            text: widget.tournament.tournamentType,
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(width: 16),
          _buildInfoItem(
            icon: Icons.map,
            color: Colors.green,
            text: widget.tournament.map,
            isSmallScreen: isSmallScreen,
          ),
        ],
      );
    }
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color color,
    required String text,
    required bool isSmallScreen,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: isSmallScreen ? 16 : 18),
        SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
    required bool isSmallScreen,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: isSmallScreen ? 16 : 18),
        SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 2),
              CountdownTimer(
                targetDate: targetDate,
                textStyle: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
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

  // FIXED: Show tournament details with prize distribution
  void _showTournamentDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Tournament Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.tournament.tournamentName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              SizedBox(height: 16),
              _buildDetailItem('Status', widget.tournament.status.toUpperCase(), Icons.info),
              SizedBox(height: 8),
              _buildDetailItem('Entry Fee', '₹${widget.tournament.entryFee}', Icons.attach_money),
              SizedBox(height: 8),
              _buildDetailItem('Prize Pool', '₹${widget.tournament.winningPrize}', Icons.celebration),
              SizedBox(height: 8),
              _buildDetailItem('Slots', '${widget.tournament.registeredPlayers}/${widget.tournament.totalSlots}', Icons.people),
              SizedBox(height: 8),
              _buildDetailItem('Type', widget.tournament.tournamentType, Icons.category),
              SizedBox(height: 8),
              _buildDetailItem('Map', widget.tournament.map, Icons.map),

              // Prize Distribution Section
              SizedBox(height: 16),
              _buildPrizeDistributionSection(),

              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You are registered for this tournament',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
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
        ],
      ),
    );
  }

  // FIXED: Build prize distribution section - CORRECTED VERSION
  Widget _buildPrizeDistributionSection() {
    if (widget.tournament.prizeDistribution.isEmpty) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey),
        ),
        child: Center(
          child: Text(
            'No prize distribution set',
            style: TextStyle(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    // FIXED: Create sorted entries and convert to widgets
    final entries = widget.tournament.prizeDistribution.entries.toList();
    entries.sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

    final prizeWidgets = entries.map((entry) {
      final position = entry.key;
      final prize = entry.value;
      return _buildPrizeDistributionItem(position, prize);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prize Distribution:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber),
          ),
          child: Column(
            children: prizeWidgets,
          ),
        ),
      ],
    );
  }

  Widget _buildPrizeDistributionItem(String position, dynamic prize) {
    // Handle both double and int prize values
    final prizeValue = prize is double ? prize : (prize is int ? prize.toDouble() : 0.0);

    String positionText;
    IconData icon;
    Color color;

    switch (position) {
      case '1':
        positionText = '🥇 1st Place';
        icon = Icons.emoji_events;
        color = Colors.amber;
        break;
      case '2':
        positionText = '🥈 2nd Place';
        icon = Icons.emoji_events;
        color = Colors.grey;
        break;
      case '3':
        positionText = '🥉 3rd Place';
        icon = Icons.emoji_events;
        color = Colors.orange;
        break;
      default:
        positionText = '${position}th Place';
        icon = Icons.celebration;
        color = Colors.blue;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              positionText,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ),
          Text(
            '₹${prizeValue.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  void _showCredentialsDialog(BuildContext context) {
    if (!widget.tournament.shouldShowCredentials) {
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
                widget.tournament.tournamentName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              SizedBox(height: 16),
              _buildCredentialDetailItem('Room ID', widget.tournament.roomId ?? 'Not available'),
              SizedBox(height: 12),
              _buildCredentialDetailItem('Room Password', widget.tournament.roomPassword ?? 'Not available'),
              SizedBox(height: 12),
              if (widget.tournament.credentialsMatchTime != null)
                _buildCredentialDetailItem(
                    'Match Time',
                    _formatMatchTime(widget.tournament.credentialsMatchTime!)
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
                  if (widget.tournament.credentialsAvailabilityTime.isNotEmpty)
                    Text(
                      'Available at: ${widget.tournament.credentialsAvailabilityTime}',
                      style: TextStyle(
                        color: Colors.blue[800],
                      ),
                    ),
                  if (widget.tournament.credentialsMatchTime != null)
                    Text(
                      'Match starts at: ${_formatMatchTime(widget.tournament.credentialsMatchTime!)}',
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
Tournament: ${widget.tournament.tournamentName}
Room ID: ${widget.tournament.roomId}
Password: ${widget.tournament.roomPassword}
Match Time: ${widget.tournament.credentialsMatchTime != null ? _formatMatchTime(widget.tournament.credentialsMatchTime!) : 'Not specified'}
''';

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