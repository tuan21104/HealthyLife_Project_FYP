import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io'; // Quan trọng để dùng HttpOverrides
import 'landing_screen.dart';

// Class này giúp bỏ qua kiểm tra chứng chỉ SSL lỗi thời trên máy ảo Android
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

  // Kích hoạt ghi đè HTTP trước khi load app
  HttpOverrides.global = MyHttpOverrides();

  // Tải các biến môi trường
  await dotenv.load(fileName: ".env");

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('vi')],
      path: 'assets/translations',
      fallbackLocale: const Locale('vi'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localization = EasyLocalization.of(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Healthy Life',
      onGenerateTitle: (context) => tr('app.title', context: context),
      locale: localization?.locale,
      supportedLocales:
          localization?.supportedLocales ?? const [Locale('en'), Locale('vi')],
      localizationsDelegates: localization?.delegates,
      theme: ThemeData(
        primaryColor: const Color(0xFF4CAF50),
        useMaterial3: true,
      ),
      home: const LandingScreen(),
    );
  }
}
