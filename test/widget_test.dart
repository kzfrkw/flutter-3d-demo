import 'package:flutter/material.dart';
import 'package:flutter_3d_demo/check/check_page.dart';
import 'package:flutter_3d_demo/check/check_result.dart';
import 'package:flutter_3d_demo/check/scene_probe.dart';
import 'package:flutter_3d_demo/main.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopProbe implements SceneProbe {
  @override
  Widget buildView(BuildContext context, CheckReporter report) =>
      const SizedBox.shrink();
}

void main() {
  testWidgets('check なしでは仮のホームを表示する', (tester) async {
    await tester.pumpWidget(App(checkMode: false, probe: _NoopProbe()));

    expect(find.text('準備中'), findsOneWidget);
    expect(find.byType(CheckPage), findsNothing);
  });

  testWidgets('check ありでは s0-check を表示する', (tester) async {
    await tester.pumpWidget(App(checkMode: true, probe: _NoopProbe()));

    expect(find.byType(CheckPage), findsOneWidget);
    expect(find.text('準備中'), findsNothing);
    expect(CheckItem.values, hasLength(3));
  });
}
