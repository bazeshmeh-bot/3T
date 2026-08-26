import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// تنظیمات اتصال به پروژه‌ی فایربیس شما (tic3-smart)
/// این فایل به‌صورت دستی از روی google-services.json ساخته شده،
/// چون امکان اجرای ابزار رسمی flutterfire CLI در این محیط نبود.
/// این مقادیر محرمانه نیستند - محافظت واقعی توسط قوانین امنیتی
/// Firestore (Security Rules) در کنسول فایربیس انجام می‌شود.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCkXw5vzTEw7pcTAIWqSiZyauZnOq8SUcw',
    appId: '1:967501050540:android:5ce6628cb2553f1cc7a509',
    messagingSenderId: '967501050540',
    projectId: 'tic3-smart',
    storageBucket: 'tic3-smart.firebasestorage.app',
  );
}
