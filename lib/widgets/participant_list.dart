import 'package:flutter/material.dart';

class ParticipantList extends StatelessWidget {
  final List<String> participants;
  ParticipantList({required this.participants});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: participants.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(participants[index]),
        );
      },
    );
  }
}
