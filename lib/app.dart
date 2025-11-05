import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamic_and_api/screens/admin_panel_screen.dart';
import 'package:dynamic_and_api/screens/dashboard_screen.dart';
import 'package:dynamic_and_api/screens/home_screen.dart';
import 'package:dynamic_and_api/screens/notificcation_screen.dart';
import 'package:dynamic_and_api/screens/recent_match.dart';
import 'package:dynamic_and_api/screens/rules_screen.dart';
import 'package:dynamic_and_api/screens/user_profile_screen.dart';
import 'package:dynamic_and_api/screens/wallet_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

class MainApp extends StatefulWidget {
  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Professional screens with proper routing
  final List<Widget> _screens = [
    HomeScreen(),
    WalletScreen(),
    RecentMatchesScreen(),
    DashboardScreen(),
    NotificationsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      drawer: AppDrawer(
        onNavigationChanged: _onTabTapped,
        currentIndex: _currentIndex,
      ),
      body: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Container(
        width: double.infinity,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42, // Increased from 32
              height: 42, // Increased from 32
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(21), // Half of width/height for perfect circle
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21), // Half of width/height for perfect circle
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 28, // Increased from 18
                  height: 28, // Increased from 18
                  fit: BoxFit.cover, // Changed to cover for better filling
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getAppBarTitle(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    _getAppBarSubtitle(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.deepPurple,
      elevation: 2,
      shadowColor: Colors.deepPurple.withOpacity(0.5),
      leading: Builder(
        builder: (context) => Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.menu_rounded, color: Colors.white, size: 20),
            onPressed: () => Scaffold.of(context).openDrawer(),
            splashRadius: 18,
          ),
        ),
      ),
      actions: [
        Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.person_rounded, color: Colors.white, size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UserProfileScreen()),
              );
            },
            splashRadius: 18,
          ),
        ),
        SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade800,
            Colors.purple.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withOpacity(0.6),
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 10,
        ),
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: Container(
              padding: EdgeInsets.all(6),
              decoration: _currentIndex == 0
                  ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
              )
                  : null,
              child: Icon(Icons.home_rounded, size: 20),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: EdgeInsets.all(6),
              decoration: _currentIndex == 1
                  ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
              )
                  : null,
              child: Icon(Icons.account_balance_wallet_rounded, size: 20),
            ),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: EdgeInsets.all(6),
              decoration: _currentIndex == 2
                  ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
              )
                  : null,
              child: Icon(Icons.history_rounded, size: 20),
            ),
            label: 'Matches',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: EdgeInsets.all(6),
              decoration: _currentIndex == 3
                  ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
              )
                  : null,
              child: Icon(Icons.leaderboard_rounded, size: 20),
            ),
            label: 'Leaderboard',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: EdgeInsets.all(6),
              decoration: _currentIndex == 4
                  ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
              )
                  : null,
              child: Stack(
                children: [
                  Icon(Icons.notifications_rounded, size: 20),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0: return 'Game Tournaments';
      case 1: return 'My Wallet';
      case 2: return 'Match History';
      case 3: return 'Leaderboard';
      case 4: return 'Notifications';
      default: return 'Game Tournaments';
    }
  }

  String _getAppBarSubtitle() {
    switch (_currentIndex) {
      case 0: return 'Compete & Win Big';
      case 1: return 'Manage your funds';
      case 2: return 'Your gaming journey';
      case 3: return 'Top players ranking';
      case 4: return 'Stay updated';
      default: return 'Compete & Win Big';
    }
  }
}

// ===============================
// PROFESSIONAL APP DRAWER
// ===============================
class AppDrawer extends StatefulWidget {
  final Function(int) onNavigationChanged;
  final int currentIndex;

  const AppDrawer({
    Key? key,
    required this.onNavigationChanged,
    required this.currentIndex,
  }) : super(key: key);

  @override
  _AppDrawerState createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _walletData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<double>(begin: -0.2, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadUserData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _getCurrentUser();
      final stats = await _getUserStatistics();
      final wallet = await _getWalletData();

      if (mounted) {
        setState(() {
          _currentUser = user;
          _userStats = stats;
          _walletData = wallet;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading drawer data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _getCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userDoc = userQuery.docs.first;
        return userDoc.data()..['userId'] = user.uid;
      }
    } catch (e) {
      print('Error getting current user: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> _getWalletData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      // First find the user document to get the username
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userDoc = userQuery.docs.first;
        final userName = userDoc.id;

        // Now get wallet data using the username
        final walletDoc = await FirebaseFirestore.instance
            .collection('wallet')
            .doc('users')
            .collection(userName)
            .doc('wallet_data')
            .get();

        if (walletDoc.exists) {
          return walletDoc.data() ?? {};
        }
      }
    } catch (e) {
      print('Error getting wallet data: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> _getUserStatistics() async {
    try {
      int tournamentsJoined = 0;
      int tournamentsWon = 0;
      double winRate = 0.0;

      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userDoc = userQuery.docs.first;
        final userData = userDoc.data();

        final registrations = userData['tournament_registrations'] as List<dynamic>? ?? [];
        tournamentsJoined = registrations.length;

        for (var reg in registrations) {
          if (reg is Map<String, dynamic> && reg['result'] == 'won') {
            tournamentsWon++;
          }
        }

        winRate = tournamentsJoined > 0 ? (tournamentsWon / tournamentsJoined * 100) : 0.0;
      }

      return {
        'tournamentsJoined': tournamentsJoined,
        'tournamentsWon': tournamentsWon,
        'winRate': winRate,
      };
    } catch (e) {
      print('Error getting user statistics: $e');
      return {
        'tournamentsJoined': 0,
        'tournamentsWon': 0,
        'winRate': 0.0,
      };
    }
  }

  String _getUserRank(double totalWinnings) {
    if (totalWinnings >= 10000) return 'Pro Player 🏆';
    if (totalWinnings >= 5000) return 'Expert ⭐';
    if (totalWinnings >= 1000) return 'Advanced 🔥';
    if (totalWinnings >= 500) return 'Intermediate 💪';
    return 'Beginner 🌱';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value * MediaQuery.of(context).size.width, 0),
          child: child,
        );
      },
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(0),
            bottomRight: Radius.circular(0),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurple.shade900,
                Colors.purple.shade800,
                Colors.deepPurple.shade800,
              ],
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? _buildLoadingDrawer()
                    : _buildDrawerContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerContent() {
    final totalBalance = (_walletData['total_balance'] ?? 0.0).toDouble();
    final totalWinning = (_walletData['total_winning'] ?? 0.0).toDouble();
    final userRank = _getUserRank(totalWinning);

    return SingleChildScrollView(
      physics: ClampingScrollPhysics(),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50, // Increased size
                      height: 50, // Increased size
                      padding: EdgeInsets.all(8), // Added padding
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple, Colors.purple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25), // Half of width/height
                        child: Image.asset(
                          'assets/icon/icon.png',
                          width: 32, // Increased size
                          height: 32, // Increased size
                          fit: BoxFit.cover, // Changed to cover
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'BattleBox Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildUserHeader(userRank),
              ],
            ),
          ),

          // Stats Section
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Player Statistics',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),
                _buildStatsGrid(totalBalance, totalWinning),
              ],
            ),
          ),

          // Navigation Section
          Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                _buildDrawerItem(
                  icon: Icons.home_rounded,
                  title: 'Home',
                  index: 0,
                  isSelected: widget.currentIndex == 0,
                ),
                _buildDivider(),
                _buildDrawerItem(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Wallet',
                  index: 1,
                  isSelected: widget.currentIndex == 1,
                ),
                _buildDivider(),
                _buildDrawerItem(
                  icon: Icons.history_rounded,
                  title: 'Match History',
                  index: 2,
                  isSelected: widget.currentIndex == 2,
                ),
                _buildDivider(),
                _buildDrawerItem(
                  icon: Icons.leaderboard_rounded,
                  title: 'Leaderboard',
                  index: 3,
                  isSelected: widget.currentIndex == 3,
                ),
                _buildDivider(),
                _buildDrawerItem(
                  icon: Icons.notifications_rounded,
                  title: 'Notifications',
                  index: 4,
                  isSelected: widget.currentIndex == 4,
                ),
              ],
            ),
          ),

          // Additional Options
          Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                _buildAdditionalItem(
                  icon: Icons.person_rounded,
                  title: 'My Profile',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UserProfileScreen()),
                    );
                  },
                ),
                _buildDivider(),
                _buildAdditionalItem(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  onTap: () {
                    // Navigate to settings
                  },
                ),
                _buildDivider(),
                _buildAdditionalItem(
                  icon: Icons.help_rounded,
                  title: 'Help & Support',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>  HelpSupportScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          // Admin Panel (if applicable)
          if ((_currentUser?['role'] ?? 'user') == 'admin') ...[
            Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: _buildAdditionalItem(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Admin Panel',
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminPanelScreen(),
                    ),
                  );
                },
              ),
            ),
          ],

          // Sign Out
          Container(
            margin: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _showLogoutConfirmation(context),
              icon: Icon(Icons.logout_rounded, size: 18),
              label: Text(
                'Sign Out',
                style: TextStyle(fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.2),
                foregroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.red.withOpacity(0.3)),
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildUserHeader(String userRank) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.deepPurple],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentUser?['name'] ?? 'User',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                _currentUser?['email'] ?? 'user@example.com',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  userRank,
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(double totalBalance, double totalWinning) {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      padding: EdgeInsets.zero,
      children: [
        _buildStatCard(
          'Wallet Balance',
          '₹${totalBalance.toStringAsFixed(0)}',
          Icons.account_balance_wallet_rounded,
          Colors.green,
        ),
        _buildStatCard(
          'Total Winnings',
          '₹${totalWinning.toStringAsFixed(0)}',
          Icons.emoji_events_rounded,
          Colors.amber,
        ),
        _buildStatCard(
          'Tournaments',
          '${_userStats['tournamentsJoined'] ?? 0}',
          Icons.tour_rounded,
          Colors.blue,
        ),
        _buildStatCard(
          'Win Rate',
          '${(_userStats['winRate'] ?? 0.0).toStringAsFixed(1)}%',
          Icons.trending_up_rounded,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
    required bool isSelected,
  }) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: Container(
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isSelected
          ? Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      )
          : null,
      onTap: () {
        Navigator.pop(context);
        widget.onNavigationChanged(index);
      },
    );
  }

  Widget _buildAdditionalItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color,
          size: 18,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: Colors.white.withOpacity(0.5),
        size: 14,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.white.withOpacity(0.1),
      height: 1,
      thickness: 1,
      indent: 12,
      endIndent: 12,
    );
  }

  Widget _buildLoadingDrawer() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            bottom: 20,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    SizedBox(height: 6),
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
                SizedBox(height: 12),
                Text(
                  'Loading...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.shade800,
                Colors.purple.shade600,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Sign Out?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Are you sure you want to sign out?',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                        _signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text('Sign Out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }
}