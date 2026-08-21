import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TicApp());
}

class TicApp extends StatelessWidget {
  const TicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Tic Tac Toe',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        // برای بهتر شدن نمایش فارسی می‌توانید فونت Vazirmatn را به assets/fonts
        // اضافه و در pubspec.yaml معرفی کنید (راهنما در README.md).
      ),
      home: const HomeScreen(),
    );
  }
}
