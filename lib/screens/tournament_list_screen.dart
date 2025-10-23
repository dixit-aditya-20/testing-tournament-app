import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  _TournamentListScreenState createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Tournament> _tournaments = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadTournaments();

    // Listen for real-time updates to tournaments
    _setupTournamentListener();
  }

  // Real-time updates for credentials
  void _setupTournamentListener() {
    _firestore
        .collection('tournaments')
        .where('game_name', isEqualTo: widget.gameName)
        .where('status', whereIn: ['upcoming', 'live'])
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _processTournamentSnapshot(snapshot);
      }
    });
  }

  Future<void> _loadTournaments() async {
    try {
      print('🔄 Loading tournaments for: ${widget.gameName}');

      final snapshot = await _firestore
          .collection('tournaments')
          .where('game_name', isEqualTo: widget.gameName)
          .where('status', whereIn: ['upcoming', 'live'])
          .orderBy('tournament_start')
          .get();

      print('📊 Firestore returned ${snapshot.docs.length} documents');
      _processTournamentSnapshot(snapshot);

    } catch (e) {
      print('❌ Error loading tournaments: $e');
      setState(() {
        _tournaments = [];
        _isLoading = false;
        _errorMessage = 'Error loading tournaments: $e';
      });
    }
  }

  void _processTournamentSnapshot(QuerySnapshot snapshot) {
    if (snapshot.docs.isNotEmpty) {
      final List<Tournament> loadedTournaments = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          print('🔍 Document ID: ${doc.id}');

          // Debug credentials
          if (data['roomId'] != null) {
            print('🔐 Tournament ${data['tournament_name']} has credentials: ${data['roomId']}');
          }

          // Check for required fields
          if (data['tournament_name'] == null) {
            print('⚠️ Missing tournament_name in document ${doc.id}');
            continue;
          }

          if (data['game_name'] == null) {
            print('⚠️ Missing game_name in document ${doc.id}');
            continue;
          }

          final tournament = Tournament.fromMap(data, doc.id);
          loadedTournaments.add(tournament);
          print('✅ Successfully created tournament: ${tournament.tournamentName}');
          print('🔐 Has credentials: ${tournament.hasCredentials}');
          print('🔐 Should show credentials: ${tournament.shouldShowCredentials}');

        } catch (e) {
          print('❌ Error parsing tournament ${doc.id}: $e');
          print('📋 Problematic data: ${doc.data()}');
        }
      }

      setState(() {
        _tournaments = loadedTournaments;
        _isLoading = false;
        _errorMessage = '';
      });

      print('🎉 Successfully loaded ${_tournaments.length} tournaments');
      print('🔐 Tournaments with credentials: ${_tournaments.where((t) => t.hasCredentials).length}');
      print('🔐 Credentials available: ${_tournaments.where((t) => t.shouldShowCredentials).length}');

    } else {
      print('⚠️ No tournaments found in Firestore for ${widget.gameName}');
      setState(() {
        _tournaments = [];
        _isLoading = false;
        _errorMessage = 'No tournaments found for ${widget.gameName}';
      });
    }
  }

  void _handleJoinTournament(Tournament tournament) async {
    try {
      final hasRegistered = await _firebaseService.isUserRegisteredForTournament(tournament.id);

      if (hasRegistered) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are already registered for this tournament'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        _showGameIdDialog(tournament);
      }
    } catch (e) {
      print('❌ Error checking registration: $e');
      _showGameIdDialog(tournament);
    }
  }

  void _showGameIdDialog(Tournament tournament) {
    print('🔄 === SHOWING GAME ID DIALOG ===');
    print('🔄 Tournament: ${tournament.tournamentName}');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        print('🔄 Building GameIdDialog widget...');
        return GameIdDialog(
          gameName: widget.gameName,
          tournament: tournament,
          onConfirm: (playerName, playerId) {
            print('✅ === GAME ID DIALOG CONFIRMED ===');
            print('✅ Player Name: $playerName');
            print('✅ Player ID: $playerId');

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Registration completed successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );

            // Refresh the tournament list to show updated registration status
            _loadTournaments();
          },
        );
      },
    );
  }

  // Handle credentials tap
  void _handleCredentialsTap(Tournament tournament) {
    if (!tournament.hasCredentials) return;

    showDialog(
      context: context,
      builder: (context) => _buildCredentialsDialog(tournament),
    );
  }

  Widget _buildCredentialsDialog(Tournament tournament) {
    final shouldShowCredentials = tournament.shouldShowCredentials;

    if (!shouldShowCredentials) {
      return _buildComingSoonDialog(tournament);
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock_open, color: Colors.indigo),
          SizedBox(width: 8),
          Text('Match Credentials'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tournament.tournamentName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            SizedBox(height: 16),
            _buildCredentialDetailItem('Room ID', tournament.roomId ?? 'Not available'),
            SizedBox(height: 12),
            _buildCredentialDetailItem('Room Password', tournament.roomPassword ?? 'Not available'),
            SizedBox(height: 12),
            if (tournament.credentialsMatchTime != null)
              _buildCredentialDetailItem(
                  'Match Time',
                  _formatMatchTime(tournament.credentialsMatchTime!)
              ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Important:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Please join the room 15 minutes before match time\n• Keep your credentials secure\n• Do not share with others',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('CLOSE'),
        ),
        ElevatedButton(
          onPressed: () {
            _copyCredentialsToClipboard(tournament);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
          ),
          child: Text('COPY DETAILS'),
        ),
      ],
    );
  }

  Widget _buildComingSoonDialog(Tournament tournament) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock_clock, color: Colors.orange),
          SizedBox(width: 8),
          Text('Credentials Coming Soon'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Match room credentials will be available:',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: Column(
              children: [
                Text(
                  '30 minutes before match starts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                SizedBox(height: 8),
                if (tournament.credentialsAvailabilityTime.isNotEmpty)
                  Text(
                    'Available at: ${tournament.credentialsAvailabilityTime}',
                    style: TextStyle(
                      color: Colors.blue[800],
                    ),
                  ),
                if (tournament.credentialsMatchTime != null)
                  Text(
                    'Match starts at: ${_formatMatchTime(tournament.credentialsMatchTime!)}',
                    style: TextStyle(
                      color: Colors.blue[800],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Please check back later to get your room ID and password.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    );
  }

  Widget _buildCredentialDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.indigo[800],
            ),
          ),
        ),
      ],
    );
  }

  String _formatMatchTime(Timestamp matchTime) {
    final date = matchTime.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _copyCredentialsToClipboard(Tournament tournament) {
    final credentials = '''
Tournament: ${tournament.tournamentName}
Room ID: ${tournament.roomId}
Password: ${tournament.roomPassword}
Match Time: ${tournament.credentialsMatchTime != null ? _formatMatchTime(tournament.credentialsMatchTime!) : 'Not specified'}
''';

    // You can use clipboard package here
    // Clipboard.setData(ClipboardData(text: credentials));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Credentials copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.gameName} Tournaments',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTournaments,
            tooltip: 'Refresh tournaments',
          ),
          IconButton(
            icon: Icon(Icons.bug_report),
            onPressed: _showDebugInfo,
            tooltip: 'Debug Info',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading Tournaments...'),
          ],
        ),
      )
          : _tournaments.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 20),
            Text(
              'No Tournaments Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 10),
            Text(
              _errorMessage.isNotEmpty
                  ? _errorMessage
                  : 'No tournaments found for ${widget.gameName}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadTournaments,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: Text('Refresh'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(widget.gameImage),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.gameName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_tournaments.length} tournament${_tournaments.length > 1 ? 's' : ''} available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    // Show credentials count
                    if (_tournaments.any((t) => t.hasCredentials))
                      Text(
                        '${_tournaments.where((t) => t.hasCredentials).length} with credentials',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                Spacer(),
                Chip(
                  label: Text('LIVE'),
                  backgroundColor: Colors.green,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTournaments,
              child: ListView.builder(
                itemCount: _tournaments.length,
                itemBuilder: (context, index) {
                  final tournament = _tournaments[index];
                  return TournamentCard(
                    tournament: tournament,
                    onJoinPressed: () => _handleJoinTournament(tournament),
                    onCredentialsTap: () => _handleCredentialsTap(tournament),
                  );
                },
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
              Text('Game: ${widget.gameName}'),
              Text('Tournaments loaded: ${_tournaments.length}'),
              Text('With credentials: ${_tournaments.where((t) => t.hasCredentials).length}'),
              Text('Credentials available: ${_tournaments.where((t) => t.shouldShowCredentials).length}'),
              Text('Error: $_errorMessage'),
              SizedBox(height: 16),
              if (_tournaments.isNotEmpty) ...[
                Text('Sample Tournament:'),
                Text('- Name: ${_tournaments.first.tournamentName}'),
                Text('- ID: ${_tournaments.first.id}'),
                Text('- Status: ${_tournaments.first.status}'),
                Text('- Entry Fee: ₹${_tournaments.first.entryFee}'),
                Text('- Has Credentials: ${_tournaments.first.hasCredentials}'),
                Text('- Should Show Credentials: ${_tournaments.first.shouldShowCredentials}'),
                if (_tournaments.first.hasCredentials) ...[
                  Text('- Room ID: ${_tournaments.first.roomId}'),
                  Text('- Room Password: ${_tournaments.first.roomPassword}'),
                  Text('- Available at: ${_tournaments.first.credentialsAvailabilityTime}'),
                ],
              ],
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
}