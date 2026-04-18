import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:my_app/src/pages/app_navigation_shell.dart';
import 'package:my_app/src/services/prefs_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// Three-slide first run: preview → how it works → ready (all sources).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _index = 0;

  // Slide 1: offline preview (no network / no permissions).
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
    // Offline preview — no network calls during onboarding.
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
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primaryContainer.withValues(alpha: 0.45),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
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
                    extra: Column(
                      children: [
                        _InteractiveHowItWorksCard(active: _index == 1),
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
                    child: Text(_index < _total - 1 ? 'Continue' : 'Get started'),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    this.body,
    required this.extra,
  });

  final int slideIndex;
  final int activeIndex;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  /// Optional; omitted on slides where the title and card carry the message.
  final String? body;
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
              if (widget.body != null && widget.body!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  widget.body!,
                  textAlign: TextAlign.center,
                  style: tt.bodyLarge?.copyWith(
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              SizedBox(
                height: widget.body != null && widget.body!.trim().isNotEmpty
                    ? 24
                    : 16,
              ),
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

enum _ScanSurface { inbox, message, quick }

/// Tappable paths: scan from list, inside message, or Quick scan — plus after-scan summary.
class _InteractiveHowItWorksCard extends StatefulWidget {
  const _InteractiveHowItWorksCard({required this.active});

  final bool active;

  @override
  State<_InteractiveHowItWorksCard> createState() =>
      _InteractiveHowItWorksCardState();
}

class _InteractiveHowItWorksCardState extends State<_InteractiveHowItWorksCard>
    with SingleTickerProviderStateMixin {
  _ScanSurface _surface = _ScanSurface.inbox;
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    if (widget.active) _enter.forward();
  }

  @override
  void didUpdateWidget(covariant _InteractiveHowItWorksCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _enter.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _pick(_ScanSurface next) {
    if (next == _surface) return;
    HapticFeedback.selectionClick();
    setState(() => _surface = next);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final chips = Row(
      children: [
        Expanded(
          child: _ScanChip(
            label: 'List & bar',
            icon: Icons.view_list_rounded,
            selected: _surface == _ScanSurface.inbox,
            onTap: () => _pick(_ScanSurface.inbox),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScanChip(
            label: 'In message',
            icon: Icons.chat_bubble_outline_rounded,
            selected: _surface == _ScanSurface.message,
            onTap: () => _pick(_ScanSurface.message),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScanChip(
            label: 'Quick',
            icon: Icons.bolt_rounded,
            selected: _surface == _ScanSurface.quick,
            onTap: () => _pick(_ScanSurface.quick),
          ),
        ),
      ],
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Text(
            'Choose where to scan',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Same model everywhere — pick what fits the moment.',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          chips,
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
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
            child: KeyedSubtree(
              key: ValueKey<_ScanSurface>(_surface),
              child: _ScanSurfaceDetail(surface: _surface),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'After you scan',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _AfterScanRow(
            icon: Icons.percent_rounded,
            iconColor: const Color(0xFF3730A3),
            title: 'Risk score',
            subtitle: 'Percentage and a Safe or Suspicious label',
          ),
          const SizedBox(height: 10),
          _AfterScanRow(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFFB45309),
            title: 'Threat inbox',
            subtitle:
                'Phishing results save automatically — review or swipe to clear',
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanChip extends StatelessWidget {
  const _ScanChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? cs.primaryContainer.withValues(alpha: 0.85)
                : cs.surfaceContainerHighest.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? cs.primary.withValues(alpha: 0.45) : cs.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                      height: 1.2,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanSurfaceDetail extends StatelessWidget {
  const _ScanSurfaceDetail({required this.surface});

  final _ScanSurface surface;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    switch (surface) {
      case _ScanSurface.inbox:
        return _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Without opening the full message',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a row in SMS or Email, then use the scan control in the '
                'app bar. Select several messages with the checklist and tap '
                'Scan (n) for a batch run.',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _MiniAppBarMock(
                trailing: Icon(Icons.shield_rounded, color: cs.primary, size: 22),
              ),
            ],
          ),
        );
      case _ScanSurface.message:
        return _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Inside the conversation or email',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Scroll to the scan card and tap Scan this message (SMS) or '
                'Scan email text (Gmail).',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _MiniMessageMock(cs: cs),
            ],
          ),
        );
      case _ScanSurface.quick:
        return _DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'No inbox needed',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the bolt icon from the app bar or Home, paste any text, '
                'and run Scan — ideal for forwards and screenshots.',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _MiniQuickMock(cs: cs),
            ],
          ),
        );
    }
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }
}

class _MiniAppBarMock extends StatelessWidget {
  const _MiniAppBarMock({required this.trailing});

  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: cs.primary, size: 20),
          const SizedBox(width: 8),
          Icon(Icons.checklist_rounded, color: cs.onSurfaceVariant, size: 20),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

class _MiniMessageMock extends StatelessWidget {
  const _MiniMessageMock({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '… message preview …',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.radar_rounded, size: 18),
            label: const Text('Scan this message'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniQuickMock extends StatelessWidget {
  const _MiniQuickMock({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Paste SMS or email text…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.outline,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: null,
              child: const Text('Scan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AfterScanRow extends StatelessWidget {
  const _AfterScanRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
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
                      animTick: animTick,
                    ),
                    const SizedBox(height: 10),
                    _DemoRow(
                      title: 'Safe (sample)',
                      message:
                          'Your OTP is 482913. Do not share it with anyone.',
                      confidence: demoRan ? 0.09 : null,
                      isPhishing: false,
                      animTick: animTick,
                    ),
                  ],
                ),
              ),
            ),
            if (!demoRan) ...[
              const SizedBox(height: 10),
              Text(
                'Tap “Preview results” to see sample risk scores.',
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
    required this.animTick,
  });

  final String title;
  final String message;
  final double? confidence;
  final bool isPhishing;
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
            ],
          ),
        );
      },
    );
  }
}
