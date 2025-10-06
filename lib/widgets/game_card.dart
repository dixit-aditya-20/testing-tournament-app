import 'package:flutter/material.dart';

class GameCard extends StatelessWidget {
  final String gameName;
  final VoidCallback onTap;

  GameCard({required this.gameName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(gameName),
        trailing: Icon(Icons.arrow_forward),
        onTap: onTap,
      ),
    );
  }
}
