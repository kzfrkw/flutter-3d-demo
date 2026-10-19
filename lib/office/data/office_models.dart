import 'dart:math' as math;

/// 床面上の点 (x, z)。単位はメートル。床の中心が原点、Y が上。
class FloorPoint {
  const FloorPoint(this.x, this.z);

  final double x;
  final double z;

  double distanceTo(FloorPoint other) =>
      math.sqrt(math.pow(x - other.x, 2) + math.pow(z - other.z, 2));

  @override
  bool operator ==(Object other) =>
      other is FloorPoint && other.x == x && other.z == z;

  @override
  int get hashCode => Object.hash(x, z);

  @override
  String toString() => 'FloorPoint($x, $z)';
}

/// 床面上の大きさ。width は X 方向、depth は Z 方向。
class FloorSize {
  const FloorSize(this.width, this.depth);

  final double width;
  final double depth;

  @override
  bool operator ==(Object other) =>
      other is FloorSize && other.width == width && other.depth == depth;

  @override
  int get hashCode => Object.hash(width, depth);

  @override
  String toString() => 'FloorSize($width, $depth)';
}

/// 壁の辺。north=+Z、south=-Z、east=+X、west=-X。
enum RoomSide { north, south, east, west }

enum EntityKind { person, seat, room }

/// 「どのエンティティか」の参照。
class EntityRef {
  const EntityRef(this.kind, this.id);

  final EntityKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is EntityRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'EntityRef(${kind.name}, $id)';
}

/// 会議室の入口(壁の切れ目)。offset は壁の中央からの符号付き距離。
/// north/south の壁なら +X 向き、east/west の壁なら +Z 向き。
class RoomDoor {
  const RoomDoor({required this.side, this.offset = 0, required this.width});

  final RoomSide side;
  final double offset;
  final double width;
}

class Room {
  const Room({
    required this.id,
    required this.name,
    required this.capacity,
    required this.position,
    required this.size,
    required this.door,
    required this.entranceWaypointId,
  });

  final String id;
  final String name;
  final int capacity;

  /// 床面上の中心。
  final FloorPoint position;

  /// 壁の外側の寸法。
  final FloorSize size;
  final RoomDoor door;

  /// 入口の外(通路側)にある Waypoint の id。
  final String entranceWaypointId;
}

class Booking {
  const Booking({
    required this.id,
    required this.roomId,
    required this.title,
    required this.start,
    required this.end,
  });

  final String id;
  final String roomId;
  final String title;

  /// 仮想時刻の一巡の始まりからの経過時間。
  final Duration start;
  final Duration end;
}

class Seat {
  const Seat({
    required this.id,
    required this.label,
    required this.position,
    required this.facing,
    this.ownerId,
  });

  final String id;
  final String label;

  /// 椅子の中心。
  final FloorPoint position;

  /// Y 軸まわりの角度(ラジアン)。前方は (x, z) = (sin facing, cos facing)。
  final double facing;
  final String? ownerId;
}

class Person {
  const Person({
    required this.id,
    required this.displayName,
    required this.role,
    required this.model,
    required this.speed,
  });

  final String id;
  final String displayName;
  final String role;

  /// 素材の識別子(今回は箱/カプセル用の固定値)。
  final String model;

  /// 歩く速さ(m/s)。
  final double speed;
}

class Waypoint {
  const Waypoint({
    required this.id,
    required this.position,
    required this.neighbors,
  });

  final String id;
  final FloorPoint position;
  final List<String> neighbors;
}

class Route {
  const Route({
    required this.personId,
    required this.waypointIds,
    required this.loop,
  });

  final String personId;
  final List<String> waypointIds;
  final bool loop;
}

/// オフィスのデータの集約。描画ライブラリには依存しない。
class OfficeData {
  OfficeData({
    required this.floorSize,
    this.outerWallThickness = 0.2,
    required this.cycleLength,
    required List<Room> rooms,
    required List<Booking> bookings,
    required List<Seat> seats,
    required List<Person> people,
    required List<Waypoint> waypoints,
    required List<Route> routes,
  }) : rooms = List.unmodifiable(rooms),
       bookings = List.unmodifiable(bookings),
       seats = List.unmodifiable(seats),
       people = List.unmodifiable(people),
       waypoints = List.unmodifiable(waypoints),
       routes = List.unmodifiable(routes),
       _rooms = {for (final e in rooms) e.id: e},
       _seats = {for (final e in seats) e.id: e},
       _people = {for (final e in people) e.id: e},
       _waypoints = {for (final e in waypoints) e.id: e};

  final FloorSize floorSize;

  /// 外壁の厚み。外壁は床の四辺から導く。
  final double outerWallThickness;

  /// 仮想時刻の一巡の長さ。
  final Duration cycleLength;
  final List<Room> rooms;
  final List<Booking> bookings;
  final List<Seat> seats;
  final List<Person> people;
  final List<Waypoint> waypoints;
  final List<Route> routes;

  final Map<String, Room> _rooms;
  final Map<String, Seat> _seats;
  final Map<String, Person> _people;
  final Map<String, Waypoint> _waypoints;

  Room? roomById(String id) => _rooms[id];
  Seat? seatById(String id) => _seats[id];
  Person? personById(String id) => _people[id];
  Waypoint? waypointById(String id) => _waypoints[id];

  /// 会議室の予定(開始の昇順)。
  List<Booking> bookingsOf(String roomId) =>
      bookings.where((b) => b.roomId == roomId).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  /// ownerId が personId の席。
  Seat? seatOf(String personId) {
    for (final s in seats) {
      if (s.ownerId == personId) return s;
    }
    return null;
  }

  Route? routeOf(String personId) {
    for (final r in routes) {
      if (r.personId == personId) return r;
    }
    return null;
  }
}
