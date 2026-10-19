import 'package:flutter_3d_demo/office/data/office_models.dart';

/// テスト用の小さな OfficeData。部屋・席は空。
/// [points] の id → 座標、[edges] は双方向の辺、[routes] は personId → waypoint id。
OfficeData smallData({
  required Map<String, FloorPoint> points,
  required List<(String, String)> edges,
  required Map<String, List<String>> routes,
  Map<String, double> speeds = const {},
  bool loop = true,
}) {
  final neighbors = {for (final id in points.keys) id: <String>[]};
  for (final (a, b) in edges) {
    neighbors[a]!.add(b);
    neighbors[b]!.add(a);
  }
  return OfficeData(
    floorSize: const FloorSize(40, 40),
    cycleLength: const Duration(minutes: 5),
    rooms: const [],
    bookings: const [],
    seats: const [],
    people: [
      for (final id in routes.keys)
        Person(
          id: id,
          displayName: id,
          role: 'r',
          model: 'capsule',
          speed: speeds[id] ?? 1.0,
        ),
    ],
    waypoints: [
      for (final e in points.entries)
        Waypoint(id: e.key, position: e.value, neighbors: neighbors[e.key]!),
    ],
    routes: [
      for (final e in routes.entries)
        Route(personId: e.key, waypointIds: e.value, loop: loop),
    ],
  );
}
