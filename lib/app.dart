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
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _firebaseService.getUserProfile(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          return Column(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(
                  user?['name'] ?? 'User',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(user?['email'] ?? 'user@example.com'),
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
              ListTile(
                leading: Icon(Icons.account_balance_wallet),
                title: Text('Wallet Balance'),
                trailing: Text(
                  '₹${user?['walletBalance']?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
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
              Spacer(),
              Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Sign Out', style: TextStyle(color: Colors.red)),
                onTap: () {
                  FirebaseAuth.instance.signOut();
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
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
    if (context.findAncestorStateOfType<_MainAppState>() != null) {
      context.findAncestorStateOfType<_MainAppState>()!.setState(() {
        context.findAncestorStateOfType<_MainAppState>()!._currentIndex = index;
      });
    }
  }
}