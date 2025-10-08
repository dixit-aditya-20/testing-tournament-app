import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../details/tournament_details.dart';
import '../modles/tournament_model.dart';
import '../services/firebase_service.dart';

class GameIdDialog extends StatefulWidget {
  final String gameName;
  final Tournament tournament;
  final Function(String, String) onConfirm;

  const GameIdDialog({
    Key? key,
    required this.gameName,
    required this.tournament,
    required this.onConfirm,
  }) : super(key: key);

  @override
  _GameIdDialogState createState() => _GameIdDialogState();
}

class _GameIdDialogState extends State<GameIdDialog> {
  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _playerIdController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = false;
  bool _hasExistingDetails = false;
  bool _isAlreadyRegistered = false;
  bool _isRegistrationClosed = false;
  bool _isTournamentFull = false;
  bool _showChangeRequest = false;
  Map<String, dynamic>? _existingGameDetails;

  // Razorpay instance
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
    _checkExistingData();
    _checkTournamentStatus();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _checkTournamentStatus() {
    final now = DateTime.now();
    setState(() {
      _isRegistrationClosed = now.isAfter(widget.tournament.registrationEnd);
      _isTournamentFull = widget.tournament.registeredPlayers >= widget.tournament.totalSlots;
    });
  }

  Future<void> _checkExistingData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if user already has game profile saved
      final existingDetails = await _firebaseService.getGameProfile(widget.gameName.toLowerCase());

      // Check if user is already registered for this tournament
      final isRegistered = await _firebaseService.hasUserRegisteredForTournament(widget.tournament.id);

      if (mounted) {
        setState(() {
          _isAlreadyRegistered = isRegistered;
          _hasExistingDetails = existingDetails != null;
          _existingGameDetails = existingDetails;

          if (_hasExistingDetails) {
            _playerNameController.text = existingDetails!['playerName'] ?? '';
            _playerIdController.text = existingDetails['playerId'] ?? '';
          }
        });
      }
    } catch (e) {
      print('❌ Error checking existing data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _buildTitle(),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _buildContent(),
        ),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildTitle() {
    if (_isAlreadyRegistered) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('Already Registered'),
        ],
      );
    } else if (_isRegistrationClosed) {
      return Row(
        children: [
          Icon(Icons.error, color: Colors.orange),
          SizedBox(width: 8),
          Text('Registration Closed'),
        ],
      );
    } else if (_isTournamentFull) {
      return Row(
        children: [
          Icon(Icons.people, color: Colors.red),
          SizedBox(width: 8),
          Text('Tournament Full'),
        ],
      );
    } else {
      return Text('Enter ${widget.gameName} Details');
    }
  }

  List<Widget> _buildContent() {
    if (_isLoading) {
      return [
        SizedBox(height: 20),
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Checking your details...', style: TextStyle(color: Colors.grey)),
      ];
    }

    if (_isAlreadyRegistered) {
      return _buildAlreadyRegisteredContent();
    }

    if (_isRegistrationClosed) {
      return _buildRegistrationClosedContent();
    }

    if (_isTournamentFull) {
      return _buildTournamentFullContent();
    }

    return _buildRegistrationForm();
  }

  List<Widget> _buildAlreadyRegisteredContent() {
    return [
      Icon(Icons.check_circle, color: Colors.green, size: 50),
      SizedBox(height: 16),
      Text(
        'You are already registered!',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 8),
      Text(
        'Tournament: ${widget.tournament.tournamentName}',
        style: TextStyle(color: Colors.grey[600]),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 8),
      Text(
        'Game: ${widget.tournament.gameName}',
        style: TextStyle(color: Colors.grey[600]),
      ),
      if (_existingGameDetails != null) ...[
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Registered Details:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
              ),
              SizedBox(height: 8),
              Text('Player Name: ${_existingGameDetails!['playerName']}'),
              Text('Game ID: ${_existingGameDetails!['playerId']}'),
            ],
          ),
        ),
      ],
      SizedBox(height: 16),
      _buildTournamentInfo(),
      SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context); // Close the dialog
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TournamentDetailsScreen(
                tournament: widget.tournament,
                playerName: _existingGameDetails!['playerName'] ?? '',
                playerId: _existingGameDetails!['playerId'] ?? '',
              ),
            ),
          );
        },
        icon: Icon(Icons.tour),
        label: Text('View Tournament Details'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    ];
  }

  List<Widget> _buildRegistrationClosedContent() {
    return [
      Icon(Icons.event_busy, color: Colors.orange, size: 50),
      SizedBox(height: 16),
      Text(
        'Registration Closed',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 8),
      Text(
        'The registration period for this tournament has ended.',
        style: TextStyle(color: Colors.grey[600]),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 16),
      _buildTournamentInfo(),
    ];
  }

  List<Widget> _buildTournamentFullContent() {
    return [
      Icon(Icons.people_outline, color: Colors.red, size: 50),
      SizedBox(height: 16),
      Text(
        'Tournament Full',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 8),
      Text(
        'All ${widget.tournament.totalSlots} slots have been filled.',
        style: TextStyle(color: Colors.grey[600]),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 16),
      _buildTournamentInfo(),
    ];
  }

  List<Widget> _buildRegistrationForm() {
    return [
      if (_hasExistingDetails && !_showChangeRequest) ...[
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'We found your saved ${widget.gameName} details',
                  style: TextStyle(color: Colors.green[800]),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
      ],
      Text(
        'Register for "${widget.tournament.tournamentName}"',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 8),
      Text(
        'Game: ${widget.tournament.gameName}',
        style: TextStyle(color: Colors.grey[600]),
      ),
      SizedBox(height: 16),
      _buildTournamentInfo(),
      SizedBox(height: 20),

      // Player Name Field
      TextField(
        controller: _playerNameController,
        enabled: !_hasExistingDetails || _showChangeRequest,
        decoration: InputDecoration(
          labelText: 'Player Name',
          border: OutlineInputBorder(),
          hintText: 'Enter your in-game name',
          prefixIcon: Icon(Icons.person),
          suffixIcon: _hasExistingDetails && !_showChangeRequest
              ? Icon(Icons.lock, color: Colors.grey)
              : null,
        ),
        readOnly: _hasExistingDetails && !_showChangeRequest,
      ),
      SizedBox(height: 16),

      // Game ID Field
      TextField(
        controller: _playerIdController,
        enabled: !_hasExistingDetails || _showChangeRequest,
        decoration: InputDecoration(
          labelText: 'Game ID',
          border: OutlineInputBorder(),
          hintText: 'Enter your game ID/username',
          prefixIcon: Icon(Icons.videogame_asset),
          suffixIcon: _hasExistingDetails && !_showChangeRequest
              ? Icon(Icons.lock, color: Colors.grey)
              : null,
        ),
        readOnly: _hasExistingDetails && !_showChangeRequest,
      ),

      // Change Request Button (only show when fields are locked)
      if (_hasExistingDetails && !_showChangeRequest) ...[
        SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _showChangeRequestForm,
          icon: Icon(Icons.edit, size: 18),
          label: Text('Request to Change Game Details'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            side: BorderSide(color: Colors.orange),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Changes may take 3-4 working days to process',
          style: TextStyle(fontSize: 12, color: Colors.orange),
          textAlign: TextAlign.center,
        ),
      ],

      // Warning Note
      SizedBox(height: 16),
      _buildWarningNote(),

      if (_isLoading) ...[
        SizedBox(height: 16),
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Processing...', style: TextStyle(color: Colors.grey)),
      ],
    ];
  }

  Widget _buildWarningNote() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Important: If your username and ID are incorrect, you might not receive any of your winnings. Please double-check before proceeding.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentInfo() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Entry Fee:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '₹${widget.tournament.entryFee}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Slots:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${widget.tournament.registeredPlayers}/${widget.tournament.totalSlots}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Registration Ends:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                _formatDate(widget.tournament.registrationEnd),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Prize Pool:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '₹${widget.tournament.prizePool}',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showChangeRequestForm() {
    setState(() {
      _showChangeRequest = true;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Change Request'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are requesting to change your game details. Please note:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            _buildBulletPoint('Changes may take 3-4 working days to process'),
            _buildBulletPoint('You cannot participate in tournaments during this period'),
            _buildBulletPoint('Your current winnings will be transferred to your new account'),
            _buildBulletPoint('All changes are subject to admin approval'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text('PROCEED'),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    if (_isAlreadyRegistered || _isRegistrationClosed || _isTournamentFull) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK', style: TextStyle(color: Colors.deepPurple)),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: _isLoading ? null : () {
          print('❌ GameIdDialog cancelled');
          Navigator.pop(context);
        },
        child: Text(
          'CANCEL',
          style: TextStyle(color: Colors.grey[700]),
        ),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : _onConfirmPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _showChangeRequest ? Colors.orange : Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        child: Text(
          _getButtonText(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ];
  }

  String _getButtonText() {
    if (_showChangeRequest) {
      return 'SUBMIT REQUEST';
    } else if (_hasExistingDetails) {
      return 'PAY NOW';
    } else {
      return 'SAVE & PAY';
    }
  }

  void _onConfirmPressed() {
    final playerName = _playerNameController.text.trim();
    final playerId = _playerIdController.text.trim();

    print('🔍 Validating inputs: Name="$playerName", ID="$playerId"');

    if (playerName.isEmpty) {
      print('⚠️ Player name is empty');
      _showError('Please enter your player name');
      return;
    }

    if (playerId.isEmpty) {
      print('⚠️ Game ID is empty');
      _showError('Please enter your game ID');
      return;
    }

    if (_isRegistrationClosed) {
      _showError('Registration for this tournament has closed');
      return;
    }

    if (_isTournamentFull) {
      _showError('This tournament is already full');
      return;
    }

    print('✅ Inputs valid, proceeding with registration');

    setState(() {
      _isLoading = true;
    });

    if (_showChangeRequest) {
      _submitChangeRequest(playerName, playerId);
    } else {
      _processRegistration(playerName, playerId);
    }
  }

  void _submitChangeRequest(String playerName, String playerId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('change_requests').add({
        'userId': userId,
        'gameName': widget.gameName,
        'oldPlayerName': _existingGameDetails!['playerName'],
        'oldPlayerId': _existingGameDetails!['playerId'],
        'newPlayerName': playerName,
        'newPlayerId': playerId,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'estimatedCompletion': DateTime.now().add(Duration(days: 4)),
      });

      // Update game profile with new details
      await _firebaseService.saveUserGameProfile(
        gameId: widget.gameName.toLowerCase(),
        gameName: widget.gameName,
        playerName: playerName,
        playerId: playerId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Change request submitted successfully!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error submitting change request: $e');
      _showError('Failed to submit change request. Please try again.');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _processRegistration(String playerName, String playerId) {
    if (!_hasExistingDetails) {
      _saveUserGameProfile(playerName, playerId).then((success) {
        if (success) {
          _tryWalletPayment(playerName, playerId);
        } else {
          setState(() {
            _isLoading = false;
          });
          _showError('Failed to save your details. Please try again.');
        }
      });
    } else {
      _tryWalletPayment(playerName, playerId);
    }
  }

  Future<bool> _saveUserGameProfile(String playerName, String playerId) async {
    try {
      final success = await _firebaseService.saveUserGameProfile(
        gameId: widget.gameName.toLowerCase(),
        gameName: widget.gameName,
        playerName: playerName,
        playerId: playerId,
      );

      if (success) {
        print('✅ User game profile saved successfully');
        return true;
      } else {
        print('❌ Failed to save user game profile');
        return false;
      }
    } catch (e) {
      print('❌ Error saving user game profile: $e');
      return false;
    }
  }

  void _tryWalletPayment(String playerName, String playerId) async {
    print('💰 Trying wallet payment...');

    final success = await _firebaseService.deductFromWallet(widget.tournament.entryFee);

    if (success) {
      print('✅ Wallet payment successful');
      _completeRegistration(playerName, playerId, 'wallet_${DateTime.now().millisecondsSinceEpoch}');
    } else {
      print('❌ Insufficient wallet balance, opening Razorpay');
      _openRazorpayPayment(playerName, playerId);
    }
  }

  void _openRazorpayPayment(String playerName, String playerId) {
    print('💳 Opening Razorpay payment gateway...');

    try {
      final user = FirebaseAuth.instance.currentUser;

      var options = {
        'key': 'rzp_test_1DP5mmOlF5G5ag',
        'amount': (widget.tournament.entryFee * 100).toInt(),
        'currency': 'INR',
        'name': 'Game Tournaments',
        'description': '${widget.tournament.tournamentName} - ${widget.tournament.gameName}',
        'prefill': {
          'contact': '8888888888',
          'email': user?.email ?? 'user@example.com',
          'name': playerName,
        },
        'external': {
          'wallets': ['paytm', 'phonepe', 'gpay']
        },
        'theme': {
          'color': '#6A0DAD'
        }
      };

      print('💰 Razorpay options: $options');

      // Clear and reinitialize to avoid multiple listeners
      _razorpay.clear();
      _initializeRazorpay();

      _razorpay.open(options);

    } catch (e) {
      print('❌ Error opening Razorpay: $e');
      _showError('Error opening payment gateway: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('✅ Payment Success: ${response.paymentId}');

    final playerName = _playerNameController.text.trim();
    final playerId = _playerIdController.text.trim();

    _completeRegistration(playerName, playerId, response.paymentId!);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('❌ Payment Error: ${response.code} - ${response.message}');
    _showError('Payment failed: ${response.message ?? "Unknown error"}');

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('👛 External Wallet: ${response.walletName}');
  }

  void _completeRegistration(String playerName, String playerId, String paymentId) async {
    print('💰 Processing successful payment...');

    try {
      final success = await _firebaseService.registerForTournament(
        tournament: widget.tournament,
        playerName: playerName,
        playerId: playerId,
        paymentId: paymentId,
        paymentMethod: paymentId.startsWith('wallet_') ? 'wallet' : 'razorpay',
      );

      if (success) {
        print('🎉 Tournament registration saved successfully!');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Success! You are now registered for ${widget.tournament.tournamentName}'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Call the onConfirm callback
          widget.onConfirm(playerName, playerId);

          // Close dialog
          Navigator.pop(context);
        }

      } else {
        throw Exception('Failed to save tournament registration');
      }
    } catch (e) {
      print('❌ Error processing payment success: $e');

      if (mounted) {
        _showError('Payment successful but registration failed. Please contact support.');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    _playerNameController.dispose();
    _playerIdController.dispose();
    super.dispose();
  }
}