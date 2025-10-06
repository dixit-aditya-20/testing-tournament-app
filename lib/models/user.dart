class UserModel {
  final String uid;
  final String name;
  int wallet;

  UserModel({required this.uid, required this.name, this.wallet = 0});
}
