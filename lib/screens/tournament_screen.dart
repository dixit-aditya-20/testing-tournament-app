// tournament_screen.dart
import 'package:flutter/material.dart';

class TournamentScreen extends StatefulWidget {
  final String gameName;
  final String gameImage;
  final String tournamentId;
  final double entryFee;

  const TournamentScreen({
    Key? key,
    required this.gameName,
    required this.gameImage,
    required this.tournamentId,
    required this.entryFee,
  }) : super(key: key);

  @override
  _TournamentScreenState createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  bool _isLoading = false;

  void _registerForTournament() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call or registration process
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      _isLoading = false;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully registered for ${widget.gameName} tournament!'),
        backgroundColor: Colors.green,
      ),
    );

    // Optionally navigate back
    // Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.gameName} Tournament'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Image
            Container(
              height: 200,
              width: double.infinity,
              child: Image.network(
                widget.gameImage,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  color: Colors.grey,
                  child: Icon(Icons.error),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Tournament Details
            Text(
              'Tournament: ${widget.gameName}',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),

            Text(
              'Tournament ID: ${widget.tournamentId}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),

            Text(
              'Entry Fee: \$${widget.entryFee}',
              style: TextStyle(fontSize: 18, color: Colors.green),
            ),
            SizedBox(height: 30),

            // Register Button
            Center(
              child: ElevatedButton(
                onPressed: _registerForTournament,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: Text(
                  'Confirm Registration',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}