import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modles/tournament_model.dart';
import '../modles/user_registration_model.dart';
import '../services/firebase_service.dart';

class AdminPanelScreen extends StatefulWidget {
  @override
  _AdminPanelScreenState createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Tournament> _tournaments = [];
  List<AppUser> _users = [];
  List<Map<String, dynamic>> _withdrawRequests = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _matchCredentials = [];

  bool _isLoading = true;
  bool _isAdmin = false;
  int _currentIndex = 0;

  // Statistics
  int _totalUsers = 0;
  int _totalTournaments = 0;
  int _pendingWithdrawals = 0;
  double _totalRevenue = 0.0;
  int _activeTournaments = 0;

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

      // Check user role directly from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final role = userData?['role'] ?? 'user';

        print('👤 User role: $role, UID: ${user.uid}');

        if (role == 'admin') {
          setState(() {
            _isAdmin = true;
          });
          _loadData();
        } else {
          _showAccessDenied();
        }
      } else {
        print('❌ User document not found');
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
          title: Text('Access Denied'),
          content: Text('You do not have permission to access the admin panel.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
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
        _loadTransactions(),
        _loadMatchCredentials(),
        _loadStatistics(),
      ]);
      print('✅ All data loaded successfully');
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
      final usersData = await _firebaseService.getAllUsers();
      print('📊 Raw users data: ${usersData.length} users found');

      setState(() {
        _users = usersData.map((userData) {
          // Handle timestamp conversion
          dynamic joinedAt = userData['joinedAt'];
          DateTime createdAt;

          if (joinedAt is Timestamp) {
            createdAt = joinedAt.toDate();
          } else if (joinedAt is DateTime) {
            createdAt = joinedAt;
          } else {
            createdAt = DateTime.now();
          }

          return AppUser(
            userId: userData['id'] ?? '',
            email: userData['email'] ?? 'No Email',
            name: userData['name'] ?? 'No Name',
            phone: '',
            profileImage: '',
            country: 'India',
            createdAt: createdAt,
            lastLogin: DateTime.now(),
            isActive: true,
            walletBalance: (userData['walletBalance'] ?? 0.0).toDouble(),
            totalWinnings: (userData['totalWinnings'] ?? 0.0).toDouble(),
            totalMatchesPlayed: userData['totalMatches'] ?? 0,
            totalMatchesWon: 0,
            totalTournamentsJoined: 0,
            winRate: 0.0,
            rank: 'Beginner',
            role: userData['role'] ?? 'user',
          );
        }).toList();
      });
      print('✅ Users loaded: ${_users.length}');
    } catch (e) {
      print('❌ Error loading users: $e');
      // Fallback: Load users directly from Firestore
      await _loadUsersDirectly();
    }
  }

  Future<void> _loadUsersDirectly() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      setState(() {
        _users = snapshot.docs.map((doc) {
          final data = doc.data();
          final basicInfo = data['basicInfo'] ?? {};
          final wallet = data['wallet'] ?? {};
          final stats = data['stats'] ?? {};

          return AppUser(
            userId: doc.id,
            email: basicInfo['email'] ?? 'No Email',
            name: basicInfo['name'] ?? 'No Name',
            phone: basicInfo['phone'] ?? '',
            profileImage: basicInfo['profileImage'] ?? '',
            country: basicInfo['country'] ?? 'India',
            createdAt: (basicInfo['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            lastLogin: DateTime.now(),
            isActive: true,
            walletBalance: (wallet['balance'] ?? 0.0).toDouble(),
            totalWinnings: (wallet['totalWinnings'] ?? 0.0).toDouble(),
            totalMatchesPlayed: stats['totalMatchesPlayed'] ?? 0,
            totalMatchesWon: stats['totalMatchesWon'] ?? 0,
            totalTournamentsJoined: stats['totalTournamentsJoined'] ?? 0,
            winRate: (stats['winRate'] ?? 0.0).toDouble(),
            rank: stats['rank'] ?? 'Beginner',
            role: data['role'] ?? 'user',
          );
        }).toList();
      });
      print('✅ Users loaded directly: ${_users.length}');
    } catch (e) {
      print('❌ Error loading users directly: $e');
    }
  }

  Future<void> _loadTournaments() async {
    try {
      print('🏆 Loading tournaments...');
      final tournaments = await _firebaseService.getUpcomingTournaments();
      setState(() {
        _tournaments = tournaments;
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
      final snapshot = await _firestore
          .collection('withdraw_requests')
          .orderBy('createdAt', descending: true)
          .get();

      print('📊 Raw withdrawal data: ${snapshot.docs.length} requests found');

      setState(() {
        _withdrawRequests = snapshot.docs.map((doc) {
          final data = doc.data();
          print('📋 Withdrawal data: $data');

          return {
            'id': doc.id,
            'userId': data['userId'] ?? 'Unknown',
            'userEmail': data['userEmail'] ?? 'No Email',
            'userName': data['userName'] ?? 'Unknown User',
            'amount': (data['amount'] ?? 0.0).toDouble(),
            'upi': data['upi'] ?? 'No UPI',
            'status': data['status'] ?? 'pending',
            'createdAt': data['createdAt'],
            'processedAt': data['processedAt'],
          };
        }).toList();
      });
      print('✅ Withdrawal requests loaded: ${_withdrawRequests.length}');
    } catch (e) {
      print('❌ Error loading withdraw requests: $e');
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final snapshot = await _firestore
          .collectionGroup('transactions')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      setState(() {
        _transactions = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'userId': data['userId'],
            'amount': data['amount'],
            'type': data['type'],
            'description': data['description'],
            'status': data['status'],
            'createdAt': data['createdAt'],
            'paymentId': data['paymentId'],
          };
        }).toList();
      });
      print('✅ Transactions loaded: ${_transactions.length}');
    } catch (e) {
      print('❌ Error loading transactions: $e');
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
            'roomId': data['roomId'],
            'roomPassword': data['roomPassword'],
            'matchTime': data['matchTime'],
            'status': data['status'],
            'participants': data['participants']?.length ?? 0,
            'createdAt': data['createdAt'],
          };
        }).toList();
      });
      print('✅ Match credentials loaded: ${_matchCredentials.length}');
    } catch (e) {
      print('❌ Error loading match credentials: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      print('📈 Loading statistics...');

      final usersSnapshot = await _firestore.collection('users').get();
      final tournamentsSnapshot = await _firestore.collection('tournaments').get();

      // Get active tournaments (upcoming or live)
      final activeTournaments = await _firestore
          .collection('tournaments')
          .where('basicInfo.status', whereIn: ['upcoming', 'live'])
          .get();

      final pendingWithdrawals = await _firestore
          .collection('withdraw_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      // Calculate revenue from all completed credit transactions
      double revenue = 0.0;
      try {
        final transactionsSnapshot = await _firestore
            .collectionGroup('transactions')
            .where('type', isEqualTo: 'credit')
            .where('status', isEqualTo: 'completed')
            .get();

        for (var doc in transactionsSnapshot.docs) {
          final data = doc.data();
          revenue += (data['amount'] ?? 0.0).toDouble();
        }
      } catch (e) {
        print('❌ Error calculating revenue: $e');
      }

      setState(() {
        _totalUsers = usersSnapshot.docs.length;
        _totalTournaments = tournamentsSnapshot.docs.length;
        _activeTournaments = activeTournaments.docs.length;
        _pendingWithdrawals = pendingWithdrawals.docs.length;
        _totalRevenue = revenue;
      });

      print('''
      📊 Statistics Loaded:
      - Users: $_totalUsers
      - Tournaments: $_totalTournaments
      - Active Tournaments: $_activeTournaments
      - Pending Withdrawals: $_pendingWithdrawals
      - Revenue: $_totalRevenue
      ''');
    } catch (e) {
      print('❌ Error loading statistics: $e');
    }
  }

  Future<void> _updateWithdrawStatus(String requestId, String status) async {
    try {
      // First get the withdrawal request details
      final requestDoc = await _firestore
          .collection('withdraw_requests')
          .doc(requestId)
          .get();

      final requestData = requestDoc.data();
      final userId = requestData?['userId'];
      final amount = (requestData?['amount'] ?? 0.0).toDouble();

      if (userId == null) {
        throw Exception('User ID not found in withdrawal request');
      }

      // Use a batch to ensure both operations succeed or fail together
      final batch = _firestore.batch();

      if (status == 'approved') {
        // Deduct money from user's wallet
        batch.update(_firestore.collection('users').doc(userId), {
          'wallet.balance': FieldValue.increment(-amount),
          'wallet.totalWithdrawn': FieldValue.increment(amount),
          'wallet.lastUpdated': FieldValue.serverTimestamp(),
        });

        // Create a transaction record for the withdrawal
        final transactionRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .doc();

        batch.set(transactionRef, {
          'type': 'withdrawal',
          'amount': amount,
          'currency': 'INR',
          'status': 'completed',
          'description': 'Withdrawal to UPI',
          'withdrawalRequestId': requestId,
          'createdAt': FieldValue.serverTimestamp(),
          'processedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update withdrawal request status
      batch.update(_firestore.collection('withdraw_requests').doc(requestId), {
        'status': status,
        'processedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Withdrawal $status and money ${status == 'approved' ? 'deducted' : 'not deducted'}'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadWithdrawRequests();
      await _loadStatistics();

    } catch (e) {
      print('❌ Error updating withdrawal status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating withdrawal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteTournament(String tournamentId) async {
    try {
      await _firestore.collection('tournaments').doc(tournamentId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tournament deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadTournaments();
      await _loadStatistics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting tournament: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addMatchCredentials(String tournamentId) async {
    try {
      final roomId = 'ROOM${DateTime.now().millisecondsSinceEpoch}';
      final roomPassword = 'PASS${DateTime.now().millisecondsSinceEpoch ~/ 1000}';

      final registrations = await _firestore
          .collectionGroup('registrations')
          .where('tournamentId', isEqualTo: tournamentId)
          .get();

      final participantIds = registrations.docs.map((doc) => doc.data()['userId']).toList();

      await _firestore.collection('matchCredentials').add({
        'tournamentId': tournamentId,
        'roomId': roomId,
        'roomPassword': roomPassword,
        'matchTime': FieldValue.serverTimestamp(),
        'releasedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'participants': participantIds,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Match credentials added successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadMatchCredentials();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding match credentials: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddTournamentDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddTournamentDialog(
        onTournamentAdded: () {
          _loadTournaments();
          _loadStatistics();
        },
      ),
    );
  }

  void _showUserDetails(AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${user.name}'),
              Text('Email: ${user.email}'),
              Text('Wallet Balance: ₹${user.walletBalance.toStringAsFixed(2)}'),
              Text('Role: ${user.role}'),
              Text('Total Matches: ${user.totalMatchesPlayed}'),
              Text('Win Rate: ${user.winRate.toStringAsFixed(1)}%'),
              Text('Joined: ${_formatDate(user.createdAt)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getUserInitials(String name) {
    if (name.isEmpty || name == 'No Name') return '?';
    final parts = name.split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    } else {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    }
  }

  void _navigateToTab(int tabIndex) {
    setState(() {
      _currentIndex = tabIndex;
    });
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              GestureDetector(
                onTap: () => _navigateToTab(2),
                child: _buildStatCard(
                  'Total Users',
                  _totalUsers.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToTab(1),
                child: _buildStatCard(
                  'Tournaments',
                  _totalTournaments.toString(),
                  Icons.tour,
                  Colors.green,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToTab(3),
                child: _buildStatCard(
                  'Pending Withdrawals',
                  _pendingWithdrawals.toString(),
                  Icons.money_off,
                  Colors.orange,
                ),
              ),
              _buildStatCard(
                'Total Revenue',
                '₹${_totalRevenue.toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.purple,
              ),
              _buildStatCard(
                'Active Tournaments',
                _activeTournaments.toString(),
                Icons.event_available,
                Colors.teal,
              ),
              _buildStatCard(
                'Match Credentials',
                _matchCredentials.length.toString(),
                Icons.lock,
                Colors.indigo,
              ),
            ],
          ),

          SizedBox(height: 24),

          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ActionChip(
                        avatar: Icon(Icons.add, size: 20),
                        label: Text('Add Tournament'),
                        onPressed: _showAddTournamentDialog,
                        backgroundColor: Colors.deepPurple,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.refresh, size: 20),
                        label: Text('Refresh Data'),
                        onPressed: _loadData,
                      ),
                      ActionChip(
                        avatar: Icon(Icons.lock, size: 20),
                        label: Text('Add Credentials'),
                        onPressed: _showAddCredentialsDialog,
                        backgroundColor: Colors.indigo,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.settings, size: 20),
                        label: Text('Bulk Operations'),
                        onPressed: _showBulkOperationsDialog,
                        backgroundColor: Colors.orange,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.bug_report, size: 20),
                        label: Text('Debug Info'),
                        onPressed: _showDebugInfo,
                        backgroundColor: Colors.red,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Users: ${_users.length}'),
              Text('Tournaments: ${_tournaments.length}'),
              Text('Withdraw Requests: ${_withdrawRequests.length}'),
              Text('Match Credentials: ${_matchCredentials.length}'),
              SizedBox(height: 16),
              Text('Statistics:'),
              Text('- Total Users: $_totalUsers'),
              Text('- Total Tournaments: $_totalTournaments'),
              Text('- Pending Withdrawals: $_pendingWithdrawals'),
              Text('- Revenue: $_totalRevenue'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentsTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tournaments (${_tournaments.length})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.deepPurple,
                ),
                child: TextButton.icon(
                  onPressed: _showAddTournamentDialog,
                  icon: Icon(Icons.add, color: Colors.white, size: 20),
                  label: Text('Add Tournament', style: TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _tournaments.isEmpty
              ? _buildEmptyState('No Tournaments', Icons.tour, 'No tournaments found. Add some tournaments to get started.')
              : RefreshIndicator(
            onRefresh: _loadTournaments,
            child: ListView.builder(
              itemCount: _tournaments.length,
              itemBuilder: (context, index) {
                final tournament = _tournaments[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                        image: tournament.imageUrl.isNotEmpty
                            ? DecorationImage(
                          image: NetworkImage(tournament.imageUrl),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: tournament.imageUrl.isEmpty
                          ? Icon(Icons.tour, color: Colors.grey)
                          : null,
                    ),
                    title: Text(tournament.tournamentName, style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Game: ${tournament.gameName}'),
                        Text('Entry: ₹${tournament.entryFee} • Slots: ${tournament.slotsLeft}/${tournament.totalSlots}'),
                        Text('Status: ${tournament.status}'),
                        Text('Starts: ${_formatDate(tournament.tournamentStart)}'),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'credentials',
                          child: Row(
                            children: [
                              Icon(Icons.lock, size: 20),
                              SizedBox(width: 8),
                              Text('Add Credentials'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteConfirmation(tournament);
                        } else if (value == 'credentials') {
                          _addMatchCredentials(tournament.id);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text('Users (${_users.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: _users.isEmpty
              ? _buildEmptyState('No Users', Icons.people, 'No users found in the system.')
              : RefreshIndicator(
            onRefresh: _loadUsers,
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Text(_getUserInitials(user.name), style: TextStyle(color: Colors.white)),
                    ),
                    title: Text(user.name),
                    subtitle: Text('${user.email} • ₹${user.walletBalance.toStringAsFixed(2)}'),
                    trailing: Chip(
                      label: Text(user.role.toUpperCase()),
                      backgroundColor: user.role == 'admin' ? Colors.deepPurple : Colors.grey,
                      labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    onTap: () => _showUserDetails(user),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawalsTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text('Withdrawal Requests (${_withdrawRequests.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: _withdrawRequests.isEmpty
              ? _buildEmptyState('No Withdrawal Requests', Icons.money_off, 'No pending withdrawal requests.')
              : RefreshIndicator(
            onRefresh: _loadWithdrawRequests,
            child: ListView.builder(
              itemCount: _withdrawRequests.length,
              itemBuilder: (context, index) {
                final request = _withdrawRequests[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: Icon(Icons.account_balance_wallet, color: _getStatusColor(request['status']), size: 30),
                    title: Text('₹${request['amount']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('UPI: ${request['upi']}'),
                        Text('User: ${request['userName']} (${request['userEmail']})'),
                        Text('Status: ${request['status']}'),
                        if (request['createdAt'] != null)
                          Text('Date: ${_formatDate((request['createdAt'] as Timestamp).toDate())}'),
                      ],
                    ),
                    trailing: request['status'] == 'pending'
                        ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () => _updateWithdrawStatus(request['id'], 'approved'),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () => _updateWithdrawStatus(request['id'], 'rejected'),
                        ),
                      ],
                    )
                        : Chip(
                      label: Text(request['status']),
                      backgroundColor: _getStatusColor(request['status']),
                      labelStyle: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCredentialsTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text('Match Credentials (${_matchCredentials.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: _matchCredentials.isEmpty
              ? _buildEmptyState('No Match Credentials', Icons.lock, 'No match credentials found.')
              : RefreshIndicator(
            onRefresh: _loadMatchCredentials,
            child: ListView.builder(
              itemCount: _matchCredentials.length,
              itemBuilder: (context, index) {
                final credential = _matchCredentials[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: Icon(Icons.meeting_room, color: Colors.indigo, size: 30),
                    title: Text('Room: ${credential['roomId']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Password: ${credential['roomPassword']}'),
                        Text('Participants: ${credential['participants']}'),
                        Text('Status: ${credential['status']}'),
                        if (credential['matchTime'] != null)
                          Text('Match: ${_formatDate((credential['matchTime'] as Timestamp).toDate())}'),
                      ],
                    ),
                    trailing: Chip(
                      label: Text(credential['status']),
                      backgroundColor: _getStatusColor(credential['status']),
                      labelStyle: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.white),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 40, color: color),
          SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, String description) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          SizedBox(height: 8),
          Text(description, style: TextStyle(fontSize: 14, color: Colors.grey[500]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': case 'active': return Colors.green;
      case 'rejected': case 'expired': return Colors.red;
      case 'pending': default: return Colors.orange;
    }
  }

  void _showDeleteConfirmation(Tournament tournament) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Tournament'),
        content: Text('Are you sure you want to delete "${tournament.tournamentName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTournament(tournament.id);
            },
            child: Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddCredentialsDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddCredentialsDialog(
        tournaments: _tournaments,
        onCredentialsAdded: _loadMatchCredentials,
      ),
    );
  }

  void _showBulkOperationsDialog() {
    showDialog(
      context: context,
      builder: (context) => _BulkOperationsDialog(
        onOperationCompleted: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text('Admin Panel'), backgroundColor: Colors.deepPurple),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Checking permissions...'),
        ])),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Refresh Data'),
        ],
      ),
      body: _isLoading ? Center(child: CircularProgressIndicator()) : _buildCurrentTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.tour), label: 'Tournaments'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.money_off), label: 'Withdrawals'),
          BottomNavigationBarItem(icon: Icon(Icons.lock), label: 'Credentials'),
        ],
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

// Add Tournament Dialog (renamed with underscore)
class _AddTournamentDialog extends StatefulWidget {
  final VoidCallback onTournamentAdded;
  const _AddTournamentDialog({required this.onTournamentAdded});

  @override
  _AddTournamentDialogState createState() => _AddTournamentDialogState();
}

class _AddTournamentDialogState extends State<_AddTournamentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gameNameController = TextEditingController();
  final TextEditingController _entryFeeController = TextEditingController();
  final TextEditingController _totalSlotsController = TextEditingController();
  final TextEditingController _prizePoolController = TextEditingController();
  final TextEditingController _tournamentIdController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();

  DateTime _registrationEnd = DateTime.now().add(Duration(days: 1));
  DateTime _tournamentStart = DateTime.now().add(Duration(days: 2));
  String _tournamentType = 'solo';
  String _platform = 'mobile';
  String _region = 'global';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add New Tournament'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _gameNameController,
                decoration: InputDecoration(labelText: 'Game Name*', border: OutlineInputBorder()),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter game name' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Tournament Name*', border: OutlineInputBorder()),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter tournament name' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _tournamentIdController,
                decoration: InputDecoration(labelText: 'Tournament ID*', border: OutlineInputBorder()),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter tournament ID' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _entryFeeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Entry Fee*', border: OutlineInputBorder(), prefixText: '₹ '),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter entry fee';
                  if (double.tryParse(value!) == null) return 'Please enter valid amount';
                  return null;
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _prizePoolController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Prize Pool*', border: OutlineInputBorder(), prefixText: '₹ '),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter prize pool';
                  if (double.tryParse(value!) == null) return 'Please enter valid amount';
                  return null;
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _totalSlotsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Total Slots*', border: OutlineInputBorder()),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter total slots';
                  if (int.tryParse(value!) == null) return 'Please enter valid number';
                  return null;
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _imageUrlController,
                decoration: InputDecoration(labelText: 'Image URL', border: OutlineInputBorder()),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _tournamentType,
                decoration: InputDecoration(labelText: 'Tournament Type', border: OutlineInputBorder()),
                items: ['solo', 'duo', 'squad'].map((type) => DropdownMenuItem(value: type, child: Text(type.toUpperCase()))).toList(),
                onChanged: (value) => setState(() => _tournamentType = value!),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _platform,
                decoration: InputDecoration(labelText: 'Platform', border: OutlineInputBorder()),
                items: ['mobile', 'pc', 'console'].map((platform) => DropdownMenuItem(value: platform, child: Text(platform.toUpperCase()))).toList(),
                onChanged: (value) => setState(() => _platform = value!),
              ),
              SizedBox(height: 12),
              ListTile(
                title: Text('Registration Ends'), subtitle: Text('${_registrationEnd.toString().split(' ')[0]}'),
                trailing: Icon(Icons.calendar_today), onTap: () => _selectRegistrationEndDate(),
              ),
              SizedBox(height: 12),
              ListTile(
                title: Text('Tournament Starts'), subtitle: Text('${_tournamentStart.toString().split(' ')[0]}'),
                trailing: Icon(Icons.calendar_today), onTap: () => _selectTournamentStartDate(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: Text('CANCEL')),
        ElevatedButton(
          onPressed: _isLoading ? null : _addTournament,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
          child: _isLoading ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('ADD TOURNAMENT'),
        ),
      ],
    );
  }

  Future<void> _selectRegistrationEndDate() async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _registrationEnd, firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (picked != null) setState(() => _registrationEnd = picked);
  }

  Future<void> _selectTournamentStartDate() async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _tournamentStart, firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (picked != null) setState(() => _tournamentStart = picked);
  }

  Future<void> _addTournament() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final tournamentData = {
        'basicInfo': {
          'tournamentId': _tournamentIdController.text.trim(),
          'tournamentName': _nameController.text.trim(),
          'gameName': _gameNameController.text.trim(),
          'gameId': _gameNameController.text.trim().toLowerCase(),
          'tournamentType': _tournamentType,
          'entryFee': double.parse(_entryFeeController.text),
          'prizePool': double.parse(_prizePoolController.text),
          'maxPlayers': int.parse(_totalSlotsController.text),
          'registeredPlayers': 0,
          'status': 'upcoming',
          'platform': _platform,
          'region': 'global',
        },
        'schedule': {
          'registrationStart': Timestamp.now(),
          'registrationEnd': Timestamp.fromDate(_registrationEnd),
          'tournamentStart': Timestamp.fromDate(_tournamentStart),
          'estimatedDuration': 180,
          'checkInTime': Timestamp.fromDate(_tournamentStart.subtract(Duration(minutes: 30))),
        },
        'rules': {
          'maxKills': 99,
          'allowedDevices': [_platform],
          'streamingRequired': false,
          'screenshotRequired': true,
          'specificRules': {'teamSize': _tournamentType == 'solo' ? 1 : _tournamentType == 'duo' ? 2 : 4},
        },
        'prizes': {
          'distribution': [
            {'rank': 1, 'prize': double.parse(_prizePoolController.text) * 0.5, 'percentage': 50},
            {'rank': 2, 'prize': double.parse(_prizePoolController.text) * 0.3, 'percentage': 30},
            {'rank': 3, 'prize': double.parse(_prizePoolController.text) * 0.2, 'percentage': 20},
          ],
        },
        'metadata': {
          'createdBy': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'version': 1,
          'featured': true,
          'sponsored': false,
        },
        'imageUrl': _imageUrlController.text.trim().isEmpty
            ? 'https://via.placeholder.com/150'
            : _imageUrlController.text.trim(),
      };

      await FirebaseFirestore.instance.collection('tournaments').add(tournamentData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tournament added successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onTournamentAdded();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding tournament: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// Add Credentials Dialog (renamed with underscore)
class _AddCredentialsDialog extends StatefulWidget {
  final List<Tournament> tournaments;
  final VoidCallback onCredentialsAdded;

  const _AddCredentialsDialog({
    required this.tournaments,
    required this.onCredentialsAdded,
  });

  @override
  __AddCredentialsDialogState createState() => __AddCredentialsDialogState();
}

class __AddCredentialsDialogState extends State<_AddCredentialsDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _roomPasswordController = TextEditingController();

  String? _selectedTournamentId;
  DateTime _matchTime = DateTime.now().add(Duration(hours: 1));
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateCredentials();
  }

  void _generateCredentials() {
    final roomId = 'ROOM${DateTime.now().millisecondsSinceEpoch}';
    final roomPassword = 'PASS${DateTime.now().millisecondsSinceEpoch ~/ 1000}';

    setState(() {
      _roomIdController.text = roomId;
      _roomPasswordController.text = roomPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Match Credentials'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedTournamentId,
              decoration: InputDecoration(
                labelText: 'Select Tournament*',
                border: OutlineInputBorder(),
              ),
              items: widget.tournaments.map((tournament) {
                return DropdownMenuItem(
                  value: tournament.id,
                  child: Text(
                    '${tournament.tournamentName} - ${tournament.gameName}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTournamentId = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a tournament';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _roomIdController,
              decoration: InputDecoration(
                labelText: 'Room ID*',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.autorenew),
                  onPressed: _generateCredentials,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter room ID';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _roomPasswordController,
              decoration: InputDecoration(
                labelText: 'Room Password*',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.autorenew),
                  onPressed: _generateCredentials,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter room password';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            ListTile(
              title: Text('Match Time'),
              subtitle: Text('${_matchTime.toString().split(' ')[0]} ${_matchTime.hour}:${_matchTime.minute.toString().padLeft(2, '0')}'),
              trailing: Icon(Icons.calendar_today),
              onTap: _selectMatchTime,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addCredentials,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
          ),
          child: _isLoading
              ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text('ADD CREDENTIALS'),
        ),
      ],
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

  Future<void> _addCredentials() async {
    if (_selectedTournamentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a tournament'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_roomIdController.text.isEmpty || _roomPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter room ID and password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final registrations = await _firestore
          .collectionGroup('registrations')
          .where('tournamentId', isEqualTo: _selectedTournamentId)
          .get();

      final participantIds = registrations.docs.map((doc) => doc.data()['userId']).toList();

      await _firestore.collection('matchCredentials').add({
        'tournamentId': _selectedTournamentId,
        'roomId': _roomIdController.text.trim(),
        'roomPassword': _roomPasswordController.text.trim(),
        'matchTime': Timestamp.fromDate(_matchTime),
        'releasedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'participants': participantIds,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Match credentials added successfully'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onCredentialsAdded();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding credentials: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// Bulk Operations Dialog (renamed with underscore)
class _BulkOperationsDialog extends StatefulWidget {
  final VoidCallback onOperationCompleted;

  const _BulkOperationsDialog({required this.onOperationCompleted});

  @override
  __BulkOperationsDialogState createState() => __BulkOperationsDialogState();
}

class __BulkOperationsDialogState extends State<_BulkOperationsDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _selectedOperation = 'add_welcome_bonus';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Bulk Operations'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedOperation,
            decoration: InputDecoration(
              labelText: 'Select Operation',
              border: OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: 'add_welcome_bonus',
                child: Text('Add Welcome Bonus to All Users'),
              ),
              DropdownMenuItem(
                value: 'reset_test_data',
                child: Text('Reset Test Data'),
              ),
              DropdownMenuItem(
                value: 'cleanup_old_tournaments',
                child: Text('Cleanup Old Tournaments'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedOperation = value!;
              });
            },
          ),
          SizedBox(height: 16),
          Text(
            _getOperationDescription(_selectedOperation),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _performBulkOperation,
          style: ElevatedButton.styleFrom(
            backgroundColor: _getOperationColor(_selectedOperation),
          ),
          child: _isLoading
              ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text('EXECUTE'),
        ),
      ],
    );
  }

  String _getOperationDescription(String operation) {
    switch (operation) {
      case 'add_welcome_bonus':
        return 'Add ₹200 welcome bonus to all users who have less than ₹200 balance';
      case 'reset_test_data':
        return 'Reset all test data (users, tournaments, transactions) - USE WITH CAUTION';
      case 'cleanup_old_tournaments':
        return 'Delete tournaments that ended more than 30 days ago';
      default:
        return '';
    }
  }

  Color _getOperationColor(String operation) {
    switch (operation) {
      case 'reset_test_data':
        return Colors.red;
      default:
        return Colors.deepPurple;
    }
  }

  Future<void> _performBulkOperation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      switch (_selectedOperation) {
        case 'add_welcome_bonus':
          await _addWelcomeBonusToAll();
          break;
        case 'reset_test_data':
          await _showResetConfirmation();
          break;
        case 'cleanup_old_tournaments':
          await _cleanupOldTournaments();
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error performing operation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addWelcomeBonusToAll() async {
    final usersSnapshot = await _firestore.collection('users').get();
    int updatedCount = 0;

    for (var doc in usersSnapshot.docs) {
      final userData = doc.data();
      final wallet = userData['wallet'] ?? {};
      final currentBalance = (wallet['balance'] ?? 0.0).toDouble();

      if (currentBalance < 200.0) {
        await _firestore.collection('users').doc(doc.id).update({
          'wallet.balance': FieldValue.increment(200.0 - currentBalance),
          'wallet.lastUpdated': FieldValue.serverTimestamp(),
        });
        updatedCount++;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Welcome bonus added to $updatedCount users'),
        backgroundColor: Colors.green,
      ),
    );

    widget.onOperationCompleted();
    Navigator.pop(context);
  }

  Future<void> _showResetConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ Confirm Reset'),
        content: Text(
          'This will delete ALL test data including users, tournaments, and transactions. '
              'This action cannot be undone. Are you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'RESET EVERYTHING',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _resetTestData();
    }
  }

  Future<void> _resetTestData() async {
    final batch = _firestore.batch();

    final tournamentsSnapshot = await _firestore.collection('tournaments').get();
    for (var doc in tournamentsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    final credentialsSnapshot = await _firestore.collection('matchCredentials').get();
    for (var doc in credentialsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    final withdrawsSnapshot = await _firestore.collection('withdraw_requests').get();
    for (var doc in withdrawsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Test data reset completed'),
        backgroundColor: Colors.green,
      ),
    );

    widget.onOperationCompleted();
    Navigator.pop(context);
  }

  Future<void> _cleanupOldTournaments() async {
    final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
    final oldTournaments = await _firestore
        .collection('tournaments')
        .where('schedule.tournamentStart', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final batch = _firestore.batch();
    for (var doc in oldTournaments.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cleaned up ${oldTournaments.docs.length} old tournaments'),
        backgroundColor: Colors.green,
      ),
    );

    widget.onOperationCompleted();
    Navigator.pop(context);
  }
}