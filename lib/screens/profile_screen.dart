import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_strings.dart';

class ProfileScreen extends StatefulWidget {
  final AppLang lang;
  const ProfileScreen({super.key, required this.lang});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int totalWins = 0;
  String playerName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      totalWins = prefs.getInt('total_wins') ?? 0;
      playerName = prefs.getString('player_name') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S(widget.lang);
    return Directionality(
      textDirection: s.isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(s.profile)),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: InputDecoration(labelText: s.isFa ? 'نام بازیکن' : 'Player name'),
                controller: TextEditingController(text: playerName),
                onSubmitted: (value) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('player_name', value);
                },
              ),
              const SizedBox(height: 20),
              Text('${s.score} (${s.isFa ? "محلی" : "local"}): $totalWins'),
              const SizedBox(height: 20),
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s.countryRank}: —'),
                      Text('${s.globalRank}: —'),
                      const SizedBox(height: 8),
                      Text(s.requiresOnlineSetup,
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
