import 'package:flutter/material.dart';

class WalletProvider extends ChangeNotifier {
  int balance = 0;

  void addMoney(int amount) {
    balance += amount;
    notifyListeners();
  }

  void deductMoney(int amount) {
    balance -= amount;
    notifyListeners();
  }
}
