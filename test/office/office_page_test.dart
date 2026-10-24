import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/guide/guide_memory.dart';
import 'package:flutter_3d_demo/office/office_page.dart';
import 'package:flutter_3d_demo/office/people/people_simulation.dart';
import 'package:flutter_3d_demo/office/status/office_status.dart';
import 'package:flutter_3d_demo/office/status/virtual_clock.dart';
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
  ValueListenable<Duration>? virtualTime,
  GuideMemory? guideMemory,
  Future<String> Function()? notesLoader,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = FakeOfficeSceneView();
  // 前の OfficePage の State を引き継がない(作り直しを再現する)。
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      home: OfficePage(
        view: fake,
        data: data ?? dummyOfficeData,
        simulation: simulation,
        virtualTime: virtualTime,
        // 既定は案内を閉じた記録つき(既存の操作系テストが案内なしで成り立つ)。
        guideMemory: guideMemory ?? GuideMemory(dismissed: true),
        notesLoader: notesLoader,
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
    // 下シートは下部ツールバーの上に付く(重ならない)
    expect(
      r.bottom,
      closeTo(tester.getRect(find.byKey(const Key('bottom-toolbar'))).top, 0.5),
    );
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

  group('視点リセット', () {
    final button = find.byKey(const Key('reset-view-button'));

    for (final size in [const Size(1000, 700), const Size(599, 800)]) {
      testWidgets('${size.width.toInt()}px: 文言つきのボタンが 1 つ。押すと描画にリセットが届く', (
        tester,
      ) async {
        final fake = await pumpPage(tester, size: size);
        expect(button, findsOneWidget);
        expect(
          find.descendant(of: button, matching: find.text('視点リセット')),
          findsOneWidget,
        );
        final signal = fake.receivedResetView;
        expect(signal, isNotNull);
        var n = 0;
        signal!.addListener(() => n++);
        await tester.tap(button);
        await tester.pump();
        expect(n, 1);
        await tester.tap(button);
        expect(n, 2);
      });
    }

    testWidgets('スマホ幅でカードを開いても下部ツールバーのボタンが隠れず押せる(AC8)', (tester) async {
      final fake = await pumpPage(tester, size: const Size(390, 800));
      fake.pick(roomA);
      await tester.pump();
      expect(sheet, findsOneWidget);
      expect(button, findsOneWidget);
      final toolbar = tester.getRect(find.byKey(const Key('bottom-toolbar')));
      expect(tester.getRect(sheet).bottom, lessThanOrEqualTo(toolbar.top));
      var n = 0;
      fake.receivedResetView!.addListener(() => n++);
      await tester.tap(button);
      expect(n, 1);
    });
  });

  group('仮想時刻とカード', () {
    testWidgets('時刻が進むとカードの会議室の状態が roomStatusAt と一致して切り替わる', (tester) async {
      final clock = VirtualClock(cycleLength: dummyOfficeData.cycleLength);
      final fake = await pumpPage(tester, virtualTime: clock);
      expect(identical(fake.receivedVirtualTime, clock), isTrue);
      fake.pick(roomA);
      await tester.pump();
      final room = dummyOfficeData.roomById('room-a')!;
      expect(
        roomStatusAt(dummyOfficeData, room, clock.value).occupancy,
        RoomOccupancy.free,
      );
      expect(
        find.descendant(
          of: side,
          matching: find.text(RoomOccupancy.free.label),
        ),
        findsOneWidget,
      );
      clock.advance(const Duration(seconds: 30));
      await tester.pump();
      expect(
        roomStatusAt(dummyOfficeData, room, clock.value).occupancy,
        RoomOccupancy.occupied,
      );
      expect(
        find.descendant(
          of: side,
          matching: find.text(RoomOccupancy.occupied.label),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: side,
          matching: find.text(RoomOccupancy.free.label),
        ),
        findsNothing,
      );
      expect(find.textContaining('週次定例'), findsWidgets);
      clock.advance(const Duration(seconds: 70));
      await tester.pump();
      expect(find.textContaining('週次定例'), findsNothing);
      tester.binding.scheduleFrame();
    });
  });

  group('ツールバー', () {
    testWidgets('PC 幅: AppBar に 視点リセット・一覧・記録・ヘルプ(文言+アイコン)。昼夜は無い(AC6)', (
      tester,
    ) async {
      await pumpPage(tester, size: const Size(1000, 700));
      for (final k in [
        'reset-view-button',
        'list-button',
        'notes-button',
        'help-button',
      ]) {
        final b = find.byKey(Key(k));
        expect(b, findsOneWidget, reason: k);
        expect(
          find.descendant(of: find.byType(AppBar), matching: b),
          findsOneWidget,
        );
        expect(
          find.descendant(of: b, matching: find.byType(Icon)),
          findsOneWidget,
        );
      }
      expect(find.text('視点リセット'), findsOneWidget);
      expect(find.text('一覧'), findsOneWidget);
      expect(find.text('ヘルプ'), findsOneWidget);
      expect(find.text('昼夜'), findsNothing);
      expect(find.text('記録'), findsOneWidget);
      expect(find.text('開発記録'), findsNothing);
      expect(find.byKey(const Key('bottom-toolbar')), findsNothing);
      expect(find.byKey(const Key('menu-button')), findsNothing);
    });

    for (final w in [600.0, 700.0]) {
      testWidgets('幅 ${w.toInt()} で AppBar があふれない', (tester) async {
        await pumpPage(tester, size: Size(w, 800));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('help-button')), findsOneWidget);
        expect(find.textContaining('ダミーデータ'), findsOneWidget);
      });
    }

    testWidgets('スマホ幅: 下部に 視点リセット・一覧、≡ メニューにヘルプ(AC7)', (tester) async {
      final fake = await pumpPage(tester, size: const Size(390, 800));
      final bar = find.byKey(const Key('bottom-toolbar'));
      expect(bar, findsOneWidget);
      expect(
        find.descendant(of: bar, matching: find.text('視点リセット')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('一覧')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('reset-view-button')), findsOneWidget);
      expect(find.byKey(const Key('help-button')), findsNothing);
      expect(find.byKey(const Key('menu-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu-button')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('menu-help')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('menu-help')),
          matching: find.text('ヘルプ'),
        ),
        findsOneWidget,
      );
      expect(fake.receivedResetView, isNotNull);
    });
  });

  group('操作案内', () {
    final guide = find.byKey(const Key('guide-start-button'));

    testWidgets('初回は自動で出て、はじめる / × / Esc / 外側クリックで閉じる(AC1)', (tester) async {
      Future<void> fresh() async {
        await pumpPage(tester, guideMemory: GuideMemory());
        expect(guide, findsOneWidget);
      }

      await fresh();
      await tester.tap(guide);
      await tester.pump();
      expect(guide, findsNothing);

      await fresh();
      await tester.tap(find.byKey(const Key('guide-close-button')));
      await tester.pump();
      expect(guide, findsNothing);

      await fresh();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(guide, findsNothing);

      await fresh();
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(guide, findsNothing);
    });

    testWidgets('PC: [ヘルプ] で再表示できる(AC2)', (tester) async {
      await pumpPage(tester, guideMemory: GuideMemory());
      await tester.tap(guide);
      await tester.pump();
      await tester.tap(find.byKey(const Key('help-button')));
      await tester.pump();
      expect(guide, findsOneWidget);
    });

    testWidgets('スマホ: ≡ → ヘルプ で再表示できる(AC2)', (tester) async {
      await pumpPage(
        tester,
        size: const Size(390, 800),
        guideMemory: GuideMemory(),
      );
      await tester.tap(guide);
      await tester.pump();
      expect(guide, findsNothing);
      await tester.tap(find.byKey(const Key('menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-help')));
      await tester.pumpAndSettle();
      expect(guide, findsOneWidget);
    });

    testWidgets('閉じた記録は渡した GuideMemory に残り、作り直しても出ない(AC3)', (tester) async {
      final memory = GuideMemory();
      await pumpPage(tester, guideMemory: memory);
      expect(memory.dismissed, isFalse);
      await tester.tap(guide);
      await tester.pump();
      expect(memory.dismissed, isTrue);
      await pumpPage(tester, guideMemory: memory);
      expect(guide, findsNothing);
      // 別の記録なら出る
      await pumpPage(tester, guideMemory: GuideMemory());
      expect(guide, findsOneWidget);
    });

    testWidgets('記録を渡さなければ毎回出る(ページごとに独立)', (tester) async {
      final fake = FakeOfficeSceneView();
      await tester.pumpWidget(
        MaterialApp(
          home: OfficePage(view: fake, data: dummyOfficeData),
        ),
      );
      expect(guide, findsOneWidget);
    });
  });

  group('一覧', () {
    final panel = find.byKey(const Key('list-panel-side'));
    final listSheet = find.byKey(const Key('list-sheet'));
    final title = find.byKey(const Key('list-panel-title'));
    final listButton = find.byKey(const Key('list-button'));

    testWidgets('[一覧] で開閉し、全件が出る(AC9)', (tester) async {
      await pumpPage(tester);
      expect(title, findsNothing);
      await tester.tap(listButton);
      await tester.pump();
      expect(panel, findsOneWidget);
      expect(title, findsOneWidget);
      expect(
        find.byKey(const ValueKey('list-item-room-room-a')),
        findsOneWidget,
      );
      await tester.tap(listButton);
      await tester.pump();
      expect(title, findsNothing);
    });

    testWidgets('スマホ幅は下シート。下部ツールバーの上に付く', (tester) async {
      await pumpPage(tester, size: const Size(390, 800));
      await tester.tap(find.byKey(const Key('list-button')));
      await tester.pump();
      expect(listSheet, findsOneWidget);
      expect(panel, findsNothing);
      expect(
        tester.getRect(listSheet).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const Key('bottom-toolbar'))).top + 0.5,
        ),
      );
      // ツールバーは押せる
      await tester.tap(find.byKey(const Key('reset-view-button')));
    });

    for (final size in [const Size(1000, 700), const Size(1280, 800)]) {
      testWidgets('${size.width.toInt()}px: 項目を選ぶとカードが開く(AC11)', (
        tester,
      ) async {
        await pumpPage(tester, size: size);
        for (final (key, name) in [
          ('list-item-room-room-b', '会議室B'),
          ('list-item-seat-seat-1', 'A-1'),
          ('list-item-person-person-a', 'メンバーA'),
        ]) {
          if (title.evaluate().isEmpty) {
            await tester.tap(listButton);
            await tester.pump();
          }
          await tester.ensureVisible(find.byKey(ValueKey(key)));
          await tester.tap(find.byKey(ValueKey(key)));
          await tester.pump();
          expect(
            find.descendant(of: side, matching: find.text(name)),
            findsWidgets,
            reason: key,
          );
          expect(side, findsOneWidget);
        }
        // 後始末(Timer を止める)
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
      });
    }

    testWidgets('幅 1100 未満: 選ぶと一覧は閉じ、カードだけ。[一覧] でカードを閉じて一覧を出す', (tester) async {
      await pumpPage(tester, size: const Size(1000, 700));
      await tester.tap(listButton);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('list-item-room-room-b')));
      await tester.pump();
      expect(side, findsOneWidget);
      expect(title, findsNothing);
      await tester.tap(listButton);
      await tester.pump();
      expect(side, findsNothing);
      expect(title, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
    });

    testWidgets('幅 1100 未満: 3D でカードを開くと一覧は閉じる', (tester) async {
      final fake = await pumpPage(tester, size: const Size(1000, 700));
      await tester.tap(listButton);
      await tester.pump();
      fake.pick(roomA);
      await tester.pump();
      expect(title, findsNothing);
      expect(side, findsOneWidget);
      fake.pick(null);
      await tester.pump();
    });

    testWidgets('幅 1100 以上: 一覧を残したままカードが切り替わる', (tester) async {
      await pumpPage(tester, size: const Size(1280, 800));
      await tester.tap(listButton);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('list-item-room-room-b')));
      await tester.pump();
      expect(title, findsOneWidget);
      expect(side, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('list-item-room-room-a')));
      await tester.pump();
      expect(title, findsOneWidget);
      expect(
        find.descendant(of: side, matching: find.text('会議室A')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
    });

    testWidgets('キーボードだけで 開く → 移動 → Enter → カード(AC12)', (tester) async {
      await pumpPage(tester, size: const Size(1280, 800));
      // キーボードだけ: Tab で [視点リセット] → [一覧] へ、Enter で開く
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      expect(title, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(side, findsOneWidget);
      expect(
        find.descendant(of: side, matching: find.text('会議室B')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
    });

    testWidgets('一覧の時刻は仮想時刻に追従する(AC10)', (tester) async {
      final clock = VirtualClock(cycleLength: dummyOfficeData.cycleLength);
      await pumpPage(tester, virtualTime: clock);
      await tester.tap(listButton);
      await tester.pump();
      final row = find.byKey(const ValueKey('list-item-room-room-a'));
      expect(
        find.descendant(of: row, matching: find.text('空き')),
        findsOneWidget,
      );
      clock.advance(const Duration(seconds: 30));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.descendant(of: row, matching: find.text('使用中')),
        findsOneWidget,
      );
      await tester.tap(listButton);
      await tester.pump();
    });
  });

  group('閉じる操作', () {
    final guide = find.byKey(const Key('guide-start-button'));
    final title = find.byKey(const Key('list-panel-title'));

    Future<void> esc(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
    }

    testWidgets('Esc は 案内 → カード → 一覧 の順に 1 つずつ(AC14)', (tester) async {
      final fake = await pumpPage(
        tester,
        size: const Size(1280, 800),
        guideMemory: GuideMemory(),
      );
      await tester.tap(find.byKey(const Key('guide-close-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('list-button')));
      await tester.pump();
      fake.pick(roomB);
      await tester.pump();
      await tester.tap(find.byKey(const Key('help-button')));
      await tester.pump();
      // 案内・一覧・カードが全部出ている(1280 は同時に出せる)
      expect(guide, findsOneWidget);
      expect(title, findsOneWidget);
      expect(side, findsOneWidget);

      await esc(tester);
      expect(guide, findsNothing);
      expect(title, findsOneWidget);
      expect(side, findsOneWidget);

      await esc(tester);
      expect(side, findsNothing);
      expect(title, findsOneWidget);

      await esc(tester);
      expect(title, findsNothing);

      // 何も開いていなければ何も起きない
      await esc(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('閉じた直後でも続けて Esc が効く(フォーカスが消えない)', (tester) async {
      await pumpPage(tester, size: const Size(1280, 800));
      await tester.tap(find.byKey(const Key('list-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('list-item-room-room-b')));
      await tester.pump();
      await esc(tester); // カード
      expect(side, findsNothing);
      await esc(tester); // 一覧
      expect(title, findsNothing);
    });

    testWidgets('3D の背景クリックでカードと一覧が閉じる。案内は閉じない(AC15)', (tester) async {
      final fake = await pumpPage(
        tester,
        size: const Size(1280, 800),
        guideMemory: GuideMemory(),
      );
      await tester.tap(find.byKey(const Key('guide-close-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('list-button')));
      await tester.pump();
      fake.pick(roomB);
      await tester.pump();
      await tester.tap(find.byKey(const Key('help-button')));
      await tester.pump();
      fake.pick(null);
      await tester.pump();
      expect(side, findsNothing);
      expect(title, findsNothing);
      expect(guide, findsOneWidget);
    });

    testWidgets('一覧・カードは × でも閉じる(AC15)', (tester) async {
      final fake = await pumpPage(tester, size: const Size(1280, 800));
      await tester.tap(find.byKey(const Key('list-button')));
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('list-panel-side')),
          matching: find.byTooltip('閉じる'),
        ),
      );
      await tester.pump();
      expect(title, findsNothing);
      fake.pick(roomB);
      await tester.pump();
      await tester.tap(
        find.descendant(of: side, matching: find.byTooltip('閉じる')),
      );
      await tester.pump();
      expect(side, findsNothing);
    });
  });

  group('開発記録(記録)', () {
    Future<String> loader() =>
        Future.value(File('docs/dev-notes.md').readAsStringSync());
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    testWidgets('広い幅: ツールバーに 記録 があり、押すと別ページになる', (tester) async {
      await pumpPage(tester, notesLoader: loader);
      expect(find.byKey(const Key('notes-button')), findsOneWidget);
      expect(find.text('記録'), findsOneWidget);
      await tester.tap(find.byKey(const Key('notes-button')));
      await settle(tester);
      expect(find.text('← デモに戻る'), findsOneWidget);
      expect(find.text('開発記録'), findsOneWidget);
      expect(find.byKey(const Key('reset-view-button')), findsNothing);
      await tester.tap(find.text('← デモに戻る'));
      await settle(tester);
      expect(find.byKey(const Key('reset-view-button')), findsOneWidget);
    });

    testWidgets('狭い幅: ≡ メニューから開ける', (tester) async {
      await pumpPage(tester, size: const Size(375, 700), notesLoader: loader);
      await tester.tap(find.byKey(const Key('menu-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-notes')), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu-notes')));
      await settle(tester);
      expect(find.text('← デモに戻る'), findsOneWidget);
    });
  });
}
