import 'package:flutter/material.dart';

/// Pushes a full-screen page on the root navigator (above the bottom bar).
Future<T?> pushPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
}

/// Replaces the current page.
Future<T?> replacePage<T>(BuildContext context, Widget page) {
  return Navigator.of(
    context,
  ).pushReplacement<T, Object?>(MaterialPageRoute(builder: (_) => page));
}
