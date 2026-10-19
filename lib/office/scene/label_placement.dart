import 'dart:math' as math;

import '../data/office_models.dart';
import 'office_layout.dart';

const double personHeight = 1.6;
const double personRadius = 0.25;

class Point3 {
  const Point3(this.x, this.y, this.z);
  final double x, y, z;
}

/// 名札・パネルの世界での大きさと隙間(m)。
class LabelStyle {
  const LabelStyle({
    this.tagWidth = 3.0,
    this.tagHeight = 0.9,
    this.tagGap = 0.15,
    this.panelWidth = 1.8,
    this.panelHeight = 1.2,
    this.panelCenterY = 1.4,
    this.panelWallGap = 0.05,
    this.panelDoorGap = 0.1,
  });

  final double tagWidth;
  final double tagHeight;

  /// 頭頂と名札の下端の間。
  final double tagGap;
  final double panelWidth;
  final double panelHeight;
  final double panelCenterY;

  /// 壁の外面からの距離。
  final double panelWallGap;

  /// ドア縁との間。
  final double panelDoorGap;
}

/// 名札の中心。人の (x, z) の真上。bob / lean / yaw は写さない。
Point3 tagCenter(FloorPoint person, {LabelStyle style = const LabelStyle()}) =>
    Point3(
      person.x,
      personHeight + style.tagGap + style.tagHeight / 2,
      person.z,
    );

class PanelPlacement {
  const PanelPlacement({
    required this.center,
    required this.side,
    required this.alongFrom,
    required this.alongTo,
  });

  final Point3 center;

  /// ドアのある辺。
  final RoomSide side;

  /// 壁に沿った区間(壁の中央からの符号付き距離。南北の壁 = +X、東西の壁 = +Z)。
  final double alongFrom;
  final double alongTo;
}

/// ドアのある辺の外側(通路側)、ドアの開口の隣。
PanelPlacement panelPlacement(
  Room room, {
  LabelStyle style = const LabelStyle(),
  LayoutStyle layout = const LayoutStyle(),
}) {
  final side = room.door.side;
  final alongX = side == RoomSide.south || side == RoomSide.north;
  final length = alongX
      ? room.size.width
      : room.size.depth - 2 * layout.roomWallThickness;
  final half = room.door.width / 2;
  final plusFrom = room.door.offset + half + style.panelDoorGap;
  final plusTo = plusFrom + style.panelWidth;
  final minusTo = room.door.offset - half - style.panelDoorGap;
  final minusFrom = minusTo - style.panelWidth;
  const eps = 1e-9;
  double from, to;
  if (plusTo <= length / 2 + eps) {
    from = plusFrom;
    to = plusTo;
  } else if (minusFrom >= -length / 2 - eps) {
    from = minusFrom;
    to = minusTo;
  } else {
    from = plusFrom;
    to = plusTo;
  }
  final mid = (from + to) / 2;
  final out = style.panelWallGap;
  final px = room.position.x;
  final pz = room.position.z;
  final w = room.size.width;
  final d = room.size.depth;
  final y = style.panelCenterY;
  final center = switch (side) {
    RoomSide.south => Point3(px + mid, y, pz - d / 2 - out),
    RoomSide.north => Point3(px + mid, y, pz + d / 2 + out),
    RoomSide.east => Point3(px + w / 2 + out, y, pz + mid),
    RoomSide.west => Point3(px - w / 2 - out, y, pz + mid),
  };
  return PanelPlacement(
    center: center,
    side: side,
    alongFrom: from,
    alongTo: to,
  );
}

/// 面の表側(ローカル −Z)が、視線方向 (viewDirX, viewDirZ) の逆を向くための
/// Y 軸まわりの回転角。水平成分がほぼ 0 なら 0。
double billboardYaw(double viewDirX, double viewDirZ) {
  if (math.sqrt(viewDirX * viewDirX + viewDirZ * viewDirZ) < 1e-6) return 0;
  return math.atan2(viewDirX, viewDirZ);
}
