import 'package:flutter/material.dart';
import 'landing_screen.dart';

void main() {
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
      home: const LandingScreen(),
    );
  }
}