import 'dart:io';

import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final d = dummyOfficeData;

  group('AC1 件数', () {
    test('各エンティティの件数', () {
      expect(d.rooms, hasLength(3));
      expect(d.seats, hasLength(8));
      expect(d.people, hasLength(6));
      expect(d.waypoints.length, inInclusiveRange(10, 16));
      expect(d.routes, hasLength(d.people.length));
      for (final r in d.rooms) {
        expect(d.bookingsOf(r.id).length, greaterThanOrEqualTo(2));
      }
      expect(d.seats.where((s) => s.ownerId == null), hasLength(2));
    });
  });

  group('AC2 参照', () {
    test('id が種類ごとに一意', () {
      void unique(Iterable<String> ids) =>
          expect(ids.toSet().length, ids.length);
      unique(d.rooms.map((e) => e.id));
      unique(d.bookings.map((e) => e.id));
      unique(d.seats.map((e) => e.id));
      unique(d.people.map((e) => e.id));
      unique(d.waypoints.map((e) => e.id));
    });

    test('参照先が実在する', () {
      for (final b in d.bookings) {
        expect(d.roomById(b.roomId), isNotNull);
      }
      for (final s in d.seats) {
        if (s.ownerId != null) expect(d.personById(s.ownerId!), isNotNull);
      }
      for (final r in d.routes) {
        expect(d.personById(r.personId), isNotNull);
        for (final w in r.waypointIds) {
          expect(d.waypointById(w), isNotNull);
        }
      }
      for (final w in d.waypoints) {
        for (final n in w.neighbors) {
          expect(d.waypointById(n), isNotNull);
        }
      }
      for (final r in d.rooms) {
        expect(d.waypointById(r.entranceWaypointId), isNotNull);
      }
    });

    test('neighbors は双方向', () {
      for (final w in d.waypoints) {
        for (final n in w.neighbors) {
          expect(d.waypointById(n)!.neighbors, contains(w.id));
        }
      }
    });

    test('Route の隣り合う点は neighbors でつながる', () {
      for (final r in d.routes) {
        final ids = r.waypointIds;
        final count = r.loop ? ids.length : ids.length - 1;
        for (var i = 0; i < count; i++) {
          final a = ids[i];
          final b = ids[(i + 1) % ids.length];
          expect(
            d.waypointById(a)!.neighbors,
            contains(b),
            reason: '${r.personId}: $a → $b',
          );
        }
      }
    });

    test('各 Person はちょうど 1 席の owner', () {
      for (final p in d.people) {
        expect(d.seats.where((s) => s.ownerId == p.id), hasLength(1));
        expect(d.seatOf(p.id), isNotNull);
        expect(d.routeOf(p.id), isNotNull);
      }
    });

    test('Booking の時間', () {
      for (final b in d.bookings) {
        expect(b.start, lessThan(b.end));
        expect(b.start, greaterThanOrEqualTo(Duration.zero));
        expect(b.end, lessThanOrEqualTo(d.cycleLength));
      }
      for (final r in d.rooms) {
        final list = d.bookingsOf(r.id);
        for (var i = 1; i < list.length; i++) {
          expect(list[i].start, greaterThanOrEqualTo(list[i - 1].end));
        }
      }
    });

    test('ID 引きは無ければ null', () {
      expect(d.roomById('nope'), isNull);
      expect(d.seatById('nope'), isNull);
      expect(d.personById('nope'), isNull);
      expect(d.waypointById('nope'), isNull);
      expect(d.routeOf('nope'), isNull);
      expect(d.seatOf('nope'), isNull);
      expect(d.bookingsOf('nope'), isEmpty);
      expect(d.roomById('room-a')!.name, '会議室A');
    });
  });

  group('AC3 位置', () {
    bool inFloor(FloorPoint p) =>
        p.x.abs() <= d.floorSize.width / 2 - d.outerWallThickness &&
        p.z.abs() <= d.floorSize.depth / 2 - d.outerWallThickness;

    test('Room・Seat・Waypoint が床の中', () {
      for (final r in d.rooms) {
        for (final sx in [-1, 1]) {
          for (final sz in [-1, 1]) {
            expect(
              inFloor(
                FloorPoint(
                  r.position.x + sx * r.size.width / 2,
                  r.position.z + sz * r.size.depth / 2,
                ),
              ),
              isTrue,
              reason: r.id,
            );
          }
        }
      }
      for (final s in d.seats) {
        expect(inFloor(s.position), isTrue, reason: s.id);
      }
      for (final w in d.waypoints) {
        expect(inFloor(w.position), isTrue, reason: w.id);
      }
    });

    test('Room どうしが重ならない', () {
      for (var i = 0; i < d.rooms.length; i++) {
        for (var j = i + 1; j < d.rooms.length; j++) {
          final a = d.rooms[i], b = d.rooms[j];
          final overlapX =
              (a.position.x - b.position.x).abs() <
              (a.size.width + b.size.width) / 2;
          final overlapZ =
              (a.position.z - b.position.z).abs() <
              (a.size.depth + b.size.depth) / 2;
          expect(overlapX && overlapZ, isFalse, reason: '${a.id}/${b.id}');
        }
      }
    });
  });

  group('AC4 名前', () {
    test('ダミーの名前の決まり', () {
      for (final p in d.people) {
        expect(p.displayName, matches(RegExp(r'^メンバー[A-Z]$')));
      }
      for (final r in d.rooms) {
        expect(r.name, matches(RegExp(r'^会議室[A-Z]$')));
      }
    });
  });

  group('AC13 data/ は描画に依存しない', () {
    test('import の検査', () {
      final files = Directory('lib/office/data')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(files, isNotEmpty);
      for (final f in files) {
        final src = f.readAsStringSync();
        expect(src, isNot(contains('package:flutter_scene')), reason: f.path);
        expect(src, isNot(contains('package:flutter/')), reason: f.path);
        expect(src, isNot(contains('/scene/')), reason: f.path);
      }
      final layout = File('lib/office/scene/office_layout.dart');
      final src = layout.readAsStringSync();
      expect(src, isNot(contains('package:flutter_scene')));
      expect(src, isNot(contains('package:flutter/')));
    });
  });
}
