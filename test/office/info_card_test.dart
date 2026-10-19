import 'package:flutter/material.dart';
import 'package:flutter_3d_demo/office/card/info_card.dart';
import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/status/office_status.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(TargetStatus st, {VoidCallback? onClose}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 360,
      height: 700,
      child: InfoCard(status: st, onClose: onClose ?? () {}),
    ),
  ),
);

RoomStatus room(String id, int sec) => roomStatusAt(
  dummyOfficeData,
  dummyOfficeData.roomById(id)!,
  Duration(seconds: sec),
);

void main() {
  testWidgets('会議室(使用中): 名前・状態・定員・現在/次の予定', (tester) async {
    await tester.pumpWidget(host(room('room-b', 0)));
    expect(find.text('会議室B'), findsOneWidget);
    expect(find.text(RoomOccupancy.occupied.label), findsOneWidget);
    expect(find.text('4名'), findsOneWidget);
    expect(find.text('1on1'), findsOneWidget);
    expect(find.text('0:00〜1:00'), findsOneWidget);
    expect(find.text('企画ミーティング'), findsOneWidget);
    expect(find.text('1:45〜2:45'), findsOneWidget);
  });

  testWidgets('会議室(空き): 現在の予定は「なし」、次周は「次周 ・」', (tester) async {
    await tester.pumpWidget(host(room('room-a', 220)));
    expect(find.text(RoomOccupancy.free.label), findsOneWidget);
    expect(find.text('なし'), findsOneWidget);
    expect(find.text('週次定例'), findsOneWidget);
    expect(find.text('次周 ・ 0:30〜1:30'), findsOneWidget);
  });

  testWidgets('予定が無い会議室は「予定なし」', (tester) async {
    final data = OfficeData(
      floorSize: const FloorSize(10, 10),
      cycleLength: const Duration(minutes: 1),
      rooms: const [
        Room(
          id: 'r',
          name: '固有の部屋',
          capacity: 3,
          position: FloorPoint(0, 0),
          size: FloorSize(3, 3),
          door: RoomDoor(side: RoomSide.south, width: 1),
          entranceWaypointId: 'w',
        ),
      ],
      bookings: const [],
      seats: const [],
      people: const [],
      waypoints: const [],
      routes: const [],
    );
    await tester.pumpWidget(
      host(roomStatusAt(data, data.rooms.first, Duration.zero)),
    );
    expect(find.text('固有の部屋'), findsOneWidget);
    expect(find.text('3名'), findsOneWidget);
    expect(find.text('予定なし'), findsOneWidget);
  });

  testWidgets('席: ラベル・使用者・離席 / 使用者なしは「未割り当て」', (tester) async {
    final seat1 = seatStatusAt(
      dummyOfficeData,
      dummyOfficeData.seatById('seat-1')!,
      (_) => null,
    );
    await tester.pumpWidget(host(seat1));
    expect(find.text('A-1'), findsOneWidget);
    expect(find.text('メンバーA'), findsOneWidget);
    expect(find.text(SeatPresence.away.label), findsOneWidget);

    final seat4 = seatStatusAt(
      dummyOfficeData,
      dummyOfficeData.seatById('seat-4')!,
      (_) => null,
    );
    await tester.pumpWidget(host(seat4));
    expect(find.text('A-4'), findsOneWidget);
    expect(find.text(unassignedOwnerLabel), findsOneWidget);
    expect(find.text(SeatPresence.unassigned.label), findsOneWidget);
  });

  testWidgets('人: 名前・役割・現在の行動', (tester) async {
    final st = personStatusAt(
      dummyOfficeData.personById('person-a')!,
      (_) => (position: const FloorPoint(0, 0), isWalking: true),
    );
    await tester.pumpWidget(host(st));
    expect(find.text('メンバーA'), findsWidgets);
    expect(find.text('エンジニア'), findsOneWidget);
    expect(find.text(PersonActivity.walking.label), findsOneWidget);
  });

  testWidgets('表示は OfficeData 由来(固有の名前がそのまま出る)', (tester) async {
    const p = Person(
      id: 'p-x',
      displayName: '固有ネーム',
      role: '固有ロール',
      model: 'capsule',
      speed: 1,
    );
    await tester.pumpWidget(host(personStatusAt(p, (_) => null)));
    expect(find.text('固有ネーム'), findsWidgets);
    expect(find.text('固有ロール'), findsOneWidget);
    expect(find.text(PersonActivity.stopped.label), findsOneWidget);
  });

  testWidgets('× で onClose が呼ばれる(ツールチップ「閉じる」)', (tester) async {
    var closed = 0;
    await tester.pumpWidget(host(room('room-b', 0), onClose: () => closed++));
    expect(find.byTooltip('閉じる'), findsOneWidget);
    await tester.tap(find.byTooltip('閉じる'));
    expect(closed, 1);
  });
}
