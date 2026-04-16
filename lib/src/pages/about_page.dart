import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Static project context for thesis / demo builds.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final i = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _info = i);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final v = _info;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.school_outlined, size: 48, color: cs.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Phishing Detector',
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            v != null
                ? 'Version ${v.version} (${v.buildNumber})'
                : 'Loading version…',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _Paragraph(
            title: 'Project',
            body:
                'Final-year project prototype: classify SMS and email content '
                'with a remote ML API, separate phishing from safe items, and '
                'integrate Gmail folders (Inbox, Sent, Spam) for realistic evaluation.',
          ),
          const SizedBox(height: 16),
          _Paragraph(
            title: 'Disclaimer',
            body:
                'This app assists analysis only. It is not a substitute for '
                'enterprise security tools or provider spam filters. Always '
                'verify sensitive actions outside the app.',
          ),
          const SizedBox(height: 16),
          _Paragraph(
            title: 'Customize for your report',
            body:
                'Replace this screen with your institution name, supervisor, '
                'student ID, and submission date in the thesis PDF.',
          ),
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
