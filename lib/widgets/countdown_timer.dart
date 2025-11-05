import 'package:flutter/material.dart';

class CountdownTimer extends StatefulWidget {
  final DateTime targetDate;
  final TextStyle textStyle;
  final String completedText;

  const CountdownTimer({
    Key? key,
    required this.targetDate,
    required this.textStyle,
    this.completedText = '00',
  }) : super(key: key);

  @override
  _CountdownTimerState createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Duration _timeLeft;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.targetDate.difference(DateTime.now());
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _timeLeft = widget.targetDate.difference(DateTime.now());
        });
        if (_timeLeft.inSeconds > 0) {
          _startTimer();
        }
      }
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return widget.completedText;
    }

    if (duration.inDays > 0) {
      final days = duration.inDays;
      final hours = duration.inHours.remainder(24);
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);

      if (days > 0) {
        return '${days}d ${hours}h ${minutes}m';
      } else {
        return '${hours}h ${minutes}m ${seconds}s';
      }
    } else if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (duration.inMinutes > 0) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds.remainder(60);
      return '${minutes}m ${seconds}s';
    } else {
      final seconds = duration.inSeconds;
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatDuration(_timeLeft),
      style: widget.textStyle,
    );
  }
}