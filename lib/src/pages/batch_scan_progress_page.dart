import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/models/batch_scan_result.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/pages/batch_scan_results_page.dart';

/// Same seed as `MaterialApp` in `main.dart` — multiscan uses a dark
/// `ColorScheme.fromSeed` so tones stay one family everywhere.
const _kAppBrandSeed = Color(0xFF0F766E);

/// Full-screen live batch scan — futuristic “clear scan” HUD aesthetic.
class BatchScanProgressPage extends StatefulWidget {
  const BatchScanProgressPage({
    super.key,
    required this.sourceLabel,
    required this.messages,
    required this.scanOne,
  });

  final String sourceLabel;
  final List<Message> messages;
  final Future<BatchScanResultItem> Function(Message msg) scanOne;

  @override
  State<BatchScanProgressPage> createState() => _BatchScanProgressPageState();
}

class _BatchScanProgressPageState extends State<BatchScanProgressPage>
    with TickerProviderStateMixin {
  final List<BatchScanResultItem> _results = [];
  int _activeIndex = 0;
  bool _running = true;
  String? _error;

  late final AnimationController _gridDrift;
  late final AnimationController _scanSweep;
  late final AnimationController _hudPulse;
  late final AnimationController _ringGlow;
  late final AnimationController _orbitSpin;

  @override
  void initState() {
    super.initState();
    _gridDrift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _scanSweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _hudPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _ringGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _orbitSpin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) => _runAll());
  }

  @override
  void dispose() {
    _gridDrift.dispose();
    _scanSweep.dispose();
    _hudPulse.dispose();
    _ringGlow.dispose();
    _orbitSpin.dispose();
    super.dispose();
  }

  Future<void> _runAll() async {
    final total = widget.messages.length;
    for (var i = 0; i < total; i++) {
      if (!mounted) return;
      setState(() => _activeIndex = i);
      try {
        final item = await widget.scanOne(widget.messages[i]);
        if (!mounted) return;
        setState(() => _results.add(item));
        HapticFeedback.lightImpact();
      } catch (e, st) {
        debugPrint('Batch scan item failed: $e\n$st');
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _running = false;
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() => _running = false);
    final completedAt = DateTime.now();
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 480),
        pageBuilder: (_, _, _) => BatchScanResultsPage(
          items: List<BatchScanResultItem>.from(_results),
          completedAt: completedAt,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
    );
  }

  String _titleFor(Message m) {
    if (m.source == 'gmail') return m.subject ?? '(No subject)';
    return m.address;
  }

  double get _fraction {
    final t = widget.messages.length;
    if (t == 0) return 0;
    return _results.length / t;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final total = widget.messages.length;
    final pct = (_fraction * 100).clamp(0.0, 100.0);
    final parentTheme = Theme.of(context);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: _kAppBrandSeed,
      brightness: Brightness.dark,
    );
    final scanTheme = parentTheme.copyWith(
      colorScheme: darkScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkScheme.surface,
    );

    return PopScope(
      canPop: !_running,
      child: Theme(
        data: scanTheme,
        child: Scaffold(
          backgroundColor: darkScheme.surface,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _DeepSpaceGradient(scheme: darkScheme),
              AnimatedBuilder(
                animation: _gridDrift,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _FuturisticGridPainter(
                      drift: _gridDrift.value,
                      scheme: darkScheme,
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _scanSweep,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ScanBeamPainter(
                      t: _scanSweep.value,
                      scheme: darkScheme,
                    ),
                  );
                },
              ),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HudTopBar(
                      scheme: darkScheme,
                      sourceLabel: widget.sourceLabel,
                      total: total,
                      running: _running,
                      onClose: _running
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _hudPulse,
                          _ringGlow,
                          _orbitSpin,
                        ]),
                        builder: (context, _) {
                          return _ClearScanHudCard(
                            scheme: darkScheme,
                            percent: pct,
                            fraction: _fraction,
                            pulse: _hudPulse.value,
                            glow: _ringGlow.value,
                            orbit: _orbitSpin.value,
                            subtitle: _running && total > 0
                                ? 'SCANNING OBJECT ${_results.length + 1} / $total'
                                : _error != null
                                    ? 'ABORTED'
                                    : 'SEQUENCE COMPLETE',
                          );
                        },
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              color: darkScheme.errorContainer
                                  .withValues(alpha: 0.72),
                              child: Text(
                                _error!,
                                style: tt.bodyMedium?.copyWith(
                                  color: darkScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        children: [
                          if (_running && total > 0 && _activeIndex < total) ...[
                            Text(
                              'ACTIVE TARGET',
                              style: tt.labelSmall?.copyWith(
                                color: darkScheme.primary.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ActiveTargetGlassCard(
                              scheme: darkScheme,
                              title: _titleFor(widget.messages[_activeIndex]),
                              sweep: _scanSweep,
                              pulse: _hudPulse,
                            ),
                            const SizedBox(height: 22),
                          ],
                          if (_results.isNotEmpty) ...[
                            Text(
                              'SCAN LOG',
                              style: tt.labelSmall?.copyWith(
                                color: darkScheme.secondary.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...List.generate(_results.length, (i) {
                              final item = _results[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 420),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, t, child) {
                                    return Opacity(
                                      opacity: t,
                                      child: Transform.translate(
                                        offset: Offset(20 * (1 - t), 0),
                                        child: Transform.scale(
                                          scale: 0.96 + 0.04 * t,
                                          child: child,
                                        ),
                                      ),
                                    );
                                  },
                                  child: _ScanLogRow(
                                    index: i + 1,
                                    item: item,
                                    title: _titleFor(item.message),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
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

class _DeepSpaceGradient extends StatelessWidget {
  const _DeepSpaceGradient({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final halo = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.22),
      scheme.surface,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.58),
          radius: 1.35,
          colors: [
            halo,
            scheme.surface,
            scheme.surfaceContainerHighest,
          ],
          stops: const [0.0, 0.46, 1.0],
        ),
      ),
    );
  }
}

/// Subtle moving grid — radar / tactical display.
class _FuturisticGridPainter extends CustomPainter {
  _FuturisticGridPainter({required this.drift, required this.scheme});

  final double drift;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = scheme.primary.withValues(alpha: 0.1);

    const step = 36.0;
    final ox = (drift * step * 2) % step;

    for (var x = -ox; x < size.width + step; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y < size.height + step; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          scheme.surface.withValues(alpha: 0.9),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _FuturisticGridPainter oldDelegate) {
    return oldDelegate.drift != drift || oldDelegate.scheme != scheme;
  }
}

/// Horizontal light beam sweeping down — “clear scan” line.
class _ScanBeamPainter extends CustomPainter {
  _ScanBeamPainter({required this.t, required this.scheme});

  final double t;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final y = t * (size.height + 120) - 60;
    final h = 56.0;
    final rect = Rect.fromLTWH(0, y, size.width, h);
    final p = scheme.primary;
    final s = scheme.secondary;

    final g = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        p.withValues(alpha: 0.0),
        p.withValues(alpha: 0.16),
        s.withValues(alpha: 0.22),
        p.withValues(alpha: 0.16),
        p.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
    );

    final paint = Paint()..shader = g.createShader(rect);
    canvas.drawRect(rect, paint);

    final core = Paint()
      ..color = scheme.onPrimary.withValues(alpha: 0.42)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, y + h * 0.5), Offset(size.width, y + h * 0.5), core);
  }

  @override
  bool shouldRepaint(covariant _ScanBeamPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.scheme != scheme;
}

class _HudTopBar extends StatelessWidget {
  const _HudTopBar({
    required this.scheme,
    required this.sourceLabel,
    required this.total,
    required this.running,
    required this.onClose,
  });

  final ColorScheme scheme;
  final String sourceLabel;
  final int total;
  final bool running;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final on = scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              color: on.withValues(alpha: running ? 0.28 : 0.88),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLEAR SCAN',
                  style: tt.titleMedium?.copyWith(
                    color: on,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sourceLabel.toUpperCase(),
                  style: tt.labelLarge?.copyWith(
                    color: scheme.primary.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.2),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hexagon_outlined, size: 18, color: scheme.secondary),
                const SizedBox(width: 8),
                Text(
                  '$total',
                  style: tt.titleMedium?.copyWith(
                    color: on,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearScanHudCard extends StatelessWidget {
  const _ClearScanHudCard({
    required this.scheme,
    required this.percent,
    required this.fraction,
    required this.pulse,
    required this.glow,
    required this.orbit,
    required this.subtitle,
  });

  final ColorScheme scheme;
  final double percent;
  final double fraction;
  final double pulse;
  final double glow;
  final double orbit;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final glowOpacity = 0.35 + glow * 0.25;
    final on = scheme.onSurface;
    final p = scheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: p.withValues(alpha: 0.42 + pulse * 0.16),
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerHighest.withValues(alpha: 0.88),
                scheme.surfaceContainer.withValues(alpha: 0.82),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: p.withValues(alpha: glowOpacity * 0.48),
                blurRadius: 32 + glow * 18,
                spreadRadius: glow * 2,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(120),
                      painter: _AdvancedProgressRingPainter(
                        progress: fraction,
                        glowPhase: glow,
                        pulse: pulse,
                        orbit: orbit,
                        scheme: scheme,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          percent.clamp(0.0, 100.0).toStringAsFixed(0),
                          style: tt.headlineLarge?.copyWith(
                            color: on,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            letterSpacing: -1.5,
                            fontSize: 36,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            shadows: [
                              Shadow(
                                color: p.withValues(alpha: 0.55),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '%',
                          style: tt.titleMedium?.copyWith(
                            color: scheme.secondary.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANALYSIS PIPELINE',
                      style: tt.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: tt.titleSmall?.copyWith(
                        color: on.withValues(alpha: 0.96),
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PlayStoreStyleProgressBar(
                      fraction: fraction,
                      scheme: scheme,
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

/// Determinate ring: orbit ticks, sweep gradient arc, tip spark, inner pulse.
class _AdvancedProgressRingPainter extends CustomPainter {
  _AdvancedProgressRingPainter({
    required this.progress,
    required this.glowPhase,
    required this.pulse,
    required this.orbit,
    required this.scheme,
  });

  final double progress;
  final double glowPhase;
  final double pulse;
  final double orbit;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 4;
    final spin = orbit * 2 * math.pi;

    final tickPaint = Paint()
      ..color = scheme.outline.withValues(alpha: 0.35)
      ..strokeWidth = 1.1;
    const tickN = 16;
    for (var i = 0; i < tickN; i++) {
      final a = (i / tickN) * 2 * math.pi + spin;
      final i0 = r + 5;
      final i1 = r + 11;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * i0,
        c + Offset(math.cos(a), math.sin(a)) * i1,
        tickPaint,
      );
    }

    final outerHalo = Paint()
      ..color = scheme.primary.withValues(alpha: 0.12 + 0.1 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(c, r + 4, outerHalo);

    final track = Paint()
      ..color = scheme.onSurface.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(c, r, track);

    final innerBreath = Paint()
      ..color = scheme.primary.withValues(alpha: 0.1 + 0.16 * glowPhase)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, r - 16, innerBreath);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep > 0.004) {
      final rect = Rect.fromCircle(center: c, radius: r);
      final arcPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 1.5 * math.pi,
          colors: [
            scheme.primaryContainer,
            scheme.primary,
            scheme.secondary,
            scheme.primary,
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
          transform: GradientRotation(glowPhase * math.pi * 0.55),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, -math.pi / 2, sweep, false, arcPaint);

      final glow = Paint()
        ..color = scheme.primary.withValues(alpha: 0.22 + glowPhase * 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(rect, -math.pi / 2, sweep, false, glow);

      if (sweep > 0.08) {
        final endA = -math.pi / 2 + sweep;
        final tip = c + Offset(math.cos(endA), math.sin(endA)) * r;
        final spark = Paint()
          ..shader = RadialGradient(
            colors: [
              scheme.onPrimary.withValues(alpha: 0.95),
              scheme.primary.withValues(alpha: 0.55),
              Colors.transparent,
            ],
            stops: const [0.0, 0.42, 1.0],
          ).createShader(Rect.fromCircle(center: tip, radius: 14));
        canvas.drawCircle(tip, 11, spark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AdvancedProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowPhase != glowPhase ||
        oldDelegate.pulse != pulse ||
        oldDelegate.orbit != orbit ||
        oldDelegate.scheme != scheme;
  }
}

/// Horizontal fill like Play Store install — smooth width.
class _PlayStoreStyleProgressBar extends StatelessWidget {
  const _PlayStoreStyleProgressBar({
    required this.fraction,
    required this.scheme,
  });

  final double fraction;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackW = constraints.maxWidth;
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 10,
                width: trackW,
                color: scheme.onSurface.withValues(alpha: 0.1),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                height: 10,
                width: trackW * f,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary,
                      scheme.secondary.withValues(alpha: 0.92),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.38),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveTargetGlassCard extends StatelessWidget {
  const _ActiveTargetGlassCard({
    required this.scheme,
    required this.title,
    required this.sweep,
    required this.pulse,
  });

  final ColorScheme scheme;
  final String title;
  final Animation<double> sweep;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final on = scheme.onSurface;
    return AnimatedBuilder(
      animation: Listenable.merge([sweep, pulse]),
      builder: (context, child) {
        final edge = 0.35 + pulse.value * 0.2;
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Color.lerp(
                    scheme.primary,
                    scheme.secondary,
                    sweep.value,
                  )!.withValues(alpha: edge),
                  width: 1.4,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surfaceContainerHighest.withValues(alpha: 0.82),
                    scheme.surfaceContainer.withValues(alpha: 0.72),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.16),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _BlinkDot(scheme: scheme, phase: sweep.value),
                      const SizedBox(width: 10),
                      Text(
                        'LIVE ANALYSIS',
                        style: tt.labelSmall?.copyWith(
                          color: scheme.secondary.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(
                      color: on.withValues(alpha: 0.96),
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: on.withValues(alpha: 0.08),
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BlinkDot extends StatelessWidget {
  const _BlinkDot({required this.scheme, required this.phase});

  final ColorScheme scheme;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final p = scheme.primary;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.withValues(alpha: 0.42 + phase * 0.48),
        boxShadow: [
          BoxShadow(
            color: p.withValues(alpha: 0.55),
            blurRadius: 8 + phase * 6,
          ),
        ],
      ),
    );
  }
}

class _ScanLogRow extends StatelessWidget {
  const _ScanLogRow({
    required this.index,
    required this.item,
    required this.title,
  });

  final int index;
  final BatchScanResultItem item;
  final String title;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    late final Color neon;
    late final IconData icon;
    late final String status;
    if (item.isFailure) {
      neon = scheme.tertiary;
      icon = Icons.cloud_off_rounded;
      status = 'FAILED';
    } else if (item.isPhishing) {
      neon = scheme.error;
      icon = Icons.warning_amber_rounded;
      status = 'THREAT';
    } else {
      neon = scheme.primary;
      icon = Icons.verified_rounded;
      status = 'CLEAR';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: neon.withValues(alpha: 0.35)),
            gradient: LinearGradient(
              colors: [
                scheme.surfaceContainerHighest.withValues(alpha: 0.78),
                scheme.surfaceContainer.withValues(alpha: 0.68),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: neon.withValues(alpha: 0.08),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: neon.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$index',
                  style: tt.labelMedium?.copyWith(
                    color: neon,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, color: neon, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      status,
                      style: tt.labelSmall?.copyWith(
                        color: neon.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
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
