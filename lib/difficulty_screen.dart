import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../logic/game_engine.dart';
import 'game_screen.dart';

class DifficultyScreen extends StatelessWidget {
  final AppLang lang;
  const DifficultyScreen({super.key, required this.lang});

  @override
  Widget build(BuildContext context) {
    final s = S(lang);
    return Directionality(
      textDirection: s.isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(s.isFa ? 'انتخاب سطح سختی' : 'Choose Difficulty')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _diffButton(context, s, AiDifficulty.easy, s.isFa ? 'آسان' : 'Easy',
                  s.isFa ? 'حرکت‌های تصادفی' : 'Random moves', Colors.green),
              const SizedBox(height: 16),
              _diffButton(context, s, AiDifficulty.medium, s.isFa ? 'متوسط' : 'Medium',
                  s.isFa ? 'دفاع و حمله‌ی هوشمند' : 'Smart attack & defense', Colors.orange),
              const SizedBox(height: 16),
              _diffButton(context, s, AiDifficulty.hard, s.isFa ? 'سخت' : 'Hard',
                  s.isFa ? 'تشخیص دوشاخه، شکست‌دادنش سخته' : 'Fork detection, hard to beat', Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _diffButton(BuildContext context, S s, AiDifficulty diff, String title, String subtitle, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameScreen(lang: lang, mode: GameMode.singlePlayerVsAi, difficulty: diff),
            ),
          );
        },
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
