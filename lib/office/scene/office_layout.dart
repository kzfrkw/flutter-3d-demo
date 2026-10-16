import 'dart:math' as math;

import '../data/office_models.dart';

enum BoxKind { floor, outerWall, roomWall, desk, chair }

/// シーンに置く箱 1 つ。描画ライブラリに依存しない設計図。
class LayoutBox {
  const LayoutBox({
    required this.id,
    required this.kind,
    this.ref,
    required this.center,
    required this.bottomY,
    required this.width,
    required this.height,
    required this.depth,
    this.yaw = 0,
    required this.color,
  });

  /// 箱の一意な名前(Node.name に使う)。entity 付きは `<entityId>#<部位>`。
  final String id;
  final BoxKind kind;

  /// 元になったエンティティ。床・外壁は null。
  final EntityRef? ref;
  final FloorPoint center;
  final double bottomY;

  /// 箱のローカル軸(X, Y, Z)の寸法。
  final double width;
  final double height;
  final double depth;

  /// Y 軸まわりの角度。Seat.facing と同じ向きの決まり。
  final double yaw;

  /// 0xAARRGGBB
  final int color;

  /// yaw を考慮した、床面上の内外判定(境界は内側)。
  bool containsPoint(FloorPoint p) {
    final dx = p.x - center.x;
    final dz = p.z - center.z;
    final c = math.cos(yaw);
    final s = math.sin(yaw);
    final lx = dx * c - dz * s;
    final lz = dx * s + dz * c;
    return lx.abs() <= width / 2 && lz.abs() <= depth / 2;
  }
}

/// 寸法と色のつまみ。
class LayoutStyle {
  const LayoutStyle({
    this.floorThickness = 0.1,
    this.outerWallHeight = 1.0,
    this.roomWallHeight = 2.0,
    this.roomWallThickness = 0.15,
    this.deskSize = const FloorSize(1.4, 0.8),
    this.deskHeight = 0.75,
    this.deskOffset = 0.75,
    this.chairSize = const FloorSize(0.5, 0.5),
    this.chairHeight = 0.45,
    this.floorColor = 0xFFE8E2D4,
    this.outerWallColor = 0xFFB8BEC8,
    this.roomWallColor = 0xFF6C8EBF,
    this.deskColor = 0xFFA9825A,
    this.chairColor = 0xFF3C4350,
  });

  final double floorThickness;
  final double outerWallHeight;
  final double roomWallHeight;
  final double roomWallThickness;
  final FloorSize deskSize;
  final double deskHeight;

  /// 机の中心 = 椅子の位置 + 前方 × deskOffset。
  final double deskOffset;
  final FloorSize chairSize;
  final double chairHeight;
  final int floorColor;
  final int outerWallColor;
  final int roomWallColor;
  final int deskColor;
  final int chairColor;
}

/// [data] から置く箱の一覧を作る。ID・位置・大きさ・向き・ドアだけを読む。
/// 順序は floor、outerWall、roomWall、desk と chair。
List<LayoutBox> buildOfficeLayout(
  OfficeData data, {
  LayoutStyle style = const LayoutStyle(),
}) {
  final boxes = <LayoutBox>[];
  final fw = data.floorSize.width;
  final fd = data.floorSize.depth;

  boxes.add(
    LayoutBox(
      id: 'floor',
      kind: BoxKind.floor,
      center: const FloorPoint(0, 0),
      bottomY: -style.floorThickness,
      width: fw,
      height: style.floorThickness,
      depth: fd,
      color: style.floorColor,
    ),
  );

  final ot = data.outerWallThickness;
  LayoutBox outer(String name, double cx, double cz, double w, double d) =>
      LayoutBox(
        id: 'outer-wall#$name',
        kind: BoxKind.outerWall,
        center: FloorPoint(cx, cz),
        bottomY: 0,
        width: w,
        height: style.outerWallHeight,
        depth: d,
        color: style.outerWallColor,
      );
  boxes
    ..add(outer('north', 0, fd / 2 - ot / 2, fw, ot))
    ..add(outer('south', 0, -fd / 2 + ot / 2, fw, ot))
    ..add(outer('east', fw / 2 - ot / 2, 0, ot, fd - 2 * ot))
    ..add(outer('west', -fw / 2 + ot / 2, 0, ot, fd - 2 * ot));

  for (final room in data.rooms) {
    boxes.addAll(_roomWalls(room, style));
  }

  for (final seat in data.seats) {
    final ref = EntityRef(EntityKind.seat, seat.id);
    final fx = math.sin(seat.facing);
    final fz = math.cos(seat.facing);
    boxes.add(
      LayoutBox(
        id: '${seat.id}#desk',
        kind: BoxKind.desk,
        ref: ref,
        center: FloorPoint(
          seat.position.x + fx * style.deskOffset,
          seat.position.z + fz * style.deskOffset,
        ),
        bottomY: 0,
        width: style.deskSize.width,
        height: style.deskHeight,
        depth: style.deskSize.depth,
        yaw: seat.facing,
        color: style.deskColor,
      ),
    );
    boxes.add(
      LayoutBox(
        id: '${seat.id}#chair',
        kind: BoxKind.chair,
        ref: ref,
        center: seat.position,
        bottomY: 0,
        width: style.chairSize.width,
        height: style.chairHeight,
        depth: style.chairSize.depth,
        yaw: seat.facing,
        color: style.chairColor,
      ),
    );
  }
  return boxes;
}

List<LayoutBox> _roomWalls(Room room, LayoutStyle style) {
  final t = style.roomWallThickness;
  final w = room.size.width;
  final d = room.size.depth;
  final px = room.position.x;
  final pz = room.position.z;
  final ref = EntityRef(EntityKind.room, room.id);

  // (辺, 壁の中心, 壁に沿う長さ)。南北=全幅、東西=奥行き−2×厚み。
  final sides = <(RoomSide, FloorPoint, double)>[
    (RoomSide.south, FloorPoint(px, pz - d / 2 + t / 2), w),
    (RoomSide.north, FloorPoint(px, pz + d / 2 - t / 2), w),
    (RoomSide.east, FloorPoint(px + w / 2 - t / 2, pz), d - 2 * t),
    (RoomSide.west, FloorPoint(px - w / 2 + t / 2, pz), d - 2 * t),
  ];

  final walls = <LayoutBox>[];
  for (final (side, center, length) in sides) {
    final alongX = side == RoomSide.south || side == RoomSide.north;
    // 壁に沿った区間 [from, to](壁の中央からの距離)の箱を作る。
    LayoutBox segment(String name, double from, double to) {
      final mid = (from + to) / 2;
      final len = to - from;
      return LayoutBox(
        id: '${room.id}#$name',
        kind: BoxKind.roomWall,
        ref: ref,
        center: alongX
            ? FloorPoint(center.x + mid, center.z)
            : FloorPoint(center.x, center.z + mid),
        bottomY: 0,
        width: alongX ? len : t,
        height: style.roomWallHeight,
        depth: alongX ? t : len,
        color: style.roomWallColor,
      );
    }

    final name = 'wall-${side.name}';
    if (side != room.door.side) {
      walls.add(segment(name, -length / 2, length / 2));
      continue;
    }
    final door = room.door;
    final lo = door.offset - door.width / 2;
    final hi = door.offset + door.width / 2;
    if (door.width <= 0 || lo < -length / 2 || hi > length / 2) {
      throw ArgumentError(
        '${room.id}: ドア(offset=${door.offset}, width=${door.width})が '
        '壁の長さ $length に収まらない',
      );
    }
    const eps = 1e-9;
    if (lo - (-length / 2) > eps)
      walls.add(segment('$name-1', -length / 2, lo));
    if (length / 2 - hi > eps) walls.add(segment('$name-2', hi, length / 2));
  }
  return walls;
}
