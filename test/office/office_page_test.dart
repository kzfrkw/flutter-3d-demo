import 'package:flutter/material.dart';
import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/office_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_office_scene_view.dart';

void main() {
  testWidgets('見出しに「ダミーデータ」があり、描画に data が渡る', (tester) async {
    final fake = FakeOfficeSceneView();
    await tester.pumpWidget(
      MaterialApp(
        home: OfficePage(view: fake, data: dummyOfficeData),
      ),
    );

    expect(find.textContaining('ダミーデータ'), findsOneWidget);
    expect(find.byKey(FakeOfficeSceneView.viewKey), findsOneWidget);
    expect(identical(fake.received, dummyOfficeData), isTrue);
  });

  testWidgets('別の OfficeData を渡すとそれが描画に届く', (tester) async {
    final fake = FakeOfficeSceneView();
    final other = OfficeData(
      floorSize: const FloorSize(4, 4),
      cycleLength: const Duration(minutes: 1),
      rooms: const [],
      bookings: const [],
      seats: const [],
      people: const [],
      waypoints: const [],
      routes: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OfficePage(view: fake, data: other),
      ),
    );

    expect(identical(fake.received, other), isTrue);
  });
}
