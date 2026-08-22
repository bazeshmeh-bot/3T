import 'package:flutter/material.dart';
import '../localization/app_strings.dart';

/// این صفحه یک جایگزین (placeholder) است.
/// پیاده‌سازی کامل بازی آنلاین (Firestore) و بازی نزدیک (nearby_connections)
/// و تولید/اسکن QR کد در فایل README.md به‌طور کامل توضیح داده شده و
/// نیاز به ساخت یک پروژه‌ی Firebase توسط خودتان دارد (کلید API شخصی شماست).
class OnlinePlaceholderScreen extends StatelessWidget {
  final AppLang lang;
  const OnlinePlaceholderScreen({super.key, required this.lang});

  @override
  Widget build(BuildContext context) {
    final s = S(lang);
    return Directionality(
      textDirection: s.isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(s.onlineMode)),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                s.requiresOnlineSetup,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
