import 'package:flutter/material.dart';
import 'home_screen.dart';

/// SplashScreen 占位 — 将由子代理填充完整实现
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          ),
          child: const Text('Get Started'),
        ),
      ),
    );
  }
}
