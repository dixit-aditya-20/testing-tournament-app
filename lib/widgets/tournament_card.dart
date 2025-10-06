import 'package:flutter/material.dart';
import '../modles/tournament_model.dart';
import 'countdown_timer.dart';

class TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final VoidCallback onJoinPressed;

  const TournamentCard({
    Key? key,
    required this.tournament,
    required this.onJoinPressed,
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
                    '\$${tournament.entryFee}',
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

            // Registration Timer
            _buildTimerSection(
              icon: Icons.timer,
              color: Colors.red,
              label: 'Registration ends in:',
              targetDate: tournament.registrationEnd,
            ),
            SizedBox(height: 8),

            // Tournament Start Timer
            _buildTimerSection(
              icon: Icons.calendar_today,
              color: Colors.purple,
              label: 'Tournament starts in:',
              targetDate: tournament.tournamentStart,
            ),
            SizedBox(height: 16),

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
}