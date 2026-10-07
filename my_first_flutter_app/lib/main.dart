import 'package:flutter/material.dart';

import 'Screens/start_screen.dart';
import 'Screens/login_screen.dart';
import 'Screens/categories_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,

      routes: {
        '/login': (context) => const LoginScreen(),
        '/categories': (context) => const CategoriesScreen(),
      },

      home: const StartScreen(),
    );
  }
}
