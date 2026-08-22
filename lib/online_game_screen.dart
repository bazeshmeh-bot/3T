import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../logic/game_engine.dart';
import '../models/game_state.dart';
import '../services/room_repository.dart';
import '../widgets/board_widget.dart';

class OnlineGameScreen extends StatefulWidget {
  final AppLang lang;
  final String roomId;
  final String myUid;
  const OnlineGameScreen({super.key, required this.lang, required this.roomId, required this.myUid});

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  late S s;
  Timer? _heartbeatTimer;
  Timer? _disconnectCheckTimer;
  int? _selectedCell;
  bool _endedByDisconnect = false;

  static const heartbeatEvery = Duration(seconds: 5);
  static const disconnectThreshold = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    s = S(widget.lang);
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _disconnectCheckTimer?.cancel();
    super.dispose();
  }

  void _startHeartbeat(int myIndex) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatEvery, (_) {
      RoomRepository.updateHeartbeat(widget.roomId, myIndex, widget.myUid);
    });
  }

  void _startDisconnectWatch(int myIndex, Map<String, dynamic> data) {
    _disconnectCheckTimer?.cancel();
    _disconnectCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final players = Map<String, dynamic>.from(data['players'] ?? {});
      final opponentKey = myIndex == 0 ? '1' : '0';
      final opponent = players[opponentKey];
      if (opponent == null) return; // هنوز نپیوسته
      final lastSeen = opponent['lastSeen'];
      if (lastSeen is! Timestamp) return;
      final diff = DateTime.now().difference(lastSeen.toDate());
      if (diff > disconnectThreshold && !_endedByDisconnect) {
        _endedByDisconnect = true;
        await RoomRepository.declareWinnerByDisconnect(widget.roomId, myIndex);
      }
    });
  }

  void _onCellTap(GameState state, int myIndex, int cell) {
    if (state.phase == GamePhase.gameOver) return;
    if (state.currentPlayer != myIndex) return; // نوبت شما نیست

    if (state.phase == GamePhase.placement) {
      final result = GameEngine.placePiece(state, cell);
      if (result.success) {
        RoomRepository.pushState(widget.roomId, state);
      } else {
        _showError(s.invalidCellOccupied);
      }
      return;
    }

    // فاز جابه‌جایی
    final tappedPiece = state.pieceAt(cell);
    if (_selectedCell == null) {
      if (tappedPiece == null || tappedPiece.owner != myIndex) {
        _showError(s.selectPieceFirst);
        return;
      }
      setState(() => _selectedCell = cell);
      return;
    }
    if (cell == _selectedCell) {
      setState(() => _selectedCell = null);
      return;
    }
    final piece = state.pieceAt(_selectedCell!);
    if (piece == null) {
      setState(() => _selectedCell = null);
      return;
    }
    if (tappedPiece != null && tappedPiece.owner == myIndex) {
      setState(() => _selectedCell = cell);
      return;
    }
    final result = GameEngine.movePiece(state, piece, cell);
    _selectedCell = null;
    if (result.success) {
      RoomRepository.pushState(widget.roomId, state);
    } else {
      switch (result.errorKey) {
        case 'back_move':
          _showError(s.invalidBackMove);
          break;
        case 'not_adjacent':
          _showError(s.invalidNotAdjacent);
          break;
        default:
          _showError(s.invalidCellOccupied);
      }
    }
    setState(() {});
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade400));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: s.isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text('${s.appTitle} — ${widget.roomId}')),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: RoomRepository.watchRoom(widget.roomId),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!.data()!;
            final players = Map<String, dynamic>.from(data['players'] ?? {});
            int? myIndex;
            players.forEach((key, value) {
              if (value['uid'] == widget.myUid) myIndex = int.parse(key);
            });
            if (myIndex == null) {
              return Center(child: Text(s.isFa ? 'در حال اتصال...' : 'Connecting...'));
            }
            final state = RoomRepository.stateFromDoc(data);

            _startHeartbeat(myIndex!);
            if (state.phase != GamePhase.gameOver) {
              _startDisconnectWatch(myIndex!, data);
            }

            final myName = players['$myIndex']?['name'] ?? '';
            final oppKey = myIndex == 0 ? '1' : '0';
            final oppName = players[oppKey]?['name'] ?? (s.isFa ? 'در انتظار...' : 'Waiting...');

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('${s.you}: $myName   |   ${s.isFa ? "حریف" : "Opponent"}: $oppName'),
                  const SizedBox(height: 8),
                  Text(
                    state.phase == GamePhase.placement ? s.placementPhase : s.movementPhase,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  if (state.phase != GamePhase.gameOver)
                    Text(
                      state.currentPlayer == myIndex
                          ? (s.isFa ? 'نوبت شماست' : 'Your turn')
                          : (s.isFa ? 'نوبت حریف' : "Opponent's turn"),
                      style: TextStyle(
                        color: state.currentPlayer == myIndex ? Colors.green.shade700 : Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    Text(
                      state.isDraw
                          ? s.draw
                          : (state.winner == myIndex
                              ? (s.isFa ? '🏆 شما بردید!' : '🏆 You won!')
                              : (s.isFa ? 'حریف برد.' : 'Opponent won.')),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 16),
                  BoardWidget(
                    board: state.board,
                    selectedCell: _selectedCell,
                    highlightCells: _selectedCell == null
                        ? []
                        : GameEngine.legalDestinations(state, state.pieceAt(_selectedCell!)!),
                    onCellTap: (cell) => _onCellTap(state, myIndex!, cell),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
