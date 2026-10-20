import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  wakeBackend();
  runApp(const ShotScoutApp());
}

class ShotScoutApp extends StatelessWidget {
  const ShotScoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShotScout',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
