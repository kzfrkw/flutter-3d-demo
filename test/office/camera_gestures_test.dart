import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/scene/camera_gestures.dart';
import 'package:flutter_3d_demo/office/scene/camera_orbit.dart';
import 'package:flutter_test/flutter_test.dart';

CameraOrbit _orbit() {
  final frame = OrbitFrame.fromBounds(
    minX: -10,
    minY: 0,
    minZ: -6,
    maxX: 10,
    maxY: 2,
    maxZ: 6,
  );
  return CameraOrbit(
    frame: frame,
    limits: OrbitLimits.forFloor(const FloorSize(20, 12)),
    initial: initialPose(frame),
  );
}

class _Taps {
  final List<Offset> positions = [];
}

Future<({CameraOrbit orbit, _Taps taps})> _pump(WidgetTester tester) async {
  final orbit = _orbit();
  final taps = _Taps();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 800,
          height: 600,
          child: OrbitGestureLayer(
            orbit: orbit,
            onTap: (p, size) => taps.positions.add(p),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
  return (orbit: orbit, taps: taps);
}

void main() {
  final center = const Offset(400, 300);

  testWidgets('マウス左ドラッグで回転(右へ → 方位増)', (tester) async {
    final r = await _pump(tester);
    final a0 = r.orbit.pose.azimuth;
    final g = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await g.moveBy(const Offset(40, 0));
    await g.moveBy(const Offset(40, 0));
    await g.up();
    expect(r.orbit.pose.azimuth, greaterThan(a0));
    expect(r.taps.positions, isEmpty);
  });

  testWidgets('マウス右ドラッグでパン(回転しない)', (tester) async {
    final r = await _pump(tester);
    final before = r.orbit.pose;
    final g = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await g.moveBy(const Offset(40, 0));
    await g.moveBy(const Offset(40, 0));
    await g.up();
    expect(r.orbit.pose.targetX, lessThan(before.targetX));
    expect(r.orbit.pose.azimuth, before.azimuth);
    expect(r.taps.positions, isEmpty);
  });

  testWidgets('ホイールでズーム(奥へ → 拡大)', (tester) async {
    final r = await _pump(tester);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(center));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    expect(r.orbit.pose.zoom, greaterThan(1));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 300)));
    expect(r.orbit.pose.zoom, lessThan(1.2));
  });

  testWidgets('PointerScaleEvent(トラックパッドのピンチ)でズーム', (tester) async {
    final r = await _pump(tester);
    final pad = TestPointer(2, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pad.hover(center));
    await tester.sendEventToBinding(
      PointerScaleEvent(position: center, scale: 1.5),
    );
    expect(r.orbit.pose.zoom, closeTo(1.5, 1e-9));
  });

  testWidgets('タッチ 1 本のドラッグで回転', (tester) async {
    final r = await _pump(tester);
    final a0 = r.orbit.pose.azimuth;
    final g = await tester.startGesture(center);
    await g.moveBy(const Offset(40, 0));
    await g.moveBy(const Offset(40, 0));
    await g.up();
    expect(r.orbit.pose.azimuth, greaterThan(a0));
    expect(r.taps.positions, isEmpty);
  });

  testWidgets('タッチ 2 本のピンチでズーム', (tester) async {
    final r = await _pump(tester);
    final g1 = await tester.startGesture(
      center + const Offset(-50, 0),
      pointer: 1,
    );
    final g2 = await tester.startGesture(
      center + const Offset(50, 0),
      pointer: 2,
    );
    await g1.moveBy(const Offset(-50, 0));
    await g2.moveBy(const Offset(50, 0));
    await g1.up();
    await g2.up();
    expect(r.orbit.pose.zoom, greaterThan(1.5));
    expect(r.taps.positions, isEmpty);
  });

  testWidgets('スロップ以内で離すと onTap(タッチ・マウス)', (tester) async {
    final r = await _pump(tester);
    final g = await tester.startGesture(center);
    await g.moveBy(const Offset(3, 0));
    await g.up();
    expect(r.taps.positions, hasLength(1));
    expect(r.taps.positions.single.dx, closeTo(403, 1e-9));
    final m = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await m.up();
    expect(r.taps.positions, hasLength(2));
  });

  testWidgets('スロップを超えると onTap なし', (tester) async {
    final r = await _pump(tester);
    final m = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await m.moveBy(const Offset(20, 0));
    await m.up();
    expect(r.taps.positions, isEmpty);
  });

  testWidgets('右ボタンは onTap を呼ばない', (tester) async {
    final r = await _pump(tester);
    final m = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await m.up();
    expect(r.taps.positions, isEmpty);
  });

  testWidgets('cancel で onTap なし', (tester) async {
    final r = await _pump(tester);
    final g = await tester.startGesture(center);
    await g.cancel();
    expect(r.taps.positions, isEmpty);
  });

  testWidgets('長いドラッグでも上限内', (tester) async {
    final r = await _pump(tester);
    final l = OrbitLimits.forFloor(const FloorSize(20, 12));
    final g = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    for (var i = 0; i < 50; i++) {
      await g.moveBy(const Offset(0, 100));
    }
    await g.up();
    expect(r.orbit.pose.pitch, l.maxPitch);
    final p = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    for (var i = 0; i < 50; i++) {
      await p.moveBy(const Offset(-300, -300));
    }
    await p.up();
    expect(r.orbit.pose.targetX, inInclusiveRange(l.minX, l.maxX));
    expect(r.orbit.pose.targetZ, inInclusiveRange(l.minZ, l.maxZ));
  });
}
