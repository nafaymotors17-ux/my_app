import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/services/gmail_service.dart';
import 'package:my_app/src/utils/date_time_utils.dart';
import 'package:my_app/src/utils/html_utils.dart';
import 'package:my_app/src/widgets/email_web_view.dart';

/// Full-screen message detail page modeled after the Gmail app.
///
/// • Opens via Navigator.push — list page state is preserved on back.
/// • Renders HTML email bodies with clickable links (no images/video/docs).
/// • Expandable sender header, clean white background, all actions in AppBar.
/// • Responsive padding + max body width for tablets / landscape.
class MessageDetailPage extends StatefulWidget {
  final Message message;
  final bool initialIsRead;
  final VoidCallback onToggleRead;
  final VoidCallback onClear;
  final Future<void> Function()? onMarkAsSpam;
  final Future<void> Function()? onTrash;

  const MessageDetailPage({
    super.key,
    required this.message,
    required this.initialIsRead,
    required this.onToggleRead,
    required this.onClear,
    this.onMarkAsSpam,
    this.onTrash,
  });

  @override
  State<MessageDetailPage> createState() => _MessageDetailPageState();
}

class _MessageDetailPageState extends State<MessageDetailPage> {
  String? _richBody;
  bool _loadingBody = false;
  late bool _isRead;
  bool _headerExpanded = false;

  Message get msg => widget.message;
  bool get isGmail => msg.source == 'gmail';
  bool get isSent => msg.gmailLabel == 'SENT';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _isRead = widget.initialIsRead;
    if (isGmail) _loadGmailBody();
  }

  Future<void> _loadGmailBody() async {
    final gmailId = msg.id.replaceFirst('gmail_', '');
    setState(() => _loadingBody = true);
    try {
      final body = await GmailService.getEmailBodyForDisplay(gmailId);
      if (mounted) {
        setState(() {
          _richBody = body;
          _loadingBody = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBody = false);
    }
  }

  // ── Sender helpers ─────────────────────────────────────────────────────────

  String get _senderName {
    final addr = msg.address;
    final m = RegExp(r'^(.+?)\s*<').firstMatch(addr);
    if (m != null) return m.group(1)!.trim().replaceAll('"', '');
    final at = addr.indexOf('@');
    if (at > 0) return addr.substring(0, at);
    return addr;
  }

  String get _senderEmail {
    final addr = msg.address;
    final m = RegExp(r'<(.+?)>').firstMatch(addr);
    if (m != null) return m.group(1)!;
    return addr;
  }

  String get _initial =>
      _senderName.isNotEmpty ? _senderName[0].toUpperCase() : '?';

  Color get _avatarColor {
    const palette = [
      Color(0xFFE53935), Color(0xFFD81B60), Color(0xFF8E24AA),
      Color(0xFF5E35B1), Color(0xFF3949AB), Color(0xFF1E88E5),
      Color(0xFF039BE5), Color(0xFF00ACC1), Color(0xFF00897B),
      Color(0xFF43A047), Color(0xFF7CB342), Color(0xFFFDD835),
      Color(0xFFFFB300), Color(0xFFFB8C00), Color(0xFFF4511E),
      Color(0xFF6D4C41), Color(0xFF546E7A),
    ];
    final hash = msg.address.codeUnits.fold<int>(0, (p, c) => p + c);
    return palette[hash % palette.length];
  }

  Color get _sourceColor => switch (msg.source) {
        'whatsapp' => Colors.green,
        'gmail' => Colors.red.shade700,
        _ => Colors.blue,
      };

  String get _sourceLabel => switch (msg.source) {
        'whatsapp' => 'WhatsApp',
        'gmail' => msg.gmailLabel ?? 'INBOX',
        'sms' => 'SMS',
        _ => msg.source.toUpperCase(),
      };

  static String _extractName(String addr) {
    final m = RegExp(r'^(.+?)\s*<').firstMatch(addr);
    if (m != null) return m.group(1)!.trim().replaceAll('"', '');
    final at = addr.indexOf('@');
    if (at > 0) return addr.substring(0, at);
    return addr;
  }

  // ── Responsive helpers ─────────────────────────────────────────────────────

  /// Horizontal padding that grows on wider screens.
  double _hPadding(double screenW) {
    if (screenW >= 900) return 48;
    if (screenW >= 600) return 32;
    return 16;
  }

  /// Max width for the readable content column (like Gmail on tablets).
  double? _maxContentWidth(double screenW) {
    if (screenW >= 900) return 720;
    if (screenW >= 600) return 600;
    return null; // full width on phones
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _toggleRead() {
    widget.onToggleRead();
    setState(() => _isRead = !_isRead);
  }

  void _clear() {
    widget.onClear();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _spam() async {
    if (widget.onMarkAsSpam == null) return;
    await widget.onMarkAsSpam!();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Marked as spam'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _trash() async {
    if (widget.onTrash == null) return;
    await widget.onTrash!();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Moved to trash'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<bool> _onLinkTap(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return true;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
    return true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final hp = _hPadding(screenW);
    final maxW = _maxContentWidth(screenW);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxW ?? double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubjectHeader(hp),
                  _buildSenderSection(hp),
                  Padding(
                    padding: EdgeInsets.only(left: hp + 52, right: hp),
                    child: const Divider(height: 1),
                  ),
                  _buildBodySection(hp),
                  // Generous bottom space so content doesn't feel cramped
                  const SizedBox(height: 64),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── App bar (all actions live here — Gmail-style) ──────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: .5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isRead
                ? Icons.mark_email_unread_outlined
                : Icons.mark_email_read_outlined,
            size: 22,
          ),
          tooltip: _isRead ? 'Mark unread' : 'Mark read',
          onPressed: _toggleRead,
        ),
        if (isGmail && widget.onTrash != null)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 22),
            tooltip: 'Move to trash',
            onPressed: _trash,
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 22),
          onSelected: (v) {
            if (v == 'spam') _spam();
            if (v == 'clear') _clear();
          },
          itemBuilder: (_) => [
            if (isGmail && widget.onMarkAsSpam != null)
              const PopupMenuItem(
                value: 'spam',
                child: Text('Report spam'),
              ),
            const PopupMenuItem(
              value: 'clear',
              child: Text('Remove'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Subject + label badge ──────────────────────────────────────────────────

  Widget _buildSubjectHeader(double hp) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hp, 4, hp, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject line
          Text(
            isGmail ? (msg.subject ?? '(No subject)') : _senderName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w400,
              height: 1.35,
              color: Color(0xFF202124),
            ),
          ),
          const SizedBox(height: 8),
          // Source badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: _sourceColor.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _sourceLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _sourceColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Sender section (expandable, Gmail-style) ──────────────────────────────

  Widget _buildSenderSection(double hp) {
    return InkWell(
      onTap: () => setState(() => _headerExpanded = !_headerExpanded),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hp, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _avatarColor,
              child: Text(
                _initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _headerExpanded
                  ? _buildExpandedHeader()
                  : _buildCollapsedHeader(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _senderName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF202124),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateTimeUtils.formatCompactDate(msg.date),
              style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                isGmail
                    ? (isSent
                        ? 'to ${_extractName(msg.gmailTo ?? msg.address)}'
                        : 'to me')
                    : msg.source.toUpperCase(),
                style: const TextStyle(fontSize: 13, color: Color(0xFF5F6368)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.expand_more, size: 18, color: Colors.grey[500]),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandedHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _senderName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF202124),
          ),
        ),
        const SizedBox(height: 8),
        _infoRow('From', _senderEmail),
        if (isGmail && msg.gmailTo != null && msg.gmailTo!.isNotEmpty)
          _infoRow('To', msg.gmailTo!),
        if (!isGmail) _infoRow('Via', msg.source.toUpperCase()),
        _infoRow('Date', DateTimeUtils.formatDetailDate(msg.date)),
        if (isGmail) _infoRow('Label', msg.gmailLabel ?? 'INBOX'),
        Align(
          alignment: Alignment.centerRight,
          child: Icon(Icons.expand_less, size: 18, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF5F6368),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF3C4043)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Email body ─────────────────────────────────────────────────────────────

  Widget _buildBodySection(double hp) {
    final body = _richBody ?? msg.body;

    if (body.trim().isEmpty && _loadingBody) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (body.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.article_outlined, size: 40, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'No content',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loadingBody)
          Padding(
            padding: EdgeInsets.fromLTRB(hp, 12, hp, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading full email…',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(hp, 16, hp, 0),
          child: _renderBody(body),
        ),
      ],
    );
  }

  Widget _renderBody(String body) {
    if (body.trim().isEmpty) {
      return Text(
        '(No content)',
        style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic),
      );
    }

    // ── HTML emails → native WebView (same approach as Gmail app) ──
    // Gives proper responsive rendering for tables, CSS, email templates.
    if (HtmlUtils.isHtml(body) && EmailWebView.isSupported) {
      return EmailWebView(htmlContent: body);
    }

    // ── Plain text (SMS / WhatsApp) → lightweight widget renderer ──
    final html = HtmlUtils.plainTextToHtml(body);
    return HtmlWidget(
      html,
      onTapUrl: _onLinkTap,
      textStyle: const TextStyle(
        fontSize: 14,
        height: 1.55,
        color: Color(0xFF202124),
      ),
    );
  }
}
