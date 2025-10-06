// ===============================
// HOME SCREEN WITH HIDDEN ADMIN ACCESS
// ===============================
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase_service.dart';
import 'tournament_list_screen.dart';
import 'admin_panel_screen.dart'; // your admin panel file

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, dynamic>> games = [
    {
      "name": "BGMI",
      "image": "https://w0.peakpx.com/wallpaper/742/631/HD-wallpaper-bgmi-trending-pubg-bgmi-iammsa-pubg.jpg",
    },
    {
      "name": "Free Fire",
      "image": "https://wallpapers.com/images/high/free-fire-logo-armed-woman-fdsbmr41d528ty45.webp",
    },
    {
      "name": "Valorant",
      "image": "https://w0.peakpx.com/wallpaper/522/122/HD-wallpaper-valorant-reyna-background-game-phone.jpg",
    },
    {
      "name": "COD Mobile",
      "image": "https://wallpapers.com/images/high/yellow-call-of-duty-phone-qh4ng5sccotp6hlh.webp",
    },
  ];

  int _tapCount = 0;
  final int _requiredTaps = 7; // Number of taps to unlock admin
  final String _secretPin = "1234"; // Set your secret PIN

  void _handleSecretTap() {
    _tapCount++;
    if (_tapCount >= _requiredTaps) {
      _tapCount = 0;
      _showAdminPinDialog();
    }
  }

  void _showAdminPinDialog() {
    final TextEditingController pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Enter Admin PIN"),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: InputDecoration(hintText: "Enter secret PIN"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (pinController.text == _secretPin) {
                Navigator.pop(context);
                await _checkAdminRoleAndOpenPanel();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Incorrect PIN")),
                );
              }
            },
            child: Text("Enter"),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAdminRoleAndOpenPanel() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final role = doc.data()?['role'] ?? 'user';

    if (role == 'admin') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminPanelScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Access Denied: Admins Only")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final PageController pageController = PageController();

    return Stack(
      children: [
        PageView.builder(
          controller: pageController,
          scrollDirection: Axis.horizontal,
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];

            return Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    game['image'],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[300],
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (c, e, s) => Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.error, size: 50, color: Colors.grey),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(0.3)),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 8,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TournamentListScreen(
                                gameName: game['name'],
                                gameImage: game['image'],
                              ),
                            ),
                          );
                        },
                        child: Text(
                          "Register Now",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      // In your navigation or drawer
                      ListTile(
                        leading: Icon(Icons.admin_panel_settings),
                        title: Text('Admin Panel'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AdminPanelScreen()),
                          );
                        },
                      ),
                      GestureDetector(
                        onTap: _handleSecretTap, // Hidden admin tap
                        child: Text(
                          game['name'],
                          style: TextStyle(
                            fontSize: 50,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.black,
                                offset: Offset(2, 2),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        Positioned(
          left: 10,
          top: 0,
          bottom: 0,
          child: Center(
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios, size: 40, color: Colors.white),
              onPressed: () {
                if (pageController.hasClients && pageController.page! > 0) {
                  pageController.previousPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ),
        ),
        Positioned(
          right: 10,
          top: 0,
          bottom: 0,
          child: Center(
            child: IconButton(
              icon: Icon(Icons.arrow_forward_ios, size: 40, color: Colors.white),
              onPressed: () {
                if (pageController.hasClients && pageController.page! < games.length - 1) {
                  pageController.nextPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
