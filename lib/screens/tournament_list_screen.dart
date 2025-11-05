import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clipboard/clipboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modles/tournament_model.dart';
import '../services/firebase_service.dart';
import '../widgets/tournament_card.dart';
import '../widgets/game_id_dialog.dart';

class TournamentListScreen extends StatefulWidget {
  final String gameName;
  final String gameImage;

  const TournamentListScreen({
    Key? key,
    required this.gameName,
    required this.gameImage,
  }) : super(key: key);

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Tournament> _tournaments = [];
  List<Tournament> _filteredTournaments = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _errorMessage = '';
  String _currentFilter = 'all';
  StreamSubscription<QuerySnapshot>? _tournamentSubscription;

  // NEW: Track registered tournaments
  Set<String> _registeredTournaments = {};

  // Filter options
  final Map<String, Map<String, dynamic>> _filters = {
    'all': {
      'label': 'All Tournaments',
      'icon': Icons.all_inclusive,
      'color': Colors.grey,
    },
    'live': {
      'label': 'Live Now',
      'icon': Icons.live_tv,
      'color': Colors.red,
    },
    'upcoming': {
      'label': 'Upcoming',
      'icon': Icons.schedule,
      'color': Colors.blue,
    },
    'free': {
      'label': 'Free Entry',
      'icon': Icons.celebration,
      'color': Colors.green,
    },
    'prize': {
      'label': 'High Prize',
      'icon': Icons.emoji_events,
      'color': Colors.amber,
    },
  };

  @override
  void initState() {
    super.initState();
    _loadTournaments();
    _setupTournamentListener();
    _loadUserRegistrations();
  }

  @override
  void dispose() {
    _tournamentSubscription?.cancel();
    super.dispose();
  }

  void _setupTournamentListener() {
    _tournamentSubscription = _firestore
        .collection('tournaments')
        .where('game_name', isEqualTo: widget.gameName)
        .where('status', whereIn: ['upcoming', 'live'])
        .orderBy('tournament_start')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _processTournamentSnapshot(snapshot);
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Real-time updates unavailable';
        });
      }
    });
  }

  // NEW: Load user registrations
  Future<void> _loadUserRegistrations() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final userQuery = await _firestore
          .collection('users')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return;

      final userName = userQuery.docs.first.id;

      // Load from tournament_registrations subcollection
      final registrationsSnapshot = await _firestore
          .collection('users')
          .doc(userName)
          .collection('tournament_registrations')
          .get();

      final registeredIds = registrationsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'registered')
          .map((doc) => doc.id)
          .toSet();

      if (mounted) {
        setState(() {
          _registeredTournaments = registeredIds;
        });
      }
    } catch (e) {
      print('Error loading user registrations: $e');
    }
  }

  Future<void> _loadTournaments() async {
    if (!_isRefreshing) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final snapshot = await _firestore
          .collection('tournaments')
          .where('game_name', isEqualTo: widget.gameName)
          .where('status', whereIn: ['upcoming', 'live'])
          .orderBy('tournament_start')
          .get();

      _processTournamentSnapshot(snapshot);
    } catch (e) {
      print('Error loading tournaments: $e');
      if (mounted) {
        setState(() {
          _tournaments = [];
          _filteredTournaments = [];
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = 'Failed to load tournaments. Please check your connection.';
        });
      }
    }
  }

  void _processTournamentSnapshot(QuerySnapshot snapshot) {
    if (snapshot.docs.isNotEmpty) {
      final List<Tournament> loadedTournaments = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final tournament = Tournament.fromMap(data, doc.id);

          if (_isValidTournament(tournament)) {
            loadedTournaments.add(tournament);
          }
        } catch (e) {
          print('Error parsing tournament ${doc.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _tournaments = loadedTournaments;
          _applyFilter(_currentFilter);
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = '';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _tournaments = [];
          _filteredTournaments = [];
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = 'No tournaments found for ${widget.gameName}';
        });
      }
    }
  }

  bool _isValidTournament(Tournament tournament) {
    return tournament.tournamentName.isNotEmpty &&
        tournament.gameName.isNotEmpty;
  }

  void _applyFilter(String filter) {
    setState(() {
      _currentFilter = filter;
      switch (filter) {
        case 'live':
          _filteredTournaments = _tournaments
              .where((t) => t.status == 'live')
              .toList();
          break;
        case 'upcoming':
          _filteredTournaments = _tournaments
              .where((t) => t.status == 'upcoming')
              .toList();
          break;
        case 'free':
          _filteredTournaments = _tournaments
              .where((t) => t.entryFee == 0)
              .toList();
          break;
        case 'prize':
          _filteredTournaments = _tournaments
              .where((t) => t.winningPrize >= 1000)
              .toList()
            ..sort((a, b) => b.winningPrize.compareTo(a.winningPrize));
          break;
        default:
          _filteredTournaments = List.from(_tournaments);
      }
    });
  }

  // FIXED: Check user registration using new structure
  Future<bool> _isUserRegisteredForTournament(String tournamentId) async {
    try {
      // First check local cache
      if (_registeredTournaments.contains(tournamentId)) {
        return true;
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Find user by UID
      final userQuery = await _firestore
          .collection('users')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return false;

      final userName = userQuery.docs.first.id;

      // Check tournament_registrations subcollection
      final registrationDoc = await _firestore
          .collection('users')
          .doc(userName)
          .collection('tournament_registrations')
          .doc(tournamentId)
          .get();

      final isRegistered = registrationDoc.exists &&
          registrationDoc.data()?['status'] == 'registered';

      // Update local cache
      if (isRegistered && mounted) {
        setState(() {
          _registeredTournaments.add(tournamentId);
        });
      }

      return isRegistered;
    } catch (e) {
      print('Error checking registration: $e');
      return false;
    }
  }

  // FIXED: Enhanced credentials access logic
  Future<void> _handleCredentialsTap(Tournament tournament) async {
    try {
      // 1. Check if user is registered for this tournament
      final isRegistered = await _isUserRegisteredForTournament(tournament.id);

      if (!isRegistered) {
        _showCustomSnackBar(
          'Access Denied 🔒',
          'You must be registered for "${tournament.tournamentName}" to view details',
          Icons.lock_outline,
          Colors.red,
        );
        return;
      }

      // 2. User is registered - show appropriate dialog
      if (tournament.shouldShowCredentials) {
        // Credentials are available
        _showCredentialsDialog(tournament);
      } else if (tournament.credentialsComingSoon) {
        // Credentials coming soon
        _showComingSoonDialog(tournament);
      } else {
        // No credentials yet, but show tournament details since user is registered
        _showTournamentDetailsDialog(tournament);
      }

    } catch (e) {
      print('❌ Error accessing tournament: $e');
      _showCustomSnackBar(
        'Error',
        'Unable to access tournament details. Please try again.',
        Icons.error,
        Colors.red,
      );
    }
  }

  // NEW: Show tournament details for registered users
  void _showTournamentDetailsDialog(Tournament tournament) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade800,
                Colors.blue.shade600,
                Colors.blue.shade900,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.emoji_events_rounded, color: Colors.white, size: 28),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tournament Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              tournament.tournamentName,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
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
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildDetailItem('Status', tournament.status.toUpperCase(), Icons.info),
                      SizedBox(height: 16),
                      _buildDetailItem('Entry Fee', '₹${tournament.entryFee}', Icons.attach_money),
                      SizedBox(height: 16),
                      _buildDetailItem('Prize Pool', '₹${tournament.winningPrize}', Icons.celebration),
                      SizedBox(height: 16),
                      _buildDetailItem('Slots', '${tournament.registeredPlayers}/${tournament.totalSlots}', Icons.people),
                      SizedBox(height: 16),
                      _buildDetailItem('Type', tournament.tournamentType, Icons.category),
                      SizedBox(height: 16),
                      _buildDetailItem('Map', tournament.map, Icons.map),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'You are Registered! 🎉',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'You have successfully registered for this tournament.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text('CLOSE'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED: Tournament Registration with new structure
  Future<void> _handleJoinTournament(Tournament tournament) async {
    try {
      // Check if user is already registered
      final hasRegistered = await _isUserRegisteredForTournament(tournament.id);

      if (hasRegistered) {
        _showCustomSnackBar(
          'Already Registered! 🎉',
          'You are already registered for "${tournament.tournamentName}"',
          Icons.check_circle,
          Colors.blue,
        );
      } else {
        // Check if registration time has ended
        if (!tournament.isRegistrationOpen) {
          _showCustomSnackBar(
            'Registration Closed',
            'Registration period has ended for this tournament',
            Icons.error_outline,
            Colors.orange,
          );
          return;
        }

        // Check if tournament is full
        if (tournament.slotsLeft <= 0) {
          _showCustomSnackBar(
            'Tournament Full',
            'All slots have been filled for this tournament',
            Icons.person_off,
            Colors.red,
          );
          return;
        }

        _showGameIdDialog(tournament);
      }
    } catch (e) {
      print('Error checking registration: $e');
      _showGameIdDialog(tournament);
    }
  }

  // UPDATED: Show game ID dialog with new registration structure
  void _showGameIdDialog(Tournament tournament) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: GameIdDialog(
          gameName: widget.gameName,
          tournament: tournament,
          onConfirm: (playerName, playerId) async {
            Navigator.pop(context);
            await _registerForTournament(tournament, playerName, playerId);
          },
        ),
      ),
    );
  }

  // FIXED: Register user for tournament with new structure
  Future<void> _registerForTournament(Tournament tournament, String playerName, String playerId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _showCustomSnackBar(
          'Registration Failed',
          'Please login to register for tournaments',
          Icons.error,
          Colors.red,
        );
        return;
      }

      // Find user by UID
      final userQuery = await _firestore
          .collection('users')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showCustomSnackBar(
          'Registration Failed',
          'User not found',
          Icons.error,
          Colors.red,
        );
        return;
      }

      final userDoc = userQuery.docs.first;
      final userName = userDoc.id;
      final userData = userDoc.data();

      // Check if user has sufficient balance
      double userBalance = 0.0;
      try {
        final walletData = await _firestore
            .collection('wallet')
            .doc('users')
            .collection(userName)
            .doc('wallet_data')
            .get();

        userBalance = (walletData.data()?['total_balance'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        print('Error fetching wallet: $e');
      }

      if (userBalance < tournament.entryFee) {
        _showCustomSnackBar(
          'Insufficient Balance',
          'You need ₹${tournament.entryFee} to register. Current balance: ₹$userBalance',
          Icons.account_balance_wallet,
          Colors.orange,
        );
        return;
      }

      // Start transaction
      await _firestore.runTransaction((transaction) async {
        // 1. Deduct entry fee from user's wallet
        final walletRef = _firestore
            .collection('wallet')
            .doc('users')
            .collection(userName)
            .doc('wallet_data');

        final walletSnapshot = await transaction.get(walletRef);
        if (walletSnapshot.exists) {
          final currentBalance = (walletSnapshot.data()?['total_balance'] as num?)?.toDouble() ?? 0.0;
          if (currentBalance >= tournament.entryFee) {
            transaction.update(walletRef, {
              'total_balance': currentBalance - tournament.entryFee,
              'updatedAt': FieldValue.serverTimestamp(),
            });

            // Add transaction record
            final transactionId = 'tournament_${DateTime.now().millisecondsSinceEpoch}';
            final transactionsRef = _firestore
                .collection('wallet')
                .doc('users')
                .collection(userName)
                .doc('transactions');

            transaction.set(transactionsRef, {
              'successful': FieldValue.arrayUnion([{
                'transaction_id': transactionId,
                'amount': tournament.entryFee,
                'type': 'tournament_registration',
                'description': 'Entry fee for ${tournament.tournamentName} - ${tournament.id}',
                'status': 'completed',
                'timestamp': FieldValue.serverTimestamp(),
              }])
            }, SetOptions(merge: true));
          } else {
            throw Exception('Insufficient balance');
          }
        }

        // 2. Update tournament slots
        final tournamentRef = _firestore.collection('tournaments').doc(tournament.id);
        final tournamentSnapshot = await transaction.get(tournamentRef);

        if (tournamentSnapshot.exists) {
          final currentSlots = (tournamentSnapshot.data()?['registered_players'] as num?)?.toInt() ?? 0;
          final totalSlots = (tournamentSnapshot.data()?['total_slots'] as num?)?.toInt() ?? 0;

          if (currentSlots < totalSlots) {
            transaction.update(tournamentRef, {
              'registered_players': FieldValue.increment(1),
              'slots_left': totalSlots - (currentSlots + 1),
              'updated_at': FieldValue.serverTimestamp(),
            });

            // Add to joined players list
            transaction.update(tournamentRef, {
              'joined_players': FieldValue.arrayUnion([userName])
            });
          } else {
            throw Exception('Tournament is full');
          }
        }

        // 3. Create registration in user's subcollection
        final registrationRef = _firestore
            .collection('users')
            .doc(userName)
            .collection('tournament_registrations')
            .doc(tournament.id);

        final registrationData = {
          'tournament_id': tournament.id,
          'tournament_name': tournament.tournamentName,
          'game_name': tournament.gameName,
          'player_name': playerName,
          'player_id': playerId,
          'entry_fee': tournament.entryFee,
          'prize_pool': tournament.winningPrize,
          'status': 'registered',
          'payment_method': 'wallet',
          'payment_id': 'wallet_${DateTime.now().millisecondsSinceEpoch}',
          'registered_at': FieldValue.serverTimestamp(),
          'tournament_start': tournament.tournamentStart,
          'tournament_type': tournament.tournamentType,
        };

        transaction.set(registrationRef, registrationData);

        // 4. Update user's game profile
        final gameKey = _getGameKey(tournament.gameName);
        final userRef = _firestore.collection('users').doc(userName);

        transaction.update(userRef, {
          'tournaments.$gameKey.${gameKey}_NAME': playerName,
          'tournaments.$gameKey.${gameKey}_ID': playerId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Update local registration cache
      if (mounted) {
        setState(() {
          _registeredTournaments.add(tournament.id);
        });
      }

      _showCustomSnackBar(
        'Registration Successful! 🎉',
        'You have been registered for "${tournament.tournamentName}"',
        Icons.emoji_events,
        Colors.green,
      );

      _triggerRefresh();

    } catch (e) {
      print('Error registering for tournament: $e');
      _showCustomSnackBar(
        'Registration Failed',
        'Error: ${e.toString()}',
        Icons.error,
        Colors.red,
      );
    }
  }

  // Helper method to get game key
  String _getGameKey(String gameName) {
    switch (gameName.toUpperCase()) {
      case 'BGMI':
        return 'BGMI';
      case 'FREE FIRE':
        return 'FREEFIRE';
      case 'VALORANT':
        return 'VALORANT';
      case 'COD MOBILE':
        return 'COD_MOBILE';
      default:
        return gameName.toUpperCase().replaceAll(' ', '_');
    }
  }

  void _triggerRefresh() {
    setState(() {
      _isRefreshing = true;
    });
    _loadTournaments();
    _loadUserRegistrations();
  }

  void _showCustomSnackBar(String title, String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
        content: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final liveCount = _tournaments.where((t) => t.status == 'live').length;
    final upcomingCount = _tournaments.where((t) => t.status == 'upcoming').length;
    final freeCount = _tournaments.where((t) => t.entryFee == 0).length;
    final prizeCount = _tournaments.where((t) => t.winningPrize >= 1000).length;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 20,
        left: 20,
        right: 20,
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
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.5),
            blurRadius: 25,
            spreadRadius: 5,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Back button and title row
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 20,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tournaments',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      widget.gameName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  '${_tournaments.length} available',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Game info card
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: NetworkImage(widget.gameImage),
                      fit: BoxFit.cover,
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to Compete?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Join tournaments and win amazing prizes. Show your skills!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(liveCount, 'Live', Icons.live_tv, Colors.red),
              _buildStatItem(upcomingCount, 'Upcoming', Icons.schedule, Colors.blue),
              _buildStatItem(freeCount, 'Free', Icons.celebration, Colors.green),
              _buildStatItem(prizeCount, 'Prize', Icons.emoji_events, Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(int count, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.2),
                color.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Filter Tournaments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _filters.entries.map((entry) {
                final isSelected = _currentFilter == entry.key;
                final filterData = entry.value;
                return Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: FilterChip(
                    selected: isSelected,
                    onSelected: (_) => _applyFilter(entry.key),
                    label: Text(
                      filterData['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                    avatar: Icon(
                      filterData['icon'] as IconData,
                      size: 18,
                      color: isSelected ? Colors.white : filterData['color'] as Color,
                    ),
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: filterData['color'] as Color,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? (filterData['color'] as Color)
                            : Colors.grey.shade300,
                        width: isSelected ? 0 : 1,
                      ),
                    ),
                    elevation: isSelected ? 2 : 0,
                    shadowColor: (filterData['color'] as Color).withOpacity(0.3),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentList() {
    if (_isLoading) {
      return _buildLoadingShimmer();
    }

    if (_filteredTournaments.isEmpty) {
      return _buildEmptyState();
    }

    return Expanded(
      child: RefreshIndicator(
        backgroundColor: Colors.deepPurple,
        color: Colors.white,
        onRefresh: _loadTournaments,
        child: ListView.separated(
          padding: EdgeInsets.all(20),
          itemCount: _filteredTournaments.length,
          separatorBuilder: (context, index) => SizedBox(height: 16),
          itemBuilder: (context, index) {
            final tournament = _filteredTournaments[index];
            final isRegistered = _registeredTournaments.contains(tournament.id);

            return TournamentCard(
              tournament: tournament,
              onJoinPressed: () => _handleJoinTournament(tournament),
              onCredentialsTap: () => _handleCredentialsTap(tournament),
              isUserRegistered: isRegistered, // NEW: Pass registration status
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Expanded(
      child: ListView.builder(
        padding: EdgeInsets.all(20),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 16,
                            color: Colors.grey.shade300,
                            margin: EdgeInsets.only(bottom: 8),
                          ),
                          Container(
                            width: 120,
                            height: 12,
                            color: Colors.grey.shade300,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Tournaments Found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _errorMessage.isEmpty
                    ? 'There are no ${_currentFilter == 'all' ? '' : _filters[_currentFilter]!['label'].toString().toLowerCase() + ' '}tournaments available for ${widget.gameName} at the moment.'
                    : _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: 24),
            if (_currentFilter != 'all')
              ElevatedButton(
                onPressed: () => _applyFilter('all'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Text('Show All Tournaments'),
              ),
            SizedBox(height: 8),
            TextButton(
              onPressed: _loadTournaments,
              child: Text(
                'Refresh',
                style: TextStyle(color: Colors.deepPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoonDialog(Tournament tournament) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.shade800,
                Colors.amber.shade600,
                Colors.orange.shade900,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock_clock_rounded, color: Colors.white, size: 28),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credentials Coming Soon',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            tournament.tournamentName,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
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
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Match room credentials will be available:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '30 minutes before match starts',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Available at: ${tournament.credentialsAvailabilityTime}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Match starts: ${_formatMatchTime(tournament.tournamentStart)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Please check back later to get your room ID and password.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Actions
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text('UNDERSTOOD'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCredentialsDialog(Tournament tournament) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
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
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_open_rounded, color: Colors.white, size: 28),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Match Credentials',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              tournament.tournamentName,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
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
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildCredentialField(
                        'Room ID',
                        tournament.roomId ?? 'Not available',
                        Icons.meeting_room_rounded,
                        false, // isPassword
                      ),
                      SizedBox(height: 20),
                      _buildCredentialField(
                        'Room Password',
                        tournament.roomPassword ?? 'Not available',
                        Icons.password_rounded,
                        true, // isPassword
                      ),

                      SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Important Instructions',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            _buildInstructionItem('Join 15-20 minutes before match time'),
                            _buildInstructionItem('Keep these credentials secure and private'),
                            _buildInstructionItem('Do not share with other participants'),
                            _buildInstructionItem('Contact support if you face any issues'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text('CLOSE'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _copyCredentialsToClipboard(tournament);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.deepPurple,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_all_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('COPY'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialField(String label, String value, IconData icon, bool isPassword) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.7), size: 18),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: Icon(Icons.copy_all_rounded, color: Colors.white, size: 18),
                  onPressed: () {
                    FlutterClipboard.copy(value).then((_) {
                      _showCustomSnackBar(
                        '${label} Copied! 📋',
                        '${label} copied to clipboard',
                        Icons.copy_all_rounded,
                        Colors.green,
                      );
                    });
                  },
                  padding: EdgeInsets.all(8),
                  tooltip: 'Copy $label',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2, right: 8),
            child: Icon(Icons.circle, size: 6, color: Colors.orange.withOpacity(0.7)),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.orange.withOpacity(0.9),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMatchTime(Timestamp matchTime) {
    final date = matchTime.toDate();
    final now = DateTime.now();
    final difference = date.difference(now);

    String timeString = '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';

    if (difference.inDays > 0) {
      timeString += ' (in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''})';
    } else if (difference.inHours > 0) {
      timeString += ' (in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''})';
    } else if (difference.inMinutes > 0) {
      timeString += ' (in ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''})';
    } else {
      timeString += ' (Starting now)';
    }

    return timeString;
  }

  void _copyCredentialsToClipboard(Tournament tournament) {
    final credentials = '''
🏆 ${tournament.tournamentName}

🔑 Room ID: ${tournament.roomId ?? 'Not available'}
🔒 Password: ${tournament.roomPassword ?? 'Not available'}
⏰ Match Time: ${_formatMatchTime(tournament.tournamentStart)}

📱 Game: ${widget.gameName}
💎 Prize Pool: ₹${tournament.winningPrize}

⚠️ Keep these details secure!
''';

    FlutterClipboard.copy(credentials).then((_) {
      _showCustomSnackBar(
        'Credentials Copied! 📋',
        'Room details copied to clipboard',
        Icons.copy_all_rounded,
        Colors.green,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterChips(),
          _buildTournamentList(),
        ],
      ),
    );
  }
}