// ===============================
// WELCOME & SIGNUP SCREEN
// ===============================
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/firebase_service.dart';
import '../services/fmc_services.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FCMService _fcmService = FCMService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;

  Future<void> _signUp() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Create user in Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;

      if (user != null) {
        // 2. Get FCM token
        String? fcmToken = await _fcmService.initializeFCM();
        List<String> fcmTokens = [];
        if (fcmToken != null) {
          fcmTokens.add(fcmToken);
        }

        if (user != null) {
          // 3. Save user data to Firestore with name as document ID
          final userName = _nameController.text.trim();

          await _firestore.collection('users').doc(userName).set({
            'uid': user.uid,
            'name': userName,
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'welcome_bonus': 200.0,
            'role': 'user', // Default role
            'fmcToken': fcmToken ?? '',
            'tournaments': {
              'BGMI': {'BGMI_NAME': '', 'BGMI_ID': ''},
              'FREEFIRE': {'FREEFIRE_NAME': '', 'FREEFIRE_ID': ''},
              'VALORANT': {'VALORANT_NAME': '', 'VALORANT_ID': ''},
              'COD_MOBILE': {'COD_MOBILE_NAME': '', 'COD_MOBILE_ID': ''},
            },
            'tournament_registrations': [],
            'matches': {
              'recent_match': [],
              'won_match': [],
              'loss_match': [],
            },
            'user_all_match_details': [],
            'user_won_match_details': [],
            'user_loss_match_details': [],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'last_login': FieldValue.serverTimestamp(),
          });

          // 4. Create wallet structure for the user
          await _createUserWalletStructure(userName, user.uid);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Account created successfully! ₹200 welcome bonus added.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Sign up failed';
      if (e.code == 'email-already-in-use') {
        message = 'Email already in use';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign up failed: $e')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _createUserWalletStructure(String userName, String userId) async {
    try {
      // Create wallet document in the correct structure
      await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('wallet_data')
          .set({
        'total_balance': 200.0, // Welcome bonus
        'total_winning': 0.0,
        'user_id': userId,
        'user_name': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Initialize transactions document
      await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('transactions')
          .set({
        'successful': [],
        'failed': [],
        'pending': [],
      });

      // Initialize withdrawal_requests document
      await _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('withdrawal_requests')
          .set({
        'approved': [],
        'denied': [],
        'failed': [],
        'pending': [],
      });

      print('✅ New wallet structure created for: $userName');
    } catch (e) {
      print('❌ Error creating wallet structure: $e');
    }
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple[50],
      body: SingleChildScrollView(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 40),
            Icon(
              Icons.sports_esports,
              size: 80,
              color: Colors.deepPurple,
            ),
            SizedBox(height: 20),
            Text(
              'Game Tournaments',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Compete and Win Big',
              style: TextStyle(
                fontSize: 16,
                color: Colors.deepPurple[700],
              ),
            ),
            SizedBox(height: 40),

            if (!_isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.phone),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SizedBox(height: 16),
            ],

            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.email),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.lock),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            SizedBox(height: 24),

            _isLoading
                ? CircularProgressIndicator()
                : SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLogin ? _login : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isLogin ? 'LOGIN' : 'SIGN UP',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                });
              },
              child: Text(
                _isLogin
                    ? 'Don\'t have an account? Sign Up'
                    : 'Already have an account? Login',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            if (!_isLogin) ...[
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(Icons.celebration, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Get ₹200 welcome bonus on sign up!',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}