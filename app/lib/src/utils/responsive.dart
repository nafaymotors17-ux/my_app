import 'package:flutter/material.dart';

/// Responsive breakpoints for the app.
/// - [compact]: phones portrait (< 600dp)
/// - [medium]: phones landscape, tablets portrait (600–840dp)
/// - [expanded]: tablets landscape, desktops (> 840dp)
class ResponsiveBreakpoints {
  static const double compact = 600;
  static const double medium = 840;

  /// Returns true if the screen is wide enough for master-detail layout.
  static bool isWideScreen(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= medium;
  }

  /// Returns true if the screen is at least medium (tablet portrait).
  static bool isMediumOrWider(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= compact;
  }

  /// Returns the current layout type.
  static LayoutType getLayoutType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= medium) return LayoutType.expanded;
    if (width >= compact) return LayoutType.medium;
    return LayoutType.compact;
  }
}

enum LayoutType { compact, medium, expanded }
