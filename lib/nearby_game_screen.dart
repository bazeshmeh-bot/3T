import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../logic/game_engine.dart';
import '../models/game_state.dart';
import '../services/nearby_service.dart';
import '../services/room_repository.dart';
import '../widgets/board_widget.dart';

/// در بازی نزدیک، میزبان (host) همیشه بازیکن ۰ و پیوسته (joiner) بازیکن ۱ است.
class NearbyGameScreen extends StatefulWidget {
  final AppLang lang;
  final NearbyService service;
  final bool isHost;
  const NearbyGameScreen({super.key, required this.lang, required this.service, required this.isHost});

  @override
  State<NearbyGameScreen> createState() => _NearbyGameScreenState();
}

class _NearbyGameScreenState extends State<NearbyGameScreen> {
  late S s;
  late GameState state;
  int? _selectedCell;
  bool _opponentLeft = false;

  int get myIndex => widget.isHost ? 0 : 1;

  @override
  void initState() {
    super.initState();
    s = S(widget.lang);
    state = GameState();
    widget.service.onDataReceived = (data) {
      setState(() {
        state = RoomRepository.stateFromDoc(data);
        _selectedCell = null;
      });
    };
    widget.service.onDisconnected = () {
      setState(() => _opponentLeft = true);
    };
  }

  void _syncState() {
    widget.service.sendData(RoomRepository.stateToMap(state));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade400));
  }

  void _onCellTap(int cell) {
    if (state.phase == GamePhase.gameOver || _opponentLeft) return;
    if (state.currentPlayer != myIndex) return;

    if (state.phase == GamePhase.placement) {
      final result = GameEngine.placePiece(state, cell);
      if (result.success) {
        setState(() {});
        _syncState();
      } else {
        _showError(s.invalidCellOccupied);
      }
      return;
    }

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
      setState(() {});
      _syncState();
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
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.service.stopAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: s.isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(s.nearbyMode)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_opponentLeft)
                Text(s.isFa ? '⚠️ حریف قطع شد' : '⚠️ Opponent disconnected',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
                onCellTap: _onCellTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
