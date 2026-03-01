
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'ae_dashboard/ae_login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (error) {
    debugPrint('Firebase init failed: $error');
  }

  runApp(ElectricityAdminApp(firebaseReady: firebaseReady));
}

class ElectricityAdminApp extends StatelessWidget {
  const ElectricityAdminApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  static const _primaryPurple = Color(0xFF4A148C);
  static const _secondaryPurple = Color(0xFF6A1B9A);
  static const _surfaceCard = Color(0xFFF5F2FA);

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(useMaterial3: true);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Electricity Admin',
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: _primaryPurple,
          secondary: _secondaryPurple,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSurface: Colors.black87,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _primaryPurple,
          foregroundColor: Colors.white,
          elevation: 1,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          color: _surfaceCard,
          elevation: 2,
          margin: const EdgeInsets.all(0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primaryPurple,
            side: const BorderSide(color: _primaryPurple),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      home: firebaseReady
          ? const AeLoginScreen()
          : const AeLoginScreen(),
    );
  }
}
