import 'package:flutter/material.dart';
import 'landing_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'diary_screen.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tải các biến môi trường từ file .env lên bộ nhớ
  await dotenv.load(fileName: ".env");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Healthy Life',
      theme: ThemeData(
        primaryColor: const Color(0xFF4CAF50),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
