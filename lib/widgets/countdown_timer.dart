import 'package:flutter/material.dart';

class CountdownTimer extends StatefulWidget {
  final DateTime targetDate;
  final TextStyle? textStyle;

  const CountdownTimer({
    Key? key,
    required this.targetDate,
    this.textStyle,
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
    Future.delayed(Duration(seconds: 1), () {
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
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatDuration(_timeLeft),
      style: widget.textStyle ?? TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.red,
      ),
    );
  }
}