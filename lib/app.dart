// ===============================
// MAIN APP WITH BOTTOM NAVIGATION
// ===============================
import 'package:dynamic_and_api/screens/dashboard_screen.dart';
import 'package:dynamic_and_api/screens/home_screen.dart';
import 'package:dynamic_and_api/screens/notificcation_screen.dart';
import 'package:dynamic_and_api/screens/recent_match.dart';
import 'package:dynamic_and_api/screens/wallet_screen.dart';
import 'package:dynamic_and_api/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MainApp extends StatefulWidget {
  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    HomeScreen(),
    WalletScreen(),
    RecentMatchesScreen(),
    DashboardScreen(),
    NotificationsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
      drawer: AppDrawer(),
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
// APP DRAWER
// ===============================
class AppDrawer extends StatelessWidget {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: FutureBuilder(
        future: _firebaseService.getCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingDrawer();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorDrawer();
          }

          final user = snapshot.data;
          return Column(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(
                  user?.name ?? 'User',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(user?.email ?? 'user@example.com'),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: user?.profileImage?.isNotEmpty == true
                      ? NetworkImage(user!.profileImage)
                      : null,
                  child: user?.profileImage?.isNotEmpty == true
                      ? null
                      : Icon(
                    Icons.person,
                    color: Colors.deepPurple,
                    size: 40,
                  ),
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                ),
              ),
              ListTile(
                leading: Icon(Icons.account_balance_wallet),
                title: Text('Wallet Balance'),
                trailing: Text(
                  '₹${user?.walletBalance.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.emoji_events),
                title: Text('Total Winnings'),
                trailing: Text(
                  '₹${user?.totalWinnings.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.leaderboard),
                title: Text('Rank'),
                trailing: Chip(
                  label: Text(
                    user?.rank ?? 'Beginner',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: Colors.deepPurple,
                ),
              ),
              Divider(),
              _buildDrawerItem(
                context,
                icon: Icons.home,
                title: 'Home',
                onTap: () => _navigateToScreen(context, 0),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.account_balance_wallet,
                title: 'Wallet',
                onTap: () => _navigateToScreen(context, 1),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.history,
                title: 'Match History',
                onTap: () => _navigateToScreen(context, 2),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.leaderboard,
                title: 'Leaderboard',
                onTap: () => _navigateToScreen(context, 3),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.notifications,
                title: 'Notifications',
                onTap: () => _navigateToScreen(context, 4),
              ),
              Divider(),
              _buildDrawerItem(
                context,
                icon: Icons.person,
                title: 'Profile',
                onTap: () {
                  // TODO: Navigate to profile screen
                  Navigator.pop(context);
                },
              ),
              _buildDrawerItem(
                context,
                icon: Icons.settings,
                title: 'Settings',
                onTap: () {
                  // TODO: Navigate to settings screen
                  Navigator.pop(context);
                },
              ),
              Spacer(),
              Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Sign Out', style: TextStyle(color: Colors.red)),
                onTap: () {
                  _showLogoutConfirmation(context);
                },
              ),
              SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingDrawer() {
    return Column(
      children: [
        UserAccountsDrawerHeader(
          accountName: Text('Loading...'),
          accountEmail: Text('Loading...'),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: CircularProgressIndicator(),
          ),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
          ),
        ),
        Expanded(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorDrawer() {
    return Column(
      children: [
        UserAccountsDrawerHeader(
          accountName: Text('Error'),
          accountEmail: Text('Failed to load user data'),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.error, color: Colors.red),
          ),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Failed to load user data',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // The drawer will automatically rebuild when popped and reopened
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

  Widget _buildDrawerItem(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }

  void _navigateToScreen(BuildContext context, int index) {
    Navigator.pop(context);
    final mainAppState = context.findAncestorStateOfType<_MainAppState>();
    if (mainAppState != null) {
      mainAppState.setState(() {
        mainAppState._currentIndex = index;
      });
    }
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
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close drawer
              _signOut();
            },
            child: Text(
              'Sign Out',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      // User will be automatically redirected to login screen due to auth state changes
    } catch (e) {
      print('Error signing out: $e');
    }
  }
}