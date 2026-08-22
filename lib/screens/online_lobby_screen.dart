import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_strings.dart';
import '../services/firebase_service.dart';
import '../services/room_repository.dart';
import 'online_game_screen.dart';
import 'qr_scan_screen.dart';

class OnlineLobbyScreen extends StatefulWidget {
  final AppLang lang;
  const OnlineLobbyScreen({super.key, required this.lang});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  late S s;
  bool _busy = false;
  String? _createdRoomId;
  String _playerName = '';
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    s = S(widget.lang);
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _playerName = prefs.getString('player_name') ?? '';
      _nameController.text = _playerName;
    });
  }

  Future<void> _saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_name', name);
  }

  String get _effectiveName =>
      _nameController.text.trim().isEmpty ? (s.isFa ? 'بازیکن' : 'Player') : _nameController.text.trim();

  Future<void> _createRoom() async {
    setState(() => _busy = true);
    try {
      await FirebaseService.ensureInitialized();
      final uid = await FirebaseService.ensureSignedIn();
      await _saveName(_effectiveName);
      final roomId = RoomRepository.generateRoomCode();
      await RoomRepository.createRoom(roomId: roomId, myUid: uid, myName: _effectiveName);
      setState(() {
        _createdRoomId = roomId;
        _busy = false;
      });
    } catch (e) {
      setState(() => _busy = false);
      _showError('$e');
    }
  }

  Future<void> _joinWithCode(String code) async {
    setState(() => _busy = true);
    try {
      await FirebaseService.ensureInitialized();
      final uid = await FirebaseService.ensureSignedIn();
      await _saveName(_effectiveName);
      final error = await RoomRepository.joinRoom(roomId: code, myUid: uid, myName: _effectiveName);
      setState(() => _busy = false);
      if (error == 'not_found') {
        _showError(s.isFa ? 'اتاقی با این کد پیدا نشد.' : 'No room found with this code.');
        return;
      }
      if (error == 'full') {
        _showError(s.isFa ? 'این اتاق پر است.' : 'This room is full.');
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineGameScreen(lang: widget.lang, roomId: code, myUid: uid),
        ),
      );
    } catch (e) {
      setState(() => _busy = false);
      _showError('$e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade400));
  }

  Future<void> _scanQr() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => QrScanScreen(lang: widget.lang)),
    );
    if (code != null && code.isNotEmpty) {
      _joinWithCode(code);
    }
  }

  Future<void> _goToCreatedRoomWhenJoined() async {
    if (_createdRoomId == null) return;
    final uid = await FirebaseService.ensureSignedIn();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(lang: widget.lang, roomId: _createdRoomId!, myUid: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: s.isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(s.onlineMode)),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: _createdRoomId != null ? _buildRoomCreatedView() : _buildMenuView(),
        ),
      ),
    );
  }

  Widget _buildMenuView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: s.isFa ? 'نام شما' : 'Your name'),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _busy ? null : _createRoom,
            icon: const Icon(Icons.add_box),
            label: Text(s.isFa ? 'ساخت اتاق جدید' : 'Create New Room'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _busy ? null : _scanQr,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(s.isFa ? 'اسکن QR اتاق' : 'Scan Room QR'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 24),
          Text(s.isFa ? 'یا کد اتاق را دستی وارد کنید:' : 'Or enter room code manually:'),
          const SizedBox(height: 8),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: s.isFa ? 'کد اتاق' : 'Room code',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy || _codeController.text.trim().isEmpty
                ? null
                : () => _joinWithCode(_codeController.text.trim()),
            child: Text(s.isFa ? 'پیوستن' : 'Join'),
          ),
          if (_busy) const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCreatedView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          s.isFa ? 'منتظر پیوستن بازیکن دوم...' : 'Waiting for player 2 to join...',
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: QrImageView(data: _createdRoomId!, size: 220),
        ),
        const SizedBox(height: 16),
        Text(
          _createdRoomId!,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4),
        ),
        const SizedBox(height: 8),
        Text(
          s.isFa
              ? 'این کد یا QR را برای بازیکن دوم بفرستید'
              : 'Send this code or QR to the second player',
          style: const TextStyle(color: Colors.black54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // بررسی دوره‌ای پیوستن بازیکن دوم
        StreamBuilder(
          stream: RoomRepository.watchRoom(_createdRoomId!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final data = snapshot.data!.data();
            if (data == null) return const SizedBox.shrink();
            final players = Map<String, dynamic>.from(data['players'] ?? {});
            if (players.containsKey('1')) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _goToCreatedRoomWhenJoined());
              return Text(s.isFa ? 'بازیکن پیدا شد! در حال ورود...' : 'Player found! Joining...');
            }
            return const CircularProgressIndicator();
          },
        ),
      ],
    );
  }
}
