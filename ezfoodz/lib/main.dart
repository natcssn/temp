import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_service.dart';
import 'login.dart';
import 'restaurants_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is not supported on Windows/Linux desktop — skip initialization
  final isDesktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.linux);

  if (!isDesktop) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  final loggedIn = await AuthService.loadSession();
  await AuthService.loadCollegesAndBuildings();
  runApp(EZFoodzApp(loggedIn: loggedIn));
}

class EZFoodzApp extends StatelessWidget {
  final bool loggedIn;
  const EZFoodzApp({super.key, required this.loggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EZFOODZ',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFF8F0),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFFF6B35),
          secondary: Color(0xFF27AE60),
          surface: Color(0xFFFFFFFF),
          error: Color(0xFFE74C3C),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF6B35),
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFFE4D6)),
          ),
          elevation: 4,
          shadowColor: Color(0x20FF6B35),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B35),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            elevation: 3,
            shadowColor: Color(0x50FF6B35),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFFE4D6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFFD5B8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
          ),
          hintStyle: const TextStyle(color: Color(0xFFB8967A)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF1C1008)),
          bodyMedium: TextStyle(color: Color(0xFF1C1008)),
          titleLarge: TextStyle(color: Color(0xFF1C1008)),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFF6B35),
          foregroundColor: Colors.white,
          elevation: 6,
        ),
      ),
      home: (loggedIn && AuthService.idCardVerified) ? RestaurantsPage() : LoginPage(),
    );
  }
}
