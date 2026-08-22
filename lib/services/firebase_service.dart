import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// سرویس اتصال به فایربیس: راه‌اندازی اولیه + ورود ناشناس
/// (نیازی به ثبت‌نام واقعی نیست، فقط برای داشتن یک شناسه‌ی یکتا برای هر بازیکن)
class FirebaseService {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    _initialized = true;
  }

  /// ورود ناشناس؛ اگر قبلاً وارد شده باشد همان کاربر را برمی‌گرداند
  static Future<String> ensureSignedIn() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return auth.currentUser!.uid;
    final result = await auth.signInAnonymously();
    return result.user!.uid;
  }
}
