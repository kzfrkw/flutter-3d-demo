import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/people/avatar_controller.dart';
import 'package:flutter_3d_demo/office/scene/office_layout.dart';

AvatarController make({
  FloorPoint? start,
  double speed = 1.5,
}) {
  final boxes = buildOfficeLayout(dummyOfficeData);
  return AvatarController(
    boxes,
    floor: dummyOfficeData.floorSize,
    start: start ?? defaultAvatarStart,
    speed: speed,
  );
}

bool overlapsAny(List<LayoutBox> boxes, double x, double z, double r) {
  for (final b in boxes) {
    if (b.kind == BoxKind.floor || b.kind == BoxKind.roomFloor) continue;
    final dx = x - b.center.x;
    final dz = z - b.center.z;
    final c = math.cos(b.yaw);
    final s = math.sin(b.yaw);
    final lx = dx * c - dz * s;
    final lz = dx * s + dz * c;
    final nx = lx.clamp(-b.width / 2, b.width / 2);
    final nz = lz.clamp(-b.depth / 2, b.depth / 2);
    final d2 = (lx - nx) * (lx - nx) + (lz - nz) * (lz - nz);
    if (d2 < r * r) return true;
  }
  return false;
}

void main() {
  final boxes = buildOfficeLayout(dummyOfficeData);
  final floor = dummyOfficeData.floorSize;

  group('動き', () {
    test('↑ で +Z に speed×dt 進む。離せば止まる', () {
      final a = make();
      final z0 = a.z;
      a.setKey(AvatarKey.forward, true);
      a.step(0.1);
      expect(a.z, closeTo(z0 + 0.15, 1e-9));
      expect(a.x, closeTo(defaultAvatarStart.x, 1e-9));
      a.setKey(AvatarKey.forward, false);
      final yaw = a.yaw;
      a.step(0.1);
      expect(a.z, closeTo(z0 + 0.15, 1e-9));
      expect(a.yaw, yaw);
    });

    test('↓ ← → は画面の手前・左・右へ同じ速さで進む', () {
      for (final (key, dx, dz) in [
        (AvatarKey.back, 0.0, -1.0),
        (AvatarKey.left, -1.0, 0.0),
        (AvatarKey.right, 1.0, 0.0),
      ]) {
        final a = make();
        a.setKey(key, true);
        a.step(0.1);
        expect(a.x - defaultAvatarStart.x, closeTo(dx * 0.15, 1e-9));
        expect(a.z - defaultAvatarStart.z, closeTo(dz * 0.15, 1e-9));
      }
    });

    test('↑↓ 同時・←→ 同時は打ち消す', () {
      final a = make();
      a.setKey(AvatarKey.forward, true);
      a.setKey(AvatarKey.back, true);
      a.setKey(AvatarKey.left, true);
      a.setKey(AvatarKey.right, true);
      a.step(0.1);
      expect(a.x, defaultAvatarStart.x);
      expect(a.z, defaultAvatarStart.z);
      expect(a.isWalking, isFalse);
    });

    test('斜めは速さが speed のまま', () {
      final a = make();
      a.setKey(AvatarKey.forward, true);
      a.setKey(AvatarKey.right, true);
      a.step(0.1);
      final dist = math.sqrt(
        math.pow(a.x - defaultAvatarStart.x, 2) +
            math.pow(a.z - defaultAvatarStart.z, 2),
      );
      expect(dist, closeTo(0.15, 1e-9));
      expect(a.x, greaterThan(defaultAvatarStart.x));
      expect(a.z, greaterThan(defaultAvatarStart.z));
    });

    test('view を回すと、その向きの「上」へ進む', () {
      final a = make();
      a.setKey(AvatarKey.forward, true);
      // 画面の上 = +X、右 = -Z。
      a.step(
        0.1,
        view: const ViewAxes(forwardX: 1, forwardZ: 0, rightX: 0, rightZ: -1),
      );
      expect(a.x, closeTo(defaultAvatarStart.x + 0.15, 1e-9));
      expect(a.z, closeTo(defaultAvatarStart.z, 1e-9));
    });

    test('dt が負・NaN は動かず、上限で丸める', () {
      final a = make();
      a.setKey(AvatarKey.forward, true);
      a.step(-1);
      a.step(double.nan);
      expect(a.z, defaultAvatarStart.z);
      a.step(10);
      expect(a.z, closeTo(defaultAvatarStart.z + 1.5 * 0.1, 1e-9));
    });

    test('releaseAll で全部離れる', () {
      final a = make();
      for (final k in AvatarKey.values) {
        a.setKey(k, true);
      }
      a.releaseAll();
      for (final k in AvatarKey.values) {
        expect(a.isPressed(k), isFalse);
      }
    });
  });

  group('向きと揺れ', () {
    test('進行方向へ近づき、1 ステップは turnRate×dt 以下。範囲は (-π, π]', () {
      final a = make();
      a.setKey(AvatarKey.right, true); // 目標 yaw = +π/2。初期 0
      var prev = a.yaw;
      for (var i = 0; i < 20; i++) {
        a.step(0.016);
        expect((a.yaw - prev).abs(), lessThanOrEqualTo(12.0 * 0.016 + 1e-9));
        expect(a.yaw, greaterThan(-math.pi));
        expect(a.yaw, lessThanOrEqualTo(math.pi));
        prev = a.yaw;
      }
      expect(a.yaw, closeTo(math.pi / 2, 1e-9));
    });

    test('止まっても向きは変わらない。揺れは歩く間だけ', () {
      final a = make();
      a.setKey(AvatarKey.left, true);
      for (var i = 0; i < 10; i++) {
        a.step(0.05);
      }
      expect(a.isWalking, isTrue);
      expect(a.bob, greaterThan(0));
      a.releaseAll();
      final yaw = a.yaw;
      a.step(0.05);
      expect(a.yaw, yaw);
      expect(a.bob, 0);
      expect(a.lean, 0);
      expect(a.isWalking, isFalse);
    });

    test('↑+→ で位置と向きの両方が変わる', () {
      final a = make();
      a.setKey(AvatarKey.forward, true);
      a.setKey(AvatarKey.right, true);
      a.step(0.05);
      expect(a.x, isNot(defaultAvatarStart.x));
      expect(a.yaw, isNot(0));
    });
  });

  group('当たり判定', () {
    test('既定の初期位置は障害物と重ならない', () {
      final a = make();
      expect(overlapsAny(boxes, a.x, a.z, personRadiusForTest), isFalse);
    });

    test('重なる start は ArgumentError', () {
      expect(
        () => make(start: FloorPoint(0, floorDepthHalf)),
        throwsArgumentError,
      );
    });

    test('speed×maxDt は直径より小さい', () {
      final a = make();
      expect(a.speed * a.maxDt, lessThan(2 * a.radius));
    });

    for (final dt in [0.016, 0.1]) {
      for (final key in AvatarKey.values) {
        test('どこから ${key.name} に 10 秒押しても重ならず床の外へ出ない(dt=$dt)', () {
          final starts = <FloorPoint>[
            defaultAvatarStart,
            const FloorPoint(-6.5, 0.5),
            const FloorPoint(-6.5, 3.0), // 会議室 A の中
            const FloorPoint(0, 0),
          ];
          for (final s in starts) {
            if (overlapsAny(boxes, s.x, s.z, 0.25)) continue;
            final a = make(start: s);
            a.setKey(key, true);
            for (var t = 0.0; t < 10; t += dt) {
              a.step(dt);
              expect(a.x.isFinite && a.z.isFinite, isTrue);
              expect(overlapsAny(boxes, a.x, a.z, 0.25 - 1e-6), isFalse,
                  reason: 'start=(${s.x},${s.z}) at (${a.x},${a.z})');
              expect(a.x.abs(), lessThanOrEqualTo(floor.width / 2));
              expect(a.z.abs(), lessThanOrEqualTo(floor.depth / 2));
            }
          }
        });
      }
    }

    test('壁に斜めに当たると壁に沿って滑る', () {
      // 南の外壁に向かって ↓+→ を押す。Z は止まり X は進む。
      final a = make(start: const FloorPoint(0, -5));
      a.setKey(AvatarKey.back, true);
      a.setKey(AvatarKey.right, true);
      for (var i = 0; i < 100; i++) {
        a.step(0.05);
      }
      expect(a.x, greaterThan(1.0));
      expect(overlapsAny(boxes, a.x, a.z, 0.25 - 1e-6), isFalse);
    });

    test('会議室 A のドアから中へ入れる。床は障害物でない', () {
      final room = dummyOfficeData.rooms.first;
      final doorX = room.position.x + room.door.offset;
      final a = make(start: FloorPoint(doorX, room.position.z - 4.0));
      a.setKey(AvatarKey.forward, true);
      for (var i = 0; i < 100; i++) {
        a.step(0.05);
      }
      expect(a.z, greaterThan(room.position.z - 1.0));
      expect(a.z, lessThan(room.position.z + room.size.depth / 2));
    });
  });
}

const double personRadiusForTest = 0.25;
final double floorDepthHalf = dummyOfficeData.floorSize.depth / 2;
