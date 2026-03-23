/// Utility functions for processing email/message HTML for safe Flutter rendering.
class HtmlUtils {
  HtmlUtils._();

  // ── Detection ──────────────────────────────────────────────────────────────

  /// Returns `true` if [text] looks like HTML (contains known tags).
  static bool isHtml(String text) {
    return RegExp(
      r'<\s*(?:html|body|div|p|a|span|table|br|h[1-6]|ul|ol|li|td|tr|blockquote|center|font|style)\b',
      caseSensitive: false,
    ).hasMatch(text);
  }

  // ── Sanitization ───────────────────────────────────────────────────────────

  /// Sanitize email HTML for safe rendering in Flutter.
  ///
  /// Strips dangerous/unsupported elements while preserving text formatting,
  /// links, lists, tables (for layout), blockquotes, and inline styles.
  static String sanitizeEmailHtml(String html) {
    // 1. Remove <head>…</head> (meta, title, CSS selectors we can't use)
    html = _stripTag(html, 'head');

    // 2. Remove <style>…</style> blocks (class-based CSS not supported)
    html = _stripTag(html, 'style');

    // 3. Remove <script>…</script>
    html = _stripTag(html, 'script');

    // 4. Remove media: <img>, <video>, <audio>, <source>, <picture>
    html = _stripSelfClosing(html, 'img');
    html = _stripTag(html, 'video');
    html = _stripTag(html, 'audio');
    html = _stripSelfClosing(html, 'source');
    html = _stripTag(html, 'picture');

    // 5. Remove embedded content: <iframe>, <object>, <embed>, <svg>
    html = _stripTag(html, 'iframe');
    html = _stripTag(html, 'object');
    html = _stripSelfClosing(html, 'embed');
    html = _stripTag(html, 'svg');

    // 6. Remove elements with display:none (tracking pixels, hidden content)
    html = html.replaceAll(
      RegExp(
        r'<[^>]+style\s*=\s*"[^"]*display\s*:\s*none[^"]*"[^>]*>[\s\S]*?</[^>]+>',
        caseSensitive: false,
      ),
      '',
    );
    html = html.replaceAll(
      RegExp(
        r"<[^>]+style\s*=\s*'[^']*display\s*:\s*none[^']*'[^>]*>[\s\S]*?</[^>]+>",
        caseSensitive: false,
      ),
      '',
    );

    // 7. Extract <body> content from full HTML documents
    final bodyMatch = RegExp(
      r'<body[^>]*>([\s\S]*)</body>',
      caseSensitive: false,
    ).firstMatch(html);
    if (bodyMatch != null) {
      html = bodyMatch.group(1)!;
    }

    // 8. Remove leftover <html>, <body>, <!DOCTYPE> tags
    html = html.replaceAll(RegExp(r'</?html[^>]*>', caseSensitive: false), '');
    html = html.replaceAll(RegExp(r'</?body[^>]*>', caseSensitive: false), '');
    html = html.replaceAll(RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false), '');

    // 9. Remove HTML comments
    html = html.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

    // 10. Collapse excessive blank lines (keep max 2 <br> in a row)
    html = html.replaceAll(RegExp(r'(<br\s*/?\s*>\s*){3,}', caseSensitive: false), '<br><br>');

    return html.trim();
  }

  /// Strip a paired tag and everything between its open and close.
  static String _stripTag(String html, String tag) {
    return html.replaceAll(
      RegExp('<$tag\\b[^>]*>[\\s\\S]*?</$tag>', caseSensitive: false),
      '',
    );
  }

  /// Strip a self-closing / void tag like `<img …>` or `<img … />`.
  static String _stripSelfClosing(String html, String tag) {
    return html.replaceAll(
      RegExp('<$tag\\b[^>]*/?>',caseSensitive: false),
      '',
    );
  }

  // ── Plain text → HTML ──────────────────────────────────────────────────────

  /// Convert plain text to HTML with clickable links and proper line breaks.
  static String plainTextToHtml(String text) {
    // 1. Escape HTML entities first (so regex can work on clean text)
    String html = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    // 2. Linkify https?:// URLs
    html = html.replaceAllMapped(
      RegExp(r'(https?://[^\s&<>"]+)', caseSensitive: false),
      (m) {
        String url = m.group(0)!;
        // Trim trailing punctuation that's typically not part of the URL
        String trailing = '';
        while (url.isNotEmpty && '.,;:!?)'.contains(url[url.length - 1])) {
          trailing = url[url.length - 1] + trailing;
          url = url.substring(0, url.length - 1);
        }
        // Decode &amp; back to & for the href attribute
        final href = url.replaceAll('&amp;', '&');
        return '<a href="$href">$url</a>$trailing';
      },
    );

    // 3. Line breaks
    html = html.replaceAll('\n', '<br>');

    return '<div style="word-wrap:break-word;">$html</div>';
  }

  // ── Public entry point ─────────────────────────────────────────────────────

  /// Detect whether [body] is HTML or plain text and prepare it for rendering.
  static String prepareForRendering(String body) {
    if (body.trim().isEmpty) return '';
    return isHtml(body) ? sanitizeEmailHtml(body) : plainTextToHtml(body);
  }
}
