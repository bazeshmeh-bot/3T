import 'dart:math';
import '../models/game_state.dart';

/// نتیجه‌ی یک تلاش برای انجام حرکت
class MoveResult {
  final bool success;
  final String? errorKey; // 'occupied' | 'not_adjacent' | 'back_move'
  MoveResult.ok() : success = true, errorKey = null;
  MoveResult.fail(this.errorKey) : success = false;
}

class GameEngine {
  /// ۸ خط برنده: ۳ ردیف، ۳ ستون، ۲ قطر
  static const List<List<int>> lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // ردیف‌ها
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // ستون‌ها
    [0, 4, 8], [2, 4, 6], // قطرها
  ];

  /// گراف مجاورت برای فاز جابه‌جایی: حرکت «شاه‌وار» - هر خانه به تمام خانه‌های
  /// فیزیکی همسایه‌اش (افقی، عمودی، مورب) مجاور است، نه فقط خانه‌های هم‌خط برد.
  /// این یعنی حرکت مورب برای خانه‌های وسطِ ضلع هم (نه فقط گوشه‌ها) امکان‌پذیره.
  static const Map<int, List<int>> adjacency = {
    0: [1, 3, 4],
    1: [0, 2, 3, 4, 5],
    2: [1, 4, 5],
    3: [0, 1, 4, 6, 7],
    4: [0, 1, 2, 3, 5, 6, 7, 8],
    5: [1, 2, 4, 7, 8],
    6: [3, 4, 7],
    7: [3, 4, 5, 6, 8],
    8: [4, 5, 7],
  };

  /// بررسی برد: اگر بازیکنی برنده شده باشد شماره‌اش را برمی‌گرداند، وگرنه null
  static int? checkWinner(List<int?> board) {
    for (final line in lines) {
      final a = board[line[0]], b = board[line[1]], c = board[line[2]];
      if (a != null && a == b && b == c) return a;
    }
    return null;
  }

  static List<int> emptyCells(List<int?> board) {
    final result = <int>[];
    for (int i = 0; i < 9; i++) {
      if (board[i] == null) result.add(i);
    }
    return result;
  }

  // ---------------- فاز چیدن (Placement) ----------------

  static MoveResult placePiece(GameState state, int cell) {
    if (state.board[cell] != null) return MoveResult.fail('occupied');

    final player = state.currentPlayer;
    state.board[cell] = player;
    state.pieces.add(Piece(owner: player, cell: cell));
    state.remainingToPlace[player] = (state.remainingToPlace[player] ?? 0) - 1;

    final winner = checkWinner(state.board);
    if (winner != null) {
      state.winner = winner;
      state.phase = GamePhase.gameOver;
      return MoveResult.ok();
    }

    // اگر هر دو بازیکن مهره‌هایشان را چیدند -> وارد فاز جابه‌جایی شو
    if (state.remainingToPlace[0] == 0 && state.remainingToPlace[1] == 0) {
      state.phase = GamePhase.movement;
    }

    state.switchTurn();
    return MoveResult.ok();
  }

  // ---------------- فاز جابه‌جایی (Movement) ----------------

  static List<int> legalDestinations(GameState state, Piece piece) {
    final neighbors = adjacency[piece.cell] ?? [];
    return neighbors.where((c) {
      if (state.board[c] != null) return false; // باید خالی باشد
      if (piece.previousCell != null && c == piece.previousCell) {
        return false; // ممنوعیت بازگشت به خانه‌ی مرحله‌ی قبل
      }
      return true;
    }).toList();
  }

  static MoveResult movePiece(GameState state, Piece piece, int destination) {
    if (state.board[destination] != null) return MoveResult.fail('occupied');

    final neighbors = adjacency[piece.cell] ?? [];
    if (!neighbors.contains(destination)) return MoveResult.fail('not_adjacent');

    if (piece.previousCell != null && destination == piece.previousCell) {
      return MoveResult.fail('back_move');
    }

    final oldCell = piece.cell;
    state.board[oldCell] = null;
    state.board[destination] = piece.owner;
    piece.previousCell = oldCell;
    piece.cell = destination;

    final winner = checkWinner(state.board);
    if (winner != null) {
      state.winner = winner;
      state.phase = GamePhase.gameOver;
      return MoveResult.ok();
    }

    state.switchTurn();
    return MoveResult.ok();
  }

  // ---------------- هوش مصنوعی ساده (اکتشافی) ----------------
  // در فاز چیدن: برد فوری -> بلاک حریف -> مرکز -> گوشه -> تصادفی
  // در فاز جابه‌جایی: برد فوری -> بلاک حریف -> حرکت به سمت مرکز -> تصادفی مجاز

  static final _rng = Random();

  static int chooseAiPlacement(GameState state, int aiPlayer) {
    final opponent = aiPlayer == 0 ? 1 : 0;
    final empties = emptyCells(state.board);

    // ۱. اگر می‌تواند فوراً ببرد
    for (final cell in empties) {
      final trial = List<int?>.from(state.board)..[cell] = aiPlayer;
      if (checkWinner(trial) == aiPlayer) return cell;
    }
    // ۲. اگر باید جلوی برد حریف را بگیرد
    for (final cell in empties) {
      final trial = List<int?>.from(state.board)..[cell] = opponent;
      if (checkWinner(trial) == opponent) return cell;
    }
    // ۳. ترجیح مرکز
    if (empties.contains(4)) return 4;
    // ۴. ترجیح گوشه‌ها
    final corners = [0, 2, 6, 8].where(empties.contains).toList();
    if (corners.isNotEmpty) return corners[_rng.nextInt(corners.length)];
    // ۵. تصادفی
    return empties[_rng.nextInt(empties.length)];
  }

  /// برمی‌گرداند: (piece, destinationCell) بهترین حرکت برای فاز جابه‌جایی
  static MapEntry<Piece, int>? chooseAiMove(GameState state, int aiPlayer) {
    final opponent = aiPlayer == 0 ? 1 : 0;
    final myPieces = state.piecesOf(aiPlayer);

    MapEntry<Piece, int>? winningMove;
    MapEntry<Piece, int>? blockingMove;
    MapEntry<Piece, int>? centerMove;
    final candidates = <MapEntry<Piece, int>>[];

    for (final piece in myPieces) {
      for (final dest in legalDestinations(state, piece)) {
        candidates.add(MapEntry(piece, dest));

        final trialBoard = List<int?>.from(state.board);
        trialBoard[piece.cell] = null;
        trialBoard[dest] = aiPlayer;
        if (checkWinner(trialBoard) == aiPlayer) {
          winningMove = MapEntry(piece, dest);
        }
        if (dest == 4) centerMove = MapEntry(piece, dest);
      }
    }
    if (winningMove != null) return winningMove;

    // بررسی این‌که آیا حریف با یک حرکت می‌تواند ببرد، و تلاش برای اشغال آن خانه
    for (final oppPiece in state.piecesOf(opponent)) {
      for (final oppDest in legalDestinations(state, oppPiece)) {
        final trialBoard = List<int?>.from(state.board);
        trialBoard[oppPiece.cell] = null;
        trialBoard[oppDest] = opponent;
        if (checkWinner(trialBoard) == opponent) {
          // آیا ما می‌توانیم به oppDest برویم؟
          final blocker = candidates.where((c) => c.value == oppDest).toList();
          if (blocker.isNotEmpty) blockingMove = blocker.first;
        }
      }
    }
    if (blockingMove != null) return blockingMove;
    if (centerMove != null) return centerMove;
    if (candidates.isEmpty) return null;
    return candidates[_rng.nextInt(candidates.length)];
  }
}
