import 'package:flutter/material.dart';

class GameIdDialog extends StatefulWidget {
  final String gameName;
  final Function(String, String) onConfirm;

  const GameIdDialog({
    Key? key,
    required this.gameName,
    required this.onConfirm,
  }) : super(key: key);

  @override
  _GameIdDialogState createState() => _GameIdDialogState();
}

class _GameIdDialogState extends State<GameIdDialog> {
  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _playerIdController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enter ${widget.gameName} Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please enter your game details to register for the tournament',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _playerNameController,
              decoration: InputDecoration(
                labelText: 'Player Name',
                border: OutlineInputBorder(),
                hintText: 'Enter your in-game name',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _playerIdController,
              decoration: InputDecoration(
                labelText: 'Game ID',
                border: OutlineInputBorder(),
                hintText: 'Enter your game ID/username',
              ),
            ),
            SizedBox(height: 10),
            if (_isLoading) ...[
              SizedBox(height: 16),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processing...', style: TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () {
            print('❌ GameIdDialog cancelled');
            Navigator.pop(context);
          },
          child: Text(
            'CANCEL',
            style: TextStyle(color: Colors.grey[700]), // Better visibility
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _onConfirmPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white, // White text for better contrast
          ),
          child: Text(
            'CONFIRM',
            style: TextStyle(
              color: Colors.white, // Explicit white color
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _onConfirmPressed() {
    final playerName = _playerNameController.text.trim();
    final playerId = _playerIdController.text.trim();

    print('🔍 Validating inputs: Name="$playerName", ID="$playerId"');

    if (playerName.isEmpty) {
      print('⚠️ Player name is empty');
      _showError('Please enter your player name');
      return;
    }

    if (playerId.isEmpty) {
      print('⚠️ Game ID is empty');
      _showError('Please enter your game ID');
      return;
    }

    print('✅ Inputs valid, calling onConfirm callback');

    setState(() {
      _isLoading = true;
    });

    // Add a small delay to show loading state
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Call the callback
        widget.onConfirm(playerName, playerId);

        // Close the dialog
        Navigator.pop(context);
        print('✅ GameIdDialog closed after confirmation');
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    _playerIdController.dispose();
    super.dispose();
  }
}