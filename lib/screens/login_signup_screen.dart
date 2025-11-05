// ===============================
// WELCOME & SIGNUP SCREEN
// ===============================
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _showVerificationNote = false;

  // List of temporary email domains to block
  final List<String> _tempEmailDomains = [
    'tempmail.com',
    'temp-mail.org',
    'guerrillamail.com',
    'mailinator.com',
    '10minutemail.com',
    'yopmail.com',
    'throwawaymail.com',
    'fakeinbox.com',
    'trashmail.com',
    'disposablemail.com',
    'temp-mail.io',
    'tmpmail.org',
    'getnada.com'
  ];

  bool _isValidEmail(String email) {
    // Basic email validation
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return false;
    }

    // Check for temporary email domains
    final domain = email.split('@')[1].toLowerCase();
    for (String tempDomain in _tempEmailDomains) {
      if (domain.contains(tempDomain)) {
        return false;
      }
    }

    return true;
  }

  bool _isValidPassword(String password) {
    return password.length >= 6;
  }

  bool _passwordsMatch() {
    return _passwordController.text == _confirmPasswordController.text;
  }

  Future<void> _sendEmailVerification(User user) async {
    try {
      await user.sendEmailVerification();
      print('✅ Verification email sent to: ${user.email}');
    } catch (e) {
      print('❌ Error sending verification email: $e');
      throw e;
    }
  }

  Future<void> _signUp() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all fields'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Validate email
    if (!_isValidEmail(_emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please use a valid email address. Temporary emails are not allowed.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Validate password
    if (!_isValidPassword(_passwordController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password must be at least 6 characters long'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Check if passwords match
    if (!_passwordsMatch()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
        // 2. Send email verification
        await _sendEmailVerification(user);

        // 3. Get FCM token
        String? fcmToken = await _fcmService.initializeFCM();
        List<String> fcmTokens = [];
        if (fcmToken != null) {
          fcmTokens.add(fcmToken);
        }

        if (user != null) {
          // 4. Save user data to Firestore with name as document ID
          final userName = _nameController.text.trim();

          await _firestore.collection('users').doc(userName).set({
            'uid': user.uid,
            'name': userName,
            'email': _emailController.text.trim(),
            'emailVerified': false, // Track email verification status
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
              'all': [], // New field for all matches
              'recent_match': [],
              'won_match': [],
              'loss_match': [],
            },
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'last_login': FieldValue.serverTimestamp(),
          });

          // 5. Create wallet structure for the user
          await _createUserWalletStructure(userName, user.uid);

          // 6. Show success message and verification note
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Account created successfully! Verification email sent.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: Duration(seconds: 5),
            ),
          );

          // 7. Show verification note and switch to login screen
          setState(() {
            _showVerificationNote = true;
            _isLogin = true; // Switch to login screen
          });

          // 8. Sign out the user immediately after signup
          await FirebaseAuth.instance.signOut();

          // 9. Clear the form
          _nameController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
          _emailController.clear();
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
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign up failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
        SnackBar(
          content: Text('Please enter email and password'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;

      if (user != null) {
        // Check if email is verified
        if (!user.emailVerified) {
          // If email is not verified, show error and sign out
          await FirebaseAuth.instance.signOut();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please verify your email address before logging in. Check your inbox or spam for verification link.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: Duration(seconds: 5),
            ),
          );

          // Show verification note
          setState(() {
            _showVerificationNote = true;
          });

          setState(() {
            _isLoading = false;
          });
          return;
        }

        // If email is verified, proceed with login
        // Update last login in Firestore
        await _firestore.collection('users').doc(user.displayName ?? _nameController.text.trim()).update({
          'last_login': FieldValue.serverTimestamp(),
          'emailVerified': user.emailVerified,
        });
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Check if user already exists in Firestore
        final userDoc = await _firestore.collection('users').doc(user.displayName).get();

        if (!userDoc.exists) {
          // New user - create document
          String? fcmToken = await _fcmService.initializeFCM();

          await _firestore.collection('users').doc(user.displayName).set({
            'uid': user.uid,
            'name': user.displayName ?? 'Google User',
            'email': user.email,
            'emailVerified': true, // Google accounts are automatically verified
            'welcome_bonus': 200.0,
            'role': 'user',
            'fmcToken': fcmToken ?? '',
            'tournaments': {
              'BGMI': {'BGMI_NAME': '', 'BGMI_ID': ''},
              'FREEFIRE': {'FREEFIRE_NAME': '', 'FREEFIRE_ID': ''},
              'VALORANT': {'VALORANT_NAME': '', 'VALORANT_ID': ''},
              'COD_MOBILE': {'COD_MOBILE_NAME': '', 'COD_MOBILE_ID': ''},
            },
            'tournament_registrations': [],
            'matches': {
              'all': [], // New field for all matches
              'recent_match': [],
              'won_match': [],
              'loss_match': [],
            },
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'last_login': FieldValue.serverTimestamp(),
          });

          // Create wallet structure for new user
          await _createUserWalletStructure(user.displayName ?? 'Google User', user.uid);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account created successfully! ₹200 welcome bonus added.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          // Existing user - update last login
          await _firestore.collection('users').doc(user.displayName).update({
            'last_login': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign in failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _resendVerificationEmail() async {
    try {
      // Create temporary auth to send verification
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;

      if (user != null) {
        await _sendEmailVerification(user);

        // Sign out immediately after sending verification
        await FirebaseAuth.instance.signOut();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email sent successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send verification email. Please try signing up again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F0F1E),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Stack(
                  children: [
                    // Background gradient and elements
                    Positioned(
                      top: -100,
                      right: -100,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.deepPurple.withOpacity(0.3),
                              Colors.transparent
                            ],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: -150,
                      left: -100,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.blue.withOpacity(0.2),
                              Colors.transparent
                            ],
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.all(16), // Reduced padding for small screens
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: constraints.maxHeight * 0.05),

                          // Custom Icon from assets
                          Container(
                            width: constraints.maxWidth * 0.25,
                            height: constraints.maxWidth * 0.25,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF6366F1).withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/icon/icon.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.sports_esports,
                                      size: constraints.maxWidth * 0.125,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          SizedBox(height: 20),

                          // Title with gradient - Responsive font size
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ).createShader(bounds),
                              child: Text(
                                'BattleBox',
                                style: TextStyle(
                                  fontSize: constraints.maxWidth * 0.08, // Responsive font size
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),

                          SizedBox(height: 8),

                          Text(
                            'Compete and Win Big',
                            style: TextStyle(
                              fontSize: constraints.maxWidth * 0.04, // Responsive font size
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: 30),

                          // Email Verification Note (shown after successful signup or when trying to login without verification)
                          if (_showVerificationNote) ...[
                            _buildVerificationNote(),
                            SizedBox(height: 20),
                          ],

                          if (!_isLogin) ...[
                            _buildTextField(
                              controller: _nameController,
                              label: 'Full Name',
                              icon: Icons.person_outline,
                              isPassword: false,
                            ),
                            SizedBox(height: 12),
                          ],

                          _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            isPassword: false,
                          ),
                          SizedBox(height: 12),

                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                            obscureText: _obscurePassword,
                            onToggleObscure: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          SizedBox(height: 12),

                          if (!_isLogin) ...[
                            _buildTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              icon: Icons.lock_outline,
                              isPassword: true,
                              obscureText: _obscureConfirmPassword,
                              onToggleObscure: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            SizedBox(height: 12),
                          ],

                          SizedBox(height: 20),

                          _isLoading
                              ? Container(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                            ),
                          )
                              : Column(
                            children: [
                              // Email/Password Login/Signup Button
                              Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF6366F1).withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: _isLogin ? _login : _signUp,
                                    child: Center(
                                      child: Text(
                                        _isLogin ? 'LOGIN' : 'SIGN UP',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: 16),

                              // OR divider
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: Colors.grey[700],
                                      thickness: 1,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: Colors.grey[700],
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 16),

                              // Google Sign In Button
                              Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey[300]!),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: _signInWithGoogle,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/images/google_icon.png',
                                          height: 24,
                                          width: 24,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(
                                              Icons.account_circle,
                                              color: Colors.grey[700],
                                              size: 24,
                                            );
                                          },
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Continue with Google',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[800],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 16),

                          // Toggle between login/signup
                          Container(
                            height: 56,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Color(0xFF1E1E2E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[800]!),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  setState(() {
                                    _isLogin = !_isLogin;
                                    _showVerificationNote = false; // Hide verification note when toggling
                                  });
                                },
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      _isLogin
                                          ? 'Don\'t have an account? Sign Up'
                                          : 'Already have an account? Login',
                                      style: TextStyle(
                                        color: Colors.grey[300],
                                        fontWeight: FontWeight.w600,
                                        fontSize: constraints.maxWidth * 0.035, // Responsive font
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          if (!_isLogin) ...[
                            SizedBox(height: 20),
                            // Welcome bonus card
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF10B981).withOpacity(0.15),
                                    Color(0xFF059669).withOpacity(0.1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Color(0xFF10B981).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF10B981).withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.celebration, color: Color(0xFF10B981), size: 20),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Welcome Bonus!',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: constraints.maxWidth * 0.04,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Get ₹200 bonus on sign up',
                                          style: TextStyle(
                                            color: Colors.green[300],
                                            fontSize: constraints.maxWidth * 0.035,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          SizedBox(height: 20), // Extra space at bottom
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerificationNote() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF6B35).withOpacity(0.15),
            Color(0xFFF7931E).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFFF6B35).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: Color(0xFFFF6B35), size: 20),
              SizedBox(width: 8),
              Text(
                'Email Verification Required',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'You must verify your email address before you can access your account. A verification link has been sent to your email address.',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '⚠️ Please check your inbox and spam folder. Click the verification link to activate your account.',
            style: TextStyle(
              color: Colors.orange[300],
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFFFF6B35).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFFFF6B35)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _resendVerificationEmail,
                      child: Center(
                        child: Text(
                          'Resend Verification Email',
                          style: TextStyle(
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isPassword,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText && isPassword,
        style: TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey[500],
              size: 20,
            ),
            onPressed: onToggleObscure,
          )
              : null,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
        cursorColor: Color(0xFF6366F1),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}