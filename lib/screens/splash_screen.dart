// lib/screens/splash_screen_lottie.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SplashScreenLottie extends StatefulWidget {
  @override
  _SplashScreenLottieState createState() => _SplashScreenLottieState();
}

class _SplashScreenLottieState extends State<SplashScreenLottie> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(milliseconds: 3000),
      vsync: this,
    );

    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.5, 1.0)),
    );

    _controller.forward();

    Future.delayed(Duration(milliseconds: 3500), () {
      Navigator.pushReplacementNamed(context, '/home');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F0F1E),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lottie Animation - You can get gaming animations from lottiefiles.com
          Lottie.asset(
            'assets/animations/game_loading.json', // Replace with your Lottie file
            width: 200,
            height: 200,
            controller: _controller,
            fit: BoxFit.contain,
          ),

          SizedBox(height: 30),

          // Animated BattleBox Text
          AnimatedBuilder(
            animation: _textAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _textAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _textAnimation.value)),
                  child: child,
                ),
              );
            },
            child: Column(
              children: [
                Stack(
                  children: [
                    // Glow
                    Text(
                      'BattleBox',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 8
                          ..color = Color(0xFF6366F1),
                      ),
                    ),
                    // Main text
                    Text(
                      'BattleBox',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2.0,
                        shadows: [
                          Shadow(
                            color: Color(0xFF8B5CF6),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10),

                Text(
                  'Tournament Gaming Platform',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}