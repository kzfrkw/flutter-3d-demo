import 'dart:math' as math;

import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/scene/office_layout.dart';
import 'package:flutter_test/flutter_test.dart';

OfficeData _small({RoomDoor? door2, double doorWidth = 1.0}) => OfficeData(
  floorSize: const FloorSize(10, 8),
  cycleLength: const Duration(minutes: 1),
  rooms: [
    Room(
      id: 'r1',
      name: 'x',
      capacity: 2,
      position: const FloorPoint(-2, 1),
      size: const FloorSize(3, 3),
      door: RoomDoor(side: RoomSide.south, width: doorWidth),
      entranceWaypointId: 'w1',
    ),
    Room(
      id: 'r2',
      name: 'x',
      capacity: 2,
      position: const FloorPoint(2, 1),
      size: const FloorSize(3, 4),
      door: door2 ?? const RoomDoor(side: RoomSide.east, offset: 0.5, width: 1),
      entranceWaypointId: 'w2',
    ),
  ],
  bookings: const [],
  seats: const [
    Seat(
      id: 's1',
      label: 'x',
      position: FloorPoint(0, -2),
      facing: math.pi / 2,
    ),
  ],
  people: const [],
  waypoints: const [
    Waypoint(id: 'w1', position: FloorPoint(-2, -1.2), neighbors: []),
    Waypoint(id: 'w2', position: FloorPoint(4.2, 1.5), neighbors: []),
  ],
  routes: const [],
);

LayoutBox _byId(List<LayoutBox> l, String id) =>
    l.firstWhere((b) => b.id == id);

void main() {
  final d = dummyOfficeData;
  final boxes = buildOfficeLayout(d);

  group('AC6 既定データ', () {
    test('種類ごとの箱', () {
      expect(boxes.where((b) => b.kind == BoxKind.floor), hasLength(1));
      expect(boxes.where((b) => b.kind == BoxKind.outerWall), isNotEmpty);
      for (final r in d.rooms) {
        expect(
          boxes.where(
            (b) =>
                b.kind == BoxKind.roomWall &&
                b.ref == EntityRef(EntityKind.room, r.id),
          ),
          isNotEmpty,
        );
      }
      for (final s in d.seats) {
        final ref = EntityRef(EntityKind.seat, s.id);
        expect(
          boxes.where((b) => b.kind == BoxKind.desk && b.ref == ref),
          hasLength(1),
        );
        expect(
          boxes.where((b) => b.kind == BoxKind.chair && b.ref == ref),
          hasLength(1),
        );
      }
    });

    test('ref は実在の id、箱の id は一意', () {
      for (final b in boxes) {
        final ref = b.ref;
        if (ref == null) continue;
        switch (ref.kind) {
          case EntityKind.room:
            expect(d.roomById(ref.id), isNotNull);
          case EntityKind.seat:
            expect(d.seatById(ref.id), isNotNull);
          case EntityKind.person:
            expect(d.personById(ref.id), isNotNull);
        }
        expect(b.id, startsWith('${ref.id}#'));
      }
      expect(boxes.map((b) => b.id).toSet().length, boxes.length);
    });

    test('Waypoint は壁・机・椅子の中に無い', () {
      final solid = boxes.where(
        (b) =>
            b.kind == BoxKind.roomWall ||
            b.kind == BoxKind.desk ||
            b.kind == BoxKind.chair,
      );
      for (final w in d.waypoints) {
        for (final b in solid) {
          expect(
            b.containsPoint(w.position),
            isFalse,
            reason: '${w.id} in ${b.id}',
          );
        }
      }
    });

    test('机と椅子が床の中', () {
      for (final b in boxes.where(
        (b) => b.kind == BoxKind.desk || b.kind == BoxKind.chair,
      )) {
        expect(b.center.x.abs(), lessThan(d.floorSize.width / 2));
        expect(b.center.z.abs(), lessThan(d.floorSize.depth / 2));
      }
    });
  });

  group('AC7 データに従う', () {
    final data = _small();
    final l = buildOfficeLayout(data);

    test('件数・id・位置どおり', () {
      expect(l.where((b) => b.kind == BoxKind.floor), hasLength(1));
      expect(l.where((b) => b.kind == BoxKind.desk), hasLength(1));
      expect(l.where((b) => b.kind == BoxKind.chair), hasLength(1));
      final refs = l
          .where((b) => b.kind == BoxKind.roomWall)
          .map((b) => b.ref!.id)
          .toSet();
      expect(refs, {'r1', 'r2'});

      final chair = l.firstWhere((b) => b.kind == BoxKind.chair);
      expect(chair.ref, const EntityRef(EntityKind.seat, 's1'));
      expect(chair.center, const FloorPoint(0, -2));
      expect(chair.yaw, math.pi / 2);

      const style = LayoutStyle();
      final desk = l.firstWhere((b) => b.kind == BoxKind.desk);
      expect(desk.yaw, math.pi / 2);
      expect(desk.center.x, closeTo(style.deskOffset, 1e-9));
      expect(desk.center.z, closeTo(-2, 1e-9));
    });

    test('LayoutStyle で寸法が変わる', () {
      final l2 = buildOfficeLayout(
        data,
        style: const LayoutStyle(roomWallHeight: 3.0, deskHeight: 1.0),
      );
      expect(l2.firstWhere((b) => b.kind == BoxKind.roomWall).height, 3.0);
      expect(l2.firstWhere((b) => b.kind == BoxKind.desk).height, 1.0);
    });

    test('ドアが辺に収まらないと ArgumentError', () {
      expect(
        () => buildOfficeLayout(_small(doorWidth: 5)),
        throwsArgumentError,
      );
      expect(
        () => buildOfficeLayout(
          _small(
            door2: const RoomDoor(side: RoomSide.east, offset: 1.8, width: 1),
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('AC8 ドアの開口', () {
    void check(OfficeData data) {
      final l = buildOfficeLayout(data);
      const style = LayoutStyle();
      for (final r in data.rooms) {
        final walls = l.where(
          (b) =>
              b.kind == BoxKind.roomWall &&
              b.ref == EntityRef(EntityKind.room, r.id),
        );
        final t = style.roomWallThickness;
        final door = r.door;
        // 壁の線上(壁の厚みの中央)の点。along は壁に沿った座標。
        FloorPoint onWall(double along) {
          final hw = r.size.width / 2 - t / 2;
          final hd = r.size.depth / 2 - t / 2;
          switch (door.side) {
            case RoomSide.south:
              return FloorPoint(r.position.x + along, r.position.z - hd);
            case RoomSide.north:
              return FloorPoint(r.position.x + along, r.position.z + hd);
            case RoomSide.east:
              return FloorPoint(r.position.x + hw, r.position.z + along);
            case RoomSide.west:
              return FloorPoint(r.position.x - hw, r.position.z + along);
          }
        }

        bool covered(double along) =>
            walls.any((w) => w.containsPoint(onWall(along)));

        expect(covered(door.offset), isFalse, reason: r.id);
        expect(covered(door.offset - door.width / 2 + 0.05), isFalse);
        expect(covered(door.offset + door.width / 2 - 0.05), isFalse);
        expect(covered(door.offset - door.width / 2 - 0.1), isTrue);
        expect(covered(door.offset + door.width / 2 + 0.1), isTrue);

        // 入口 Waypoint は部屋の外側・ドアの辺の側で、ドアの幅の中
        final wp = data.waypointById(r.entranceWaypointId)!.position;
        final dx = wp.x - r.position.x;
        final dz = wp.z - r.position.z;
        switch (door.side) {
          case RoomSide.south:
            expect(dz, lessThan(-r.size.depth / 2));
            expect((dx - door.offset).abs(), lessThanOrEqualTo(door.width / 2));
          case RoomSide.north:
            expect(dz, greaterThan(r.size.depth / 2));
            expect((dx - door.offset).abs(), lessThanOrEqualTo(door.width / 2));
          case RoomSide.east:
            expect(dx, greaterThan(r.size.width / 2));
            expect((dz - door.offset).abs(), lessThanOrEqualTo(door.width / 2));
          case RoomSide.west:
            expect(dx, lessThan(-r.size.width / 2));
            expect((dz - door.offset).abs(), lessThanOrEqualTo(door.width / 2));
        }
      }
    }

    test('既定データ', () => check(d));
    test('小さなデータ(別の辺)', () => check(_small()));
    test('壁の箱の id が部位つきで引ける', () {
      expect(_byId(boxes, 'floor').kind, BoxKind.floor);
    });
  });
}
