import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/office_page.dart';
import 'package:flutter_3d_demo/office/people/people_simulation.dart';
import 'package:flutter_3d_demo/office/status/office_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_office_scene_view.dart';

const roomB = EntityRef(EntityKind.room, 'room-b');
const roomA = EntityRef(EntityKind.room, 'room-a');
const seat1 = EntityRef(EntityKind.seat, 'seat-1');
const personA = EntityRef(EntityKind.person, 'person-a');

Future<FakeOfficeSceneView> pumpPage(
  WidgetTester tester, {
  Size size = const Size(1000, 700),
  OfficeData? data,
  PeopleSimulation? simulation,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = FakeOfficeSceneView();
  await tester.pumpWidget(
    MaterialApp(
      home: OfficePage(
        view: fake,
        data: data ?? dummyOfficeData,
        simulation: simulation,
      ),
    ),
  );
  return fake;
}

final side = find.byKey(const Key('info-card-side'));
final sheet = find.byKey(const Key('info-card-sheet'));

void main() {
  testWidgets('見出しに「ダミーデータ」があり、描画に data が渡る', (tester) async {
    final fake = await pumpPage(tester);
    expect(find.textContaining('ダミーデータ'), findsOneWidget);
    expect(find.byKey(FakeOfficeSceneView.viewKey), findsOneWidget);
    expect(identical(fake.received, dummyOfficeData), isTrue);
    expect(fake.receivedOnPick, isNotNull);
    expect(fake.receivedVirtualTime, isNotNull);
    expect(fake.receivedVirtualTime!.value, Duration.zero);
    expect(side, findsNothing);
    expect(sheet, findsNothing);
  });

  testWidgets('別の OfficeData を渡すとそれが描画に届く', (tester) async {
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
    final fake = await pumpPage(tester, data: other);
    expect(identical(fake.received, other), isTrue);
  });

  testWidgets('会議室を選ぶとカードが出る', (tester) async {
    final fake = await pumpPage(tester);
    fake.pick(roomB);
    await tester.pump();
    expect(side, findsOneWidget);
    expect(
      find.descendant(of: side, matching: find.text('会議室B')),
      findsOneWidget,
    );
    expect(find.text(RoomOccupancy.occupied.label), findsOneWidget);
    expect(find.text('4名'), findsOneWidget);
    expect(find.text('1on1'), findsOneWidget);
    expect(find.text('企画ミーティング'), findsOneWidget);
  });

  testWidgets('席・人を選ぶとそれぞれの項目が出る', (tester) async {
    final fake = await pumpPage(tester);
    fake.pick(seat1);
    await tester.pump();
    expect(find.text('A-1'), findsOneWidget);
    expect(find.text('メンバーA'), findsOneWidget);
    expect(find.text(SeatPresence.away.label), findsOneWidget);
    fake.pick(personA);
    await tester.pump();
    expect(find.text('エンジニア'), findsOneWidget);
    expect(find.text(PersonActivity.stopped.label), findsOneWidget);
  });

  testWidgets('別の対象を選ぶと内容が切り替わる', (tester) async {
    final fake = await pumpPage(tester);
    fake.pick(roomB);
    await tester.pump();
    fake.pick(roomA);
    await tester.pump();
    expect(
      find.descendant(of: side, matching: find.text('会議室A')),
      findsOneWidget,
    );
    expect(find.text('会議室B'), findsNothing);
    expect(find.text(RoomOccupancy.free.label), findsOneWidget);
    // 同じ対象をもう一度押しても閉じない
    fake.pick(roomA);
    await tester.pump();
    expect(side, findsOneWidget);
  });

  testWidgets('× で閉じる', (tester) async {
    final fake = await pumpPage(tester);
    fake.pick(roomB);
    await tester.pump();
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pump();
    expect(side, findsNothing);
  });

  testWidgets('Esc で閉じる', (tester) async {
    final fake = await pumpPage(tester);
    fake.pick(roomB);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(side, findsNothing);
  });

  testWidgets('× を押したあとでも Esc で閉じる(フォーカスが移っても)', (tester) async {
    final fake = await pumpPage(tester);
    fake.pick(roomB);
    await tester.pump();
    fake.pick(roomA);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(side, findsNothing);
  });

  testWidgets('背景(null)の選択で閉じる', (tester) async {
    final fake = await pumpPage(tester);
    fake.pick(roomB);
    await tester.pump();
    fake.pick(null);
    await tester.pump();
    expect(side, findsNothing);
  });

  testWidgets('データに無い id を選んでもカードは出ない', (tester) async {
    final fake = await pumpPage(tester);
    fake.pick(const EntityRef(EntityKind.room, 'room-zzz'));
    await tester.pump();
    expect(side, findsNothing);
  });

  testWidgets('選択中の対象がデータから無くなったら閉じる', (tester) async {
    final fake = FakeOfficeSceneView();
    Widget app(OfficeData d) => MaterialApp(
      home: OfficePage(view: fake, data: d),
    );
    await tester.pumpWidget(app(dummyOfficeData));
    fake.pick(roomB);
    await tester.pump();
    expect(side, findsOneWidget);
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
    await tester.pumpWidget(app(other));
    expect(side, findsNothing);
  });

  testWidgets('広い幅は右パネル、3D ビューは残る', (tester) async {
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = FakeOfficeSceneView();
    await tester.pumpWidget(
      MaterialApp(
        home: OfficePage(view: fake, data: dummyOfficeData),
      ),
    );
    fake.pick(roomB);
    await tester.pump();
    expect(side, findsOneWidget);
    expect(sheet, findsNothing);
    expect(find.byKey(FakeOfficeSceneView.viewKey), findsOneWidget);
    // 3D ビューの大きさは変わらない(重ね表示)
    final viewSize = tester.getSize(find.byKey(FakeOfficeSceneView.viewKey));
    expect(viewSize.width, 800);
    final card = tester.getRect(side);
    expect(card.right, 800);
    expect(card.width, lessThan(400));
  });

  testWidgets('幅 600 は右パネル、599 は下シート(高さ約 40%)', (tester) async {
    final fake = await pumpPage(tester, size: const Size(600, 800));
    fake.pick(roomB);
    await tester.pump();
    expect(side, findsOneWidget);

    final fake2 = await pumpPage(tester, size: const Size(599, 800));
    fake2.pick(roomB);
    await tester.pump();
    expect(sheet, findsOneWidget);
    expect(side, findsNothing);
    final bodyHeight = tester
        .getSize(find.byKey(FakeOfficeSceneView.viewKey))
        .height;
    final r = tester.getRect(sheet);
    expect(r.height, closeTo(bodyHeight * 0.4, 0.5));
    expect(r.width, 599);
    expect(r.bottom, closeTo(800, 0.5));
    expect(find.byKey(FakeOfficeSceneView.viewKey), findsOneWidget);
  });

  testWidgets('下シートも × で閉じられる', (tester) async {
    final fake = await pumpPage(tester, size: const Size(390, 800));
    fake.pick(roomB);
    await tester.pump();
    expect(sheet, findsOneWidget);
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pump();
    expect(sheet, findsNothing);
  });

  testWidgets('カードの「現在の行動」は渡した PeopleSimulation を読む', (tester) async {
    final sim = PeopleSimulation(dummyOfficeData);
    final fake = await pumpPage(tester, simulation: sim);
    fake.pick(personA);
    await tester.pump();
    expect(find.text(PersonActivity.stopped.label), findsOneWidget);
    sim.step(0.1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(PersonActivity.walking.label), findsOneWidget);
    // Timer を止める
    fake.pick(null);
    await tester.pump();
  });
}
