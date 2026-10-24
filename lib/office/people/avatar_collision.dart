import 'dart:math' as math;

import '../data/office_models.dart';
import '../scene/office_layout.dart';

/// 自分(円)がぶつかる箱。床と会議室の床は歩けるので含めない。
bool isObstacle(LayoutBox box) =>
    box.kind == BoxKind.outerWall ||
    box.kind == BoxKind.roomWall ||
    box.kind == BoxKind.desk ||
    box.kind == BoxKind.chair;

/// 円(中心 [px], [pz]、半径 [r])が箱の長方形(床面への投影)と重なるか。接するだけは重ならない。
bool circleOverlapsBox(LayoutBox box, double px, double pz, double r) {
  final dx = px - box.center.x;
  final dz = pz - box.center.z;
  final c = math.cos(box.yaw);
  final s = math.sin(box.yaw);
  final lx = dx * c - dz * s;
  final lz = dx * s + dz * c;
  final nx = lx.clamp(-box.width / 2, box.width / 2);
  final nz = lz.clamp(-box.depth / 2, box.depth / 2);
  final ex = lx - nx;
  final ez = lz - nz;
  return ex * ex + ez * ez < r * r;
}

bool _blocked(
  List<LayoutBox> obstacles,
  FloorSize floor,
  double r,
  double x,
  double z,
) {
  if (x.abs() > floor.width / 2 - r || z.abs() > floor.depth / 2 - r) {
    return true;
  }
  for (final b in obstacles) {
    if (circleOverlapsBox(b, x, z, r)) return true;
  }
  return false;
}

/// 円が障害物か床の外に重なるか([obstacles] は [isObstacle] で絞ったもの)。
bool circleBlocked(
  List<LayoutBox> obstacles,
  FloorSize floor,
  double r,
  double x,
  double z,
) => _blocked(obstacles, floor, r, x, z);

/// (x, z) から (dx, dz) だけ動かす。X 軸 → Z 軸の順に別々に試し、通る軸だけ進める
/// (壁沿いの滑り)。止められた軸は、通れる最大の距離まで二分探索で詰める。
({double x, double z}) moveWithSlide(
  List<LayoutBox> obstacles,
  FloorSize floor,
  double r,
  double x,
  double z,
  double dx,
  double dz,
) {
  var nx = x;
  var nz = z;
  if (dx != 0) nx = _advance(obstacles, floor, r, x, z, dx, true);
  if (dz != 0) nz = _advance(obstacles, floor, r, nx, z, dz, false);
  return (x: nx, z: nz);
}

double _advance(
  List<LayoutBox> obstacles,
  FloorSize floor,
  double r,
  double x,
  double z,
  double delta,
  bool alongX,
) {
  double at(double t) => (alongX ? x : z) + delta * t;
  bool blockedAt(double t) => alongX
      ? _blocked(obstacles, floor, r, at(t), z)
      : _blocked(obstacles, floor, r, x, at(t));
  if (!blockedAt(1)) return at(1);
  var lo = 0.0;
  var hi = 1.0;
  for (var i = 0; i < 8; i++) {
    final mid = (lo + hi) / 2;
    if (blockedAt(mid)) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return at(lo);
}
