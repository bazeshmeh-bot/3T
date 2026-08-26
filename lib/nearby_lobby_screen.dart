import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_strings.dart';
import '../services/nearby_service.dart';
import 'nearby_game_screen.dart';

class NearbyLobbyScreen extends StatefulWidget {
  final AppLang lang;
  const NearbyLobbyScreen({super.key, required this.lang});

  @override
  State<NearbyLobbyScreen> createState() => _NearbyLobbyScreenState();
}

class _NearbyLobbyScreenState extends State<NearbyLobbyScreen> {
  late S s;
  final NearbyService _service = NearbyService();
  String _playerName = '';
  bool _busy = false;
  bool _isHosting = false;
  bool _isDiscovering = false;
  final Map<String, String> _foundEndpoints = {}; // id -> name

  @override
  void initState() {
    super.initState();
    s = S(widget.lang);
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _playerName =
        prefs.getString('player_name') ?? (s.isFa ? 'بازیکن' : 'Player'));
  }

  @override
  void dispose() {
    _service.stopAll();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ].request();
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  Future<void> _startHosting() async {
    setState(() => _busy = true);
    final granted = await _requestPermissions();
    if (!granted) {
      setState(() => _busy = false);
      _showError(s.isFa
          ? 'برای بازی نزدیک باید دسترسی بلوتوث/وای‌فای/مکان را بدهید.'
          : 'Bluetooth/WiFi/Location permission is required for nearby play.');
      return;
    }
    _service.onConnected = () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NearbyGameScreen(lang: widget.lang, service: _service, isHost: true),
        ),
      );
    };
    await _service.startAdvertising(_playerName);
    setState(() {
      _isHosting = true;
      _busy = false;
    });
  }

  Future<void> _startDiscovery() async {
    setState(() => _busy = true);
    final granted = await _requestPermissions();
    if (!granted) {
      setState(() => _busy = false);
      _showError(s.isFa
          ? 'برای بازی نزدیک باید دسترسی بلوتوث/وای‌فای/مکان را بدهید.'
          : 'Bluetooth/WiFi/Location permission is required for nearby play.');
      return;
    }
    _foundEndpoints.clear();
    _service.onEndpointFound = (id, name) {
      setState(() => _foundEndpoints[id] = name);
    };
    _service.onConnected = () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NearbyGameScreen(lang: widget.lang, service: _service, isHost: false),
        ),
      );
    };
    await _service.startDiscovery(_playerName);
    setState(() {
      _isDiscovering = true;
      _busy = false;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade400));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: s.isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(s.nearbyMode)),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: _isHosting
              ? _buildHostingView()
              : _isDiscovering
                  ? _buildDiscoveringView()
                  : _buildMenuView(),
        ),
      ),
    );
  }

  Widget _buildMenuView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          s.isFa
              ? 'بلوتوث و وای‌فای هر دو گوشی را روشن کنید و نزدیک هم باشید.'
              : 'Turn on Bluetooth and WiFi on both phones and stay close together.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _busy ? null : _startHosting,
          icon: const Icon(Icons.wifi_tethering),
          label: Text(s.isFa ? 'میزبانی بازی (منتظر بمان)' : 'Host Game (wait for player)'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _busy ? null : _startDiscovery,
          icon: const Icon(Icons.search),
          label: Text(s.isFa ? 'جستجوی بازی‌های نزدیک' : 'Search for Nearby Games'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
        if (_busy) const Padding(
          padding: EdgeInsets.only(top: 20),
          child: CircularProgressIndicator(),
        ),
      ],
    );
  }

  Widget _buildHostingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(s.isFa ? 'در حال پخش... منتظر بازیکن دوم' : 'Broadcasting... waiting for player 2'),
        ],
      ),
    );
  }

  Widget _buildDiscoveringView() {
    return Column(
      children: [
        Text(s.isFa ? 'دستگاه‌های پیدا شده:' : 'Devices found:'),
        const SizedBox(height: 12),
        Expanded(
          child: _foundEndpoints.isEmpty
              ? Center(child: Text(s.isFa ? 'در حال جستجو...' : 'Searching...'))
              : ListView(
                  children: _foundEndpoints.entries
                      .map((e) => Card(
                            child: ListTile(
                              title: Text(e.value),
                              trailing: const Icon(Icons.arrow_forward),
                              onTap: () => _service.requestConnection(_playerName, e.key),
                            ),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }
}
