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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _hasExistingDetails = false;
  bool _isAlreadyRegistered = false;
  bool _isRegistrationClosed = false;
  bool _isTournamentFull = false;
  bool _showChangeRequest = false;
  Map<String, dynamic>? _existingGameDetails;

  // Payment variables
  late Razorpay _razorpay;
  String _selectedPaymentMethod = 'wallet';
  double _walletBalance = 0.0;
  String? _userName;
  String? _userId;

  // Track payment state to prevent duplicates
  bool _paymentInProgress = false;

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
    _checkExistingData();
    _checkTournamentStatus();
    _loadWalletBalance();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _checkTournamentStatus() {
    final now = DateTime.now();
    final registrationEnd = widget.tournament.registrationEnd.toDate();

    setState(() {
      _isRegistrationClosed = now.isAfter(registrationEnd);
      _isTournamentFull = widget.tournament.registeredPlayers >= widget.tournament.totalSlots;
    });
  }

  Future<void> _loadWalletBalance() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userQuery = await _firestore
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          _userName = userDoc.id;
          _userId = user.uid;

          final walletDataDoc = await _firestore
              .collection('wallet')
              .doc('users')
              .collection(_userName!)
              .doc('wallet_data')
              .get();

          if (walletDataDoc.exists) {
            final walletData = walletDataDoc.data();
            setState(() {
              _walletBalance = (walletData?['total_balance'] as num?)?.toDouble() ?? 0.0;
            });
          } else {
            await _initializeWallet();
          }
        }
      }
    } catch (e) {
      print('❌ Error loading wallet balance: $e');
    }
  }

  Future<void> _initializeWallet() async {
    try {
      if (_userName != null && _userId != null) {
        await _firestore
            .collection('wallet')
            .doc('users')
            .collection(_userName!)
            .doc('wallet_data')
            .set({
          'total_balance': 0.0,
          'total_winning': 0.0,
          'user_id': _userId,
          'user_name': _userName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _walletBalance = 0.0;
        });
      }
    } catch (e) {
      print('❌ Error initializing wallet: $e');
    }
  }

  Future<void> _checkExistingData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userQuery = await _firestore
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          _userName = userDoc.id;
          _userId = user.uid;
          final userData = userDoc.data();

          final tournaments = userData['tournaments'] as Map<String, dynamic>? ?? {};
          final gameKey = _getGameKey(widget.gameName);

          if (tournaments.containsKey(gameKey)) {
            final gameDetails = tournaments[gameKey] as Map<String, dynamic>? ?? {};
            final nameField = '${widget.gameName.toUpperCase()}_NAME';
            final idField = '${widget.gameName.toUpperCase()}_ID';

            final playerName = gameDetails[nameField];
            final playerId = gameDetails[idField];

            if (playerName != null && playerName.isNotEmpty &&
                playerId != null && playerId.isNotEmpty) {
              setState(() {
                _hasExistingDetails = true;
                _existingGameDetails = {
                  'playerName': playerName,
                  'playerId': playerId,
                };
                _playerNameController.text = playerName;
                _playerIdController.text = playerId;
              });
            }
          }

          final registrationQuery = await _firestore
              .collection('tournament_registrations')
              .where('userId', isEqualTo: user.uid)
              .where('tournamentId', isEqualTo: widget.tournament.id)
              .limit(1)
              .get();

          setState(() {
            _isAlreadyRegistered = registrationQuery.docs.isNotEmpty;
          });
        }
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
      return Text(
        _hasExistingDetails ? 'Save & Pay' : 'Enter ${widget.gameName} Details',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      );
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
          Navigator.pop(context);
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

      TextField(
        controller: _playerIdController,
        enabled: !_hasExistingDetails || _showChangeRequest,
        decoration: InputDecoration(
          labelText: '${widget.gameName} ID',
          border: OutlineInputBorder(),
          hintText: 'Enter your game ID/username',
          prefixIcon: Icon(Icons.videogame_asset),
          suffixIcon: _hasExistingDetails && !_showChangeRequest
              ? Icon(Icons.lock, color: Colors.grey)
              : null,
        ),
        readOnly: _hasExistingDetails && !_showChangeRequest,
      ),

      if (!_showChangeRequest) ...[
        SizedBox(height: 20),
        _buildPaymentOptions(),
      ],

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

  Widget _buildPaymentOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        SizedBox(height: 12),
        _buildPaymentOption(
          value: 'wallet',
          title: 'Wallet Balance',
          subtitle: 'Use your available wallet balance',
          icon: Icons.account_balance_wallet,
          balance: _walletBalance,
        ),
        SizedBox(height: 8),
        _buildPaymentOption(
          value: 'razorpay',
          title: 'Razorpay UPI/Cards',
          subtitle: 'Pay using UPI, Credit/Debit Cards',
          icon: Icons.credit_card,
        ),
        SizedBox(height: 8),
        _buildPaymentOption(
          value: 'paytm',
          title: 'PayTM',
          subtitle: 'Pay using PayTM Wallet or UPI',
          icon: Icons.payment,
        ),
        SizedBox(height: 8),
        _buildPaymentOption(
          value: 'phonepe',
          title: 'PhonePe',
          subtitle: 'Pay using PhonePe UPI',
          icon: Icons.phone_android,
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    double? balance,
  }) {
    final isSelected = _selectedPaymentMethod == value;
    final isWallet = value == 'wallet';
    final hasSufficientBalance = isWallet ? (_walletBalance >= widget.tournament.entryFee) : true;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.deepPurple : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? Colors.deepPurple.withOpacity(0.05) : Colors.transparent,
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _selectedPaymentMethod,
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedPaymentMethod = newValue;
            });
          }
        },
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: isSelected ? Colors.deepPurple : Colors.grey[700]),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.deepPurple : Colors.grey[800],
                  ),
                ),
              ],
            ),
            if (isWallet && balance != null) ...[
              SizedBox(height: 4),
              Text(
                'Balance: ₹${balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: hasSufficientBalance ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12),
        ),
        secondary: isWallet && !hasSufficientBalance
            ? Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.orange),
          ),
          child: Text(
            'Low Balance',
            style: TextStyle(
              fontSize: 10,
              color: Colors.orange[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        )
            : null,
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: EdgeInsets.symmetric(horizontal: 8),
      ),
    );
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
                _formatDate(widget.tournament.registrationEnd.toDate()),
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
                '₹${widget.tournament.winningPrize}',
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
      return 'PAY NOW';
    }
  }

  void _onConfirmPressed() {
    if (_paymentInProgress) {
      print('⚠️ Payment already in progress, ignoring duplicate click');
      return;
    }

    final playerName = _playerNameController.text.trim();
    final playerId = _playerIdController.text.trim();

    print('🔍 Validating inputs: Name="$playerName", ID="$playerId"');

    if (playerName.isEmpty) {
      _showError('Please enter your player name');
      return;
    }

    if (playerId.isEmpty) {
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

    if (_selectedPaymentMethod == 'wallet' && _walletBalance < widget.tournament.entryFee) {
      _showError('Insufficient wallet balance. Please choose another payment method.');
      return;
    }

    print('✅ Inputs valid, proceeding with registration');
    setState(() {
      _isLoading = true;
      _paymentInProgress = true;
    });

    if (_showChangeRequest) {
      _submitChangeRequest(playerName, playerId);
    } else {
      _processRegistration(playerName, playerId);
    }
  }

  void _submitChangeRequest(String playerName, String playerId) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userQuery = await _firestore
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          final userName = userDoc.id;

          await _firestore.collection('change_requests').add({
            'userId': user.uid,
            'userName': userName,
            'gameName': widget.gameName,
            'oldPlayerName': _existingGameDetails!['playerName'],
            'oldPlayerId': _existingGameDetails!['playerId'],
            'newPlayerName': playerName,
            'newPlayerId': playerId,
            'status': 'pending',
            'requestedAt': FieldValue.serverTimestamp(),
            'estimatedCompletion': DateTime.now().add(Duration(days: 4)),
          });

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
        }
      }
    } catch (e) {
      print('❌ Error submitting change request: $e');
      _showError('Failed to submit change request. Please try again.');
      setState(() {
        _isLoading = false;
        _paymentInProgress = false;
      });
    }
  }

  void _processRegistration(String playerName, String playerId) {
    _saveUserGameDetails(playerName, playerId).then((success) {
      if (success) {
        _processPayment(playerName, playerId);
      } else {
        setState(() {
          _isLoading = false;
          _paymentInProgress = false;
        });
        _showError('Failed to save your details. Please try again.');
      }
    });
  }

  void _processPayment(String playerName, String playerId) {
    switch (_selectedPaymentMethod) {
      case 'wallet':
        _processWalletPayment(playerName, playerId);
        break;
      case 'razorpay':
        _openRazorpayPayment(playerName, playerId);
        break;
      case 'paytm':
      case 'phonepe':
        _processUpiPayment(playerName, playerId);
        break;
      default:
        _openRazorpayPayment(playerName, playerId);
    }
  }

  Future<bool> _saveUserGameDetails(String playerName, String playerId) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userQuery = await _firestore
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          final userName = userDoc.id;

          final gameKey = _getGameKey(widget.gameName);
          final nameField = '${widget.gameName.toUpperCase()}_NAME';
          final idField = '${widget.gameName.toUpperCase()}_ID';

          await _firestore.collection('users').doc(userName).update({
            'tournaments.$gameKey.$nameField': playerName,
            'tournaments.$gameKey.$idField': playerId,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          print('✅ User game details saved successfully');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error saving user game details: $e');
      return false;
    }
  }

  void _processWalletPayment(String playerName, String playerId) async {
    print('💰 Processing wallet payment...');

    try {
      final user = _auth.currentUser;
      if (user != null && _userName != null) {
        final walletDataDoc = await _firestore
            .collection('wallet')
            .doc('users')
            .collection(_userName!)
            .doc('wallet_data')
            .get();

        if (walletDataDoc.exists) {
          final walletData = walletDataDoc.data();
          final currentBalance = (walletData?['total_balance'] as num?)?.toDouble() ?? 0.0;

          if (currentBalance < widget.tournament.entryFee) {
            _showError('Insufficient wallet balance. Please choose another payment method.');
            setState(() {
              _isLoading = false;
              _paymentInProgress = false;
            });
            return;
          }

          final batch = _firestore.batch();

          final walletDataRef = _firestore
              .collection('wallet')
              .doc('users')
              .collection(_userName!)
              .doc('wallet_data');
          batch.update(walletDataRef, {
            'total_balance': FieldValue.increment(-widget.tournament.entryFee),
          });

          final transactionRef = _firestore
              .collection('wallet')
              .doc('users')
              .collection(_userName!)
              .doc('transactions')
              .collection('successful')
              .doc();

          batch.set(transactionRef, {
            'amount': widget.tournament.entryFee,
            'type': 'debit',
            'description': 'Tournament Registration - ${widget.tournament.tournamentName}',
            'tournamentId': widget.tournament.id,
            'tournamentName': widget.tournament.tournamentName,
            'gameName': widget.tournament.gameName,
            'playerName': playerName,
            'playerId': playerId,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'completed',
            'paymentMethod': 'wallet',
          });

          await batch.commit();

          setState(() {
            _walletBalance = currentBalance - widget.tournament.entryFee;
          });

          print('✅ Wallet payment successful');
          _completeRegistration(playerName, playerId, 'wallet_${DateTime.now().millisecondsSinceEpoch}');
        } else {
          _showError('Wallet not found. Please try another payment method.');
          setState(() {
            _isLoading = false;
            _paymentInProgress = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error processing wallet payment: $e');
      _showError('Wallet payment failed. Please try another payment method.');
      setState(() {
        _isLoading = false;
        _paymentInProgress = false;
      });
    }
  }

  void _processUpiPayment(String playerName, String playerId) {
    print('📱 Processing ${_selectedPaymentMethod.toUpperCase()} payment...');
    _openRazorpayPayment(playerName, playerId);
  }

  void _openRazorpayPayment(String playerName, String playerId) {
    print('💳 Opening Razorpay payment gateway...');

    try {
      final user = _auth.currentUser;

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
        'theme': {
          'color': '#6A0DAD'
        }
      };

      if (_selectedPaymentMethod == 'paytm' || _selectedPaymentMethod == 'phonepe') {
        options['external'] = {
          'wallets': _selectedPaymentMethod == 'paytm' ? ['paytm'] : ['phonepe']
        };
      }

      print('💰 Razorpay options: $options');

      // Clear and reinitialize to prevent duplicate listeners
      _razorpay.clear();
      _initializeRazorpay();

      _razorpay.open(options);

    } catch (e) {
      print('❌ Error opening Razorpay: $e');
      _showError('Error opening payment gateway: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _paymentInProgress = false;
        });
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('🔄 Payment Success Handler Started');
    print('✅ Payment Success: ${response.paymentId}');

    // IMPORTANT: Clear Razorpay immediately
    _razorpay.clear();

    final playerName = _playerNameController.text.trim();
    final playerId = _playerIdController.text.trim();

    // Store payment record and complete registration
    _storeRazorpayPaymentRecord(response, playerName, playerId);
    print('🔄 Payment Success Handler Completed');
  }

  Future<void> _storeRazorpayPaymentRecord(
      PaymentSuccessResponse response, String playerName, String playerId) async {
    try {
      if (_userName != null) {
        final razorpayDocRef = _firestore
            .collection('wallet')
            .doc('users')
            .collection(_userName!)
            .doc('transactions')
            .collection('successful')
            .doc(response.paymentId);

        await razorpayDocRef.set({
          'paymentId': response.paymentId,
          'orderId': response.orderId,
          'signature': response.signature,
          'amount': widget.tournament.entryFee,
          'type': 'debit',
          'description': 'Tournament Registration - ${widget.tournament.tournamentName}',
          'tournamentId': widget.tournament.id,
          'tournamentName': widget.tournament.tournamentName,
          'gameName': widget.tournament.gameName,
          'playerName': playerName,
          'playerId': playerId,
          'paymentMethod': _selectedPaymentMethod,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        });

        _completeRegistration(playerName, playerId, response.paymentId!);
      }
    } catch (e) {
      print('❌ Error storing payment record: $e');
      _showError('Payment successful but failed to save record. Please contact support.');
      setState(() {
        _isLoading = false;
        _paymentInProgress = false;
      });
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('❌ Payment Error: ${response.code} - ${response.message}');

    // IMPORTANT: Clear Razorpay on error too
    _razorpay.clear();

    if (_userName != null) {
      _storeFailedPaymentRecord(response);
    }

    _showError('Payment failed: ${response.message ?? "Unknown error"}');

    if (mounted) {
      setState(() {
        _isLoading = false;
        _paymentInProgress = false;
      });
    }
  }

  Future<void> _storeFailedPaymentRecord(PaymentFailureResponse response) async {
    try {
      final playerName = _playerNameController.text.trim();
      final playerId = _playerIdController.text.trim();

      final failedDocRef = _firestore
          .collection('wallet')
          .doc('users')
          .collection(_userName!)
          .doc('transactions')
          .collection('failed')
          .doc();

      await failedDocRef.set({
        'error_code': response.code,
        'error_message': response.message,
        'amount': widget.tournament.entryFee,
        'description': 'Failed Tournament Registration - ${widget.tournament.tournamentName}',
        'tournamentId': widget.tournament.id,
        'tournamentName': widget.tournament.tournamentName,
        'gameName': widget.tournament.gameName,
        'playerName': playerName,
        'playerId': playerId,
        'paymentMethod': _selectedPaymentMethod,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'failed',
      });
    } catch (e) {
      print('❌ Error storing failed payment record: $e');
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('👛 External Wallet: ${response.walletName}');

    // Clear Razorpay for external wallet too
    _razorpay.clear();
  }

  void _completeRegistration(String playerName, String playerId, String paymentId) async {
    print('💰 Processing successful payment...');

    try {
      final user = _auth.currentUser;
      if (user != null && _userName != null) {
        final batch = _firestore.batch();

        final registrationRef = _firestore.collection('tournament_registrations').doc();
        batch.set(registrationRef, {
          'userId': user.uid,
          'userName': _userName,
          'tournamentId': widget.tournament.id,
          'tournamentName': widget.tournament.tournamentName,
          'gameName': widget.tournament.gameName,
          'playerName': playerName,
          'playerId': playerId,
          'entryFee': widget.tournament.entryFee,
          'paymentId': paymentId,
          'paymentMethod': _selectedPaymentMethod,
          'registeredAt': FieldValue.serverTimestamp(),
          'status': 'registered',
        });

        final tournamentRef = _firestore.collection('tournaments').doc(widget.tournament.id);
        batch.update(tournamentRef, {
          'registered_players': FieldValue.increment(1),
          'updated_at': FieldValue.serverTimestamp(),
        });

        await batch.commit();

        print('🎉 Tournament registration saved successfully!');

        // IMPORTANT: Close the dialog FIRST before showing any messages
        if (mounted) {
          Navigator.pop(context); // Close the dialog first

          // Then show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 Success! You are now registered for ${widget.tournament.tournamentName}'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Call the onConfirm callback AFTER dialog is closed
          widget.onConfirm(playerName, playerId);
        }
      }
    } catch (e) {
      print('❌ Error processing payment success: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _paymentInProgress = false;
        });

        _showError('Payment successful but registration failed. Please contact support with payment ID: $paymentId');
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