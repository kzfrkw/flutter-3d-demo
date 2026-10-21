import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/list/office_list_panel.dart';
import 'package:flutter_3d_demo/office/people/people_simulation.dart';
import 'package:flutter_3d_demo/office/status/office_status.dart';
import 'package:flutter_3d_demo/office/status/virtual_clock.dart';
import 'package:flutter_test/flutter_test.dart';

final data = dummyOfficeData;

Finder item(EntityKind k, String id) =>
    find.byKey(ValueKey('list-item-${k.name}-$id'));

class Harness {
  Harness(this.clock, this.selected, this.closed);
  final VirtualClock clock;
  final List<EntityRef> selected;
  final List<int> closed;
}

Future<Harness> pumpList(
  WidgetTester tester, {
  PeopleSimulation? sim,
  EntityRef? selectedRef,
  VirtualClock? clock,
}) async {
  tester.view.physicalSize = const Size(400, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = clock ?? VirtualClock(cycleLength: data.cycleLength);
  final h = Harness(c, [], []);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OfficeListPanel(
          data: data,
          time: c,
          lookup: personLookupOf(sim),
          selected: selectedRef,
          onSelect: h.selected.add,
          onClose: () => h.closed.add(1),
        ),
      ),
    ),
  );
  await tester.pump();
  return h;
}

void main() {
  testWidgets('見出し 3 つと全件(AC9)', (tester) async {
    await pumpList(tester);
    expect(find.byKey(const Key('list-panel-title')), findsOneWidget);
    expect(find.byKey(const Key('list-heading-room')), findsOneWidget);
    expect(find.byKey(const Key('list-heading-seat')), findsOneWidget);
    expect(find.byKey(const Key('list-heading-person')), findsOneWidget);
    for (final r in data.rooms) {
      expect(item(EntityKind.room, r.id), findsOneWidget);
    }
    for (final s in data.seats) {
      expect(item(EntityKind.seat, s.id), findsOneWidget);
    }
    for (final p in data.people) {
      expect(item(EntityKind.person, p.id), findsOneWidget);
    }
  });

  testWidgets('各行に名前と状態の文言(定員も)(AC9)', (tester) async {
    await pumpList(tester);
    Finder inRow(EntityKind k, String id, String text) => find.descendant(
      of: item(k, id),
      matching: find.text(text),
    );
    for (final r in data.rooms) {
      final st = roomStatusAt(data, r, Duration.zero);
      expect(inRow(EntityKind.room, r.id, r.name), findsOneWidget);
      expect(inRow(EntityKind.room, r.id, st.occupancy.label), findsOneWidget);
      expect(inRow(EntityKind.room, r.id, '定員 ${r.capacity}名'), findsOneWidget);
    }
    for (final s in data.seats) {
      final st = seatStatusAt(data, s, personLookupOf(null));
      expect(inRow(EntityKind.seat, s.id, s.label), findsOneWidget);
      expect(inRow(EntityKind.seat, s.id, st.presence.label), findsOneWidget);
    }
    expect(
      inRow(EntityKind.seat, 'seat-4', SeatPresence.unassigned.label),
      findsOneWidget,
    );
    for (final p in data.people) {
      expect(inRow(EntityKind.person, p.id, p.displayName), findsOneWidget);
      expect(
        inRow(EntityKind.person, p.id, PersonActivity.stopped.label),
        findsOneWidget,
      );
    }
  });

  testWidgets('仮想時刻を進めると会議室の状態が roomStatusAt と一致して切り替わる(AC10)', (tester) async {
    final h = await pumpList(tester);
    final room = data.roomById('room-a')!;
    Finder label(RoomOccupancy o) => find.descendant(
      of: item(EntityKind.room, 'room-a'),
      matching: find.text(o.label),
    );
    expect(roomStatusAt(data, room, h.clock.value).occupancy, RoomOccupancy.free);
    expect(label(RoomOccupancy.free), findsOneWidget);
    h.clock.advance(const Duration(seconds: 30));
    await tester.pump();
    expect(
      roomStatusAt(data, room, h.clock.value).occupancy,
      RoomOccupancy.occupied,
    );
    expect(label(RoomOccupancy.occupied), findsOneWidget);
    expect(label(RoomOccupancy.free), findsNothing);
  });

  testWidgets('席・人の状態は渡した lookup を読む(AC10)', (tester) async {
    final sim = PeopleSimulation(data);
    await pumpList(tester, sim: sim);
    final personRow = item(EntityKind.person, 'person-a');
    expect(
      find.descendant(
        of: personRow,
        matching: find.text(PersonActivity.stopped.label),
      ),
      findsOneWidget,
    );
    sim.step(0.1);
    // 親が再 build して lookup を読み直す想定。ここでは同じ lookup を再度渡す。
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfficeListPanel(
            data: data,
            time: ValueNotifier(Duration.zero),
            lookup: personLookupOf(sim),
            selected: null,
            onSelect: (_) {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: item(EntityKind.person, 'person-a'),
        matching: find.text(PersonActivity.walking.label),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Semantics ラベルに種別・名前・状態(AC13)', (tester) async {
    await pumpList(tester);
    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel('会議室 会議室B 使用中 定員4名'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('席 A-1 離席'), findsOneWidget);
    expect(find.bySemanticsLabel('人 メンバーA 停止中'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('タップで onSelect が正しい参照で呼ばれる', (tester) async {
    final h = await pumpList(tester);
    await tester.tap(item(EntityKind.room, 'room-b'));
    await tester.tap(item(EntityKind.seat, 'seat-1'));
    await tester.tap(item(EntityKind.person, 'person-a'));
    expect(h.selected, [
      const EntityRef(EntityKind.room, 'room-b'),
      const EntityRef(EntityKind.seat, 'seat-1'),
      const EntityRef(EntityKind.person, 'person-a'),
    ]);
  });

  testWidgets('[×] で onClose', (tester) async {
    final h = await pumpList(tester);
    await tester.tap(find.byTooltip('閉じる'));
    expect(h.closed, hasLength(1));
  });

  testWidgets('初期フォーカスは最初の行。Tab で次の行、Enter / Space で選択(AC12)', (tester) async {
    final h = await pumpList(tester);
    final first = data.rooms.first;
    bool inside(Finder f) {
      final ctx = FocusManager.instance.primaryFocus?.context;
      if (ctx == null) return false;
      final key = f.evaluate().single.widget.key;
      var found = false;
      ctx.visitAncestorElements((e) {
        if (e.widget.key == key) found = true;
        return !found;
      });
      return found;
    }

    expect(inside(item(EntityKind.room, first.id)), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(h.selected, [EntityRef(EntityKind.room, first.id)]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(h.selected.last, EntityRef(EntityKind.room, data.rooms[1].id));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(h.selected.last, EntityRef(EntityKind.room, data.rooms[2].id));
  });
}
