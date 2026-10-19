import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/people/people_simulation.dart';
import 'package:flutter_3d_demo/office/status/office_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'people_test_data.dart';

Duration s(int sec) => Duration(seconds: sec);

RoomStatus room(String id, Duration t) =>
    roomStatusAt(dummyOfficeData, dummyOfficeData.roomById(id)!, t);

void main() {
  group('会議室', () {
    test('時刻 0 秒: B=使用中(1on1)、A・C=空き', () {
      final b = room('room-b', Duration.zero);
      expect(b.occupancy, RoomOccupancy.occupied);
      expect(b.current?.title, '1on1');
      expect(b.next?.title, '企画ミーティング');
      expect(b.nextIsNextCycle, isFalse);
      expect(room('room-a', Duration.zero).occupancy, RoomOccupancy.free);
      expect(room('room-c', Duration.zero).occupancy, RoomOccupancy.free);
      expect(room('room-a', Duration.zero).current, isNull);
      expect(room('room-a', Duration.zero).next?.title, '週次定例');
    });

    test('境界: 開始ちょうど=使用中、終了ちょうど=空き', () {
      expect(room('room-a', s(29)).occupancy, RoomOccupancy.free);
      expect(room('room-a', s(30)).occupancy, RoomOccupancy.occupied);
      expect(room('room-a', s(89)).occupancy, RoomOccupancy.occupied);
      expect(room('room-a', s(90)).occupancy, RoomOccupancy.free);
      expect(room('room-a', s(90)).next?.title, '設計レビュー');
    });

    test('一巡の終わりを越えると次の予定は次周の先頭', () {
      final a = room('room-a', s(220));
      expect(a.occupancy, RoomOccupancy.free);
      expect(a.next?.title, '週次定例');
      expect(a.nextIsNextCycle, isTrue);
    });

    test('時刻が一巡を超えても同じ結果', () {
      final base = room('room-b', s(10));
      final over = room('room-b', const Duration(minutes: 5, seconds: 10));
      expect(over.occupancy, base.occupancy);
      expect(over.current?.id, base.current?.id);
      expect(over.next?.id, base.next?.id);
    });

    test('予定が無い部屋は空きで next も null', () {
      final data = OfficeData(
        floorSize: const FloorSize(10, 10),
        cycleLength: const Duration(minutes: 1),
        rooms: const [
          Room(
            id: 'r',
            name: 'R',
            capacity: 2,
            position: FloorPoint(0, 0),
            size: FloorSize(3, 3),
            door: RoomDoor(side: RoomSide.south, width: 1),
            entranceWaypointId: 'w',
          ),
        ],
        bookings: const [],
        seats: const [],
        people: const [],
        waypoints: const [],
        routes: const [],
      );
      final st = roomStatusAt(data, data.rooms.first, s(5));
      expect(st.occupancy, RoomOccupancy.free);
      expect(st.next, isNull);
      expect(st.nextIsNextCycle, isFalse);
    });

    test('文言は列挙の label', () {
      expect(RoomOccupancy.free.label, '空き');
      expect(RoomOccupancy.occupied.label, '使用中');
    });
  });

  group('席', () {
    final seat1 = dummyOfficeData.seatById('seat-1')!; // 使用者 person-a
    final seat4 = dummyOfficeData.seatById('seat-4')!; // 使用者なし
    PersonLookup at(double dx) =>
        (id) => (
          position: FloorPoint(seat1.position.x + dx, seat1.position.z),
          isWalking: false,
        );

    test('使用者あり/なし', () {
      final a = seatStatusAt(dummyOfficeData, seat1, (_) => null);
      expect(a.owner?.displayName, 'メンバーA');
      final b = seatStatusAt(dummyOfficeData, seat4, (_) => null);
      expect(b.owner, isNull);
      expect(b.presence, SeatPresence.unassigned);
      expect(unassignedOwnerLabel, '未割り当て');
    });

    test('在席/離席の境界(0.8 m ちょうどは在席)', () {
      expect(
        seatStatusAt(dummyOfficeData, seat1, at(seatPresenceRadius)).presence,
        SeatPresence.present,
      );
      expect(
        seatStatusAt(
          dummyOfficeData,
          seat1,
          at(seatPresenceRadius + 0.01),
        ).presence,
        SeatPresence.away,
      );
      expect(
        seatStatusAt(dummyOfficeData, seat1, (_) => null).presence,
        SeatPresence.away,
      );
    });

    test('owner の Person がデータに無ければ owner は null', () {
      const orphan = Seat(
        id: 'x',
        label: 'X',
        position: FloorPoint(0, 0),
        facing: 0,
        ownerId: 'nobody',
      );
      final st = seatStatusAt(dummyOfficeData, orphan, (_) => null);
      expect(st.owner, isNull);
      expect(st.presence, SeatPresence.unassigned);
    });
  });

  group('人', () {
    final person = dummyOfficeData.personById('person-a')!;
    test('名前・役割・行動', () {
      final walking = personStatusAt(
        person,
        (_) => (position: const FloorPoint(0, 0), isWalking: true),
      );
      expect(walking.person.displayName, 'メンバーA');
      expect(walking.person.role, 'エンジニア');
      expect(walking.activity, PersonActivity.walking);
      expect(walking.activity.label, '歩行中');
      final stopped = personStatusAt(
        person,
        (_) => (position: const FloorPoint(0, 0), isWalking: false),
      );
      expect(stopped.activity, PersonActivity.stopped);
      expect(stopped.activity.label, '停止中');
    });

    test('シミュレーション無しは停止中', () {
      final lookup = personLookupOf(null);
      expect(lookup('person-a'), isNull);
      expect(personStatusAt(person, lookup).activity, PersonActivity.stopped);
    });

    test('実際の PeopleSimulation の値と一致', () {
      final sim = PeopleSimulation(dummyOfficeData);
      sim.step(0.1);
      final lookup = personLookupOf(sim);
      final w = sim.walkerOf('person-a')!;
      expect(lookup('person-a')!.isWalking, w.isWalking);
      expect(lookup('person-a')!.position, w.position);
      expect(lookup('nobody'), isNull);
      expect(personStatusAt(person, lookup).activity, PersonActivity.walking);
    });

    test('停止している Walker は停止中', () {
      final data = smallData(
        points: {'a': const FloorPoint(0, 0)},
        edges: const [],
        routes: {
          'p': ['a'],
        },
      );
      final sim = PeopleSimulation(data)..step(0.1);
      final p = data.personById('p')!;
      expect(
        personStatusAt(p, personLookupOf(sim)).activity,
        PersonActivity.stopped,
      );
    });
  });

  group('statusOf', () {
    test('種類ごとに引き、無い id は null', () {
      TargetStatus? st(EntityKind k, String id) => statusOf(
        EntityRef(k, id),
        dummyOfficeData,
        time: Duration.zero,
        lookup: personLookupOf(null),
      );
      expect(st(EntityKind.room, 'room-b'), isA<RoomStatus>());
      expect(st(EntityKind.room, 'room-b')!.title, '会議室B');
      expect(st(EntityKind.seat, 'seat-1')!.title, 'A-1');
      expect(st(EntityKind.person, 'person-a')!.title, 'メンバーA');
      expect(st(EntityKind.room, 'nope'), isNull);
      expect(st(EntityKind.seat, 'room-a'), isNull);
    });
  });
}
