import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import 'game_screen.dart';
import 'profile_screen.dart';
import 'online_placeholder_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppLang lang = AppLang.fa;

  @override
  Widget build(BuildContext context) {
    final s = S(lang);
    return Directionality(
      textDirection: s.isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.appTitle),
          actions: [
            TextButton(
              onPressed: () => setState(() {
                lang = lang == AppLang.fa ? AppLang.en : AppLang.fa;
              }),
              child: Text(s.switchLang, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.grid_3x3, size: 72, color: Colors.blue),
                const SizedBox(height: 24),
                _menuButton(s.singlePlayer, Icons.smartphone, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameScreen(lang: lang, mode: GameMode.singlePlayerVsAi),
                    ),
                  );
                }),
                _menuButton(s.twoPlayerLocal, Icons.people, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameScreen(lang: lang, mode: GameMode.twoPlayerLocal),
                    ),
                  );
                }),
                _menuButton(s.onlineMode, Icons.wifi, () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => OnlinePlaceholderScreen(lang: lang)));
                }),
                _menuButton(s.nearbyMode, Icons.bluetooth, () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => OnlinePlaceholderScreen(lang: lang)));
                }),
                _menuButton(s.profile, Icons.person, () {
                  Navigator.push(
                      context, MaterialPageRoute(builder: (_) => ProfileScreen(lang: lang)));
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuButton(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      ),
    );
  }
}
