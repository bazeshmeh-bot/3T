/// مدل داده‌ی وضعیت بازی
enum GamePhase { placement, movement, gameOver }

/// یک مهره روی صفحه
class Piece {
  final int owner; // 0 یا 1
  int cell; // خانه‌ی فعلی (0..8)

  Piece({required this.owner, required this.cell});
}

class GameState {
  /// board[i] = شماره‌ی مالک (0 یا 1) یا null اگر خالی باشد
  List<int?> board = List<int?>.filled(9, null);
  List<Piece> pieces = [];

  int currentPlayer = 0; // 0 یا 1
  GamePhase phase = GamePhase.placement;
  int? winner; // null تا وقتی کسی نبرده
  bool isDraw = false;

  // تعداد مهره‌های باقی‌مانده برای چیدن، هر بازیکن با ۳ مهره شروع می‌کند
  Map<int, int> remainingToPlace = {0: 3, 1: 3};

  // فقط برای «آخرین مهره‌ای که در کل بازی جابه‌جا شده» - نه هر مهره جداگانه.
  // اگر مهره‌ای که الان در lastMovedToCell نشسته دوباره انتخاب شود، نمی‌تواند
  // به lastMovedFromCell برگردد. با هر حرکت جدید، این محدودیت جابه‌جا می‌شود.
  int? lastMovedFromCell;
  int? lastMovedToCell;

  int scoreP0 = 0;
  int scoreP1 = 0;

  GameState();

  List<Piece> piecesOf(int player) => pieces.where((p) => p.owner == player).toList();

  Piece? pieceAt(int cell) {
    for (final p in pieces) {
      if (p.cell == cell) return p;
    }
    return null;
  }

  void switchTurn() {
    currentPlayer = currentPlayer == 0 ? 1 : 0;
  }

  void reset() {
    board = List<int?>.filled(9, null);
    pieces = [];
    currentPlayer = 0;
    phase = GamePhase.placement;
    winner = null;
    isDraw = false;
    remainingToPlace = {0: 3, 1: 3};
    lastMovedFromCell = null;
    lastMovedToCell = null;
  }
}
