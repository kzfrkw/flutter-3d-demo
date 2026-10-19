import 'dart:math' as math;

import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/scene/label_placement.dart';
import 'package:flutter_3d_demo/office/scene/office_layout.dart';
import 'package:flutter_test/flutter_test.dart';

Room _room(RoomSide side, {double offset = 0, FloorSize? size}) => Room(
  id: 'r',
  name: 'R',
  capacity: 2,
  position: const FloorPoint(2, 3),
  size: size ?? const FloorSize(5, 5),
  door: RoomDoor(side: side, offset: offset, width: 1.2),
  entranceWaypointId: 'w',
);

void main() {
  const style = LabelStyle();

  test('名札: 人の真上で、下端がカプセル上端より上', () {
    final c = tagCenter(const FloorPoint(1.5, -2));
    expect(c.x, 1.5);
    expect(c.z, -2);
    expect(c.y - style.tagHeight / 2, greaterThan(personHeight));
  });

  group('パネル', () {
    test('既定データ: 全会議室でドア側の外・開口と重ならず・壁の長さ内(B は端を越える)', () {
      for (final room in dummyOfficeData.rooms) {
        final p = panelPlacement(room);
        expect(p.side, room.door.side);
        // 南向き: 壁の外面(z = 中心 − 奥行/2)より外(−Z 側)
        expect(
          p.center.z,
          closeTo(
            room.position.z - room.size.depth / 2 - style.panelWallGap,
            1e-9,
          ),
        );
        final doorHi = room.door.offset + room.door.width / 2;
        expect(p.alongFrom, greaterThanOrEqualTo(doorHi));
        expect(p.alongTo - p.alongFrom, closeTo(style.panelWidth, 1e-9));
        expect(
          p.center.x,
          closeTo(room.position.x + (p.alongFrom + p.alongTo) / 2, 1e-9),
        );
        expect(p.center.y, style.panelCenterY);
      }
      final a = panelPlacement(dummyOfficeData.roomById('room-a')!);
      expect(a.alongTo, lessThanOrEqualTo(2.5 + 1e-9));
      final b = panelPlacement(dummyOfficeData.roomById('room-b')!);
      expect(b.alongTo, greaterThan(2.0)); // 壁の端を越えるフォールバック
    });

    test('床以外のどの箱(壁・机など)にも重ならない', () {
      final boxes = buildOfficeLayout(dummyOfficeData);
      for (final room in dummyOfficeData.rooms) {
        final p = panelPlacement(room);
        final from = p.center.x - style.panelWidth / 2;
        final to = p.center.x + style.panelWidth / 2;
        for (final x in [from, p.center.x, to]) {
          for (final b in boxes.where((b) => b.kind != BoxKind.floor)) {
            expect(
              b.containsPoint(FloorPoint(x, p.center.z)),
              isFalse,
              reason: '${room.id} x=$x が ${b.id} と重なる',
            );
          }
        }
      }
    });

    test('+ 側が壁の外に出るなら − 側', () {
      // 幅 8(壁 ±4)。offset 0.9 なら + 側 1.6..3.4 が収まる。
      final fits = _room(
        RoomSide.south,
        offset: 0.9,
        size: const FloorSize(8, 5),
      );
      expect(panelPlacement(fits).alongFrom, closeTo(0.9 + 0.6 + 0.1, 1e-9));
      // offset 1.9 なら + 側 2.6..4.4 は越えるので、− 側 -0.6..1.2 を使う。
      final p = panelPlacement(
        _room(RoomSide.south, offset: 1.9, size: const FloorSize(8, 5)),
      );
      expect(p.alongTo, closeTo(1.9 - 0.6 - 0.1, 1e-9));
      expect(p.alongFrom, closeTo(1.9 - 0.6 - 0.1 - 1.8, 1e-9));
    });

    test('両側とも収まらなければ + 側', () {
      final room = _room(RoomSide.south, size: const FloorSize(3, 5));
      final p = panelPlacement(room);
      expect(p.alongFrom, closeTo(0.7, 1e-9));
    });

    test('他の辺: north / east / west は外側', () {
      final n = panelPlacement(_room(RoomSide.north));
      expect(n.center.z, closeTo(3 + 2.5 + 0.05, 1e-9));
      final e = panelPlacement(_room(RoomSide.east));
      expect(e.center.x, closeTo(2 + 2.5 + 0.05, 1e-9));
      expect(e.center.z, closeTo(3 + (e.alongFrom + e.alongTo) / 2, 1e-9));
      final w = panelPlacement(_room(RoomSide.west));
      expect(w.center.x, closeTo(2 - 2.5 - 0.05, 1e-9));
    });
  });

  group('billboardYaw', () {
    // 表の法線 (−sinθ, −cosθ) が 視線の逆 (−dx,−dz)/|d| に向く。
    void expectFacing(double dx, double dz) {
      final t = billboardYaw(dx, dz);
      final len = math.sqrt(dx * dx + dz * dz);
      final dot = (-math.sin(t)) * (-dx / len) + (-math.cos(t)) * (-dz / len);
      expect(dot, closeTo(1, 1e-9), reason: 'd=($dx,$dz)');
    }

    test('±X, ±Z, 斜め', () {
      expectFacing(0, 1);
      expectFacing(0, -1);
      expectFacing(1, 0);
      expectFacing(-1, 0);
      expectFacing(0.35, 1);
      expectFacing(-0.7, -0.2);
    });

    test('カメラが -Z 側(視線 +Z)なら回転なし、+Z 側なら π', () {
      expect(billboardYaw(0, 1), closeTo(0, 1e-9));
      expect(billboardYaw(0, -1).abs(), closeTo(math.pi, 1e-9));
    });

    test('水平成分がほぼ 0 なら 0', () {
      expect(billboardYaw(0, 0), 0);
      expect(billboardYaw(1e-12, 0), 0);
    });
  });
}
