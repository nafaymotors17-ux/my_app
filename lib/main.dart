import 'package:flutter/material.dart';
import 'package:my_app/src/pages/splash_screen.dart';
import 'package:my_app/src/services/prefs_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrefsService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phishing Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
          primary: const Color(0xFF0F766E),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: Color(0xFFFAFAFA),
          foregroundColor: Color(0xFF171717),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        cardTheme: CardThemeData(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
