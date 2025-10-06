import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modles/tournament_model.dart';
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
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _withdrawRequests = [];
  List<Map<String, dynamic>> _transactions = [];

  bool _isLoading = true;
  bool _isAdmin = false;
  int _currentIndex = 0;

  // Statistics
  int _totalUsers = 0;
  int _totalTournaments = 0;
  int _pendingWithdrawals = 0;
  double _totalRevenue = 0.0;

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

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userRole = userDoc.data()?['role'] ?? 'user';

      if (userRole == 'admin') {
        setState(() {
          _isAdmin = true;
        });
        _loadData();
      } else {
        _showAccessDenied();
      }
    } catch (e) {
      print('Error checking admin access: $e');
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
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to previous screen
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
        _loadStatistics(),
      ]);
    } catch (e) {
      print('Error loading admin data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      setState(() {
        _users = snapshot.docs.map((doc) {
          final data = doc.data();
          final userName = data['name'] ?? 'No Name';
          return {
            'id': doc.id,
            'name': userName,
            'email': data['email'] ?? 'No Email',
            'walletBalance': (data['walletBalance'] ?? 0.0).toDouble(),
            'role': data['role'] ?? 'user',
            'joinedAt': data['joinedAt'],
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  Future<void> _loadTournaments() async {
    try {
      print('Loading tournaments from Firestore...');

      final snapshot = await _firestore
          .collection('tournaments')
          .get();

      print('Raw tournament docs: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print('No tournaments found in Firestore');
        setState(() {
          _tournaments = [];
        });
        return;
      }

      final List<Tournament> loadedTournaments = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          print('Processing tournament: ${doc.id} - ${data['tournamentName']}');

          final tournament = Tournament.fromMap(data);
          loadedTournaments.add(tournament);

        } catch (e) {
          print('Error parsing tournament ${doc.id}: $e');
          print('Problematic data: ${doc.data()}');
        }
      }

      print('Successfully loaded ${loadedTournaments.length} tournaments');

      setState(() {
        _tournaments = loadedTournaments;
      });

    } catch (e) {
      print('Error loading tournaments: $e');
      setState(() {
        _tournaments = [];
      });
    }
  }

  Future<void> _loadWithdrawRequests() async {
    try {
      final snapshot = await _firestore
          .collection('withdraw_requests')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _withdrawRequests = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'userId': data['userId'],
            'amount': data['amount'],
            'upi': data['upi'],
            'status': data['status'] ?? 'pending',
            'timestamp': data['timestamp'],
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading withdraw requests: $e');
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(50)
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
            'timestamp': data['timestamp'],
            'paymentId': data['paymentId'],
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading transactions: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      // Total users
      final usersSnapshot = await _firestore.collection('users').get();

      // Total tournaments
      final tournamentsSnapshot = await _firestore.collection('tournaments').get();

      // Pending withdrawals
      final pendingWithdrawals = await _firestore
          .collection('withdraw_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      // Calculate total revenue from transactions
      final transactionsSnapshot = await _firestore
          .collection('transactions')
          .where('type', isEqualTo: 'credit')
          .get();

      double revenue = 0.0;
      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data();
        revenue += (data['amount'] ?? 0.0).toDouble();
      }

      setState(() {
        _totalUsers = usersSnapshot.docs.length;
        _totalTournaments = tournamentsSnapshot.docs.length;
        _pendingWithdrawals = pendingWithdrawals.docs.length;
        _totalRevenue = revenue;
      });
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  Future<void> _updateWithdrawStatus(String requestId, String status) async {
    try {
      await _firestore
          .collection('withdraw_requests')
          .doc(requestId)
          .update({'status': status});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Withdrawal $status'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadWithdrawRequests();
      await _loadStatistics();
    } catch (e) {
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

  void _showAddTournamentDialog() {
    showDialog(
      context: context,
      builder: (context) => AddTournamentDialog(
        onTournamentAdded: () {
          _loadTournaments();
          _loadStatistics();
        },
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${user['name']}'),
              Text('Email: ${user['email']}'),
              Text('Wallet Balance: ₹${user['walletBalance']}'),
              Text('Role: ${user['role']}'),
              if (user['joinedAt'] != null)
                Text('Joined: ${_formatDate(user['joinedAt'])}'),
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

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    if (date is Timestamp) {
      return date.toDate().toString().split(' ')[0];
    }
    return date.toString();
  }

  String _getUserInitials(String name) {
    if (name.isEmpty || name == 'No Name') return '?';

    // Split the name and take first letter of each word
    final parts = name.split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    } else {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    }
  }

  // Navigate to specific tab
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
          // Statistics Cards - NOW CLICKABLE
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              // Total Users Card - Click to go to Users tab
              GestureDetector(
                onTap: () => _navigateToTab(2), // Users tab
                child: _buildStatCard(
                  'Total Users',
                  _totalUsers.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              // Tournaments Card - Click to go to Tournaments tab
              GestureDetector(
                onTap: () => _navigateToTab(1), // Tournaments tab
                child: _buildStatCard(
                  'Tournaments',
                  _totalTournaments.toString(),
                  Icons.tour,
                  Colors.green,
                ),
              ),
              // Pending Withdrawals Card - Click to go to Withdrawals tab
              GestureDetector(
                onTap: () => _navigateToTab(3), // Withdrawals tab
                child: _buildStatCard(
                  'Pending Withdrawals',
                  _pendingWithdrawals.toString(),
                  Icons.money_off,
                  Colors.orange,
                ),
              ),
              // Total Revenue Card
              _buildStatCard(
                'Total Revenue',
                '₹${_totalRevenue.toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.purple,
              ),
            ],
          ),

          SizedBox(height: 24),

          // Quick Actions
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                        avatar: Icon(Icons.bug_report, size: 20),
                        label: Text('Debug Data'),
                        onPressed: _debugFirestore,
                        backgroundColor: Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Recent Activity Section
          SizedBox(height: 24),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  if (_tournaments.isEmpty && _withdrawRequests.isEmpty)
                    Text(
                      'No recent activity',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Column(
                      children: [
                        if (_tournaments.isNotEmpty) ...[
                          ListTile(
                            leading: Icon(Icons.tour, color: Colors.green),
                            title: Text('Latest Tournament'),
                            subtitle: Text(_tournaments.first.tournamentName),
                            trailing: Chip(
                              label: Text('₹${_tournaments.first.entryFee}'),
                              backgroundColor: Colors.green,
                              labelStyle: TextStyle(color: Colors.white),
                            ),
                          ),
                          Divider(),
                        ],
                        if (_withdrawRequests.isNotEmpty) ...[
                          ListTile(
                            leading: Icon(Icons.money_off, color: Colors.orange),
                            title: Text('Latest Withdrawal Request'),
                            subtitle: Text('₹${_withdrawRequests.first['amount']} - ${_withdrawRequests.first['status']}'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _navigateToTab(3),
                          ),
                        ],
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentsTab() {
    return Column(
      children: [
        // Header with Add Button - FIXED VISIBILITY
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tournaments (${_tournaments.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
                  label: Text(
                    'Add Tournament',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tournaments List
        Expanded(
          child: _tournaments.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tour, size: 80, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No Tournaments Found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  'Add your first tournament using the button above',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _showAddTournamentDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  child: Text('Add First Tournament'),
                ),
              ],
            ),
          )
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
                        image: DecorationImage(
                          image: NetworkImage(tournament.imageUrl),
                          fit: BoxFit.cover,
                          onError: (error, stackTrace) {
                            // If image fails to load, show placeholder
                          },
                        ),
                      ),
                    ),
                    title: Text(
                      tournament.tournamentName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Game: ${tournament.gameName}'),
                        Text('Entry Fee: ₹${tournament.entryFee}'),
                        Text('Slots: ${tournament.registeredPlayers}/${tournament.totalSlots}'),
                        Text('Ends: ${_formatDate(tournament.registrationEnd)}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteConfirmation(tournament),
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
          child: Text(
            'Users (${_users.length})',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people, size: 80, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No Users',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          )
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
                      child: Text(
                        _getUserInitials(user['name']),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(user['name']),
                    subtitle: Text('${user['email']} • ₹${user['walletBalance']}'),
                    trailing: Chip(
                      label: Text(user['role'].toUpperCase()),
                      backgroundColor: user['role'] == 'admin'
                          ? Colors.deepPurple
                          : Colors.grey,
                      labelStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
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
          child: Text(
            'Withdrawal Requests (${_withdrawRequests.length})',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _withdrawRequests.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.money_off, size: 80, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No Withdrawal Requests',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _loadWithdrawRequests,
            child: ListView.builder(
              itemCount: _withdrawRequests.length,
              itemBuilder: (context, index) {
                final request = _withdrawRequests[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      Icons.account_balance_wallet,
                      color: _getStatusColor(request['status']),
                      size: 30,
                    ),
                    title: Text('₹${request['amount']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('UPI: ${request['upi']}'),
                        Text('Status: ${request['status']}'),
                        if (request['timestamp'] != null)
                          Text('Date: ${_formatDate(request['timestamp'])}'),
                      ],
                    ),
                    trailing: request['status'] == 'pending'
                        ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () => _updateWithdrawStatus(
                              request['id'], 'approved'),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () => _updateWithdrawStatus(
                              request['id'], 'rejected'),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  void _showDeleteConfirmation(Tournament tournament) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Tournament'),
        content: Text('Are you sure you want to delete "${tournament.tournamentName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
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

  // Debug method to check Firestore data
  Future<void> _debugFirestore() async {
    try {
      print('=== FIREBASE DEBUG ===');

      // Check tournaments collection
      final tournamentsSnapshot = await FirebaseFirestore.instance
          .collection('tournaments')
          .get();

      print('Tournaments in Firestore: ${tournamentsSnapshot.docs.length}');
      for (var doc in tournamentsSnapshot.docs) {
        print('Tournament: ${doc.data()}');
      }

      // Check if user is admin
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        print('Current user role: ${userDoc.data()?['role']}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Check console for debug info'),
          backgroundColor: Colors.blue,
        ),
      );

    } catch (e) {
      print('Debug error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debug error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Admin Panel'),
          backgroundColor: Colors.deepPurple,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Checking permissions...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildCurrentTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tour),
            label: 'Tournaments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.money_off),
            label: 'Withdrawals',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildTournamentsTab();
      case 2:
        return _buildUsersTab();
      case 3:
        return _buildWithdrawalsTab();
      default:
        return _buildDashboardTab();
    }
  }
}

// Add Tournament Dialog
class AddTournamentDialog extends StatefulWidget {
  final VoidCallback onTournamentAdded;

  const AddTournamentDialog({required this.onTournamentAdded});

  @override
  _AddTournamentDialogState createState() => _AddTournamentDialogState();
}

class _AddTournamentDialogState extends State<AddTournamentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gameNameController = TextEditingController();
  final TextEditingController _entryFeeController = TextEditingController();
  final TextEditingController _totalSlotsController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _tournamentIdController = TextEditingController();

  DateTime _registrationEnd = DateTime.now().add(Duration(days: 1));
  DateTime _tournamentStart = DateTime.now().add(Duration(days: 2));
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
                decoration: InputDecoration(
                  labelText: 'Game Name*',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., BGMI, Free Fire',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter game name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Tournament Name*',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Weekly Championship',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter tournament name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _tournamentIdController,
                decoration: InputDecoration(
                  labelText: 'Tournament ID*',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., BGMI_WEEKLY_001',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter tournament ID';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _entryFeeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Entry Fee*',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                  hintText: 'e.g., 50',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter entry fee';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter valid amount';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _totalSlotsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Total Slots*',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 100',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter total slots';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter valid number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _imageUrlController,
                decoration: InputDecoration(
                  labelText: 'Image URL',
                  border: OutlineInputBorder(),
                  hintText: 'Optional - leave empty for default',
                ),
              ),
              SizedBox(height: 12),
              ListTile(
                title: Text('Registration Ends'),
                subtitle: Text('${_registrationEnd.toString().split(' ')[0]}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectRegistrationEndDate(),
              ),
              SizedBox(height: 12),
              ListTile(
                title: Text('Tournament Starts'),
                subtitle: Text('${_tournamentStart.toString().split(' ')[0]}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectTournamentStartDate(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addTournament,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
          ),
          child: _isLoading
              ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text('ADD TOURNAMENT'),
        ),
      ],
    );
  }

  Future<void> _selectRegistrationEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _registrationEnd,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _registrationEnd) {
      setState(() {
        _registrationEnd = picked;
      });
    }
  }

  Future<void> _selectTournamentStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tournamentStart,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _tournamentStart) {
      setState(() {
        _tournamentStart = picked;
      });
    }
  }

  Future<void> _addTournament() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tournament = Tournament(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        gameName: _gameNameController.text.trim(),
        tournamentName: _nameController.text.trim(),
        entryFee: double.parse(_entryFeeController.text),
        totalSlots: int.parse(_totalSlotsController.text),
        registeredPlayers: 0,
        registrationEnd: _registrationEnd,
        tournamentStart: _tournamentStart,
        imageUrl: _imageUrlController.text.trim().isEmpty
            ? 'https://via.placeholder.com/150'
            : _imageUrlController.text.trim(),
        tournamentId: _tournamentIdController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournament.id)
          .set(tournament.toMap());

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