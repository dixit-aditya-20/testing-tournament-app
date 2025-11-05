import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UserProfileScreen extends StatefulWidget {
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String _errorMessage = '';
  late TabController _tabController;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<DocumentSnapshot>? _walletSubscription;
  String? _userDocumentId;

  // Wallet data
  Map<String, dynamic> _walletData = {};
  List<dynamic> _transactions = [];
  List<dynamic> _withdrawalRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _walletSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not logged in';
        });
        return;
      }

      // Find user document
      final querySnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        _userDocumentId = doc.id;

        // Set up real-time listener for user data
        _userSubscription = _firestore
            .collection('users')
            .doc(_userDocumentId)
            .snapshots()
            .listen((doc) {
          _processUserDocument(doc);
        });

        // Load wallet data
        _loadWalletData();

        _processUserDocument(doc);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User profile not found. Please complete your registration.';
        });
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load user data: ${e.toString()}';
      });
    }
  }

  Future<void> _loadWalletData() async {
    try {
      if (_userDocumentId == null) return;

      // Listen to wallet data
      _walletSubscription = _firestore
          .collection('wallet')
          .doc('users')
          .collection(_userDocumentId!)
          .doc('wallet_data')
          .snapshots()
          .listen((doc) {
        if (doc.exists) {
          setState(() {
            _walletData = doc.data() as Map<String, dynamic>? ?? {};
          });
        }
      });

      // Load transactions
      final transactionsDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(_userDocumentId!)
          .doc('transactions')
          .get();

      if (transactionsDoc.exists) {
        final data = transactionsDoc.data() ?? {};
        setState(() {
          _transactions = [
            ...(data['successful'] ?? []),
            ...(data['failed'] ?? []),
            ...(data['pending'] ?? [])
          ];
        });
      }

      // Load withdrawal requests
      final withdrawalDoc = await _firestore
          .collection('wallet')
          .doc('users')
          .collection(_userDocumentId!)
          .doc('withdrawal_requests')
          .get();

      if (withdrawalDoc.exists) {
        final data = withdrawalDoc.data() ?? {};
        setState(() {
          _withdrawalRequests = [
            ...(data['approved'] ?? []),
            ...(data['denied'] ?? []),
            ...(data['failed'] ?? []),
            ...(data['pending'] ?? [])
          ];
        });
      }

    } catch (e) {
      print('Error loading wallet data: $e');
    }
  }

  void _processUserDocument(DocumentSnapshot doc) {
    if (!mounted) return;

    try {
      if (doc.exists) {
        final userData = doc.data() as Map<String, dynamic>? ?? {};

        setState(() {
          _user = userData;
          _isLoading = false;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User profile not found. Please complete your registration.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error processing user data: ${e.toString()}';
      });
    }
  }

  // WALLET FUNCTIONALITY METHODS
  Future<void> _addMoney(double amount) async {
    if (_userDocumentId == null) return;

    try {
      // Create transaction record with actual timestamp
      final currentTime = DateTime.now();
      final transaction = {
        'amount': amount,
        'type': 'deposit',
        'description': 'Wallet Deposit via Razorpay',
        'status': 'completed',
        'created_at': currentTime.millisecondsSinceEpoch,
        'timestamp': currentTime.millisecondsSinceEpoch,
        'transaction_id': 'DEP_${currentTime.millisecondsSinceEpoch}',
        'payment_method': 'razorpay', // Add payment method
      };

      // ... rest of your existing _addMoney code ...
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add money: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestWithdrawal(double amount) async {
    if (_userDocumentId == null) return;

    final currentBalance = (_walletData['total_balance'] ?? 0.0).toDouble();

    if (amount > currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance for withdrawal'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Minimum withdrawal amount is ₹100'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final withdrawalRequest = {
        'amount': amount,
        'status': 'pending',
        'requested_at': DateTime.now().millisecondsSinceEpoch, // Use actual timestamp
        'request_id': 'WD_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': _auth.currentUser?.uid,
        'user_name': _userDocumentId,
      };

      await _firestore
          .collection('wallet')
          .doc('users')
          .collection(_userDocumentId!)
          .doc('withdrawal_requests')
          .update({
        'pending': FieldValue.arrayUnion([withdrawalRequest]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Withdrawal request of ₹$amount submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit withdrawal request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Game ID Change Request System
  Future<void> _submitGameIdChangeRequest(String gameName, String newPlayerName, String newPlayerId) async {
    if (_userDocumentId == null) return;

    try {
      final gameFieldMap = {
        'BGMI': 'BGMI',
        'Free Fire': 'FREEFIRE',
        'Valorant': 'VALORANT',
        'COD Mobile': 'COD_MOBILE',
      };

      final field = gameFieldMap[gameName];
      if (field == null) return;

      // Get current values for reference
      final currentName = _getCurrentGameName(gameName);
      final currentId = _getCurrentGameId(gameName);

      // Create change request
      final changeRequest = {
        'game_name': gameName,
        'game_field': field,
        'current_player_name': currentName,
        'current_player_id': currentId,
        'requested_player_name': newPlayerName,
        'requested_player_id': newPlayerId,
        'status': 'pending',
        'requested_at': FieldValue.serverTimestamp(),
        'request_id': 'GID_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': _auth.currentUser?.uid,
        'user_name': _userDocumentId,
      };

      // Submit request to admin
      await _firestore
          .collection('users')
          .doc(_userDocumentId)
          .collection('changing_id_requests')
          .doc('${field}_${DateTime.now().millisecondsSinceEpoch}')
          .set(changeRequest);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$gameName ID change request submitted for admin approval!'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit change request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getCurrentGameName(String gameName) {
    final tournaments = _user?['tournaments'] ?? {};
    switch (gameName) {
      case 'BGMI': return tournaments['BGMI']?['BGMI_NAME'] ?? 'Not set';
      case 'Free Fire': return tournaments['FREEFIRE']?['FREEFIRE_NAME'] ?? 'Not set';
      case 'Valorant': return tournaments['VALORANT']?['VALORANT_NAME'] ?? 'Not set';
      case 'COD Mobile': return tournaments['COD_MOBILE']?['COD_MOBILE_NAME'] ?? 'Not set';
      default: return 'Not set';
    }
  }

  String _getCurrentGameId(String gameName) {
    final tournaments = _user?['tournaments'] ?? {};
    switch (gameName) {
      case 'BGMI': return tournaments['BGMI']?['BGMI_ID'] ?? 'Not set';
      case 'Free Fire': return tournaments['FREEFIRE']?['FREEFIRE_ID'] ?? 'Not set';
      case 'Valorant': return tournaments['VALORANT']?['VALORANT_ID'] ?? 'Not set';
      case 'COD Mobile': return tournaments['COD_MOBILE']?['COD_MOBILE_ID'] ?? 'Not set';
      default: return 'Not set';
    }
  }

  // UI BUILD METHODS
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.shade800,
            Colors.purple.shade600,
            Colors.deepPurple.shade900,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 3,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 18,
                ),
              ),
              Spacer(),
              if ((_user?['role'] ?? 'user') == 'admin')
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(width: 8),
            ],
          ),
          SizedBox(height: 16),
          Stack(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Icon(
                  Icons.person_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            _user?['name'] ?? 'User Name',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            _user?['email'] ?? 'user@example.com',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Level ${((_user?['totalTournamentsJoined'] ?? 0) / 10 + 1).toInt()} Player',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: 16),
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalBalance = (_walletData['total_balance'] ?? 0.0).toDouble();
    final totalWinning = (_walletData['total_winning'] ?? 0.0).toDouble();
    final totalMatches = _user?['totalMatches'] ?? 0;
    final winRate = _user?['winRate'] ?? 0.0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Balance',
            '₹${totalBalance.toStringAsFixed(0)}',
            Icons.account_balance_wallet_rounded,
            Colors.green,
          ),
          _buildStatItem(
            'Winnings',
            '₹${totalWinning.toStringAsFixed(0)}',
            Icons.emoji_events_rounded,
            Colors.amber,
          ),
          _buildStatItem(
            'Matches',
            '$totalMatches',
            Icons.sports_esports_rounded,
            Colors.blue,
          ),
          _buildStatItem(
            'Win Rate',
            '${winRate.toStringAsFixed(1)}%',
            Icons.trending_up_rounded,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.3),
                color.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Tab bar with proper sizing
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.deepPurple,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.deepPurple,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        tabs: [
          Tab(icon: Icon(Icons.person_rounded, size: 24), text: 'Profile'),
          Tab(icon: Icon(Icons.emoji_events_rounded, size: 24), text: 'Tournaments'),
          Tab(icon: Icon(Icons.sports_esports_rounded, size: 24), text: 'Matches'),
          Tab(icon: Icon(Icons.games_rounded, size: 24), text: 'Game IDs'),
          Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 24), text: 'Wallet'),
        ],
      ),
    );
  }

  // Profile Tab
  Widget _buildProfileTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildInfoCard(
          'Personal Information',
          Icons.person_outline_rounded,
          Colors.blue,
          [
            _buildInfoRow('Name', _user?['name'] ?? 'Not provided'),
            _buildInfoRow('Email', _user?['email'] ?? 'Not provided'),
            _buildInfoRow('Phone', _user?['phone'] ?? 'Not provided'),
            _buildInfoRow('User ID', _user?['uid'] ?? 'Not provided'),
            _buildInfoRow('Role', (_user?['role'] ?? 'user').toUpperCase()),
          ],
        ),
        SizedBox(height: 16),
        _buildInfoCard(
          'Tournament Stats',
          Icons.emoji_events_outlined,
          Colors.amber,
          [
            _buildInfoRow('Total Tournaments', '${_user?['totalTournamentsJoined'] ?? 0}'),
            _buildInfoRow('Tournaments Won', '${_user?['tournamentsWon'] ?? 0}'),
            _buildInfoRow('Active Tournaments', '${_user?['activeTournaments'] ?? 0}'),
            _buildInfoRow('Win Rate', '${(_user?['tournamentWinRate'] ?? 0.0).toStringAsFixed(1)}%'),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, IconData icon, Color color, List<Widget> children) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Tournaments Tab
  Widget _buildTournamentsTab() {
    final registrations = _user?['tournament_registrations'] ?? [];

    if (registrations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'No Tournament Registrations',
        message: 'Join tournaments to see your registration history here',
        actionText: 'Browse Tournaments',
        onAction: () {
          Navigator.pop(context);
        },
      );
    }

    return ListView(
      padding: EdgeInsets.all(12),
      children: [
        ...registrations.map((registration) => _buildTournamentCard(registration)).toList(),
      ],
    );
  }

  Widget _buildTournamentCard(dynamic registration) {
    final status = registration['status'] ?? 'unknown';
    final winnings = (registration['winnings'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(12),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getStatusColor(status).withOpacity(0.2),
                _getStatusColor(status).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getStatusIcon(status),
            color: _getStatusColor(status),
            size: 22,
          ),
        ),
        title: Text(
          registration['tournament_name']?.toString() ?? 'Unknown Tournament',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 2),
            Text(
              'Game: ${registration['game_name'] ?? 'Unknown'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            SizedBox(height: 2),
            Text(
              'Entry: ₹${(registration['entry_fee'] as num?)?.toDouble()?.toStringAsFixed(0) ?? '0'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            SizedBox(height: 2),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: winnings > 0 ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '₹${winnings.toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.green,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Won',
              style: TextStyle(
                color: Colors.green,
                fontSize: 9,
              ),
            ),
          ],
        ) : null,
      ),
    );
  }

  // Matches Tab
  Widget _buildMatchesTab() {
    final matches = _user?['matches'] ?? {};

    if (matches.isEmpty) {
      return _buildEmptyState(
        icon: Icons.sports_esports_outlined,
        title: 'No Match History',
        message: 'Play matches to see your performance history here',
        actionText: 'Join Tournament',
        onAction: () {
          Navigator.pop(context);
        },
      );
    }

    return ListView(
      padding: EdgeInsets.all(12),
      children: [
        if ((matches['recent_match'] as List?)?.isNotEmpty ?? false)
          _buildMatchSection('Recent Matches', matches['recent_match'] ?? [], Colors.blue),
        if ((matches['won_match'] as List?)?.isNotEmpty ?? false)
          _buildMatchSection('Won Matches', matches['won_match'] ?? [], Colors.green),
        if ((matches['loss_match'] as List?)?.isNotEmpty ?? false)
          _buildMatchSection('Lost Matches', matches['loss_match'] ?? [], Colors.red),
      ],
    );
  }

  Widget _buildMatchSection(String title, List<dynamic> matches, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.circle, color: color, size: 10),
              ),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(width: 6),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${matches.length}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...matches.map((match) => _buildMatchCard(match, title)).toList(),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMatchCard(dynamic match, String section) {
    final winnings = (match['winnings'] as num?)?.toDouble() ?? 0;
    final score = match['score']?.toString() ?? 'N/A';
    final position = match['position']?.toString() ?? 'N/A';

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(12),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getMatchResultColor(section).withOpacity(0.2),
                _getMatchResultColor(section).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getMatchResultIcon(section),
            color: _getMatchResultColor(section),
            size: 22,
          ),
        ),
        title: Text(
          match['tournament_name']?.toString() ?? 'Unknown Match',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 2),
            Text(
              'Game: ${match['game_name'] ?? 'Unknown'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            SizedBox(height: 2),
            Text(
              'Score: $score • Position: $position',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            SizedBox(height: 2),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _getMatchResultColor(section).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                section.toUpperCase(),
                style: TextStyle(
                  color: _getMatchResultColor(section),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: winnings > 0 ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '₹${winnings.toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.green,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Prize',
              style: TextStyle(
                color: Colors.green,
                fontSize: 9,
              ),
            ),
          ],
        ) : null,
      ),
    );
  }

  // Game IDs Tab
  Widget _buildGameIdsTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildGameIdCard(
          'BGMI',
          _getCurrentGameName('BGMI'),
          _getCurrentGameId('BGMI'),
          Icons.sports_esports_rounded,
          Colors.orange,
          'Battle Grounds Mobile India',
        ),
        SizedBox(height: 12),
        _buildGameIdCard(
          'Free Fire',
          _getCurrentGameName('Free Fire'),
          _getCurrentGameId('Free Fire'),
          Icons.gamepad_rounded,
          Colors.amber,
          'Free Fire Max',
        ),
        SizedBox(height: 12),
        _buildGameIdCard(
          'Valorant',
          _getCurrentGameName('Valorant'),
          _getCurrentGameId('Valorant'),
          Icons.computer_rounded,
          Colors.red,
          'Valorant',
        ),
        SizedBox(height: 12),
        _buildGameIdCard(
          'COD Mobile',
          _getCurrentGameName('COD Mobile'),
          _getCurrentGameId('COD Mobile'),
          Icons.military_tech_rounded,
          Colors.blue,
          'Call of Duty Mobile',
        ),
      ],
    );
  }

  Widget _buildGameIdCard(String gameName, String playerName, String playerId, IconData icon, Color color, String description) {
    final isSet = playerName != 'Not set' && playerId != 'Not set' && playerName.isNotEmpty && playerId.isNotEmpty;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.05),
              color.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gameName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSet ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSet ? Colors.green : Colors.grey,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isSet ? 'SET' : 'NOT SET',
                      style: TextStyle(
                        color: isSet ? Colors.green : Colors.grey,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildGameIdDetail('Player Name', playerName, Icons.person_rounded),
              SizedBox(height: 8),
              _buildGameIdDetail('Player ID', playerId, Icons.badge_rounded),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showEditGameIdDialog(gameName),
                icon: Icon(Icons.edit_rounded, size: 16),
                label: Text('Edit ${gameName} ID'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameIdDetail(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (value != 'Not set' && value.isNotEmpty)
            IconButton(
              icon: Icon(Icons.copy_rounded, size: 16),
              onPressed: () => _copyToClipboard(value, label),
              color: Colors.grey.shade600,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
        ],
      ),
    );
  }

  // Wallet Tab
  Widget _buildWalletTab() {
    final totalBalance = (_walletData['total_balance'] ?? 0.0).toDouble();
    final totalWinning = (_walletData['total_winning'] ?? 0.0).toDouble();

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildWalletSummary(totalBalance, totalWinning),
        SizedBox(height: 16),
        _buildWithdrawRequests(),
        SizedBox(height: 16),
        _buildTransactionHistory(),
      ],
    );
  }

  Widget _buildWalletSummary(double totalBalance, double totalWinning) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Balance',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '₹${totalBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Winnings',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '₹${totalWinning.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showWithdrawalDialog(),
                    icon: Icon(Icons.money_rounded, size: 18),
                    label: Text('Withdraw'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddMoneyDialog(),
                    icon: Icon(Icons.add_rounded, size: 18),
                    label: Text('Add Money'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: Colors.deepPurple),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawRequests() {
    if (_withdrawalRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.request_quote_outlined,
        title: 'No Withdrawal Requests',
        message: 'You haven\'t made any withdrawal requests yet',
        actionText: 'Request Withdrawal',
        onAction: () => _showWithdrawalDialog(),
      );
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.request_quote_rounded, color: Colors.deepPurple, size: 20),
                SizedBox(width: 6),
                Text(
                  'Withdrawal Requests',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ..._withdrawalRequests.map((request) {
              return _buildWithdrawalRequestCard(request);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalRequestCard(Map<String, dynamic> request) {
    final status = request['status'] ?? 'pending';
    final amount = (request['amount'] as num?)?.toDouble() ?? 0;
    final date = request['requested_at'];

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getWithdrawalStatusColor(status).withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _getWithdrawalStatusColor(status).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getWithdrawalStatusIcon(status),
            color: _getWithdrawalStatusColor(status),
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Status: ${_formatWithdrawalStatus(status)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
                if (request['request_id'] != null) ...[
                  SizedBox(height: 2),
                  Text(
                    'ID: ${request['request_id']}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 9,
                    ),
                  ),
                ]
              ],
            ),
          ),
          Text(
            _formatDate(date),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory() {
    if (_transactions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_outlined,
        title: 'No Transactions',
        message: 'Your transaction history will appear here',
        actionText: 'Add Money',
        onAction: () => _showAddMoneyDialog(),
      );
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, color: Colors.deepPurple, size: 20),
                SizedBox(width: 6),
                Text(
                  'Transaction History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ..._transactions.map((transaction) {
              return _buildTransactionCard(transaction);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final type = transaction['type'] ?? 'unknown';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
    final description = transaction['description']?.toString() ?? 'Unknown Transaction';
    final status = transaction['status'] ?? 'completed';
    final date = transaction['created_at'];

    // Parse the date with better error handling
    String displayDate;
    try {
      displayDate = _formatDate(date);

      // If it's still showing "Just now" but the transaction is old, force actual date
      if (displayDate == 'Just now') {
        DateTime transactionDate;
        if (date is Timestamp) {
          transactionDate = date.toDate();
        } else if (date is int) {
          transactionDate = DateTime.fromMillisecondsSinceEpoch(date);
        } else {
          transactionDate = DateTime.now().subtract(Duration(days: 1)); // Default to yesterday
        }
        displayDate = DateFormat('MMM dd, yyyy').format(transactionDate);
      }
    } catch (e) {
      // Fallback to current date if parsing fails
      displayDate = DateFormat('MMM dd, yyyy').format(DateTime.now());
    }

    // Determine if this is a Razorpay transaction
    final isRazorpayTransaction = description.toLowerCase().contains('razorpay') ||
        description.toLowerCase().contains('wallet deposit') ||
        transaction['payment_method']?.toString().toLowerCase().contains('razorpay') == true;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRazorpayTransaction
            ? Colors.purple.shade50  // Light purple background for Razorpay
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: isRazorpayTransaction
            ? Border.all(color: Colors.purple.shade100, width: 1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isRazorpayTransaction
                  ? Colors.purple.withOpacity(0.1)  // Purple for Razorpay
                  : _getTransactionColor(type).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRazorpayTransaction
                  ? Icons.payment_rounded  // Payment icon for Razorpay
                  : _getTransactionIcon(type),
              color: isRazorpayTransaction
                  ? Colors.purple  // Purple color for Razorpay
                  : _getTransactionColor(type),
              size: 18,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isRazorpayTransaction ? Colors.purple.shade800 : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  'Status: ${_formatTransactionStatus(status)}',
                  style: TextStyle(
                    color: isRazorpayTransaction ? Colors.purple.shade600 : Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: isRazorpayTransaction ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                if (isRazorpayTransaction) ...[
                  SizedBox(height: 2),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'RAZORPAY',
                      style: TextStyle(
                        color: Colors.purple,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (transaction['transaction_id'] != null) ...[
                  SizedBox(height: 2),
                  Text(
                    'ID: ${transaction['transaction_id']}',
                    style: TextStyle(
                      color: isRazorpayTransaction ? Colors.purple.shade500 : Colors.grey.shade500,
                      fontSize: 9,
                    ),
                  ),
                ]
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_getTransactionAmountPrefix(type)}₹${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isRazorpayTransaction
                      ? Colors.purple  // Purple for Razorpay amounts
                      : _getTransactionAmountColor(type),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Text(
                displayDate,
                style: TextStyle(
                  color: isRazorpayTransaction ? Colors.purple.shade600 : Colors.grey.shade600,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper Methods
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey.shade400),
            ),
            SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(actionText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // UPDATED Date Formatting Method - Fixed to show actual dates
  // UPDATED Date Formatting Method - Fixed to handle transaction dates properly
  String _formatDate(dynamic date) {
    try {
      // If date is null, return current time
      if (date == null) {
        return DateFormat('MMM dd, yyyy').format(DateTime.now());
      }

      DateTime dateTime;

      if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(date);
      } else if (date is String) {
        dateTime = DateTime.tryParse(date) ?? DateTime.now();
      } else {
        dateTime = DateTime.now();
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      // For debugging - print the actual date
      print('Transaction Date: $dateTime, Difference: $difference');

      // Show relative time for recent transactions, actual date for older ones
      if (difference.inDays == 0) {
        if (difference.inHours < 1) {
          if (difference.inMinutes < 1) {
            return 'Just now';
          }
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM dd, yyyy').format(dateTime);
      }
    } catch (e) {
      print('Error formatting date: $e, date value: $date');
      // If any error occurs, return current time formatted
      return DateFormat('MMM dd, yyyy').format(DateTime.now());
    }
  }

  // Status and Color Helpers
  Color _getStatusColor(String status) {
    switch (status) {
      case 'registered': return Colors.blue;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'registered': return Icons.hourglass_empty_rounded;
      case 'completed': return Icons.check_circle_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      default: return Icons.help_rounded;
    }
  }

  Color _getMatchResultColor(String section) {
    switch (section) {
      case 'Won Matches': return Colors.green;
      case 'Lost Matches': return Colors.red;
      default: return Colors.blue;
    }
  }

  IconData _getMatchResultIcon(String section) {
    switch (section) {
      case 'Won Matches': return Icons.emoji_events_rounded;
      case 'Lost Matches': return Icons.sentiment_dissatisfied_rounded;
      default: return Icons.sports_esports_rounded;
    }
  }

  Color _getWithdrawalStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getWithdrawalStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.pending_actions_rounded;
      case 'approved': return Icons.check_circle_rounded;
      case 'rejected': return Icons.cancel_rounded;
      default: return Icons.help_rounded;
    }
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'deposit': return Colors.green;
      case 'winning': return Colors.amber.shade700;
      case 'withdrawal': return Colors.blue;
      case 'entry_fee': return Colors.red;
      case 'refund': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'deposit': return Icons.add_circle_rounded;
      case 'winning': return Icons.emoji_events_rounded;
      case 'withdrawal': return Icons.remove_circle_rounded;
      case 'entry_fee': return Icons.payment_rounded;
      case 'refund': return Icons.assignment_return_rounded;
      default: return Icons.receipt_rounded;
    }
  }

  Color _getTransactionAmountColor(String type) {
    switch (type) {
      case 'deposit':
      case 'winning':
      case 'refund': return Colors.green;
      case 'withdrawal':
      case 'entry_fee': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getTransactionAmountPrefix(String type) {
    switch (type) {
      case 'deposit':
      case 'winning':
      case 'refund': return '+';
      case 'withdrawal':
      case 'entry_fee': return '-';
      default: return '';
    }
  }

  String _formatWithdrawalStatus(String status) {
    return status.toUpperCase();
  }

  String _formatTransactionStatus(String status) {
    return status.toUpperCase();
  }

  // Dialogs
  void _showEditGameIdDialog(String gameName) {
    final nameController = TextEditingController();
    final idController = TextEditingController();

    // Pre-fill existing values
    nameController.text = _getCurrentGameName(gameName);
    idController.text = _getCurrentGameId(gameName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request $gameName ID Change'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your request will be sent to admin for approval',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'New Player Name',
                border: OutlineInputBorder(),
                hintText: 'Enter your new in-game name',
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: idController,
              decoration: InputDecoration(
                labelText: 'New Player ID',
                border: OutlineInputBorder(),
                hintText: 'Enter your new game ID',
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Changes require admin approval for security',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && idController.text.isNotEmpty) {
                Navigator.pop(context);
                _submitGameIdChangeRequest(gameName, nameController.text, idController.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please fill both fields'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  void _showAddMoneyDialog() {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Money to Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter amount to add to your wallet:'),
            SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '₹',
                border: OutlineInputBorder(),
                labelText: 'Amount',
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Minimum amount: ₹10',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount >= 10) {
                Navigator.pop(context);
                _addMoney(amount);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter at least ₹10'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Add Money'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawalDialog() {
    final amountController = TextEditingController();
    final totalBalance = (_walletData['total_balance'] ?? 0.0).toDouble();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available Balance: ₹${totalBalance.toStringAsFixed(2)}'),
            SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '₹',
                border: OutlineInputBorder(),
                labelText: 'Withdrawal Amount',
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Minimum withdrawal: ₹100',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount >= 100 && amount <= totalBalance) {
                Navigator.pop(context);
                _requestWithdrawal(amount);
              } else if (amount < 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Minimum withdrawal amount is ₹100'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Insufficient balance'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Request Withdrawal'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.deepPurple,
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                'Loading Profile...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
              ),
              SizedBox(height: 20),
              Text(
                'Oops! Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadUserData,
                icon: Icon(Icons.refresh_rounded),
                label: Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                _buildTabBar(),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildProfileTab(),
            _buildTournamentsTab(),
            _buildMatchesTab(),
            _buildGameIdsTab(),
            _buildWalletTab(),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverAppBarDelegate(this.child);

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}