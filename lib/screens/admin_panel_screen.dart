import 'package:dynamic_and_api/modles/user_registration_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';

class AdminPanelScreen extends StatefulWidget {
  @override
  _AdminPanelScreenState createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _tournaments = [];
  List<AppUser> _users = [];
  List<Map<String, dynamic>> _withdrawRequests = [];
  List<Map<String, dynamic>> _matchCredentials = [];
  List<Map<String, dynamic>> _recentRegistrations = [];

  bool _isLoading = true;
  bool _isAdmin = false;
  int _currentIndex = 0;

  // Statistics
  int _totalUsers = 0;
  int _totalTournaments = 0;
  int _pendingWithdrawals = 0;
  double _totalRevenue = 0.0;
  int _activeTournaments = 0;
  int _todayRegistrations = 0;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showAccessDenied();
        return;
      }

      final userQuery = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userData = userQuery.docs.first.data();
        final role = userData['role'] as String? ?? 'user';

        if (role == 'admin') {
          setState(() {
            _isAdmin = true;
          });
          _loadData();
        } else {
          _showAccessDenied();
        }
      } else {
        _showAccessDenied();
      }
    } catch (e) {
      print('❌ Error checking admin access: $e');
      _showAccessDenied();
    }
  }

  void _showAccessDenied() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red),
              SizedBox(width: 12),
              Text('Access Denied', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('You do not have permission to access the admin panel.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple,
              ),
              child: Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _loadData() async {
    try {
      await Future.wait([
        _loadUsers(),
        _loadTournaments(),
        _loadWithdrawRequests(),
        _loadMatchCredentials(),
        _loadRecentRegistrations(),
        _loadStatistics(),
      ]);
    } catch (e) {
      print('❌ Error loading admin data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    try {
      print('👥 Loading users...');
      final usersSnapshot = await _firestore.collection('users').get();

      List<AppUser> loadedUsers = [];

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userName = userDoc.id;

        double totalBalance = 0.0;
        double totalWinning = 0.0;

        try {
          final walletDataDoc = await _firestore
              .collection('wallet')
              .doc('users')
              .collection(userName)
              .doc('wallet_data')
              .get();

          if (walletDataDoc.exists) {
            final walletData = walletDataDoc.data();
            totalBalance = (walletData?['total_balance'] as num?)?.toDouble() ?? 0.0;
            totalWinning = (walletData?['total_winning'] as num?)?.toDouble() ?? 0.0;
          }
        } catch (e) {
          print('⚠️ Error loading wallet for user $userName: $e');
        }

        loadedUsers.add(AppUser(
          userId: userData['uid'] ?? userDoc.id,
          email: userData['email'] ?? 'No Email',
          name: userData['name'] ?? userName,
          phone: userData['phone'] ?? '',
          fcmToken: userData['fcmToken'] ?? '',
          totalWinning: totalWinning,
          totalBalance: totalBalance,
          createdAt: (userData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastLogin: (userData['last_login'] as Timestamp?)?.toDate() ?? DateTime.now(),
          tournaments: userData['tournaments'] ?? {},
          matches: userData['matches'] ?? {},
          withdrawRequests: [],
          transactions: [],
          tournamentRegistrations: userData['tournament_registrations'] ?? [],
          role: userData['role'] ?? 'user',
        ));
      }

      setState(() {
        _users = loadedUsers;
      });
      print('✅ Users loaded: ${_users.length}');
    } catch (e) {
      print('❌ Error loading users: $e');
    }
  }

  Future<void> _loadTournaments() async {
    try {
      print('🏆 Loading tournaments...');
      final snapshot = await _firestore.collection('tournaments').get();

      setState(() {
        _tournaments = snapshot.docs.map((doc) {
          final data = doc.data();
          final totalSlots = (data['total_slots'] as num?)?.toInt() ?? 0;
          final registeredPlayers = (data['registered_players'] as num?)?.toInt() ?? 0;

          return {
            'id': doc.id,
            ...data,
            'slots_left': totalSlots - registeredPlayers,
            'tournament_name': data['tournament_name'] ?? 'Unnamed Tournament',
            'game_name': data['game_name'] ?? 'Unknown Game',
            'entry_fee': (data['entry_fee'] as num?)?.toDouble() ?? 0.0,
            'status': data['status'] ?? 'unknown',
          };
        }).toList();
      });
      print('✅ Tournaments loaded: ${_tournaments.length}');
    } catch (e) {
      print('❌ Error loading tournaments: $e');
      setState(() {
        _tournaments = [];
      });
    }
  }

  Future<void> _loadWithdrawRequests() async {
    try {
      print('💰 Loading withdrawal requests...');
      final List<Map<String, dynamic>> allWithdrawRequests = [];

      final usersSnapshot = await _firestore.collection('users').get();

      for (var userDoc in usersSnapshot.docs) {
        final userName = userDoc.id;
        final userData = userDoc.data();

        try {
          final withdrawSnapshot = await _firestore
              .collection('wallet')
              .doc('users')
              .collection(userName)
              .doc('withdrawal_requests')
              .get();

          if (withdrawSnapshot.exists) {
            final withdrawData = withdrawSnapshot.data() ?? {};
            final pendingRequests = withdrawData['pending'] as List<dynamic>? ?? [];

            for (var request in pendingRequests) {
              if (request is Map<String, dynamic>) {
                allWithdrawRequests.add({
                  'id': request['withdrawal_id'] ?? '${DateTime.now().millisecondsSinceEpoch}',
                  'userId': userName,
                  'userEmail': userData['email'] ?? 'No Email',
                  'userName': userData['name'] ?? userName,
                  'amount': (request['amount'] as num?)?.toDouble() ?? 0.0,
                  'payment_method': request['payment_method'] ?? 'No Method',
                  'account_details': request['account_details'] ?? 'No Details',
                  'status': 'pending',
                  'requested_at': request['requested_at'] ?? Timestamp.now(),
                  'timestamp': request['timestamp'] ?? Timestamp.now(),
                });
              }
            }
          }
        } catch (e) {
          print('⚠️ Error loading withdrawals for user $userName: $e');
        }
      }

      allWithdrawRequests.sort((a, b) {
        final timeA = a['timestamp'] as Timestamp;
        final timeB = b['timestamp'] as Timestamp;
        return timeB.compareTo(timeA);
      });

      setState(() {
        _withdrawRequests = allWithdrawRequests;
      });
      print('✅ Withdrawal requests loaded: ${_withdrawRequests.length}');
    } catch (e) {
      print('❌ Error loading withdraw requests: $e');
    }
  }

  Future<void> _loadMatchCredentials() async {
    try {
      final snapshot = await _firestore
          .collection('matchCredentials')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _matchCredentials = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'tournamentId': data['tournamentId'],
            'tournamentName': _getTournamentName(data['tournamentId']),
            'roomId': data['roomId'],
            'roomPassword': data['roomPassword'],
            'matchTime': data['matchTime'],
            'credentialsAddedAt': data['credentialsAddedAt'],
            'status': data['status'] ?? 'active',
            'participants': (data['participants'] as List?)?.length ?? 0,
            'createdAt': data['createdAt'],
          };
        }).toList();
      });
      print('✅ Match credentials loaded: ${_matchCredentials.length}');
    } catch (e) {
      print('❌ Error loading match credentials: $e');
    }
  }

  Future<void> _loadRecentRegistrations() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final registrations = await _firestore
          .collection('tournament_registrations')
          .where('registered_at', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();

      setState(() {
        _recentRegistrations = registrations.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
            'user_name': data['user_name'] ?? 'Unknown User',
            'tournament_name': data['tournament_name'] ?? 'Unknown Tournament',
            'registered_at': data['registered_at'],
          };
        }).toList();
        _todayRegistrations = _recentRegistrations.length;
      });
    } catch (e) {
      print('❌ Error loading recent registrations: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      print('📈 Loading statistics...');

      final usersSnapshot = await _firestore.collection('users').get();
      final tournamentsSnapshot = await _firestore.collection('tournaments').get();

      double totalRevenue = 0.0;
      for (var tournament in _tournaments) {
        final entryFee = (tournament['entry_fee'] as num?)?.toDouble() ?? 0.0;
        final registeredPlayers = (tournament['registered_players'] as num?)?.toInt() ?? 0;
        totalRevenue += entryFee * registeredPlayers;
      }

      setState(() {
        _totalUsers = usersSnapshot.docs.length;
        _totalTournaments = tournamentsSnapshot.docs.length;
        _activeTournaments = _tournaments.where((t) => t['status'] == 'upcoming').length;
        _pendingWithdrawals = _withdrawRequests.length;
        _totalRevenue = totalRevenue;
      });

      print('''
      📊 Statistics Loaded:
      - Users: $_totalUsers
      - Tournaments: $_totalTournaments
      - Active Tournaments: $_activeTournaments
      - Pending Withdrawals: $_pendingWithdrawals
      - Total Revenue: $_totalRevenue
      ''');
    } catch (e) {
      print('❌ Error loading statistics: $e');
    }
  }

  String _getTournamentName(String tournamentId) {
    final tournament = _tournaments.firstWhere(
          (t) => t['id'] == tournamentId,
      orElse: () => {'tournament_name': 'Unknown Tournament'},
    );
    return tournament['tournament_name'];
  }

  // ENHANCED: Tournament Management with Prize Distribution
  Future<void> _createTournament(Map<String, dynamic> tournamentData) async {
    try {
      final totalSlots = tournamentData['total_slots'] as int;
      final slotsLeft = totalSlots;

      final completeData = {
        ...tournamentData,
        'slots_left': slotsLeft,
        'registered_players': 0,
        'status': 'upcoming',
        'created_at': Timestamp.now(),
        'updated_at': Timestamp.now(),
        'joined_players': [],
        'roomId': '',
        'roomPassword': '',
        'credentialsAddedAt': null,
        'credentialsMatchTime': null,
      };

      await _firestore.collection('tournaments').add(completeData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Tournament created successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadTournaments();
      await _loadStatistics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error creating tournament: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateTournamentStatus(String tournamentId, String status) async {
    try {
      await _firestore.collection('tournaments').doc(tournamentId).update({
        'status': status,
        'updated_at': Timestamp.now(),
      });

      if (status == 'completed') {
        final tournament = _tournaments.firstWhere((t) => t['id'] == tournamentId);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPrizeDistributionDialog(tournamentId, tournament);
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tournament status updated to $status'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadTournaments();
      await _loadStatistics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating tournament: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Enhanced Prize Distribution
  Future<void> _distributePrizesWithCustomSplit(String tournamentId, List<Map<String, dynamic>> prizeDistribution) async {
    try {
      final tournamentDoc = await _firestore.collection('tournaments').doc(tournamentId).get();
      if (!tournamentDoc.exists) return;

      final tournamentData = tournamentDoc.data()!;
      final joinedPlayers = List.from(tournamentData['joined_players'] ?? []);
      final prizePool = (tournamentData['winning_prize'] as num).toDouble();

      double totalDistributed = prizeDistribution.fold(0.0, (sum, prize) => sum + (prize['amount'] as double));

      if (totalDistributed > prizePool) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Total prize distribution exceeds prize pool!'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      for (int i = 0; i < prizeDistribution.length && i < joinedPlayers.length; i++) {
        final prize = prizeDistribution[i];
        final playerName = joinedPlayers[i];
        final prizeAmount = prize['amount'] as double;
        final position = prize['position'] as int;

        await _creditPrizeToPlayer(playerName, prizeAmount, tournamentData['tournament_name'], position);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🏆 Prizes distributed successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error distributing prizes: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _creditPrizeToPlayer(String playerName, double amount, String tournamentName, int position) async {
    try {
      final walletRef = _firestore
          .collection('wallet')
          .doc('users')
          .collection(playerName)
          .doc('wallet_data');

      final walletSnapshot = await walletRef.get();
      if (walletSnapshot.exists) {
        await walletRef.update({
          'total_balance': FieldValue.increment(amount),
          'total_winning': FieldValue.increment(amount),
          'updatedAt': Timestamp.now(),
        });

        final transactionsRef = _firestore
            .collection('wallet')
            .doc('users')
            .collection(playerName)
            .doc('transactions');

        await transactionsRef.set({
          'successful': FieldValue.arrayUnion([{
            'transaction_id': 'prize_${DateTime.now().millisecondsSinceEpoch}',
            'amount': amount,
            'type': 'prize',
            'description': '${_getPositionSuffix(position)} Prize from $tournamentName',
            'status': 'completed',
            'timestamp': Timestamp.now(),
          }])
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error crediting prize to player: $e');
    }
  }

  String _getPositionSuffix(int position) {
    switch (position) {
      case 1: return '${position}st';
      case 2: return '${position}nd';
      case 3: return '${position}rd';
      default: return '${position}th';
    }
  }

  void _showPrizeDistributionDialog(String tournamentId, Map<String, dynamic> tournament) {
    showDialog(
      context: context,
      builder: (context) => PrizeDistributionDialog(
        tournament: tournament,
        onPrizeDistributed: (distribution) {
          _distributePrizesWithCustomSplit(tournamentId, distribution);
        },
      ),
    );
  }

  // ENHANCED: Match Credentials Management
  Future<void> _addMatchCredentials(Map<String, dynamic> credentialData) async {
    try {
      final tournamentId = credentialData['tournamentId'];
      final roomId = credentialData['roomId'];
      final roomPassword = credentialData['roomPassword'];
      final matchTime = credentialData['matchTime'];

      await _firestore.collection('tournaments').doc(tournamentId).update({
        'roomId': roomId,
        'roomPassword': roomPassword,
        'credentialsMatchTime': matchTime,
        'credentialsAddedAt': Timestamp.now(),
        'updated_at': Timestamp.now(),
      });

      await _firestore.collection('matchCredentials').add({
        'tournamentId': tournamentId,
        'tournamentName': credentialData['tournamentName'],
        'roomId': roomId,
        'roomPassword': roomPassword,
        'matchTime': matchTime,
        'status': 'active',
        'participants': credentialData['participants'] ?? [],
        'createdAt': Timestamp.now(),
        'releasedAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔐 Match credentials added successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadMatchCredentials();
      await _loadTournaments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error adding match credentials: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Withdrawal Management
  Future<void> _updateWithdrawStatus(String requestId, String status) async {
    try {
      final request = _withdrawRequests.firstWhere((req) => req['id'] == requestId);
      final userName = request['userId'];
      final amount = request['amount'] as double;

      if (userName == null) {
        throw Exception('User name not found in withdrawal request');
      }

      final withdrawRef = _firestore
          .collection('wallet')
          .doc('users')
          .collection(userName)
          .doc('withdrawal_requests');

      final withdrawSnapshot = await withdrawRef.get();

      if (!withdrawSnapshot.exists) {
        throw Exception('Withdrawal document not found for user: $userName');
      }

      final withdrawData = withdrawSnapshot.data() ?? {};
      final pendingRequests = withdrawData['pending'] as List<dynamic>? ?? [];

      final requestIndex = pendingRequests.indexWhere((req) {
        if (req is Map<String, dynamic>) {
          final reqId = req['withdrawal_id'] ?? req['id'];
          return reqId == requestId;
        }
        return false;
      });

      if (requestIndex == -1) {
        throw Exception('Withdrawal request not found in pending list');
      }

      final requestToUpdate = Map<String, dynamic>.from(pendingRequests[requestIndex] as Map<String, dynamic>);

      final updatedPending = List<dynamic>.from(pendingRequests);
      updatedPending.removeAt(requestIndex);

      final updateData = <String, dynamic>{
        'pending': updatedPending,
      };

      if (status == 'approved') {
        final approvedRequests = withdrawData['approved'] as List<dynamic>? ?? [];
        requestToUpdate['status'] = 'approved';
        requestToUpdate['processed_at'] = Timestamp.now();

        updateData['approved'] = FieldValue.arrayUnion([requestToUpdate]);
      } else if (status == 'denied') {
        final deniedRequests = withdrawData['denied'] as List<dynamic>? ?? [];
        requestToUpdate['status'] = 'denied';
        requestToUpdate['processed_at'] = Timestamp.now();

        updateData['denied'] = FieldValue.arrayUnion([requestToUpdate]);

        final balanceRef = _firestore
            .collection('wallet')
            .doc('users')
            .collection(userName)
            .doc('wallet_data');

        final balanceSnapshot = await balanceRef.get();
        if (balanceSnapshot.exists) {
          await balanceRef.update({
            'total_balance': FieldValue.increment(amount),
            'updatedAt': Timestamp.now(),
          });
        }
      }

      await withdrawRef.update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Withdrawal $status successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadWithdrawRequests();
      await _loadStatistics();

    } catch (e) {
      print('❌ Error updating withdrawal status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error updating withdrawal: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Delete Methods
  Future<void> _deleteTournament(String tournamentId) async {
    try {
      await _firestore.collection('tournaments').doc(tournamentId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ Tournament deleted successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadTournaments();
      await _loadStatistics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error deleting tournament: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteMatchCredentials(String credentialId) async {
    try {
      await _firestore.collection('matchCredentials').doc(credentialId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ Match credentials deleted successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadMatchCredentials();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error deleting credentials: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // FIXED: RESPONSIVE DASHBOARD COMPONENTS
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Welcome Header
          _buildWelcomeHeader(),
          SizedBox(height: 16),

          // Statistics Grid - Responsive
          _buildStatisticsSection(),
          SizedBox(height: 16),

          // Quick Actions
          _buildQuickActions(),
          SizedBox(height: 16),

          // Recent Activity
          _buildRecentActivity(),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Manage your gaming platform',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            'Platform Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        _buildStatisticsGrid(),
      ],
    );
  }

  Widget _buildStatisticsGrid() {
    final stats = [
      {'title': 'Total Users', 'value': _totalUsers, 'icon': Icons.people_alt_rounded, 'color': Colors.blue, 'bgColor': Colors.blue.shade50},
      {'title': 'Tournaments', 'value': _totalTournaments, 'icon': Icons.tour_rounded, 'color': Colors.green, 'bgColor': Colors.green.shade50},
      {'title': 'Pending Withdrawals', 'value': _pendingWithdrawals, 'icon': Icons.payment_rounded, 'color': Colors.orange, 'bgColor': Colors.orange.shade50},
      {'title': 'Today Registrations', 'value': _todayRegistrations, 'icon': Icons.how_to_reg_rounded, 'color': Colors.purple, 'bgColor': Colors.purple.shade50},
      {'title': 'Active Tournaments', 'value': _activeTournaments, 'icon': Icons.event_available_rounded, 'color': Colors.teal, 'bgColor': Colors.teal.shade50},
      {'title': 'Total Revenue', 'value': _totalRevenue, 'icon': Icons.attach_money_rounded, 'color': Colors.indigo, 'bgColor': Colors.indigo.shade50, 'isMoney': true},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        final childAspectRatio = constraints.maxWidth > 600 ? 1.4 : 1.2;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: childAspectRatio,
          ),
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            return _buildModernStatCard(
              stat['title'] as String,
              stat['isMoney'] == true ? '₹${(stat['value'] as double).toStringAsFixed(0)}' : stat['value'].toString(),
              stat['icon'] as IconData,
              stat['color'] as Color,
              stat['bgColor'] as Color,
            );
          },
        );
      },
    );
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                Icon(Icons.more_vert_rounded, color: Colors.grey.shade400, size: 14),
              ],
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'label': 'Add Tournament', 'icon': Icons.add_box_rounded, 'color': Colors.deepPurple, 'onTap': _showAddTournamentDialog},
      {'label': 'Manage Credentials', 'icon': Icons.lock_rounded, 'color': Colors.indigo, 'onTap': _showAddCredentialsDialog},
      {'label': 'View Withdrawals', 'icon': Icons.payment_rounded, 'color': Colors.orange, 'onTap': () => _navigateToTab(3)},
      {'label': 'User Management', 'icon': Icons.people_alt_rounded, 'color': Colors.blue, 'onTap': () => _navigateToTab(2)},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions.map((action) {
                return _buildModernActionChip(
                  action['label'] as String,
                  action['icon'] as IconData,
                  action['color'] as Color,
                  action['onTap'] as VoidCallback,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernActionChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _recentRegistrations.isEmpty
                ? _buildEmptyActivity()
                : Column(
              children: _recentRegistrations.take(3).map((registration) {
                return _buildModernRegistrationItem(registration);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernRegistrationItem(Map<String, dynamic> registration) {
    final time = (registration['registered_at'] as Timestamp).toDate();
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green, Colors.green.shade600],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 16),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  registration['user_name'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  registration['tournament_name'],
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('HH:mm').format(time),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                DateFormat('MMM dd').format(time),
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.event_note_rounded, size: 40, color: Colors.grey.shade300),
          SizedBox(height: 8),
          Text(
            'No recent activity',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'New registrations will appear here',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Enhanced Tournament Management Tab
  Widget _buildTournamentsTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tournament Management',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${_tournaments.length} tournaments found',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildModernAddButton(
                'Add Tournament',
                Icons.add_rounded,
                _showAddTournamentDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: _tournaments.isEmpty
              ? _buildModernEmptyState(
            'No Tournaments',
            Icons.tour_rounded,
            'Create your first tournament to get started',
            'Add Tournament',
            _showAddTournamentDialog,
          )
              : RefreshIndicator(
            onRefresh: _loadTournaments,
            child: ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: _tournaments.length,
              itemBuilder: (context, index) {
                final tournament = _tournaments[index];
                return _buildModernTournamentCard(tournament);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTournamentCard(Map<String, dynamic> tournament) {
    final status = tournament['status'] ?? 'upcoming';
    final statusColor = _getStatusColor(status);

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament['tournament_name'] ?? 'Unnamed Tournament',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${tournament['game_name']} • ${tournament['tournament_type']}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                _buildModernTournamentInfoItem(
                  'Entry Fee',
                  '₹${(tournament['entry_fee'] as num?)?.toStringAsFixed(0) ?? '0'}',
                  Icons.attach_money_rounded,
                  Colors.green,
                ),
                _buildModernTournamentInfoItem(
                  'Prize Pool',
                  '₹${(tournament['winning_prize'] as num?)?.toStringAsFixed(0) ?? '0'}',
                  Icons.emoji_events_rounded,
                  Colors.amber,
                ),
                _buildModernTournamentInfoItem(
                  'Slots',
                  '${tournament['registered_players'] ?? 0}/${tournament['total_slots'] ?? 0}',
                  Icons.people_rounded,
                  Colors.blue,
                ),
              ],
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _buildModernActionButton(
                  'Credentials',
                  Icons.lock_rounded,
                  Colors.indigo,
                      () => _showAddCredentialsDialogForTournament(tournament),
                ),
                _buildModernActionButton(
                  'Distribute Prizes',
                  Icons.celebration_rounded,
                  Colors.orange,
                      () => _showPrizeDistributionDialog(tournament['id'] as String, tournament),
                ),
                _buildModernActionButton(
                  'Delete',
                  Icons.delete_rounded,
                  Colors.red,
                      () => _showDeleteConfirmation(tournament),
                ),
                _buildModernActionButton(
                  'Mark Live',
                  Icons.live_tv_rounded,
                  Colors.green,
                      () => _updateTournamentStatus(tournament['id'] as String, 'live'),
                ),
                _buildModernActionButton(
                  'Mark Completed',
                  Icons.done_all_rounded,
                  Colors.purple,
                      () => _updateTournamentStatus(tournament['id'] as String, 'completed'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTournamentInfoItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 14),
            SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
                fontSize: 10,
              ),
            ),
            SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 12),
      label: Text(
        text,
        style: TextStyle(fontSize: 10),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _buildModernAddButton(String text, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(
        text,
        style: TextStyle(fontSize: 12),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 1,
      ),
    );
  }

  void _showAddCredentialsDialogForTournament(Map<String, dynamic> tournament) {
    showDialog(
      context: context,
      builder: (context) => CredentialsDialog(
        tournaments: [tournament],
        onCredentialsAdded: _addMatchCredentials,
      ),
    );
  }

  // Users Tab
  Widget _buildUsersTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${_users.length} users registered',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? _buildModernEmptyState(
            'No Users',
            Icons.people_alt_rounded,
            'No users found in the system',
            'Refresh',
            _loadUsers,
          )
              : RefreshIndicator(
            onRefresh: _loadUsers,
            child: ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return _buildModernUserCard(user);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernUserCard(AppUser user) {
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purple],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          user.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.email,
              style: TextStyle(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Row(
              children: [
                Chip(
                  label: Text(
                    '₹${user.totalBalance.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                    ),
                  ),
                  backgroundColor: Colors.green,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.symmetric(horizontal: 4),
                ),
                SizedBox(width: 2),
                Chip(
                  label: Text(
                    '₹${user.totalWinning.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                    ),
                  ),
                  backgroundColor: Colors.blue,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.symmetric(horizontal: 4),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: user.role == 'admin' ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: user.role == 'admin' ? Colors.red : Colors.blue,
            ),
          ),
          child: Text(
            user.role.toUpperCase(),
            style: TextStyle(
              color: user.role == 'admin' ? Colors.red : Colors.blue,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Withdrawals Tab
  Widget _buildWithdrawalsTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Withdrawal Requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${_withdrawRequests.length} pending requests',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _withdrawRequests.isEmpty
              ? _buildModernEmptyState(
            'No Withdrawals',
            Icons.payment_rounded,
            'No pending withdrawal requests',
            'Refresh',
            _loadWithdrawRequests,
          )
              : RefreshIndicator(
            onRefresh: _loadWithdrawRequests,
            child: ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: _withdrawRequests.length,
              itemBuilder: (context, index) {
                final request = _withdrawRequests[index];
                return _buildModernWithdrawalCard(request);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernWithdrawalCard(Map<String, dynamic> request) {
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange, Colors.orange.shade600],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.payment_rounded, color: Colors.white, size: 16),
        ),
        title: Text(
          '₹${(request['amount'] as double).toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request['userName'],
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
            ),
            SizedBox(height: 1),
            Text(
              request['payment_method'],
              style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
            ),
            SizedBox(height: 1),
            Text(
              request['account_details'],
              style: TextStyle(fontSize: 7, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.check, color: Colors.green, size: 12),
              ),
              onPressed: () => _updateWithdrawStatus(request['id'], 'approved'),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
            IconButton(
              icon: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.close, color: Colors.red, size: 12),
              ),
              onPressed: () => _updateWithdrawStatus(request['id'], 'denied'),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  // Match Credentials Tab
  Widget _buildMatchCredentialsTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Match Credentials',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${_matchCredentials.length} credentials active',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildModernAddButton(
                'Add Credentials',
                Icons.lock_rounded,
                _showAddCredentialsDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: _matchCredentials.isEmpty
              ? _buildModernEmptyState(
            'No Credentials',
            Icons.lock_rounded,
            'No match credentials found',
            'Add Credentials',
            _showAddCredentialsDialog,
          )
              : RefreshIndicator(
            onRefresh: _loadMatchCredentials,
            child: ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: _matchCredentials.length,
              itemBuilder: (context, index) {
                final credential = _matchCredentials[index];
                return _buildModernCredentialCard(credential);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernCredentialCard(Map<String, dynamic> credential) {
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.indigo.shade600],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.lock_rounded, color: Colors.white, size: 16),
        ),
        title: Text(
          credential['tournamentName'] ?? 'Unknown Tournament',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Room ID: ${credential['roomId']}',
              style: TextStyle(fontSize: 10),
            ),
            SizedBox(height: 1),
            Text(
              'Password: ${credential['roomPassword']}',
              style: TextStyle(fontSize: 10),
            ),
            SizedBox(height: 1),
            Text(
              'Participants: ${credential['participants']}',
              style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.delete_rounded, color: Colors.red, size: 12),
          ),
          onPressed: () => _showDeleteCredentialsConfirmation(credential),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> tournament) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text(
              'Delete Tournament',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${tournament['tournament_name']}"? This action cannot be undone.',
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            child: Text('CANCEL', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTournament(tournament['id'] as String);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('DELETE', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showDeleteCredentialsConfirmation(Map<String, dynamic> credential) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text(
              'Delete Credentials',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete credentials for "${credential['tournamentName']}"?',
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            child: Text('CANCEL', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMatchCredentials(credential['id'] as String);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('DELETE', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showAddTournamentDialog() {
    showDialog(
      context: context,
      builder: (context) => TournamentDialog(
        onTournamentCreated: _createTournament,
      ),
    );
  }

  void _showAddCredentialsDialog() {
    showDialog(
      context: context,
      builder: (context) => CredentialsDialog(
        tournaments: _tournaments,
        onCredentialsAdded: _addMatchCredentials,
      ),
    );
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'live': return Colors.green;
      case 'upcoming': return Colors.blue;
      case 'completed': return Colors.grey;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }

  Widget _buildModernEmptyState(String title, IconData icon, String message, String buttonText, VoidCallback onPressed) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(icon, size: 30, color: Colors.grey.shade400),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(Icons.refresh_rounded, size: 14),
              label: Text(buttonText, style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking permissions...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Admin Panel',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? _buildModernLoading()
          : _buildCurrentTab(),
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  Widget _buildModernLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.purple],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30),
          ),
          SizedBox(height: 16),
          Text(
            'Loading Admin Panel...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          CircularProgressIndicator(
            color: Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildModernBottomNav() {
    final tabs = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'icon': Icons.tour_rounded, 'label': 'Tournaments'},
      {'icon': Icons.people_alt_rounded, 'label': 'Users'},
      {'icon': Icons.payment_rounded, 'label': 'Withdrawals'},
      {'icon': Icons.lock_rounded, 'label': 'Credentials'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tab = entry.value;
              final isSelected = _currentIndex == index;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _navigateToTab(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                          colors: [Colors.deepPurple, Colors.purple],
                        )
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            tab['icon'] as IconData,
                            size: 18,
                            color: isSelected ? Colors.white : Colors.grey.shade600,
                          ),
                          SizedBox(height: 2),
                          Text(
                            tab['label'] as String,
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected ? Colors.white : Colors.grey.shade600,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0: return _buildDashboardTab();
      case 1: return _buildTournamentsTab();
      case 2: return _buildUsersTab();
      case 3: return _buildWithdrawalsTab();
      case 4: return _buildMatchCredentialsTab();
      default: return _buildDashboardTab();
    }
  }
}

// ENHANCED TOURNAMENT DIALOG WITH PRIZE DISTRIBUTION AND MAP FIELD
class TournamentDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onTournamentCreated;
  final Map<String, dynamic>? tournament;

  const TournamentDialog({
    required this.onTournamentCreated,
    this.tournament,
  });

  @override
  _TournamentDialogState createState() => _TournamentDialogState();
}

class _TournamentDialogState extends State<TournamentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gameNameController = TextEditingController();
  final TextEditingController _entryFeeController = TextEditingController();
  final TextEditingController _totalSlotsController = TextEditingController();
  final TextEditingController _prizePoolController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _mapController = TextEditingController(); // ADDED MAP CONTROLLER

  // Prize distribution controllers
  final List<TextEditingController> _prizeControllers = [];
  final List<TextEditingController> _positionControllers = [];

  DateTime _registrationEnd = DateTime.now().add(Duration(days: 1));
  DateTime _tournamentStart = DateTime.now().add(Duration(days: 2));
  String _tournamentType = 'Solo';
  String _gameType = 'BGMI';
  bool _isLoading = false;
  int _prizeDistributionCount = 3; // Default to 3 positions

  @override
  void initState() {
    super.initState();
    _initializePrizeDistribution();
    if (widget.tournament != null) {
      _loadTournamentData();
    }
  }

  void _initializePrizeDistribution() {
    // Initialize with default 3 positions
    for (int i = 0; i < _prizeDistributionCount; i++) {
      _positionControllers.add(TextEditingController(text: '${i + 1}'));
      _prizeControllers.add(TextEditingController(text: ''));
    }
  }

  void _loadTournamentData() {
    final tournament = widget.tournament!;
    _nameController.text = tournament['tournament_name'] ?? '';
    _gameNameController.text = tournament['game_name'] ?? '';
    _entryFeeController.text = (tournament['entry_fee'] as num?)?.toString() ?? '';
    _prizePoolController.text = (tournament['winning_prize'] as num?)?.toString() ?? '';
    _totalSlotsController.text = (tournament['total_slots'] as num?)?.toString() ?? '';
    _descriptionController.text = tournament['description'] ?? '';
    _mapController.text = tournament['map'] ?? ''; // LOAD MAP DATA
    _tournamentType = tournament['tournament_type'] ?? 'Solo';
    _gameType = tournament['game_name'] ?? 'BGMI';

    if (tournament['registration_end'] != null) {
      _registrationEnd = (tournament['registration_end'] as Timestamp).toDate();
    }
    if (tournament['tournament_start'] != null) {
      _tournamentStart = (tournament['tournament_start'] as Timestamp).toDate();
    }
  }

  void _addPrizeField() {
    setState(() {
      _prizeDistributionCount++;
      _positionControllers.add(TextEditingController(text: '$_prizeDistributionCount'));
      _prizeControllers.add(TextEditingController(text: ''));
    });
  }

  void _removePrizeField(int index) {
    if (_prizeDistributionCount > 1) {
      setState(() {
        _prizeDistributionCount--;
        _positionControllers.removeAt(index);
        _prizeControllers.removeAt(index);
        // Update position numbers
        for (int i = 0; i < _positionControllers.length; i++) {
          _positionControllers[i].text = '${i + 1}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9, maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple, Colors.purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tour_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.tournament == null ? 'Create Tournament' : 'Edit Tournament',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Fill in the tournament details',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Padding(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildModernFormField(
                        'Tournament Name',
                        _nameController,
                        Icons.emoji_events_rounded,
                      ),
                      SizedBox(height: 12),
                      _buildDropdown(
                        'Game',
                        _gameType,
                        ['BGMI', 'Free Fire', 'Valorant', 'COD Mobile', 'Other'],
                            (value) => setState(() => _gameType = value!),
                      ),
                      SizedBox(height: 12),
                      _buildModernFormField(
                        'Entry Fee (₹)',
                        _entryFeeController,
                        Icons.attach_money_rounded,
                        isNumber: true,
                      ),
                      SizedBox(height: 12),
                      _buildModernFormField(
                        'Prize Pool (₹)',
                        _prizePoolController,
                        Icons.celebration_rounded,
                        isNumber: true,
                      ),
                      SizedBox(height: 12),
                      _buildModernFormField(
                        'Total Slots',
                        _totalSlotsController,
                        Icons.people_rounded,
                        isNumber: true,
                      ),
                      SizedBox(height: 12),
                      _buildDropdown(
                        'Tournament Type',
                        _tournamentType,
                        ['Solo', 'Duo', 'Squad', 'Team'],
                            (value) => setState(() => _tournamentType = value!),
                      ),
                      SizedBox(height: 12),
                      // ADDED MAP FIELD
                      _buildModernFormField(
                        'Map',
                        _mapController,
                        Icons.map_rounded,
                      ),
                      SizedBox(height: 12),
                      _buildModernFormField(
                        'Description',
                        _descriptionController,
                        Icons.description_rounded,
                        maxLines: 2,
                      ),
                      SizedBox(height: 16),
                      _buildDateSection(),
                      SizedBox(height: 16),
                      _buildPrizeDistributionSection(),
                      SizedBox(height: 16),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernFormField(String label, TextEditingController controller, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade700),
        hintText: 'Enter $label',
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Icon(icon, color: Colors.deepPurple, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.deepPurple),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        if (isNumber && double.tryParse(value) == null) {
          return 'Please enter a valid number';
        }
        return null;
      },
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade700),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixIcon: Icon(Icons.category_rounded, color: Colors.deepPurple, size: 18),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: TextStyle(fontSize: 12)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Schedule',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDateItem(
                'Registration Ends',
                _registrationEnd,
                    () => _selectDate(true),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildDateItem(
                'Tournament Starts',
                _tournamentStart,
                    () => _selectDate(false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateItem(String label, DateTime date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
              ),
            ),
            SizedBox(height: 2),
            Text(
              DateFormat('MMM dd, HH:mm').format(date),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrizeDistributionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Prize Distribution',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey.shade800,
              ),
            ),
            Spacer(),
            Text(
              'Total Positions: $_prizeDistributionCount',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Set prize amounts for each position (₹)',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(height: 8),
        ...List.generate(_prizeDistributionCount, (index) {
          return _buildPrizeDistributionField(index);
        }),
        SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addPrizeField,
          icon: Icon(Icons.add_rounded, size: 14),
          label: Text('Add More Positions', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.deepPurple,
            side: BorderSide(color: Colors.deepPurple),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        ),
      ],
    );
  }

  Widget _buildPrizeDistributionField(int index) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 60,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_getPositionSuffix(index + 1)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _prizeControllers[index],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Prize Amount (₹)',
                labelStyle: TextStyle(color: Colors.grey.shade700),
                hintText: 'Enter amount for position ${index + 1}',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                if (double.tryParse(value) == null) {
                  return 'Invalid amount';
                }
                return null;
              },
            ),
          ),
          SizedBox(width: 8),
          if (_prizeDistributionCount > 1)
            IconButton(
              icon: Icon(Icons.remove_circle_rounded, color: Colors.red, size: 16),
              onPressed: () => _removePrizeField(index),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
        ],
      ),
    );
  }

  String _getPositionSuffix(int position) {
    switch (position) {
      case 1: return '${position}st';
      case 2: return '${position}nd';
      case 3: return '${position}rd';
      default: return '${position}th';
    }
  }

  Future<void> _selectDate(bool isRegistrationEnd) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isRegistrationEnd ? _registrationEnd : _tournamentStart,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          final newDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isRegistrationEnd) {
            _registrationEnd = newDateTime;
          } else {
            _tournamentStart = newDateTime;
          }
        });
      }
    }
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(color: Colors.grey.shade400),
            ),
            child: Text('CANCEL', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : Text(widget.tournament == null ? 'CREATE' : 'UPDATE', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Validate prize distribution
      double totalPrizeDistributed = 0;
      List<Map<String, dynamic>> prizeDistribution = [];

      for (int i = 0; i < _prizeControllers.length; i++) {
        final amountText = _prizeControllers[i].text;
        if (amountText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please enter prize amount for ${_getPositionSuffix(i + 1)} position'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        final amount = double.tryParse(amountText);
        if (amount == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid prize amount for ${_getPositionSuffix(i + 1)} position'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        totalPrizeDistributed += amount;
        prizeDistribution.add({
          'position': i + 1,
          'amount': amount,
        });
      }

      final prizePool = double.tryParse(_prizePoolController.text) ?? 0;
      if (totalPrizeDistributed > prizePool) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Total prize distribution (₹${totalPrizeDistributed.toStringAsFixed(0)}) exceeds prize pool (₹${prizePool.toStringAsFixed(0)})'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final tournamentData = {
        'tournament_name': _nameController.text.trim(),
        'game_name': _gameType,
        'entry_fee': double.parse(_entryFeeController.text),
        'winning_prize': double.parse(_prizePoolController.text),
        'total_slots': int.parse(_totalSlotsController.text),
        'tournament_type': _tournamentType,
        'map': _mapController.text.trim(), // ADDED MAP FIELD
        'description': _descriptionController.text.trim(),
        'registration_end': Timestamp.fromDate(_registrationEnd),
        'tournament_start': Timestamp.fromDate(_tournamentStart),
        'prize_distribution': prizeDistribution, // Add prize distribution to tournament data
      };

      widget.onTournamentCreated(tournamentData);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gameNameController.dispose();
    _entryFeeController.dispose();
    _totalSlotsController.dispose();
    _prizePoolController.dispose();
    _descriptionController.dispose();
    _mapController.dispose(); // DISPOSE MAP CONTROLLER
    for (var controller in _prizeControllers) {
      controller.dispose();
    }
    for (var controller in _positionControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

// MODERN CREDENTIALS DIALOG (Responsive)
class CredentialsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> tournaments;
  final Function(Map<String, dynamic>) onCredentialsAdded;

  const CredentialsDialog({
    required this.tournaments,
    required this.onCredentialsAdded,
  });

  @override
  _CredentialsDialogState createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends State<CredentialsDialog> {
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _roomPasswordController = TextEditingController();
  String? _selectedTournamentId;
  DateTime _matchTime = DateTime.now().add(Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    _generateCredentials();
  }

  void _generateCredentials() {
    final roomId = 'ROOM${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final roomPassword = 'PASS${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
    setState(() {
      _roomIdController.text = roomId;
      _roomPasswordController.text = roomPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo, Colors.indigo.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Match Credentials',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Set up room details for the tournament',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDropdown(
                      'Select Tournament',
                      _selectedTournamentId,
                      widget.tournaments.map((t) => t['id'] as String).toList(),
                          (value) => setState(() => _selectedTournamentId = value),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _roomIdController,
                      decoration: InputDecoration(
                        labelText: 'Room ID',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        hintText: 'Enter room ID',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: Icon(Icons.meeting_room_rounded, color: Colors.indigo, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.autorenew_rounded, color: Colors.indigo, size: 16),
                          onPressed: _generateCredentials,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _roomPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Room Password',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        hintText: 'Enter room password',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: Icon(Icons.password_rounded, color: Colors.indigo, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.autorenew_rounded, color: Colors.indigo, size: 16),
                          onPressed: _generateCredentials,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildDateItem(),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text('CANCEL', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _addCredentials,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text('ADD CREDENTIALS', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(Icons.tour_rounded, color: Colors.indigo, size: 18),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items.map((String item) {
        final tournament = widget.tournaments.firstWhere((t) => t['id'] == item);
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            tournament['tournament_name'],
            style: TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDateItem() {
    return GestureDetector(
      onTap: _selectMatchTime,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, color: Colors.grey.shade600, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Match Time',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    DateFormat('MMM dd, HH:mm').format(_matchTime),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMatchTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _matchTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_matchTime),
      );

      if (pickedTime != null) {
        setState(() {
          _matchTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _addCredentials() {
    if (_selectedTournamentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a tournament'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final tournament = widget.tournaments.firstWhere((t) => t['id'] == _selectedTournamentId);

    final credentialData = {
      'tournamentId': _selectedTournamentId,
      'tournamentName': tournament['tournament_name'],
      'roomId': _roomIdController.text.trim(),
      'roomPassword': _roomPasswordController.text.trim(),
      'matchTime': Timestamp.fromDate(_matchTime),
    };

    widget.onCredentialsAdded(credentialData);
    Navigator.pop(context);
  }
}

// MODERN PRIZE DISTRIBUTION DIALOG (Responsive)
class PrizeDistributionDialog extends StatefulWidget {
  final Map<String, dynamic> tournament;
  final Function(List<Map<String, dynamic>>) onPrizeDistributed;

  const PrizeDistributionDialog({
    required this.tournament,
    required this.onPrizeDistributed,
  });

  @override
  _PrizeDistributionDialogState createState() => _PrizeDistributionDialogState();
}

class _PrizeDistributionDialogState extends State<PrizeDistributionDialog> {
  final List<TextEditingController> _prizeControllers = [];
  final double totalPrizePool = 2000.0;
  double remainingAmount = 2000.0;

  @override
  void initState() {
    super.initState();
    _prizeControllers.addAll([
      TextEditingController(text: '1000'),
      TextEditingController(text: '500'),
      TextEditingController(text: '200'),
      TextEditingController(text: '150'),
      TextEditingController(text: '150'),
    ]);
    _calculateRemaining();
  }

  void _calculateRemaining() {
    double distributed = 0;
    for (var controller in _prizeControllers) {
      distributed += double.tryParse(controller.text) ?? 0;
    }
    setState(() {
      remainingAmount = totalPrizePool - distributed;
    });
  }

  void _addPrizeField() {
    setState(() {
      _prizeControllers.add(TextEditingController());
    });
  }

  void _removePrizeField(int index) {
    if (_prizeControllers.length > 1) {
      setState(() {
        _prizeControllers.removeAt(index);
        _calculateRemaining();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.amber],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.celebration_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Distribute Prizes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Total Prize Pool: ₹${totalPrizePool.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Remaining Amount Indicator
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: remainingAmount >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: remainingAmount >= 0 ? Colors.green.shade200 : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            remainingAmount >= 0 ? Icons.check_circle_rounded : Icons.error_rounded,
                            color: remainingAmount >= 0 ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  remainingAmount >= 0 ? 'Perfect Distribution!' : 'Over Budget!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: remainingAmount >= 0 ? Colors.green : Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Remaining: ₹${remainingAmount.abs().toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: remainingAmount >= 0 ? Colors.green.shade600 : Colors.red.shade600,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Prize Distribution Fields
                    ..._prizeControllers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final controller = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${index + 1}${_getPositionSuffix(index + 1)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Prize Amount (₹)',
                                  labelStyle: TextStyle(color: Colors.grey.shade700),
                                  hintText: 'Enter amount',
                                  hintStyle: TextStyle(color: Colors.grey.shade500),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  suffixText: '₹',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                onChanged: (value) => _calculateRemaining(),
                              ),
                            ),
                            SizedBox(width: 8),
                            if (_prizeControllers.length > 1)
                              IconButton(
                                icon: Icon(Icons.remove_circle_rounded, color: Colors.red, size: 16),
                                onPressed: () => _removePrizeField(index),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                          ],
                        ),
                      );
                    }),

                    SizedBox(height: 12),

                    // Add More Button
                    OutlinedButton.icon(
                      onPressed: _addPrizeField,
                      icon: Icon(Icons.add_rounded, size: 14),
                      label: Text('Add More Positions', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: BorderSide(color: Colors.orange),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('CANCEL', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: remainingAmount == 0 ? _distributePrizes : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('DISTRIBUTE PRIZES', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPositionSuffix(int position) {
    switch (position) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  void _distributePrizes() {
    final distribution = _prizeControllers.asMap().entries.map((entry) {
      final position = entry.key + 1;
      final amount = double.tryParse(entry.value.text) ?? 0.0;
      return {
        'position': position,
        'amount': amount,
      };
    }).toList();

    widget.onPrizeDistributed(distribution);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    for (var controller in _prizeControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}