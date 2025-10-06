// ===============================
// NOTIFICATIONS SCREEN
// ===============================
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupFCM();
  }

  Future<void> _setupFCM() async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await _firebaseService.saveFCMToken(fcmToken);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Handle foreground notifications
      _showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Handle when app is opened from notification
      _handleNotificationClick(message);
    });
  }

  void _showNotification(RemoteMessage message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.notification?.title ?? 'New Notification'),
        backgroundColor: Colors.deepPurple,
      ),
    );
    _loadNotifications();
  }

  void _handleNotificationClick(RemoteMessage message) {
    // Handle notification click action
    print('Notification clicked: ${message.data}');
  }

  Future<void> _loadNotifications() async {
    final notifications = await _firebaseService.getUserNotifications();
    setState(() {
      _notifications = notifications;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _notifications.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'No notifications',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              'You\'ll see tournament updates and results here',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationItem(notification);
        },
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.notifications,
          color: Colors.deepPurple,
        ),
        title: Text(notification['title']),
        subtitle: Text(notification['body']),
        trailing: Text(
          notification['time'],
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }
}