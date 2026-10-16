import 'dart:math' as math;

import 'office_models.dart';

/// 既定のダミーデータ(コード内固定、外部通信なし)。
/// 実在の人名・社名・予定は含めない。
final OfficeData dummyOfficeData = _build();

OfficeData _build() {
  const south = RoomDoor(side: RoomSide.south, width: 1.2);

  // 辺の一覧から、双方向の neighbors を組み立てる。
  const edges = <(String, String)>[
    ('wp-01', 'wp-02'),
    ('wp-02', 'wp-03'),
    ('wp-03', 'wp-04'),
    ('wp-04', 'wp-05'),
    ('wp-05', 'wp-06'),
    ('wp-06', 'wp-07'),
    ('wp-02', 'wp-08'),
    ('wp-02', 'wp-09'),
    ('wp-03', 'wp-09'),
    ('wp-04', 'wp-10'),
    ('wp-05', 'wp-11'),
    ('wp-06', 'wp-11'),
    ('wp-06', 'wp-12'),
  ];
  const points = <String, FloorPoint>{
    'wp-01': FloorPoint(-8.5, 0.8),
    'wp-02': FloorPoint(-6.5, 0.8),
    'wp-03': FloorPoint(-3.8, 0.8),
    'wp-04': FloorPoint(-1.0, 0.8),
    'wp-05': FloorPoint(2.0, 0.8),
    'wp-06': FloorPoint(5.5, 0.8),
    'wp-07': FloorPoint(8.5, 0.8),
    'wp-08': FloorPoint(-6.5, 4.0),
    'wp-09': FloorPoint(-5.0, -0.6),
    'wp-10': FloorPoint(-1.0, 4.0),
    'wp-11': FloorPoint(4.0, -0.6),
    'wp-12': FloorPoint(5.5, 4.0),
  };
  final neighbors = {for (final id in points.keys) id: <String>[]};
  for (final (a, b) in edges) {
    neighbors[a]!.add(b);
    neighbors[b]!.add(a);
  }

  Booking booking(String id, String room, String title, int s, int e) =>
      Booking(
        id: id,
        roomId: room,
        title: title,
        start: Duration(seconds: s),
        end: Duration(seconds: e),
      );

  const people = [
    ('person-a', 'メンバーA', 'エンジニア', 1.2),
    ('person-b', 'メンバーB', 'デザイナー', 1.0),
    ('person-c', 'メンバーC', '企画', 1.4),
    ('person-d', 'メンバーD', 'エンジニア', 1.1),
    ('person-e', 'メンバーE', 'デザイナー', 1.3),
    ('person-f', 'メンバーF', '企画', 1.2),
  ];

  const routes = <String, List<String>>{
    'person-a': ['wp-09', 'wp-02', 'wp-08', 'wp-02'],
    'person-b': ['wp-09', 'wp-03', 'wp-04', 'wp-10', 'wp-04', 'wp-03'],
    'person-c': ['wp-01', 'wp-02', 'wp-03', 'wp-02'],
    'person-d': ['wp-11', 'wp-06', 'wp-12', 'wp-06'],
    'person-e': ['wp-11', 'wp-05', 'wp-04', 'wp-10', 'wp-04', 'wp-05'],
    'person-f': ['wp-07', 'wp-06', 'wp-05', 'wp-06'],
  };

  return OfficeData(
    floorSize: const FloorSize(20, 14),
    cycleLength: const Duration(minutes: 5),
    rooms: const [
      Room(
        id: 'room-a',
        name: '会議室A',
        capacity: 8,
        position: FloorPoint(-6.5, 4.0),
        size: FloorSize(5.0, 5.0),
        door: south,
        entranceWaypointId: 'wp-02',
      ),
      Room(
        id: 'room-b',
        name: '会議室B',
        capacity: 4,
        position: FloorPoint(-1.0, 4.0),
        size: FloorSize(4.0, 5.0),
        door: south,
        entranceWaypointId: 'wp-04',
      ),
      Room(
        id: 'room-c',
        name: '会議室C',
        capacity: 6,
        position: FloorPoint(5.5, 4.0),
        size: FloorSize(5.0, 5.0),
        door: south,
        entranceWaypointId: 'wp-06',
      ),
    ],
    bookings: [
      booking('booking-a1', 'room-a', '週次定例', 30, 90),
      booking('booking-a2', 'room-a', '設計レビュー', 150, 210),
      booking('booking-b1', 'room-b', '1on1', 0, 60),
      booking('booking-b2', 'room-b', '企画ミーティング', 105, 165),
      booking('booking-b3', 'room-b', '振り返り', 210, 270),
      booking('booking-c1', 'room-c', 'デザインレビュー', 60, 120),
      booking('booking-c2', 'room-c', '進捗共有', 180, 240),
    ],
    seats: const [
      Seat(
        id: 'seat-1',
        label: 'A-1',
        position: FloorPoint(-5.8, -4.4),
        facing: 0,
        ownerId: 'person-a',
      ),
      Seat(
        id: 'seat-2',
        label: 'A-2',
        position: FloorPoint(-4.2, -4.4),
        facing: 0,
        ownerId: 'person-b',
      ),
      Seat(
        id: 'seat-3',
        label: 'A-3',
        position: FloorPoint(-5.8, -2.0),
        facing: math.pi,
        ownerId: 'person-c',
      ),
      Seat(
        id: 'seat-4',
        label: 'A-4',
        position: FloorPoint(-4.2, -2.0),
        facing: math.pi,
      ),
      Seat(
        id: 'seat-5',
        label: 'B-1',
        position: FloorPoint(3.2, -4.4),
        facing: 0,
        ownerId: 'person-d',
      ),
      Seat(
        id: 'seat-6',
        label: 'B-2',
        position: FloorPoint(4.8, -4.4),
        facing: 0,
        ownerId: 'person-e',
      ),
      Seat(
        id: 'seat-7',
        label: 'B-3',
        position: FloorPoint(3.2, -2.0),
        facing: math.pi,
        ownerId: 'person-f',
      ),
      Seat(
        id: 'seat-8',
        label: 'B-4',
        position: FloorPoint(4.8, -2.0),
        facing: math.pi,
      ),
    ],
    people: [
      for (final (id, name, role, speed) in people)
        Person(
          id: id,
          displayName: name,
          role: role,
          model: 'capsule',
          speed: speed,
        ),
    ],
    waypoints: [
      for (final e in points.entries)
        Waypoint(id: e.key, position: e.value, neighbors: neighbors[e.key]!),
    ],
    routes: [
      for (final e in routes.entries)
        Route(personId: e.key, waypointIds: e.value, loop: true),
    ],
  );
}
