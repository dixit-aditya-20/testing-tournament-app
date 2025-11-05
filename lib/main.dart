import 'package:dynamic_and_api/screens/login_signup_screen.dart';
import 'package:dynamic_and_api/services/firebase_messaging_background.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set up background message handler
  await setupBackgroundHandler();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final NotificationService _notificationService = NotificationService();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    // Initialize notification service with navigator key
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notificationService.initialize(navigatorKey);
      }
    });

    // Setup notification listener for navigation
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    // Listen for notification taps and navigate accordingly
    _notificationService.notificationStream.listen((data) {
      _handleNotificationData(data);
    });
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final String type = data['type'] ?? 'general';
    final String? tournamentId = data['tournamentId'];
    final String? roomId = data['roomId'];

    print('📱 Notification received in main: $type');

    if (navigatorKey.currentState != null) {
      switch (type) {
        case 'payment_success':
          _showNotificationSnackBar('💰 Payment successful!', Colors.green);
          break;
        case 'tournament_result':
          _showNotificationSnackBar('🏆 Tournament results are available!', Colors.amber);
          break;
        case 'room_credentials':
          _showNotificationSnackBar('🎮 Room credentials available!', Colors.blue);
          break;
        case 'withdrawal_approved':
          _showNotificationSnackBar('✅ Withdrawal approved!', Colors.green);
          break;
        case 'withdrawal_rejected':
          _showNotificationSnackBar('❌ Withdrawal rejected!', Colors.red);
          break;
        case 'tournament_reminder':
          _showNotificationSnackBar('⚡ Tournament starting soon!', Colors.orange);
          break;
        case 'welcome_bonus':
          _showNotificationSnackBar('🎁 Welcome bonus received!', Colors.purple);
          break;
        case 'admin_notification':
          _showNotificationSnackBar('📢 Admin announcement!', Colors.deepPurple);
          break;
        default:
          _showNotificationSnackBar('🔔 New notification!', Colors.deepPurple);
          break;
      }

      // Navigate based on notification type
      _navigateBasedOnNotification(type, tournamentId, roomId, data);
    }
  }

  void _navigateBasedOnNotification(String type, String? tournamentId, String? roomId, Map<String, dynamic> data) {
    // You can add navigation logic here based on notification type
    switch (type) {
      case 'tournament_result':
      case 'tournament_reminder':
        if (tournamentId != null && tournamentId.isNotEmpty) {
          // Navigate to tournament details
          print('Navigating to tournament: $tournamentId');
        }
        break;
      case 'room_credentials':
        if (roomId != null && roomId.isNotEmpty) {
          // Navigate to room details or show dialog
          print('Showing room credentials for: $roomId');
        }
        break;
      case 'payment_success':
      case 'withdrawal_approved':
      // Navigate to wallet screen
        print('Navigating to wallet');
        break;
    }
  }

  void _showNotificationSnackBar(String message, Color color) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Tournaments',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      navigatorKey: navigatorKey,
      home: SplashScreenWrapper(
        notificationService: _notificationService,
        firestore: _firestore,
      ),
      debugShowCheckedModeBanner: false,
    );
  }

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }
}

// ADDED: Splash Screen Wrapper
class SplashScreenWrapper extends StatefulWidget {
  final NotificationService notificationService;
  final FirebaseFirestore firestore;

  const SplashScreenWrapper({
    Key? key,
    required this.notificationService,
    required this.firestore,
  }) : super(key: key);

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Navigate to auth wrapper after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showSplash ? SplashScreen() : AuthWrapper(
      notificationService: widget.notificationService,
      firestore: widget.firestore,
    );
  }
}

// ADDED: Splash Screen
class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F0F1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Box
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF6366F1).withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),

            SizedBox(height: 40),

            // BattleBox Text
            Stack(
              children: [
                // Glow effect
                Text(
                  'BattleBox',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 6
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
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Tagline
            Text(
              'Compete • Win • Dominate',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// UPDATED: AuthWrapper with email verification check
class AuthWrapper extends StatefulWidget {
  final NotificationService notificationService;
  final FirebaseFirestore firestore;

  const AuthWrapper({
    Key? key,
    required this.notificationService,
    required this.firestore,
  }) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          final User user = snapshot.data!;

          // Check if email is verified
          if (user.emailVerified) {
            // User is logged in AND verified - initialize user-specific notifications
            _initializeUserNotifications(user);
            return MainApp();
          } else {
            // User is logged in but NOT verified - show WelcomeScreen with verification note
            return WelcomeScreen();
          }
        }

        // User is not logged in
        return WelcomeScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 20),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _initializeUserNotifications(User user) {
    print('👤 Initializing notifications for user: ${user.uid}');

    // Subscribe user to relevant topics
    _subscribeToTopics();

    // Save FCM token to user's document in Firestore
    _saveUserFCMToken(user);

    // Initialize user-specific notification settings
    _initializeUserNotificationSettings(user);
  }

  void _subscribeToTopics() {
    try {
      // Subscribe to general topics
      widget.notificationService.subscribeToTopic('all_users');
      widget.notificationService.subscribeToTopic('general_notifications');

      print('✅ Subscribed to notification topics');
    } catch (e) {
      print('❌ Error subscribing to topics: $e');
    }
  }

  Future<void> _saveUserFCMToken(User user) async {
    try {
      final token = await widget.notificationService.getFCMToken();
      if (token != null) {
        print('🔑 FCM Token for user ${user.uid}: $token');

        // Find user document by uid and update FCM token
        final userQuery = await widget.firestore
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userName = userQuery.docs.first.id;
          await widget.firestore.collection('users').doc(userName).update({
            'fcmToken': token,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });
          print('✅ FCM token saved for user: $userName');
        } else {
          print('⚠️ User document not found for uid: ${user.uid}');
        }
      } else {
        print('⚠️ No FCM token available');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  Future<void> _initializeUserNotificationSettings(User user) async {
    try {
      // Find user document
      final userQuery = await widget.firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userName = userQuery.docs.first.id;
        final userDoc = await widget.firestore.collection('users').doc(userName).get();

        // Initialize notification settings if they don't exist
        if (!userDoc.exists || userDoc.data()?['notificationSettings'] == null) {
          await widget.firestore.collection('users').doc(userName).update({
            'notificationSettings': {
              'pushNotifications': true,
              'emailNotifications': false,
              'tournamentReminders': true,
              'paymentAlerts': true,
              'promotional': true,
              'lastUpdated': FieldValue.serverTimestamp(),
            }
          });
          print('✅ Notification settings initialized for user: $userName');
        }
      }
    } catch (e) {
      print('❌ Error initializing notification settings: $e');
    }
  }

  @override
  void dispose() {
    // Unsubscribe from topics when user logs out (handled in AuthWrapper dispose)
    _unsubscribeFromTopics();
    super.dispose();
  }

  void _unsubscribeFromTopics() {
    try {
      // Unsubscribe from topics when user logs out
      widget.notificationService.unsubscribeFromTopic('all_users');
      widget.notificationService.unsubscribeFromTopic('general_notifications');
      print('✅ Unsubscribed from notification topics');
    } catch (e) {
      print('❌ Error unsubscribing from topics: $e');
    }
  }
}