import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../modles/tournament_model.dart';
import '../services/firebase_service.dart';
import '../widgets/tournament_card.dart';
import 'payment_screen.dart';
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
  bool _hasDataInFirebase = false;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    try {
      print('🔄 Loading tournaments for: ${widget.gameName}');

      // Load directly from Firestore with proper query
      final snapshot = await _firestore
          .collection('tournaments')
          .where('basicInfo.gameName', isEqualTo: widget.gameName)
          .where('basicInfo.status', whereIn: ['upcoming', 'live'])
          .get();

      print('📊 Firestore returned ${snapshot.docs.length} tournaments for ${widget.gameName}');

      if (snapshot.docs.isNotEmpty) {
        final List<Tournament> loadedTournaments = [];

        for (var doc in snapshot.docs) {
          try {
            final tournament = Tournament.fromFirestore(doc);
            loadedTournaments.add(tournament);
          } catch (e) {
            print('❌ Error parsing tournament: $e');
          }
        }

        setState(() {
          _tournaments = loadedTournaments;
          _hasDataInFirebase = true;
          _isLoading = false;
        });

        print('✅ Successfully loaded ${_tournaments.length} tournaments');
      } else {
        print('⚠️ No tournaments found in Firestore for ${widget.gameName}');
        // Use mock data as fallback
        final mockTournaments = _getMockTournaments();
        setState(() {
          _tournaments = mockTournaments;
          _hasDataInFirebase = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading tournaments: $e');
      // Fallback to mock data
      final mockTournaments = _getMockTournaments();
      setState(() {
        _tournaments = mockTournaments;
        _hasDataInFirebase = false;
        _isLoading = false;
      });
    }
  }

  List<Tournament> _getMockTournaments() {
    final now = DateTime.now();

    return [
      // BGMI Tournaments
      if (widget.gameName == 'BGMI') ...[
        Tournament(
          id: 'bgmi_tournament_1',
          gameName: 'BGMI',
          tournamentName: 'BGMI Championship Season 1',
          entryFee: 50.0,
          totalSlots: 100,
          registeredPlayers: 45,
          registrationEnd: now.add(Duration(days: 2, hours: 5)),
          tournamentStart: now.add(Duration(days: 3)),
          imageUrl: 'https://w0.peakpx.com/wallpaper/742/631/HD-wallpaper-bgmi-trending-pubg-bgmi-iammsa-pubg.jpg',
          tournamentId: 'BGMI001',
          region: 'Global',
          platform: 'Mobile',
          prizePool: 5000.0,
          tournamentType: 'Solo',
          status: 'upcoming',
        ),
        Tournament(
          id: 'bgmi_tournament_2',
          gameName: 'BGMI',
          tournamentName: 'BGMI Weekly Showdown',
          entryFee: 30.0,
          totalSlots: 50,
          registeredPlayers: 32,
          registrationEnd: now.add(Duration(days: 1, hours: 3)),
          tournamentStart: now.add(Duration(days: 2)),
          imageUrl: 'https://w0.peakpx.com/wallpaper/742/631/HD-wallpaper-bgmi-trending-pubg-bgmi-iammsa-pubg.jpg',
          tournamentId: 'BGMI002',
          region: 'India',
          platform: 'Mobile',
          prizePool: 1500.0,
          tournamentType: 'Squad',
          status: 'upcoming',
        ),
      ],

      // Free Fire Tournaments
      if (widget.gameName == 'Free Fire') ...[
        Tournament(
          id: 'freefire_tournament_1',
          gameName: 'Free Fire',
          tournamentName: 'Free Fire Masters',
          entryFee: 25.0,
          totalSlots: 80,
          registeredPlayers: 28,
          registrationEnd: now.add(Duration(days: 3, hours: 6)),
          tournamentStart: now.add(Duration(days: 4)),
          imageUrl: 'https://wallpapers.com/images/high/free-fire-logo-armed-woman-fdsbmr41d528ty45.webp',
          tournamentId: 'FF001',
          region: 'Global',
          platform: 'Mobile',
          prizePool: 2000.0,
          tournamentType: 'Squad',
          status: 'upcoming',
        ),
        Tournament(
          id: 'freefire_tournament_2',
          gameName: 'Free Fire',
          tournamentName: 'Free Fire Clash',
          entryFee: 15.0,
          totalSlots: 40,
          registeredPlayers: 18,
          registrationEnd: now.add(Duration(hours: 12)),
          tournamentStart: now.add(Duration(days: 1)),
          imageUrl: 'https://wallpapers.com/images/high/free-fire-logo-armed-woman-fdsbmr41d528ty45.webp',
          tournamentId: 'FF002',
          region: 'India',
          platform: 'Mobile',
          prizePool: 600.0,
          tournamentType: 'Duo',
          status: 'upcoming',
        ),
      ],

      // Valorant Tournaments
      if (widget.gameName == 'Valorant') ...[
        Tournament(
          id: 'valorant_tournament_1',
          gameName: 'Valorant',
          tournamentName: 'Valorant Pro Series',
          entryFee: 80.0,
          totalSlots: 40,
          registeredPlayers: 15,
          registrationEnd: now.add(Duration(days: 5, hours: 4)),
          tournamentStart: now.add(Duration(days: 6)),
          imageUrl: 'https://w0.peakpx.com/wallpaper/522/122/HD-wallpaper-valorant-reyna-background-game-phone.jpg',
          tournamentId: 'VAL001',
          region: 'Global',
          platform: 'PC',
          prizePool: 3200.0,
          tournamentType: '5v5',
          status: 'upcoming',
        ),
      ],

      // COD Mobile Tournaments
      if (widget.gameName == 'COD Mobile') ...[
        Tournament(
          id: 'codm_tournament_1',
          gameName: 'COD Mobile',
          tournamentName: 'COD Mobile Championship',
          entryFee: 40.00,
          totalSlots: 60,
          registeredPlayers: 22,
          registrationEnd: now.add(Duration(days: 4, hours: 3)),
          tournamentStart: now.add(Duration(days: 5)),
          imageUrl: 'https://wallpapers.com/images/high/yellow-call-of-duty-phone-qh4ng5sccotp6hlh.webp',
          tournamentId: 'CODM001',
          region: 'Global',
          platform: 'Mobile',
          prizePool: 2400.0,
          tournamentType: 'Squad',
          status: 'upcoming',
        ),
      ],
    ];
  }

  void _handleJoinTournament(Tournament tournament) async {
    try {
      final hasRegistered = await _firebaseService.hasUserRegisteredForTournament(tournament.id);

      if (hasRegistered) {
        // User has registered before, go directly to payment
        _navigateToPayment(tournament, null, null);
      } else {
        // First time registration, show game ID dialog
        _showGameIdDialog(tournament);
      }
    } catch (e) {
      print('Error checking registration: $e');
      // If there's an error with Firebase, show the dialog anyway
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
          tournament: tournament, // Pass tournament data
          onConfirm: (playerName, playerId) {
            print('✅ === GAME ID DIALOG CONFIRMED ===');
            print('✅ Player Name: $playerName');
            print('✅ Player ID: $playerId');
            // Razorpay will open automatically now
          },
        );
      },
    );
  }

  void _navigateToPayment(Tournament tournament, String? playerName, String? playerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          tournament: tournament,
          playerName: playerName,
          playerId: playerId,
          gameName: widget.gameName,
        ),
      ),
    );
  }

  Future<void> _seedDataToFirebase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Add sample tournaments to Firestore
      final mockTournaments = _getMockTournaments();

      for (var tournament in mockTournaments) {
        final tournamentData = {
          'basicInfo': {
            'tournamentId': tournament.tournamentId,
            'tournamentName': tournament.tournamentName,
            'gameName': tournament.gameName,
            'gameId': tournament.gameName.toLowerCase().replaceAll(' ', ''),
            'tournamentType': tournament.tournamentType?.toLowerCase() ?? 'solo',
            'entryFee': tournament.entryFee,
            'prizePool': tournament.prizePool,
            'maxPlayers': tournament.totalSlots,
            'registeredPlayers': tournament.registeredPlayers,
            'status': tournament.status?.toLowerCase() ?? 'upcoming',
            'platform': tournament.platform?.toLowerCase() ?? 'mobile',
            'region': tournament.region?.toLowerCase() ?? 'global',
          },
          'schedule': {
            'registrationStart': Timestamp.now(),
            'registrationEnd': Timestamp.fromDate(tournament.registrationEnd!),
            'tournamentStart': Timestamp.fromDate(tournament.tournamentStart!),
            'estimatedDuration': 180,
            'checkInTime': Timestamp.fromDate(tournament.tournamentStart!.subtract(Duration(minutes: 30))),
          },
          'rules': {
            'maxKills': 99,
            'allowedDevices': [tournament.platform?.toLowerCase() ?? 'mobile'],
            'streamingRequired': false,
            'screenshotRequired': true,
            'specificRules': {
              'map': tournament.gameName == 'BGMI' ? 'Erangel' : 'Default',
              'perspective': 'TPP',
              'teamSize': _getTeamSize(tournament.tournamentType),
            },
          },
          'prizes': {
            'distribution': [
              {'rank': 1, 'prize': (tournament.prizePool! * 0.5), 'percentage': 50},
              {'rank': 2, 'prize': (tournament.prizePool! * 0.3), 'percentage': 30},
              {'rank': 3, 'prize': (tournament.prizePool! * 0.2), 'percentage': 20},
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
        };

        await _firestore
            .collection('tournaments')
            .doc(tournament.id)
            .set(tournamentData);
      }

      await _loadTournaments(); // Reload tournaments after seeding

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sample tournaments added to Firebase!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error seeding data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _getTeamSize(String? tournamentType) {
    switch (tournamentType?.toLowerCase()) {
      case 'solo':
        return 1;
      case 'duo':
        return 2;
      case 'squad':
        return 4;
      case '5v5':
        return 5;
      default:
        return 1;
    }
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
          if (!_hasDataInFirebase && !_isLoading)
            IconButton(
              icon: Icon(Icons.cloud_upload),
              onPressed: _seedDataToFirebase,
              tooltip: 'Add sample data to Firebase',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTournaments,
            tooltip: 'Refresh tournaments',
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
            if (!_hasDataInFirebase) ...[
              SizedBox(height: 8),
              Text(
                'Checking Firebase...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
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
              _hasDataInFirebase
                  ? 'No tournaments found for ${widget.gameName}'
                  : 'No tournaments found in Firebase',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _seedDataToFirebase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: Text('Add Sample Tournaments to Firebase'),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: _loadTournaments,
              child: Text('Refresh'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Data source indicator
          if (!_hasDataInFirebase)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(8),
              color: Colors.orange[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Showing sample data - Add tournaments via Admin Panel',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[800],
                    ),
                  ),
                ],
              ),
            ),

          // Tournaments count
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
                  ],
                ),
                Spacer(),
                if (_hasDataInFirebase)
                  Chip(
                    label: Text('LIVE'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
              ],
            ),
          ),

          // Tournaments list
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
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}