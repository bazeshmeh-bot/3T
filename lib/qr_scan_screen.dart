import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../localization/app_strings.dart';

class QrScanScreen extends StatefulWidget {
  final AppLang lang;
  const QrScanScreen({super.key, required this.lang});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    final s = S(widget.lang);
    return Directionality(
      textDirection: s.isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(s.isFa ? 'اسکن QR اتاق' : 'Scan Room QR')),
        body: MobileScanner(
          onDetect: (capture) {
            if (_handled) return;
            final barcodes = capture.barcodes;
            if (barcodes.isEmpty) return;
            final value = barcodes.first.rawValue;
            if (value == null || value.isEmpty) return;
            _handled = true;
            Navigator.pop(context, value);
          },
        ),
      ),
    );
  }
}
