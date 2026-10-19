import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/people/people_count.dart';
import 'package:flutter_test/flutter_test.dart';

void _expectConsistent(OfficeData d) {
  final ids = d.people.map((p) => p.id).toSet();
  expect(ids, hasLength(d.people.length), reason: 'Person の id が一意');
  for (final p in d.people) {
    expect(p.displayName, matches(RegExp(r'^メンバー[A-Z]$')));
    expect(d.routeOf(p.id), isNotNull, reason: '${p.id} の Route');
  }
  for (final r in d.routes) {
    expect(ids, contains(r.personId));
    expect(r.waypointIds.length, greaterThanOrEqualTo(2));
    for (final id in r.waypointIds) {
      expect(d.waypointById(id), isNotNull, reason: id);
    }
    final n = r.waypointIds.length;
    for (var i = 0; i < n; i++) {
      final a = d.waypointById(r.waypointIds[i])!;
      final b = r.waypointIds[(i + 1) % n];
      expect(a.neighbors, contains(b), reason: '${r.personId}: ${a.id}→$b');
    }
  }
  for (final s in d.seats) {
    if (s.ownerId != null) expect(ids, contains(s.ownerId));
  }
}

void main() {
  group('AC8 parsePeopleCount', () {
    test('無い・空・整数でないときは null', () {
      expect(parsePeopleCount(Uri.parse('http://x/')), isNull);
      expect(parsePeopleCount(Uri.parse('http://x/?people=')), isNull);
      expect(parsePeopleCount(Uri.parse('http://x/?people=abc')), isNull);
      expect(parsePeopleCount(Uri.parse('http://x/?check')), isNull);
    });

    test('範囲内はそのまま、範囲外は 5〜10 に丸める', () {
      expect(parsePeopleCount(Uri.parse('http://x/?people=7')), 7);
      expect(parsePeopleCount(Uri.parse('http://x/?people=5')), 5);
      expect(parsePeopleCount(Uri.parse('http://x/?people=10')), 10);
      expect(parsePeopleCount(Uri.parse('http://x/?people=3')), 5);
      expect(parsePeopleCount(Uri.parse('http://x/?people=99')), 10);
      expect(parsePeopleCount(Uri.parse('http://x/?people=-1')), 5);
    });
  });

  group('AC8 withPeopleCount', () {
    test('null と同じ人数は同じ参照を返す', () {
      expect(
        identical(withPeopleCount(dummyOfficeData, null), dummyOfficeData),
        isTrue,
      );
      expect(
        identical(withPeopleCount(dummyOfficeData, 6), dummyOfficeData),
        isTrue,
      );
    });

    test('10 人にすると Person が 10 人で、決まりを満たす', () {
      final d = withPeopleCount(dummyOfficeData, 10);
      expect(d.people, hasLength(10));
      expect(d.routes, hasLength(10));
      expect(d.seats, hasLength(8));
      expect(d.waypoints, hasLength(12));
      _expectConsistent(d);
    });

    test('8 人でも決まりを満たす', () {
      final d = withPeopleCount(dummyOfficeData, 8);
      expect(d.people, hasLength(8));
      _expectConsistent(d);
    });

    test('5 人にすると先頭 5 人だけ残り、席の owner の参照が宙に浮かない', () {
      final d = withPeopleCount(dummyOfficeData, 5);
      expect(d.people, hasLength(5));
      expect(d.routes, hasLength(5));
      expect(d.seats, hasLength(8));
      expect(d.seatOf('person-f'), isNull);
      _expectConsistent(d);
    });

    test('dummyOfficeData 自体は 6 人のまま', () {
      withPeopleCount(dummyOfficeData, 10);
      expect(dummyOfficeData.people, hasLength(6));
      expect(dummyOfficeData.routes, hasLength(6));
    });

    test(
      'officeDataForUri はクエリなしで dummyOfficeData を返し、?people=10 で 10 人になる',
      () {
        expect(
          identical(
            officeDataForUri(Uri.parse('http://x/'), dummyOfficeData),
            dummyOfficeData,
          ),
          isTrue,
        );
        expect(
          officeDataForUri(
            Uri.parse('http://x/?people=10'),
            dummyOfficeData,
          ).people,
          hasLength(10),
        );
      },
    );

    test('必要な Waypoint が無いと ArgumentError', () {
      final base = OfficeData(
        floorSize: const FloorSize(10, 10),
        cycleLength: const Duration(minutes: 5),
        rooms: const [],
        bookings: const [],
        seats: const [],
        people: const [
          Person(
            id: 'person-a',
            displayName: 'メンバーA',
            role: 'r',
            model: 'capsule',
            speed: 1,
          ),
        ],
        waypoints: const [],
        routes: const [],
      );
      expect(() => withPeopleCount(base, 6), throwsArgumentError);
    });
  });
}
