/// رشته‌های دوزبانه‌ی برنامه (فارسی / انگلیسی)
/// Simple lightweight localization (no code-gen needed).
enum AppLang { fa, en }

class S {
  final AppLang lang;
  S(this.lang);

  bool get isFa => lang == AppLang.fa;

  String get appTitle => isFa ? 'دوز هوشمند' : 'Smart Tic Tac Toe';
  String get home => isFa ? 'خانه' : 'Home';
  String get singlePlayer => isFa ? 'تک‌نفره (مقابل موبایل)' : 'Single Player (vs AI)';
  String get twoPlayerLocal => isFa ? 'دو نفره (یک موبایل)' : 'Two Player (Same Device)';
  String get onlineMode => isFa ? 'بازی آنلاین' : 'Online Game';
  String get nearbyMode => isFa ? 'بازی نزدیک (بلوتوث/وای‌فای)' : 'Nearby Game (Bluetooth/WiFi)';
  String get profile => isFa ? 'پروفایل' : 'Profile';
  String get newGame => isFa ? 'بازی جدید' : 'New Game';
  String get placementPhase => isFa ? 'مرحله چیدن مهره' : 'Placement Phase';
  String get movementPhase => isFa ? 'مرحله جابه‌جایی مهره' : 'Movement Phase';
  String turnOf(String name) => isFa ? 'نوبت: $name' : "Turn: $name";
  String get player1 => isFa ? 'بازیکن ۱' : 'Player 1';
  String get player2 => isFa ? 'بازیکن ۲' : 'Player 2';
  String get you => isFa ? 'شما' : 'You';
  String get computer => isFa ? 'موبایل' : 'Computer';
  String winnerIs(String name) => isFa ? '🏆 برنده: $name' : '🏆 Winner: $name';
  String get draw => isFa ? 'بازی مساوی شد' : 'Game is a draw';
  String get invalidBackMove => isFa
      ? 'خطا: نمی‌توانید مهره را به خانه‌ی مرحله‌ی قبل برگردانید.'
      : 'Error: You cannot move this piece back to its previous cell.';
  String get invalidCellOccupied =>
      isFa ? 'خطا: این خانه قبلاً پر شده است.' : 'Error: This cell is already occupied.';
  String get invalidNotAdjacent => isFa
      ? 'خطا: مهره فقط می‌تواند به خانه‌ی همجوار منتقل شود.'
      : 'Error: The piece can only move to an adjacent cell.';
  String get selectPieceFirst =>
      isFa ? 'ابتدا یکی از مهره‌های خودتان را انتخاب کنید.' : 'Select one of your pieces first.';
  String get timeUp => isFa ? 'زمان تمام شد! حرکت خودکار انجام شد.' : 'Time is up! Auto-move played.';
  String get score => isFa ? 'امتیاز' : 'Score';
  String get countryRank => isFa ? 'رتبه کشوری' : 'Country Rank';
  String get globalRank => isFa ? 'رتبه جهانی' : 'Global Rank';
  String get requiresOnlineSetup => isFa
      ? 'این بخش نیاز به اتصال به سرور فایربیس دارد. برای فعال‌سازی به فایل README.md مراجعه کنید.'
      : 'This section requires a Firebase backend connection. See README.md to enable it.';
  String get switchLang => isFa ? 'English' : 'فارسی';
  String secondsLeft(int s) => isFa ? '$s ثانیه باقی‌مانده' : '$s seconds left';
}
