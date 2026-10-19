import 'package:flutter/material.dart';
import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/scene/scene_labels.dart';
import 'package:flutter_3d_demo/office/status/office_status.dart';
import 'package:flutter_3d_demo/office/status_style.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('PersonTag は表示名を出す', (tester) async {
    await tester.pumpWidget(host(const PersonTag(name: 'メンバーA')));
    expect(find.text('メンバーA'), findsOneWidget);
  });

  testWidgets('RoomPanel は会議室名と状態の文言を出す', (tester) async {
    final b = roomStatusAt(
      dummyOfficeData,
      dummyOfficeData.roomById('room-b')!,
      Duration.zero,
    );
    await tester.pumpWidget(host(RoomPanel(status: b)));
    expect(find.text('会議室B'), findsOneWidget);
    expect(find.text(RoomOccupancy.occupied.label), findsOneWidget);

    final a = roomStatusAt(
      dummyOfficeData,
      dummyOfficeData.roomById('room-a')!,
      Duration.zero,
    );
    await tester.pumpWidget(host(RoomPanel(status: a)));
    expect(find.text('会議室A'), findsOneWidget);
    expect(find.text(RoomOccupancy.free.label), findsOneWidget);
  });

  testWidgets('RoomPanel の背景色は状態で変わる', (tester) async {
    Future<Color?> bgOf(String id) async {
      final st = roomStatusAt(
        dummyOfficeData,
        dummyOfficeData.roomById(id)!,
        Duration.zero,
      );
      await tester.pumpWidget(host(RoomPanel(status: st)));
      final box = tester.widget<DecoratedBox>(find.byKey(RoomPanel.boxKey));
      return (box.decoration as BoxDecoration).color;
    }

    final occupied = await bgOf('room-b');
    final free = await bgOf('room-a');
    expect(occupied, roomOccupancyStyle(RoomOccupancy.occupied).background);
    expect(free, roomOccupancyStyle(RoomOccupancy.free).background);
    expect(occupied, isNot(free));
  });

  test('状態の色は文字と背景のコントラスト比 4.5 以上', () {
    for (final o in RoomOccupancy.values) {
      final s = roomOccupancyStyle(o);
      expect(contrast(s.foreground, s.background), greaterThanOrEqualTo(4.5));
    }
    expect(
      contrast(personTagForeground, personTagBackground),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('2 状態は文言・アイコン・明るさが違う(色だけに頼らない)', () {
    final f = roomOccupancyStyle(RoomOccupancy.free);
    final o = roomOccupancyStyle(RoomOccupancy.occupied);
    expect(f.icon, isNot(o.icon));
    expect(
      (f.background.computeLuminance() - o.background.computeLuminance()).abs(),
      greaterThan(0.3),
    );
  });
}
