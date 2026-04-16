import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:my_app/src/pages/app_navigation_shell.dart';
import 'package:my_app/src/pages/onboarding_page.dart';
import 'package:my_app/src/services/prefs_service.dart';

/// Branded intro shown on cold start; native splash matches [flutter_native_splash] color.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;
  Timer? _navTimer;
  bool _didNavigate = false;

  static const Color _teal = Color(0xFF0F766E);
  static const Color _tealDark = Color(0xFF115E59);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    unawaited(_controller.forward());

    _navTimer = Timer(const Duration(milliseconds: 2800), _goToApp);
  }

  void _goToApp() {
    if (_didNavigate || !mounted) return;
    _didNavigate = true;
    _navTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (context, animation, secondaryAnimation) {
          return PrefsService.hasCompletedOnboarding()
              ? const AppNavigationShell()
              : const OnboardingPage();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goToApp,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_tealDark, _teal, Color(0xFF14B8A6)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              size: 72,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Phishing Detector',
                            textAlign: TextAlign.center,
                            style: tt.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'SMS & email safety with on-device checks',
                            textAlign: TextAlign.center,
                            style: tt.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Master's FYP · Intelligent threat separation",
                            textAlign: TextAlign.center,
                            style: tt.labelLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 48),
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tap anywhere to continue',
                            style: tt.labelMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
