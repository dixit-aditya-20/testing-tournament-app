// ===============================
// MAIN APP WITH BOTTOM NAVIGATION (FIXED)
// ===============================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamic_and_api/screens/dashboard_screen.dart';
import 'package:dynamic_and_api/screens/home_screen.dart';
import 'package:dynamic_and_api/screens/notificcation_screen.dart';
import 'package:dynamic_and_api/screens/recent_match.dart';
import 'package:dynamic_and_api/screens/wallet_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'modles/user_registration_model.dart';

class MainApp extends StatefulWidget {
  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;

  // FIXED: Added all 5 screens to match the 5 bottom navigation items
  final List<Widget> _screens = [
    HomeScreen(),
    WalletScreen(),
    RecentMatchesScreen(),
    DashboardScreen(),
    NotificationsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // FIXED: Safety check to prevent index out of bounds
    if (_currentIndex >= _screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: AppDrawer(
        onNavigationChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        currentIndex: _currentIndex,
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.deepPurple,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Matches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
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
}

// ===============================
// APP DRAWER (FIXED)
// ===============================
class AppDrawer extends StatelessWidget {
  final Function(int) onNavigationChanged;
  final int currentIndex;

  const AppDrawer({
    Key? key,
    required this.onNavigationChanged,
    required this.currentIndex,
  }) : super(key: key);

  Future<AppUser?> _getCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      print('🔍 Fetching user data for UID: ${user.uid}');

      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userDoc = userQuery.docs.first;
        final userData = userDoc.data();
        final userName = userDoc.id;

        print('✅ User found: $userName');

        // Get wallet data
        double totalBalance = 0.0;
        double totalWinning = 0.0;

        // Try multiple wallet locations
        try {
          final walletDoc = await FirebaseFirestore.instance
              .collection('wallet')
              .doc('users')
              .collection(userName)
              .doc('wallet_data')
              .get();

          if (walletDoc.exists) {
            final walletData = walletDoc.data();
            totalBalance = (walletData?['total_balance'] as num?)?.toDouble() ?? 0.0;
            totalWinning = (walletData?['total_winning'] as num?)?.toDouble() ?? 0.0;
            print('💰 Wallet data found: balance=$totalBalance, winning=$totalWinning');
          }
        } catch (e) {
          print('⚠️ Error checking wallet: $e');
        }

        return AppUser(
          userId: user.uid,
          email: (userData['email'] as String?) ?? user.email ?? 'No Email',
          name: (userData['name'] as String?) ?? user.displayName ?? userName,
          phone: (userData['phone'] as String?) ?? '',
          fcmToken: (userData['fcmToken'] as String?) ?? '',
          totalWinning: totalWinning,
          totalBalance: totalBalance,
          createdAt: (userData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastLogin: DateTime.now(),
          tournaments: (userData['tournaments'] as Map<String, dynamic>?) ?? {},
          matches: (userData['matches'] as Map<String, dynamic>?) ?? {},
          withdrawRequests: [],
          transactions: [],
          tournamentRegistrations: (userData['tournament_registrations'] as List<dynamic>?) ?? [],
          role: userData['role'] ?? 'user',
        );
      } else {
        print('❌ User document not found for UID: ${user.uid}');
        return AppUser(
          userId: user.uid,
          email: user.email ?? 'user@example.com',
          name: user.displayName ?? 'User',
          phone: '',
          fcmToken: '',
          totalWinning: 0.0,
          totalBalance: 0.0,
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
          tournaments: {},
          matches: {},
          withdrawRequests: [],
          transactions: [],
          tournamentRegistrations: [],
          role: 'user',
        );
      }
    } catch (e) {
      print('❌ Error fetching user: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _getUserStatistics(String userName) async {
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
      print('❌ Error getting user statistics: $e');
      return {
        'tournamentsJoined': 0,
        'tournamentsWon': 0,
        'winRate': 0.0,
      };
    }
  }

  String _getUserRank(double totalWinnings) {
    if (totalWinnings >= 10000) return 'Pro Player';
    if (totalWinnings >= 5000) return 'Expert';
    if (totalWinnings >= 1000) return 'Advanced';
    if (totalWinnings >= 500) return 'Intermediate';
    return 'Beginner';
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: FutureBuilder<AppUser?>(
        future: _getCurrentUser(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingDrawer(context);
          }

          if (userSnapshot.hasError || !userSnapshot.hasData) {
            return _buildErrorDrawer(context);
          }

          final user = userSnapshot.data!;

          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserStatistics(user.name),
            builder: (context, statsSnapshot) {
              final stats = statsSnapshot.data ?? {
                'tournamentsJoined': 0,
                'tournamentsWon': 0,
                'winRate': 0.0,
              };

              final userRank = _getUserRank(user.totalWinning);

              return Column(
                children: [
                  UserAccountsDrawerHeader(
                    accountName: Text(
                      user.name,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    accountEmail: Text(user.email),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        color: Colors.deepPurple,
                        size: 40,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // User Stats
                        _buildStatItem(
                          Icons.account_balance_wallet,
                          'Wallet Balance',
                          '₹${user.totalBalance.toStringAsFixed(2)}',
                          Colors.green,
                        ),
                        _buildStatItem(
                          Icons.emoji_events,
                          'Total Winnings',
                          '₹${user.totalWinning.toStringAsFixed(2)}',
                          Colors.orange,
                        ),
                        _buildStatItem(
                          Icons.leaderboard,
                          'Rank',
                          userRank,
                          Colors.purple,
                          isChip: true,
                        ),
                        _buildStatItem(
                          Icons.tour,
                          'Tournaments Joined',
                          '${stats['tournamentsJoined']}',
                          Colors.blue,
                        ),
                        _buildStatItem(
                          Icons.emoji_events_outlined,
                          'Tournaments Won',
                          '${stats['tournamentsWon']}',
                          Colors.amber,
                        ),
                        _buildStatItem(
                          Icons.trending_up,
                          'Win Rate',
                          '${stats['winRate'].toStringAsFixed(1)}%',
                          Colors.green,
                        ),

                        Divider(),

                        // Navigation Items
                        _buildDrawerItem(
                          context,
                          icon: Icons.home,
                          title: 'Home',
                          index: 0,
                          isSelected: currentIndex == 0,
                        ),
                        _buildDrawerItem(
                          context,
                          icon: Icons.account_balance_wallet,
                          title: 'Wallet',
                          index: 1,
                          isSelected: currentIndex == 1,
                        ),
                        _buildDrawerItem(
                          context,
                          icon: Icons.history,
                          title: 'Match History',
                          index: 2,
                          isSelected: currentIndex == 2,
                        ),
                        _buildDrawerItem(
                          context,
                          icon: Icons.leaderboard,
                          title: 'Leaderboard',
                          index: 3,
                          isSelected: currentIndex == 3,
                        ),
                        _buildDrawerItem(
                          context,
                          icon: Icons.notifications,
                          title: 'Notifications',
                          index: 4,
                          isSelected: currentIndex == 4,
                        ),

                        Divider(),

                        // Admin Panel Check
                        FutureBuilder<DocumentSnapshot>(
                          future: _getUserRole(),
                          builder: (context, roleSnapshot) {
                            if (roleSnapshot.hasData && roleSnapshot.data?.exists == true) {
                              final userData = roleSnapshot.data!.data() as Map<String, dynamic>?;
                              final role = userData?['role'] as String?;

                              if (role == 'admin') {
                                return _buildDrawerItem(
                                  context,
                                  icon: Icons.admin_panel_settings,
                                  title: 'Admin Panel',
                                  index: -1, // Special index for admin
                                  isSelected: false,
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(context, '/admin');
                                  },
                                );
                              }
                            }
                            return SizedBox.shrink();
                          },
                        ),

                        // Sign Out
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.logout, color: Colors.red),
                          title: Text('Sign Out', style: TextStyle(color: Colors.red)),
                          onTap: () => _showLogoutConfirmation(context),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String title, String value, Color color, {bool isChip = false}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: isChip
          ? Chip(
        label: Text(
          value,
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        backgroundColor: color,
      )
          : Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {
    required IconData icon,
    required String title,
    required int index,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.deepPurple : null),
      title: Text(title, style: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.deepPurple : null,
      )),
      tileColor: isSelected ? Colors.deepPurple.withOpacity(0.1) : null,
      onTap: onTap ?? () {
        Navigator.pop(context);
        onNavigationChanged(index);
      },
    );
  }

  Future<DocumentSnapshot> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user logged in');

    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) throw Exception('User document not found');

    return userQuery.docs.first;
  }

  Widget _buildLoadingDrawer(BuildContext context) {
    return Column(
      children: [
        UserAccountsDrawerHeader(
          accountName: Text('Loading...'),
          accountEmail: Text('Loading...'),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: CircularProgressIndicator(),
          ),
          decoration: BoxDecoration(color: Colors.deepPurple),
        ),
        Expanded(
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }

  Widget _buildErrorDrawer(BuildContext context) {
    return Column(
      children: [
        UserAccountsDrawerHeader(
          accountName: Text('Error'),
          accountEmail: Text('Failed to load user data'),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.error, color: Colors.red),
          ),
          decoration: BoxDecoration(color: Colors.deepPurple),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text('Failed to load user data', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Scaffold.of(context).openDrawer();
                  },
                  child: Text('Retry'),
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
      builder: (context) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              _signOut(context);
            },
            child: Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}