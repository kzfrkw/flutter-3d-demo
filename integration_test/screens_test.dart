import 'package:flutter/material.dart';
import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/office_page.dart';
import 'package:flutter_3d_demo/office/people/people_simulation.dart';
import 'package:flutter_3d_demo/office/scene/office_scene_view.dart';
import 'package:flutter_3d_demo/office/scene/scene_loading.dart';
import 'package:flutter_3d_demo/office/scene/scene_labels.dart';
import 'package:flutter_3d_demo/office/status/office_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';

/// 3D の代わりに床色の面を出し、pick を外から起こせる偽の描画。
class _FakeView implements OfficeSceneView {
  /// null なら床色の面。読み込み中・エラーの画面を出すときに渡す。
  _FakeView({this.child});
  final Widget? child;

  ValueChanged<EntityRef?>? onPick;

  @override
  Widget build(
    BuildContext context,
    OfficeData data, {
    ValueChanged<EntityRef?>? onPick,
    ValueListenable<Duration>? virtualTime,
    ViewResetSignal? resetView,
  }) {
    this.onPick = onPick;
    return child ?? const ColoredBox(color: Color(0xFFE8E2D4));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await tester.pump();
    await binding.takeScreenshot(name);
  }

  Widget app(Widget home) => MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
    ),
    themeMode: ThemeMode.system,
    home: home,
  );

  Future<void> showCard(
    WidgetTester tester,
    String name,
    EntityRef ref, {
    Duration time = Duration.zero,
    PeopleSimulation? sim,
    double? width,
  }) async {
    final view = _FakeView();
    Widget page = OfficePage(
      view: view,
      data: dummyOfficeData,
      simulation: sim,
      virtualTime: ValueNotifier(time),
    );
    if (width != null) {
      page = Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: page),
      );
    }
    await tester.pumpWidget(app(page));
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    view.onPick!(ref);
    await tester.pump();
    await shoot(tester, name);
  }

  testWidgets('s2 screens', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    const roomB = EntityRef(EntityKind.room, 'room-b');
    const roomA = EntityRef(EntityKind.room, 'room-a');
    await showCard(tester, 's2-card-room', roomB);
    await showCard(
      tester,
      's2-card-room-free',
      roomA,
      time: const Duration(seconds: 220),
    );
    await showCard(
      tester,
      's2-card-seat',
      const EntityRef(EntityKind.seat, 'seat-1'),
    );
    await showCard(
      tester,
      's2-card-seat-unassigned',
      const EntityRef(EntityKind.seat, 'seat-4'),
    );
    final sim = PeopleSimulation(dummyOfficeData)..step(0.1);
    await showCard(
      tester,
      's2-card-person',
      const EntityRef(EntityKind.person, 'person-a'),
      sim: sim,
    );
    await showCard(tester, 's2-card-sheet', roomB, width: 390);

    final rooms = dummyOfficeData.rooms;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: ColoredBox(
            color: const Color(0xFFE8E2D4),
            child: Center(
              child: Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  SizedBox(
                    width: 180,
                    height: 54,
                    child: PersonTag(
                      name: dummyOfficeData.people.first.displayName,
                    ),
                  ),
                  for (final r in [rooms[0], rooms[1]])
                    SizedBox(
                      width: 144,
                      height: 96,
                      child: RoomPanel(
                        status: roomStatusAt(dummyOfficeData, r, Duration.zero),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await shoot(tester, 's2-labels');
  });

  /// 幅 [width] の端末として出す(MediaQuery も合わせる)。
  Widget sized(Widget page, double? width) => width == null
      ? page
      : Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 800,
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(size: Size(width, 800)),
                child: page,
              ),
            ),
          ),
        );

  /// 無限アニメ(読み込み中)があるので pumpAndSettle は使わず、時間を進めて撮る。
  Future<void> shootAfter(
    WidgetTester tester,
    String name,
    Duration after,
  ) async {
    await tester.pump(after);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await tester.pump();
    await binding.takeScreenshot(name);
  }

  testWidgets('s1 screens (reset button, loading, error)', (tester) async {
    const roomA = EntityRef(EntityKind.room, 'room-a');
    Future<_FakeView> open(_FakeView view, {double? width}) async {
      await tester.pumpWidget(
        app(
          sized(
            OfficePage(
              view: view,
              data: dummyOfficeData,
              virtualTime: ValueNotifier(Duration.zero),
            ),
            width,
          ),
        ),
      );
      await binding.convertFlutterSurfaceToImage();
      return view;
    }

    var view = await open(_FakeView());
    await shoot(tester, 's1-reset-wide');
    view.onPick!(roomA);
    await tester.pump();
    await shoot(tester, 's1-reset-wide-card');

    view = await open(_FakeView(), width: 390);
    await shoot(tester, 's1-reset-narrow');
    view.onPick!(roomA);
    await tester.pump();
    await shoot(tester, 's1-reset-narrow-card');

    await open(_FakeView(child: const SceneLoading()));
    await shootAfter(tester, 's1-loading', const Duration(seconds: 1));
    await shootAfter(tester, 's1-loading-slow', const Duration(seconds: 10));
    await open(_FakeView(child: const SceneLoading()), width: 390);
    await shootAfter(tester, 's1-loading-narrow', const Duration(seconds: 1));

    await open(
      _FakeView(
        child: SceneErrorView(
          failure: const SceneLoadFailure(
            SceneLoadFailureKind.webgl2Unsupported,
          ),
          onReload: () {},
        ),
      ),
    );
    await shoot(tester, 's1-error-webgl2');
    await open(
      _FakeView(
        child: SceneErrorView(
          failure: const SceneLoadFailure(
            SceneLoadFailureKind.loadFailed,
            detail: 'Exception: Failed to load shader bundle',
          ),
          onReload: () {},
        ),
      ),
    );
    await shoot(tester, 's1-error-load');
    await open(
      _FakeView(
        child: SceneErrorView(
          failure: const SceneLoadFailure(
            SceneLoadFailureKind.loadFailed,
            detail: 'Exception: Failed to load shader bundle',
          ),
          onReload: () {},
        ),
      ),
      width: 390,
    );
    await shoot(tester, 's1-error-load-narrow');
  });
}
