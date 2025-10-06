import 'package:flutter/material.dart';

class RulesScreen extends StatelessWidget {
  final String gameName;

  RulesScreen({required this.gameName});

  final List<String> rules = [
    "1. Make sure your game name and ID are correct.",
    "2. Joining multiple times with same account is not allowed.",
    "3. Matches are strictly monitored; cheating leads to disqualification.",
    "4. Entry fee is non-refundable once payment is made.",
    "5. Winner will get prize as per tournament rules.",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$gameName Rules"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Tournament Rules",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: rules.length,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    rules[index],
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
