import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_strings.dart';
import '../services/firebase_service.dart';
import '../services/room_repository.dart';
import '../services/presence_repository.dart';
import '../services/matchmaking_repository.dart';
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
  bool _readyForPresence = false;
  String? _createdRoomId;
  String _playerName = '';
  String? _myUid;
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  Timer? _heartbeatTimer;
  StreamSubscription? _challengeSub;
  StreamSubscription? _queueSub;
  bool _challengeDialogShown = false;
  bool _quickMatching = false;

  @override
  void initState() {
    super.initState();
    s = S(widget.lang);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _playerName = prefs.getString('player_name') ?? '';
    _nameController.text = _playerName;
    setState(() {});

    try {
      await FirebaseService.ensureInitialized();
      final uid = await FirebaseService.ensureSignedIn();
      _myUid = uid;
      await PresenceRepository.goOnline(uid, _effectiveName);
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        PresenceRepository.heartbeat(uid);
      });
      _challengeSub = PresenceRepository.watchMyChallenge(uid).listen(_onChallengeSnapshot);
      setState(() => _readyForPresence = true);
    } catch (e) {
      _showError('$e');
    }
  }

  void _onChallengeSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists || _challengeDialogShown || _createdRoomId != null) return;
    final data = snap.data();
    if (data == null) return;
    _challengeDialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(s.isFa ? 'دعوت به دوئل' : 'Duel Invitation'),
        content: Text(
          s.isFa
              ? '${data['fromName']} شما را به بازی دعوت کرد. قبول می‌کنید؟'
              : '${data['fromName']} challenged you to a duel. Accept?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _challengeDialogShown = false;
              await PresenceRepository.clearChallenge(_myUid!);
            },
            child: Text(s.isFa ? 'رد' : 'Decline'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final roomId = data['roomId'] as String;
              await PresenceRepository.clearChallenge(_myUid!);
              await RoomRepository.joinRoom(roomId: roomId, myUid: _myUid!, myName: _effectiveName);
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OnlineGameScreen(lang: widget.lang, roomId: roomId, myUid: _myUid!),
                ),
              );
            },
            child: Text(s.isFa ? 'قبول' : 'Accept'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _challengeSub?.cancel();
    _queueSub?.cancel();
    if (_myUid != null) {
      PresenceRepository.goOffline(_myUid!);
      MatchmakingRepository.cancelQueue(_myUid!);
    }
    super.dispose();
  }

  Future<void> _saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_name', name);
    if (_myUid != null) await PresenceRepository.goOnline(_myUid!, name);
  }

  String get _effectiveName =>
      _nameController.text.trim().isEmpty ? (s.isFa ? 'بازیکن' : 'Player') : _nameController.text.trim();

  Future<void> _createRoom() async {
    setState(() => _busy = true);
    try {
      final uid = _myUid ?? await FirebaseService.ensureSignedIn();
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

  Future<void> _challenge(String targetUid, String targetName) async {
    setState(() => _busy = true);
    try {
      final uid = _myUid ?? await FirebaseService.ensureSignedIn();
      await _saveName(_effectiveName);
      final roomId = RoomRepository.generateRoomCode();
      await RoomRepository.createRoom(roomId: roomId, myUid: uid, myName: _effectiveName);
      await PresenceRepository.sendChallenge(
        toUid: targetUid,
        fromUid: uid,
        fromName: _effectiveName,
        roomId: roomId,
      );
      setState(() {
        _createdRoomId = roomId;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.isFa ? 'دعوت‌نامه برای $targetName فرستاده شد' : 'Invitation sent to $targetName'),
      ));
    } catch (e) {
      setState(() => _busy = false);
      _showError('$e');
    }
  }

  Future<void> _joinWithCode(String code) async {
    setState(() => _busy = true);
    try {
      final uid = _myUid ?? await FirebaseService.ensureSignedIn();
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

  Future<void> _startQuickMatch() async {
    setState(() => _quickMatching = true);
    try {
      final uid = _myUid ?? await FirebaseService.ensureSignedIn();
      await _saveName(_effectiveName);
      final roomId = await MatchmakingRepository.tryQuickMatch(myUid: uid, myName: _effectiveName);
      if (roomId != null) {
        // بلافاصله جفت شدیم
        if (!mounted) return;
        setState(() => _quickMatching = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnlineGameScreen(lang: widget.lang, roomId: roomId, myUid: uid),
          ),
        );
        return;
      }
      // کسی پیدا نشد؛ منتظر می‌مانیم تا نفر بعدی ما را پیدا کند
      _queueSub?.cancel();
      _queueSub = MatchmakingRepository.watchMyQueueEntry(uid).listen((snap) {
        final data = snap.data();
        if (data != null && data['status'] == 'matched' && data['roomId'] != null) {
          _queueSub?.cancel();
          if (!mounted) return;
          setState(() => _quickMatching = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OnlineGameScreen(
                  lang: widget.lang, roomId: data['roomId'] as String, myUid: uid),
            ),
          );
        }
      });
    } catch (e) {
      setState(() => _quickMatching = false);
      _showError('$e');
    }
  }

  Future<void> _cancelQuickMatch() async {
    _queueSub?.cancel();
    if (_myUid != null) await MatchmakingRepository.cancelQueue(_myUid!);
    setState(() => _quickMatching = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
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
    if (_createdRoomId == null || _myUid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(lang: widget.lang, roomId: _createdRoomId!, myUid: _myUid!),
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
          child: _quickMatching
              ? _buildQuickMatchingView()
              : (_createdRoomId != null ? _buildRoomCreatedView() : _buildMenuView()),
        ),
      ),
    );
  }

  Widget _buildMenuView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: s.isFa ? 'نام شما' : 'Your name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _busy ? null : _startQuickMatch,
          icon: const Icon(Icons.flash_on),
          label: Text(s.isFa ? '⚡ بازی خودکار (اتصال به هر بازیکن آماده)' : '⚡ Quick Match (connect to anyone ready)'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _busy ? null : _createRoom,
          icon: const Icon(Icons.add_box),
          label: Text(s.isFa ? 'ساخت اتاق جدید (با QR)' : 'Create New Room (with QR)'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _scanQr,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(s.isFa ? 'اسکن QR' : 'Scan QR'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: s.isFa ? 'کد اتاق' : 'Room code',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              onPressed: _busy || _codeController.text.trim().isEmpty
                  ? null
                  : () => _joinWithCode(_codeController.text.trim()),
              icon: const Icon(Icons.login),
            ),
          ],
        ),
        const Divider(height: 32),
        Text(s.isFa ? 'بازیکنان آنلاین (برای دوئل بزنید)' : 'Online Players (tap to duel)',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(child: _buildPlayersList()),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildPlayersList() {
    if (!_readyForPresence) return const Center(child: CircularProgressIndicator());
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: PresenceRepository.watchOnlinePlayers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final now = DateTime.now();
        final docs = snapshot.data!.docs.where((d) {
          if (d.id == _myUid) return false;
          final data = d.data();
          final lastSeen = data['lastSeen'];
          if (lastSeen is! Timestamp) return false;
          return now.difference(lastSeen.toDate()) < const Duration(seconds: 15);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Text(
              s.isFa ? 'الان کسی آنلاین نیست' : 'No one is online right now',
              style: const TextStyle(color: Colors.black54),
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final name = (data['name'] ?? '?').toString();
            final wins = data['wins'] ?? 0;
            final games = data['gamesPlayed'] ?? 0;
            final inGame = data['inGame'] == true;
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
                title: Text(name),
                subtitle: Text(s.isFa ? '$wins برد از $games بازی' : '$wins wins / $games games'),
                trailing: inGame
                    ? Text(s.isFa ? 'در حال بازی' : 'In game', style: const TextStyle(color: Colors.grey))
                    : ElevatedButton(
                        onPressed: _busy ? null : () => _challenge(docs[i].id, name),
                        child: Text(s.isFa ? 'چالش' : 'Duel'),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickMatchingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            s.isFa ? 'در حال جستجوی حریف آماده...' : 'Searching for a ready opponent...',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _cancelQuickMatch,
            child: Text(s.isFa ? 'لغو جستجو' : 'Cancel Search'),
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
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _createdRoomId = null),
          child: Text(s.isFa ? 'انصراف' : 'Cancel'),
        ),
      ],
    );
  }
}
