import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:my_app/src/pages/app_navigation_shell.dart';
import 'package:my_app/src/services/gmail_auth_service.dart';
import 'package:my_app/src/services/prefs_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// Three-slide first run: SMS permission → Gmail → how scanning works.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _index = 0;
  bool _smsRequesting = false;
  bool _gmailSigningIn = false;

  static const _total = 3;

  Future<void> _finish() async {
    await PrefsService.setOnboardingCompleted(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const AppNavigationShell();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _requestSms() async {
    if (kIsWeb) return;
    setState(() => _smsRequesting = true);
    try {
      final s = await Permission.sms.request();
      if (!mounted) return;
      if (s.isPermanentlyDenied) {
        await openAppSettings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.isGranted
                  ? 'SMS permission granted'
                  : 'You can allow SMS later in system settings',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _smsRequesting = false);
    }
  }

  Future<void> _signInGmail() async {
    setState(() => _gmailSigningIn = true);
    try {
      final user = await GmailAuthService.signIn();
      if (!mounted) return;
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signed in as ${user.email}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in cancelled or failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _gmailSigningIn = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                  Row(
                    children: List.generate(
                      _total,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _index ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: i == _index
                                ? cs.primary
                                : cs.outline.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 72),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _Slide(
                    icon: Icons.sms_outlined,
                    iconBg: const Color(0xFFCCFBF1),
                    iconColor: const Color(0xFF0F766E),
                    title: 'SMS access',
                    body:
                        'We read your unread SMS on this device so you can run the '
                        'phishing model on real messages. Nothing is uploaded unless you tap scan.',
                    extra: kIsWeb
                        ? const Text(
                            'SMS scanning runs on Android with permission.',
                            textAlign: TextAlign.center,
                          )
                        : FilledButton.icon(
                            onPressed: _smsRequesting ? null : _requestSms,
                            icon: _smsRequesting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.lock_open_rounded),
                            label: Text(
                              _smsRequesting ? 'Requesting…' : 'Allow SMS access',
                            ),
                          ),
                  ),
                  _Slide(
                    icon: Icons.mail_outline,
                    iconBg: const Color(0xFFFEE2E2),
                    iconColor: const Color(0xFFB91C1C),
                    title: 'Gmail',
                    body:
                        'Connect your Google account to load unread Inbox messages and '
                        'scan email bodies with the same API. You can skip and sign in later from the Email tab.',
                    extra: Column(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _gmailSigningIn ? null : _signInGmail,
                          icon: _gmailSigningIn
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(
                            _gmailSigningIn ? 'Signing in…' : 'Sign in with Google',
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          child: const Text('Skip for now'),
                        ),
                      ],
                    ),
                  ),
                  _Slide(
                    icon: Icons.shield_rounded,
                    iconBg: const Color(0xFFD1FAE5),
                    iconColor: const Color(0xFF047857),
                    title: 'How scanning works',
                    body:
                        '• Shield on a message — scan that SMS or email.\n'
                        '• Bolt — paste any text without opening a message.\n'
                        '• Checklist — select several messages, then batch scan with a full report.\n'
                        'Results can be saved on device for the Threat inbox.',
                    extra: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  if (_index > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 64),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      if (_index < _total - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      } else {
                        _finish();
                      }
                    },
                    child: Text(_index < _total - 1 ? 'Next' : 'Get started'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.extra,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String body;
  final Widget extra;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: iconColor),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: tt.bodyLarge?.copyWith(
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          extra,
        ],
      ),
    );
  }
}
