import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_app/src/models/message.dart';
import 'package:my_app/src/utils/date_time_utils.dart';
import 'package:my_app/src/utils/html_utils.dart';
import 'package:my_app/src/widgets/email_web_view.dart';

/// Side panel for master-detail layout on wide screens.
/// Mirrors the Gmail-like design of [MessageDetailPage].
class MessageDetailPanel extends StatelessWidget {
  final Message? message;
  final bool isRead;
  final VoidCallback? onToggleRead;
  final VoidCallback? onClear;
  final Future<void> Function()? onMarkAsSpam;
  final Future<void> Function()? onTrash;
  final Future<String>? fullBodyFuture;

  const MessageDetailPanel({
    super.key,
    this.message,
    required this.isRead,
    this.onToggleRead,
    this.onClear,
    this.onMarkAsSpam,
    this.onTrash,
    this.fullBodyFuture,
  });

  @override
  Widget build(BuildContext context) {
    if (message == null) return _buildEmptyState(context);
    return _buildDetail(context, message!);
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mail_outline_rounded, size: 56, color: cs.outline.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              'Select a message',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: cs.outline),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose from the list to read it here',
              style: TextStyle(fontSize: 13, color: cs.outline.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Detail view ────────────────────────────────────────────────────────────

  Widget _buildDetail(BuildContext context, Message msg) {
    final isGmail = msg.source == 'gmail';
    final isSent = msg.gmailLabel == 'SENT';
    final sourceColor = _sourceColor(msg);
    final name = _extractName(msg.address);
    final email = _extractEmail(msg.address);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarColor = _avatarColor(msg.address);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // ── Actions bar (top) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                if (onToggleRead != null)
                  IconButton(
                    icon: Icon(
                      isRead ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined,
                      size: 20,
                    ),
                    tooltip: isRead ? 'Mark unread' : 'Mark read',
                    onPressed: onToggleRead,
                  ),
                if (isGmail && onMarkAsSpam != null)
                  IconButton(
                    icon: const Icon(Icons.report_gmailerrorred_outlined, size: 20),
                    tooltip: 'Report spam',
                    onPressed: () async => await onMarkAsSpam!(),
                  ),
                if (isGmail && onTrash != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Trash',
                    onPressed: () async => await onTrash!(),
                  ),
                const Spacer(),
                if (onClear != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Remove',
                    onPressed: onClear,
                  ),
              ],
            ),
          ),
          // ── Scrollable content ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject
                  Text(
                    isGmail ? (msg.subject ?? '(No subject)') : name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                      color: Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Label badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: sourceColor.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isGmail ? (msg.gmailLabel ?? 'INBOX') : msg.source.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: sourceColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Sender row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: avatarColor,
                        child: Text(
                          initial,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF202124)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  DateTimeUtils.formatCompactDate(msg.date),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isGmail)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  isSent ? 'to ${msg.gmailTo ?? msg.address}' : 'to me',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  // Body
                  _buildBody(context, msg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body rendering ─────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, Message msg) {
    if (fullBodyFuture != null) {
      return FutureBuilder<String>(
        future: fullBodyFuture,
        builder: (context, snapshot) {
          final body = snapshot.hasData && snapshot.data!.isNotEmpty
              ? snapshot.data!
              : msg.body;
          if (snapshot.connectionState == ConnectionState.waiting &&
              body.trim().isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _renderBody(body);
        },
      );
    }
    return _renderBody(msg.body);
  }

  Widget _renderBody(String body) {
    if (body.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No content',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ),
      );
    }

    // HTML emails → WebView for proper rendering
    if (HtmlUtils.isHtml(body) && EmailWebView.isSupported) {
      return EmailWebView(htmlContent: body);
    }

    // Plain text → lightweight widget renderer
    final html = HtmlUtils.plainTextToHtml(body);
    return HtmlWidget(
      html,
      onTapUrl: (url) async {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {}
        }
        return true;
      },
      textStyle: const TextStyle(
        fontSize: 14,
        height: 1.55,
        color: Color(0xFF202124),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _extractName(String addr) {
    final m = RegExp(r'^(.+?)\s*<').firstMatch(addr);
    if (m != null) return m.group(1)!.trim().replaceAll('"', '');
    final at = addr.indexOf('@');
    if (at > 0) return addr.substring(0, at);
    return addr;
  }

  static String _extractEmail(String addr) {
    final m = RegExp(r'<(.+?)>').firstMatch(addr);
    if (m != null) return m.group(1)!;
    return addr;
  }

  static Color _sourceColor(Message msg) => switch (msg.source) {
        'whatsapp' => Colors.green,
        'gmail' => Colors.red.shade700,
        _ => Colors.blue,
      };

  static Color _avatarColor(String address) {
    const palette = [
      Color(0xFFE53935), Color(0xFFD81B60), Color(0xFF8E24AA),
      Color(0xFF5E35B1), Color(0xFF3949AB), Color(0xFF1E88E5),
      Color(0xFF039BE5), Color(0xFF00ACC1), Color(0xFF00897B),
      Color(0xFF43A047), Color(0xFF7CB342), Color(0xFFFDD835),
      Color(0xFFFFB300), Color(0xFFFB8C00), Color(0xFFF4511E),
      Color(0xFF6D4C41), Color(0xFF546E7A),
    ];
    final hash = address.codeUnits.fold<int>(0, (p, c) => p + c);
    return palette[hash % palette.length];
  }
}
