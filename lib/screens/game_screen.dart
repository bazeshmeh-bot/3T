import 'dart:async';
import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../logic/game_engine.dart';
import '../models/game_state.dart';
import '../widgets/board_widget.dart';

/// حالت بازی: تک‌نفره (مقابل موبایل) یا دو نفره روی یک دستگاه
enum GameMode { singlePlayerVsAi, twoPlayerLocal }

class GameScreen extends StatefulWidget {
  final AppLang lang;
  final GameMode mode;
  final AiDifficulty difficulty;
  const GameScreen({
    super.key,
    required this.lang,
    required this.mode,
    this.difficulty = AiDifficulty.medium,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int turnSeconds = 30;

  late GameState state;
  late S s;
  Timer? _timer;
  int _secondsLeft = turnSeconds;
  int? _selectedCell; // مهره‌ی انتخاب‌شده در فاز جابه‌جایی

  // در حالت تک‌نفره، بازیکن ۱ = انسان(0)، بازیکن ۲ = هوش مصنوعی(1)
  bool get aiTurnNow => widget.mode == GameMode.singlePlayerVsAi && state.currentPlayer == 1;

  @override
  void initState() {
    super.initState();
    s = S(widget.lang);
    state = GameState();
    _startTurnTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTurnTimer() {
    _timer?.cancel();
    _secondsLeft = turnSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (state.phase == GamePhase.gameOver) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _autoMove();
      } else if (aiTurnNow && _secondsLeft == turnSeconds - 1) {
        // هوش مصنوعی کمی بعد از شروع نوبت حرکت می‌کند (حس طبیعی‌تر)
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && state.phase != GamePhase.gameOver) _autoMove();
        });
      }
    });
  }

  /// حرکت خودکار: هم برای پایان‌زمان و هم برای نوبتِ هوش مصنوعی استفاده می‌شود
  void _autoMove() {
    final player = state.currentPlayer;
    if (state.phase == GamePhase.placement) {
      final cell = GameEngine.chooseAiPlacement(state, player, difficulty: widget.difficulty);
      GameEngine.placePiece(state, cell);
    } else if (state.phase == GamePhase.movement) {
      final choice = GameEngine.chooseAiMove(state, player, difficulty: widget.difficulty);
      if (choice != null) {
        GameEngine.movePiece(state, choice.key, choice.value);
      }
    }
    _selectedCell = null;
    if (state.phase != GamePhase.gameOver) {
      _startTurnTimer();
    } else {
      _onGameOver();
    }
    setState(() {});
  }

  void _onGameOver() {
    if (state.winner == 0) {
      state.scoreP0++;
    } else if (state.winner == 1) {
      state.scoreP1++;
    }
    setState(() {});
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade400),
    );
  }

  void _onCellTap(int cell) {
    if (state.phase == GamePhase.gameOver) return;
    if (aiTurnNow) return; // نوبت انسان نیست

    if (state.phase == GamePhase.placement) {
      final result = GameEngine.placePiece(state, cell);
      if (!result.success) {
        _showError(s.invalidCellOccupied);
        return;
      }
      _afterHumanMove();
      return;
    }

    // فاز جابه‌جایی
    final tappedPiece = state.pieceAt(cell);
    if (_selectedCell == null) {
      if (tappedPiece == null || tappedPiece.owner != state.currentPlayer) {
        _showError(s.selectPieceFirst);
        return;
      }
      setState(() => _selectedCell = cell);
      return;
    }

    // یک مهره از قبل انتخاب شده؛ حالا مقصد را می‌زنیم
    if (cell == _selectedCell) {
      setState(() => _selectedCell = null); // لغو انتخاب
      return;
    }
    final piece = state.pieceAt(_selectedCell!);
    if (piece == null) {
      setState(() => _selectedCell = null);
      return;
    }
    // اگر یک مهره‌ی دیگر از خودش را زد، انتخاب را عوض کن
    if (tappedPiece != null && tappedPiece.owner == state.currentPlayer) {
      setState(() => _selectedCell = cell);
      return;
    }

    final result = GameEngine.movePiece(state, piece, cell);
    if (!result.success) {
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
      return;
    }
    _selectedCell = null;
    _afterHumanMove();
  }

  void _afterHumanMove() {
    if (state.phase == GamePhase.gameOver) {
      _onGameOver();
    } else {
      _startTurnTimer();
    }
    setState(() {});
  }

  List<int> get _highlightDestinations {
    if (_selectedCell == null) return [];
    final piece = state.pieceAt(_selectedCell!);
    if (piece == null) return [];
    return GameEngine.legalDestinations(state, piece);
  }

  String _playerName(int player) {
    if (widget.mode == GameMode.singlePlayerVsAi) {
      return player == 0 ? s.you : s.computer;
    }
    return player == 0 ? s.player1 : s.player2;
  }

  @override
  Widget build(BuildContext context) {
    final phaseLabel = state.phase == GamePhase.placement ? s.placementPhase : s.movementPhase;

    return Directionality(
      textDirection: s.isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(s.appTitle)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(phaseLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (state.phase != GamePhase.gameOver) ...[
                Text(s.turnOf(_playerName(state.currentPlayer)),
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                Text(s.secondsLeft(_secondsLeft),
                    style: TextStyle(
                        color: _secondsLeft <= 10 ? Colors.red : Colors.black54, fontSize: 14)),
              ] else
                Text(
                  state.isDraw ? s.draw : s.winnerIs(_playerName(state.winner!)),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 16),
              BoardWidget(
                board: state.board,
                selectedCell: _selectedCell,
                highlightCells: _highlightDestinations,
                onCellTap: _onCellTap,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text('${s.score} ${_playerName(0)}: ${state.scoreP0}'),
                  Text('${s.score} ${_playerName(1)}: ${state.scoreP1}'),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    final keepScores = [state.scoreP0, state.scoreP1];
                    state.reset();
                    state.scoreP0 = keepScores[0];
                    state.scoreP1 = keepScores[1];
                    _selectedCell = null;
                  });
                  _startTurnTimer();
                },
                child: Text(s.newGame),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
