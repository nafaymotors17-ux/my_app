import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:my_app/src/pages/app_navigation_shell.dart';
import 'package:my_app/src/services/prefs_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// Three-slide first run: demo → how it works → ready (all services).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _index = 0;

  // Slide 1: offline demo state (no network / no permissions).
  bool _demoRan = false;
  int _demoAnimTick = 0;

  // Slide 3: SMS permission request.
  bool _smsRequesting = false;

  static const _total = 3;

  Future<void> _finish() async {
    await PrefsService.setOnboardingSources(
      sms: true,
      gmail: true,
      paste: true,
    );
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _runDemoScan() {
    // Offline demo: we intentionally avoid network calls during onboarding.
    setState(() {
      _demoRan = true;
      _demoAnimTick++;
    });
  }

  void _next() {
    if (_index < _total - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
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
                physics: const BouncingScrollPhysics(),
                children: [
                  _Slide(
                    slideIndex: 0,
                    activeIndex: _index,
                    icon: Icons.shield_rounded,
                    iconBg: const Color(0xFFCCFBF1),
                    iconColor: const Color(0xFF0F766E),
                    title: 'Stop phishing before you click',
                    body:
                        'Scan suspicious SMS and emails with confidence, highlights, and a saved Threat inbox.',
                    extra: Column(
                      children: [
                        _DemoComparisonCard(
                          demoRan: _demoRan,
                          animTick: _demoAnimTick,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _runDemoScan,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: Text(
                                  _demoRan ? 'Play again' : 'Preview results',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _SmallInfoPill(
                          icon: Icons.lock_outline,
                          text: 'Offline preview — no permissions, no network',
                        ),
                      ],
                    ),
                  ),
                  _Slide(
                    slideIndex: 1,
                    activeIndex: _index,
                    icon: Icons.auto_awesome_rounded,
                    iconBg: const Color(0xFFE0E7FF),
                    iconColor: const Color(0xFF3730A3),
                    title: 'How it works',
                    body:
                        'You stay in control. The app only analyzes text when you tap Scan.',
                    extra: Column(
                      children: [
                        _HowItWorksCard(active: _index == 1),
                        const SizedBox(height: 10),
                        _SmallInfoPill(
                          icon: Icons.policy_outlined,
                          text: 'Only scanned text is sent to your detection API',
                        ),
                      ],
                    ),
                  ),
                  _Slide(
                    slideIndex: 2,
                    activeIndex: _index,
                    icon: Icons.rocket_launch_rounded,
                    iconBg: const Color(0xFFD1FAE5),
                    iconColor: const Color(0xFF047857),
                    title: 'You’re all set',
                    body:
                        'SMS, Email, and Quick scan are ready. Allow SMS on Android to load messages; sign in to Gmail from the Email tab when you want.',
                    extra: Column(
                      children: [
                        _ServicesReadyCard(
                          smsRequesting: _smsRequesting,
                          onAllowSms: kIsWeb ? null : _requestSms,
                        ),
                        const SizedBox(height: 10),
                        _SmallInfoPill(
                          icon: Icons.tour_outlined,
                          text: 'Replay anytime from Settings → Show onboarding again',
                        ),
                      ],
                    ),
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
                    onPressed: _next,
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

class _Slide extends StatefulWidget {
  const _Slide({
    required this.slideIndex,
    required this.activeIndex,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.extra,
  });

  final int slideIndex;
  final int activeIndex;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String body;
  final Widget extra;

  @override
  State<_Slide> createState() => _SlideState();
}

class _SlideState extends State<_Slide> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _iconScale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack),
    );
    _entrance.forward();
  }

  @override
  void didUpdateWidget(covariant _Slide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeIndex == widget.slideIndex &&
        oldWidget.activeIndex != widget.slideIndex) {
      _entrance.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Column(
            children: [
              const SizedBox(height: 12),
              ScaleTransition(
                scale: _iconScale,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: widget.iconBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.iconColor.withValues(alpha: 0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, size: 56, color: widget.iconColor),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.body,
                textAlign: TextAlign.center,
                style: tt.bodyLarge?.copyWith(
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              widget.extra,
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallInfoPill extends StatelessWidget {
  const _SmallInfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatefulWidget {
  const _HowItWorksCard({required this.active});

  final bool active;

  @override
  State<_HowItWorksCard> createState() => _HowItWorksCardState();
}

class _HowItWorksCardState extends State<_HowItWorksCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.active) _c.forward();
  }

  @override
  void didUpdateWidget(covariant _HowItWorksCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What you get',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _StaggerBullet(
              controller: _c,
              interval: const Interval(0, 0.28, curve: Curves.easeOutCubic),
              child: _Bullet(
                icon: Icons.percent_rounded,
                title: 'Confidence score',
                subtitle: 'A clear probability + label (Safe / Suspicious)',
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 8),
            _StaggerBullet(
              controller: _c,
              interval: const Interval(0.18, 0.52, curve: Curves.easeOutCubic),
              child: _Bullet(
                icon: Icons.highlight_rounded,
                title: 'Highlights',
                subtitle:
                    'Risky parts like links, urgency and verification prompts',
                color: const Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(height: 8),
            _StaggerBullet(
              controller: _c,
              interval: const Interval(0.38, 0.78, curve: Curves.easeOutCubic),
              child: _Bullet(
                icon: Icons.inventory_2_outlined,
                title: 'Threat inbox',
                subtitle: 'Save results locally so you can review later',
                color: const Color(0xFFB45309),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = const Interval(0.55, 1, curve: Curves.easeOutCubic)
                    .transform(_c.value);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - t)),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        'Flow: Open a message → Tap the shield → Get score + highlights → Save.',
                        style: tt.bodyMedium?.copyWith(
                          height: 1.35,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StaggerBullet extends StatelessWidget {
  const _StaggerBullet({
    required this.controller,
    required this.interval,
    required this.child,
  });

  final AnimationController controller;
  final Interval interval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = interval.transform(controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(16 * (1 - t), 0),
            child: child,
          ),
        );
      },
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: tt.bodyMedium?.copyWith(
                  height: 1.35,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DemoComparisonCard extends StatelessWidget {
  const _DemoComparisonCard({
    required this.demoRan,
    required this.animTick,
  });

  final bool demoRan;
  final int animTick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preview',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'offline',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) {
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                key: ValueKey<bool>(demoRan),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DemoRow(
                      title: 'Phishing (sample)',
                      message:
                          'Verify your account now: secure-login.example.com/verify',
                      confidence: demoRan ? 0.92 : null,
                      isPhishing: true,
                      highlights: const ['Verify', 'secure-login', '/verify'],
                      animTick: animTick,
                    ),
                    const SizedBox(height: 10),
                    _DemoRow(
                      title: 'Safe (sample)',
                      message:
                          'Your OTP is 482913. Do not share it with anyone.',
                      confidence: demoRan ? 0.09 : null,
                      isPhishing: false,
                      highlights: const ['OTP', 'Do not share'],
                      animTick: animTick,
                    ),
                  ],
                ),
              ),
            ),
            if (!demoRan) ...[
              const SizedBox(height: 10),
              Text(
                'Tap “Preview results” to show confidence + highlights.',
                textAlign: TextAlign.center,
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServicesReadyCard extends StatelessWidget {
  const _ServicesReadyCard({
    required this.smsRequesting,
    required this.onAllowSms,
  });

  final bool smsRequesting;
  final VoidCallback? onAllowSms;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ServiceRow(
              icon: Icons.sms_outlined,
              iconBg: const Color(0xFFCCFBF1),
              iconColor: const Color(0xFF0F766E),
              title: 'SMS inbox',
              subtitle: kIsWeb
                  ? 'Use the SMS tab on Android'
                  : 'Unread messages — allow SMS when prompted',
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: smsRequesting ? null : onAllowSms,
                icon: smsRequesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_rounded),
                label: Text(smsRequesting ? 'Requesting…' : 'Allow SMS access'),
              ),
            ],
            const SizedBox(height: 14),
            _ServiceRow(
              icon: Icons.mail_outline,
              iconBg: const Color(0xFFFEE2E2),
              iconColor: const Color(0xFFB91C1C),
              title: 'Gmail inbox',
              subtitle: 'Sign in from the Email tab',
            ),
            const SizedBox(height: 14),
            _ServiceRow(
              icon: Icons.bolt_rounded,
              iconBg: const Color(0xFFE0E7FF),
              iconColor: const Color(0xFF3730A3),
              title: 'Quick scan',
              subtitle: 'Paste text from the bolt icon on any tab',
            ),
            const SizedBox(height: 12),
            Text(
              'All three features are included.',
              textAlign: TextAlign.center,
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: tt.bodyMedium?.copyWith(
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DemoRow extends StatelessWidget {
  const _DemoRow({
    required this.title,
    required this.message,
    required this.confidence,
    required this.isPhishing,
    required this.highlights,
    required this.animTick,
  });

  final String title;
  final String message;
  final double? confidence;
  final bool isPhishing;
  final List<String> highlights;
  final int animTick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bg = isPhishing ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5);
    final border = isPhishing ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final fg = isPhishing ? const Color(0xFFB91C1C) : const Color(0xFF047857);

    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(animTick + (isPhishing ? 1000 : 0)),
      tween: Tween<double>(begin: 0, end: confidence ?? 0),
      duration: confidence != null
          ? const Duration(milliseconds: 650)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, animatedConf, _) {
        final pct = confidence != null ? (animatedConf * 100).round() : null;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isPhishing ? Icons.warning_rounded : Icons.check_circle,
                    size: 18,
                    color: fg,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (pct != null)
                    Text(
                      '$pct%',
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: fg,
                      ),
                    )
                  else
                    Text(
                      '—%',
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: tt.bodyMedium?.copyWith(height: 1.3),
              ),
              if (confidence != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: highlights
                      .asMap()
                      .entries
                      .map(
                        (e) => TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: Duration(milliseconds: 280 + e.key * 70),
                          // easeOutBack overshoots past 1.0 — Opacity requires [0, 1].
                          curve: Curves.easeOutBack,
                          builder: (context, t, child) {
                            final opacity = t.clamp(0.0, 1.0);
                            final scale = 0.92 + 0.08 * t;
                            return Opacity(
                              opacity: opacity,
                              child: Transform.scale(
                                scale: scale,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Text(
                              e.value,
                              style: tt.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
