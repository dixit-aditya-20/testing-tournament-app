import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  String? userId;

  void login(String uid) {
    userId = uid;
    notifyListeners();
  }

  void logout() {
    userId = null;
    notifyListeners();
  }
}
