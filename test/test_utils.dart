import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuition_app/core/theme/app_theme.dart';
import 'package:tuition_app/data/app_scope.dart';
import 'package:tuition_app/data/app_state.dart';
import 'package:tuition_app/data/repositories/messaging_repository.dart';
import 'package:tuition_app/shared/models/models.dart';

/// Completes every dispatch synchronously. Phones ending in 0 fail on the
/// first attempt so retry behaviour can be asserted.
class InstantTransport implements MessageTransport {
  @override
  void dispatch(
    List<MessageRecipient> recipients, {
    required VoidCallback onUpdate,
    required void Function(MessageRecipient r) onSettled,
  }) {
    for (final r in recipients) {
      r.attempts += 1;
      final fail = r.attempts == 1 && r.phone.endsWith('0');
      r.status = fail ? DeliveryStatus.failed : DeliveryStatus.delivered;
      onSettled(r);
    }
    onUpdate();
  }

  @override
  void dispose() {}
}

AppState testState() => AppState(
  now: DateTime(2026, 10, 21, 18, 30),
  transport: InstantTransport(),
);

/// Small Android phone (360×640 dp).
Future<void> setPhoneSize(
  WidgetTester tester, {
  Size size = const Size(360, 640),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Widget host(AppState state, Widget child, {double textScale = 1.0}) => AppScope(
  state: state,
  child: MaterialApp(
    theme: AppTheme.dark(),
    builder: (context, w) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: w!,
    ),
    home: child,
  ),
);
