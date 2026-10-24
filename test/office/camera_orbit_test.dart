import 'dart:math' as math;

import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/scene/camera_orbit.dart';
import 'package:flutter_3d_demo/office/scene/camera_yaw.dart';
import 'package:flutter_test/flutter_test.dart';

OrbitFrame _frame() => OrbitFrame.fromBounds(
  minX: -10,
  minY: -0.1,
  minZ: -6,
  maxX: 10,
  maxY: 2,
  maxZ: 6,
);

CameraOrbit _orbit({double yaw = 0}) {
  final frame = _frame();
  return CameraOrbit(
    frame: frame,
    limits: OrbitLimits.forFloor(const FloorSize(20, 12)),
    initial: initialPose(frame, yawDegrees: yaw),
  );
}

void main() {
  group('向き', () {
    test('右へドラッグ → 方位が増える', () {
      final o = _orbit();
      final before = o.pose.azimuth;
      o.rotate(50, 0);
      expect(o.pose.azimuth, greaterThan(before));
    });

    test('下へドラッグ → 仰角が増える', () {
      final o = _orbit();
      final before = o.pose.pitch;
      o.rotate(0, 20);
      expect(o.pose.pitch, greaterThan(before));
    });

    test('ホイールを奥へ(dy<0) → 拡大、手前(dy>0) → 縮小', () {
      final o = _orbit();
      o.zoomByScroll(-100);
      expect(o.pose.zoom, greaterThan(1));
      final o2 = _orbit();
      o2.zoomByScroll(100);
      expect(o2.pose.zoom, lessThan(1));
    });

    test('zoomBy: >1 で拡大', () {
      final o = _orbit();
      o.zoomBy(1.5);
      expect(o.pose.zoom, closeTo(1.5, 1e-9));
    });

    test('パン: 右へ → 注視点は画面左(x が減る)、下へ → z が増える(yaw 0)', () {
      final o = _orbit();
      final x0 = o.pose.targetX;
      final z0 = o.pose.targetZ;
      o.pan(40, 0, viewWidth: 800, viewHeight: 600);
      expect(o.pose.targetX, lessThan(x0));
      expect(o.pose.targetZ, closeTo(z0, 1.0));
      final o2 = _orbit();
      o2.pan(0, 40, viewWidth: 800, viewHeight: 600);
      expect(o2.pose.targetZ, greaterThan(z0));
    });
  });

  group('groundAxes(#12)', () {
    test('単位ベクトルで直交し、pan の右と同じ符号', () {
      for (final yaw in [0.0, 90.0, 180.0, -90.0, 37.0]) {
        final f = _frame();
        final pose = initialPose(f, yawDegrees: yaw);
        final a = f.groundAxes(pose);
        expect(
          math.sqrt(a.forwardX * a.forwardX + a.forwardZ * a.forwardZ),
          closeTo(1, 1e-9),
        );
        expect(
          math.sqrt(a.rightX * a.rightX + a.rightZ * a.rightZ),
          closeTo(1, 1e-9),
        );
        expect(a.forwardX * a.rightX + a.forwardZ * a.rightZ, closeTo(0, 1e-9));
        // 右ドラッグ(dx>0)で注視点が動く向きは -right。
        final o = CameraOrbit(
          frame: f,
          limits: OrbitLimits.forFloor(const FloorSize(20, 14), margin: 100),
          initial: pose,
        );
        o.pan(10, 0, viewWidth: 800, viewHeight: 600);
        final dx = o.pose.targetX - pose.targetX;
        final dz = o.pose.targetZ - pose.targetZ;
        expect(dx * a.rightX + dz * a.rightZ, lessThan(0));
        expect(dx * a.forwardX + dz * a.forwardZ, closeTo(0, 1e-9));
      }
    });
  });

  group('初期姿勢', () {
    test('yaw 0 の視線は T4 までの (0.35, 0.9, -1) の向きと一致', () {
      final f = _frame();
      final fwd = f.forward(initialPose(f));
      // forward = 注視点 - 目 = -(0.35, 0.9, -1) の向き。
      final n = math.sqrt(0.35 * 0.35 + 0.9 * 0.9 + 1);
      expect(fwd.x, closeTo(-0.35 / n, 1e-9));
      expect(fwd.y, closeTo(-0.9 / n, 1e-9));
      expect(fwd.z, closeTo(1 / n, 1e-9));
    });

    test('目の距離は 2 × reach', () {
      final f = _frame();
      final p = initialPose(f);
      final e = f.eye(p);
      final t = f.target(p);
      final d = math.sqrt(
        math.pow(e.x - t.x, 2) +
            math.pow(e.y - t.y, 2) +
            math.pow(e.z - t.z, 2),
      );
      expect(d, closeTo(2 * f.reach, 1e-9));
    });

    test('yaw 90 の目の水平オフセットは rotateAboutY の結果', () {
      final f = _frame();
      final p = initialPose(f, yawDegrees: 90);
      final e = f.eye(p);
      final t = f.target(p);
      final base = f.eye(initialPose(f));
      final r = rotateAboutY(base.x - t.x, base.z - t.z, 90);
      expect(e.x - t.x, closeTo(r.x, 1e-9));
      expect(e.z - t.z, closeTo(r.z, 1e-9));
      expect(e.y, closeTo(base.y, 1e-9));
    });
  });

  group('上限', () {
    void expectInLimits(CameraOrbit o) {
      final l = OrbitLimits.forFloor(const FloorSize(20, 12));
      final p = o.pose;
      expect(p.pitch, inInclusiveRange(l.minPitch, l.maxPitch));
      expect(p.zoom, inInclusiveRange(l.minZoom, l.maxZoom));
      expect(p.targetX, inInclusiveRange(l.minX, l.maxX));
      expect(p.targetZ, inInclusiveRange(l.minZ, l.maxZ));
      expect(p.azimuth, greaterThan(-math.pi - 1e-9));
      expect(p.azimuth, lessThanOrEqualTo(math.pi + 1e-9));
      expect(p.pitch.isFinite && p.zoom.isFinite, isTrue);
    }

    test('forFloor は床 ± margin、仰角は真上と水平の間', () {
      final l = OrbitLimits.forFloor(const FloorSize(20, 12), margin: 1);
      expect(l.minX, -11);
      expect(l.maxX, 11);
      expect(l.minZ, -7);
      expect(l.maxZ, 7);
      expect(l.minPitch, greaterThan(0));
      expect(l.maxPitch, lessThan(math.pi / 2));
      expect(l.minZoom, lessThan(1));
      expect(l.maxZoom, greaterThan(1));
    });

    test('極端な値でも範囲内', () {
      for (final v in [1e9, -1e9, 1e300, -1e300]) {
        final o = _orbit();
        o.rotate(v, v);
        expectInLimits(o);
        o.zoomBy(v);
        expectInLimits(o);
        o.zoomByScroll(v);
        expectInLimits(o);
        o.pan(v, v, viewWidth: 800, viewHeight: 600);
        expectInLimits(o);
      }
    });

    test('NaN・無限大は無視(状態を変えない)', () {
      final o = _orbit();
      final before = o.pose;
      o.rotate(double.nan, 1);
      o.rotate(1, double.infinity);
      o.zoomBy(double.nan);
      o.zoomBy(double.infinity);
      o.zoomBy(0);
      o.zoomByScroll(double.nan);
      o.pan(double.nan, 0, viewWidth: 800, viewHeight: 600);
      o.pan(0, double.infinity, viewWidth: 800, viewHeight: 600);
      expect(o.pose, before);
    });

    test('1000 回の連続入力のあとも範囲内', () {
      final o = _orbit();
      final rnd = math.Random(1);
      for (var i = 0; i < 1000; i++) {
        o.rotate(rnd.nextDouble() * 400 - 200, rnd.nextDouble() * 400 - 200);
        o.zoomByScroll(rnd.nextDouble() * 2000 - 1000);
        o.pan(
          rnd.nextDouble() * 600 - 300,
          rnd.nextDouble() * 600 - 300,
          viewWidth: 800,
          viewHeight: 600,
        );
        expectInLimits(o);
      }
    });

    test('ズームを上限・下限まで続ける', () {
      final o = _orbit();
      for (var i = 0; i < 100; i++) {
        o.zoomBy(2);
      }
      expect(
        o.pose.zoom,
        OrbitLimits.forFloor(const FloorSize(20, 12)).maxZoom,
      );
      for (var i = 0; i < 100; i++) {
        o.zoomBy(0.5);
      }
      expect(
        o.pose.zoom,
        OrbitLimits.forFloor(const FloorSize(20, 12)).minZoom,
      );
    });

    test('方位は 10 周しても同じ向きで (-π, π]', () {
      final o = _orbit();
      final a0 = o.pose.azimuth;
      // 2π ぶんを 0.006 rad/px で割った px を 10 周。
      final px = 2 * math.pi / CameraOrbit.azimuthPerPixel;
      for (var i = 0; i < 10; i++) {
        o.rotate(px, 0);
      }
      expectInLimits(o);
      final diff = (o.pose.azimuth - a0) % (2 * math.pi);
      expect(math.min(diff, 2 * math.pi - diff), lessThan(1e-6));
    });
  });

  group('リセット', () {
    test('操作のあとリセットで initial に一致する', () {
      final o = _orbit(yaw: 90);
      o.rotate(100, 50);
      o.zoomBy(2);
      o.pan(30, 30, viewWidth: 800, viewHeight: 600);
      expect(o.pose, isNot(o.initial));
      o.reset();
      expect(o.pose, o.initial);
      expect(o.initial.azimuth, closeTo(90 * math.pi / 180, 1e-9));
    });
  });
}
