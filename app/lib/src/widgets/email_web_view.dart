import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:my_app/src/utils/html_utils.dart';

/// Renders email HTML inside a native WebView for proper responsive rendering.
///
/// Links are intercepted via JavaScript (not navigation delegate) so the
/// initial page load is never accidentally blocked.
class EmailWebView extends StatefulWidget {
  final String htmlContent;

  const EmailWebView({super.key, required this.htmlContent});

  static bool get isSupported {
    try {
      return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  @override
  State<EmailWebView> createState() => _EmailWebViewState();
}

class _EmailWebViewState extends State<EmailWebView> {
  late final WebViewController _controller;
  double _contentHeight = 300;
  bool _ready = false;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      // ── JS → Flutter channels ──
      ..addJavaScriptChannel(
        'HeightChannel',
        onMessageReceived: (msg) {
          final h = double.tryParse(msg.message);
          if (h != null && h > 10 && mounted) {
            setState(() => _contentHeight = h);
          }
        },
      )
      ..addJavaScriptChannel(
        'LinkChannel',
        onMessageReceived: (msg) => _openExternally(msg.message),
      )
      // ── Page lifecycle (no onNavigationRequest — links handled via JS) ──
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _requestHeight();
          _markReady();
        },
      ))
      ..loadHtmlString(_buildDocument(widget.htmlContent));

    // Safety timeout: if onPageFinished never fires, show content anyway.
    _safetyTimer = Timer(const Duration(seconds: 4), _markReady);
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EmailWebView old) {
    super.didUpdateWidget(old);
    if (old.htmlContent != widget.htmlContent) {
      setState(() {
        _ready = false;
        _contentHeight = 300;
      });
      _safetyTimer?.cancel();
      _safetyTimer = Timer(const Duration(seconds: 4), _markReady);
      _controller.loadHtmlString(_buildDocument(widget.htmlContent));
    }
  }

  void _markReady() {
    if (mounted && !_ready) setState(() => _ready = true);
  }

  // ── Height ─────────────────────────────────────────────────────────────────

  void _requestHeight() {
    _controller.runJavaScript('''
      (function() {
        var h = Math.max(
          document.body.scrollHeight || 0,
          document.body.offsetHeight || 0,
          document.documentElement.scrollHeight || 0
        );
        if (h > 10) HeightChannel.postMessage(String(h));
      })();
    ''');
  }

  // ── Links ──────────────────────────────────────────────────────────────────

  Future<void> _openExternally(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $url')),
        );
      }
    }
  }

  // ── HTML builder ───────────────────────────────────────────────────────────

  String _buildDocument(String body) {
    final sanitized = HtmlUtils.isHtml(body)
        ? HtmlUtils.sanitizeEmailHtml(body)
        : HtmlUtils.plainTextToHtml(body);

    // NOTE: JavaScript intercepts <a> clicks and sends them to Flutter
    // via LinkChannel — so the WebView never navigates away from this page.
    return '''<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes">
<style>
  *, *::before, *::after { box-sizing: border-box !important; }
  html { -webkit-text-size-adjust: 100%; }
  html, body { margin: 0; padding: 0; background: #fff; }
  body {
    font-family: 'Roboto', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 14px; line-height: 1.6; color: #202124;
    word-wrap: break-word; overflow-wrap: break-word;
    overflow: hidden;
  }
  body > *, div, section, article, header, footer, main, aside, nav,
  table, td, th, tr, tbody, thead, tfoot, p, span, center {
    max-width: 100% !important;
  }
  img, video, audio, iframe, object, embed, svg, picture, source, canvas {
    display: none !important; width: 0 !important; height: 0 !important;
  }
  a { color: #1a73e8; text-decoration: none; word-break: break-all; }
  table { border-collapse: collapse; width: 100% !important; table-layout: fixed !important; }
  td, th { word-wrap: break-word; overflow-wrap: break-word; overflow: hidden; }
  blockquote { border-left: 3px solid #dadce0; margin: 8px 0; padding: 0 0 0 12px; color: #5f6368; }
  pre { overflow-x: auto; background: #f8f9fa; padding: 12px; border-radius: 8px; font-size: 13px; white-space: pre-wrap; }
  code { background: #f1f3f4; padding: 2px 4px; border-radius: 4px; font-size: 13px; }
  h1 { font-size: 20px; margin: 16px 0 8px; }
  h2 { font-size: 18px; margin: 14px 0 6px; }
  h3 { font-size: 16px; margin: 12px 0 4px; }
  [width] { width: auto !important; max-width: 100% !important; }
</style>
</head><body>
$sanitized
<script>
  // Report content height to Flutter
  function rh(){
    var h=Math.max(document.body.scrollHeight||0,document.body.offsetHeight||0,document.documentElement.scrollHeight||0);
    if(h>10)HeightChannel.postMessage(String(h));
  }
  rh();
  window.addEventListener('load',function(){setTimeout(rh,200);});
  if(typeof ResizeObserver!=='undefined'){new ResizeObserver(function(){setTimeout(rh,50)}).observe(document.body);}

  // Intercept link clicks → send to Flutter instead of navigating
  document.addEventListener('click',function(e){
    var t=e.target;
    while(t&&t.tagName!=='A')t=t.parentElement;
    if(t&&t.href&&t.href.indexOf('about:')!==0){
      e.preventDefault();
      e.stopPropagation();
      LinkChannel.postMessage(t.href);
    }
  },true);
</script>
</body></html>''';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: _contentHeight,
      child: Stack(
        children: [
          // Always show the WebView (no opacity gating)
          WebViewWidget(controller: _controller),
          // Loading overlay — fades away when ready
          if (!_ready)
            Container(
              color: Colors.white,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
