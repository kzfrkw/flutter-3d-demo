import 'dart:math' as math;

import '../data/office_models.dart';

/// シーンの枠。中心と、全体が収まる半径(reach)。目の距離・ズーム 1 の見える範囲の基準。
class OrbitFrame {
  const OrbitFrame({
    required this.centerX,
    required this.centerY,
    required this.centerZ,
    required this.reach,
  });

  /// 箱の AABB から。reach = 対角線の半分 × 1.1(OrthographicCamera.framing と同じ)。
  factory OrbitFrame.fromBounds({
    required double minX,
    required double minY,
    required double minZ,
    required double maxX,
    required double maxY,
    required double maxZ,
  }) {
    final dx = maxX - minX;
    final dy = maxY - minY;
    final dz = maxZ - minZ;
    return OrbitFrame(
      centerX: (minX + maxX) / 2,
      centerY: (minY + maxY) / 2,
      centerZ: (minZ + maxZ) / 2,
      reach: math.sqrt(dx * dx + dy * dy + dz * dz) / 2 * 1.1,
    );
  }

  final double centerX;
  final double centerY;
  final double centerZ;
  final double reach;

  /// 目から注視点までの距離。
  double get distance => 2 * reach;

  /// 近面は 0。
  double get farDistance => 4 * reach;

  /// 注視点(Y は常に centerY)。
  ({double x, double y, double z}) target(OrbitPose pose) =>
      (x: pose.targetX, y: centerY, z: pose.targetZ);

  /// 目 = 注視点 + 距離 × 向き。
  ({double x, double y, double z}) eye(OrbitPose pose) {
    final h = _horizontal(pose.azimuth);
    final cp = math.cos(pose.pitch);
    return (
      x: pose.targetX + distance * cp * h.x,
      y: centerY + distance * math.sin(pose.pitch),
      z: pose.targetZ + distance * cp * h.z,
    );
  }

  /// 視線方向(単位ベクトル。注視点 - 目)。
  ({double x, double y, double z}) forward(OrbitPose pose) {
    final h = _horizontal(pose.azimuth);
    final cp = math.cos(pose.pitch);
    return (x: -cp * h.x, y: -math.sin(pose.pitch), z: -cp * h.z);
  }

  /// ズーム込みの「画面 1px あたりのワールド長」。
  double unitsPerPixel(
    OrbitPose pose, {
    required double viewWidth,
    required double viewHeight,
  }) {
    final side = math.min(viewWidth, viewHeight);
    if (!(side > 0)) return 0;
    return (2 * reach / pose.zoom) / side;
  }
}

/// 方位 [azimuth] での、注視点から目への水平の単位ベクトル。
/// 方位 0 = (0.35, -1) の向き。正の値は `rotateAboutY`(camera_yaw.dart)と同じ向きに回す。
({double x, double z}) _horizontal(double azimuth) {
  final n = math.sqrt(0.35 * 0.35 + 1);
  final bx = 0.35 / n;
  final bz = -1 / n;
  final c = math.cos(azimuth);
  final s = math.sin(azimuth);
  return (x: bx * c + bz * s, z: -bx * s + bz * c);
}

/// 上限。注視点の範囲は床 ± margin。
class OrbitLimits {
  const OrbitLimits({
    this.minPitch = _defaultMinPitch,
    this.maxPitch = _defaultMaxPitch,
    this.minZoom = 0.6,
    this.maxZoom = 4.0,
    required this.minX,
    required this.maxX,
    required this.minZ,
    required this.maxZ,
  });

  /// 床の大きさから導出(注視点の範囲 = 床 ± margin)。
  factory OrbitLimits.forFloor(FloorSize floor, {double margin = 1.0}) =>
      OrbitLimits(
        minX: -floor.width / 2 - margin,
        maxX: floor.width / 2 + margin,
        minZ: -floor.depth / 2 - margin,
        maxZ: floor.depth / 2 + margin,
      );

  static const double _defaultMinPitch = 15 * math.pi / 180;
  static const double _defaultMaxPitch = 80 * math.pi / 180;

  final double minPitch;
  final double maxPitch;
  final double minZoom;
  final double maxZoom;
  final double minX;
  final double maxX;
  final double minZ;
  final double maxZ;
}

/// カメラの姿勢。不変。
class OrbitPose {
  const OrbitPose({
    required this.azimuth,
    required this.pitch,
    required this.zoom,
    required this.targetX,
    required this.targetZ,
  });

  /// 方位(ラジアン、(-π, π])。
  final double azimuth;

  /// 仰角(水平面からの角度。0 = 水平、π/2 = 真上)。
  final double pitch;

  /// 1 = 全体が収まる。
  final double zoom;
  final double targetX;
  final double targetZ;

  @override
  bool operator ==(Object other) =>
      other is OrbitPose &&
      other.azimuth == azimuth &&
      other.pitch == pitch &&
      other.zoom == zoom &&
      other.targetX == targetX &&
      other.targetZ == targetZ;

  @override
  int get hashCode => Object.hash(azimuth, pitch, zoom, targetX, targetZ);

  @override
  String toString() =>
      'OrbitPose(az=$azimuth, pitch=$pitch, zoom=$zoom, '
      'target=($targetX, $targetZ))';
}

/// 初期姿勢。方位 = yawDegrees(?cameraYaw)、仰角 = T4 までの固定カメラ
/// direction(0.35, 0.9, -1) と同じ、ズーム 1、注視点 = 枠の中心。
OrbitPose initialPose(OrbitFrame frame, {double yawDegrees = 0}) => OrbitPose(
  azimuth: _normalizeAngle(yawDegrees * math.pi / 180),
  pitch: math.atan2(0.9, math.sqrt(0.35 * 0.35 + 1)),
  zoom: 1,
  targetX: frame.centerX,
  targetZ: frame.centerZ,
);

double _normalizeAngle(double a) {
  var r = a % (2 * math.pi);
  if (r > math.pi) r -= 2 * math.pi;
  if (r <= -math.pi) r += 2 * math.pi;
  return r;
}

/// 入力(ドラッグ・ホイール・ピンチ)を姿勢に反映する。上限は毎回かける。
/// NaN・無限大の入力は無視する(状態を変えない)。
class CameraOrbit {
  CameraOrbit({
    required this.frame,
    required this.limits,
    required OrbitPose initial,
  }) : _initial = initial,
       _pose = initial;

  /// 感度。値は触り心地で調整してよい。
  static const double azimuthPerPixel = 0.006;
  static const double pitchPerPixel = 0.005;
  static const double scrollZoomPerPixel = 0.0015;

  final OrbitFrame frame;
  final OrbitLimits limits;
  final OrbitPose _initial;
  OrbitPose _pose;

  OrbitPose get pose => _pose;
  OrbitPose get initial => _initial;

  /// ドラッグ(px)。dx>0(右へ)→ azimuth 増。dy>0(下へ)→ pitch 増(より見下ろす)。
  void rotate(double dx, double dy) {
    if (!dx.isFinite || !dy.isFinite) return;
    final az = _pose.azimuth + dx * azimuthPerPixel;
    final pitch = _pose.pitch + dy * pitchPerPixel;
    if (!az.isFinite || !pitch.isFinite) return;
    _set(azimuth: az, pitch: pitch);
  }

  /// factor>1 で拡大、<1 で縮小。1 回の倍率は [1/4, 4] に丸める。
  void zoomBy(double factor) {
    if (!factor.isFinite || factor <= 0) return;
    _set(zoom: _pose.zoom * factor.clamp(0.25, 4.0));
  }

  /// ホイール。dy<0(奥へ回す)→ 拡大、dy>0 → 縮小。
  void zoomByScroll(double scrollDy) {
    if (!scrollDy.isFinite) return;
    final e = (-scrollDy * scrollZoomPerPixel).clamp(-10.0, 10.0);
    zoomBy(math.exp(e));
  }

  /// ドラッグ(px)に追従して注視点を床面上で動かす。dx>0(右へ)→ シーンが右へ、
  /// dy>0(下へ)→ 注視点は奥(視線の水平方向)へ。縦は 1/sin(pitch) 倍。
  void pan(
    double dx,
    double dy, {
    required double viewWidth,
    required double viewHeight,
  }) {
    if (!dx.isFinite || !dy.isFinite) return;
    final upp = frame.unitsPerPixel(
      _pose,
      viewWidth: viewWidth,
      viewHeight: viewHeight,
    );
    if (!(upp > 0) || !upp.isFinite) return;
    final f = frame.forward(_pose);
    final fl = math.sqrt(f.x * f.x + f.z * f.z);
    if (fl == 0) return;
    final fx = f.x / fl;
    final fz = f.z / fl;
    // 画面の右 = (fz, -fx)。
    final rx = fz;
    final rz = -fx;
    final vy = dy * upp / math.sin(_pose.pitch);
    final tx = _pose.targetX - rx * dx * upp + fx * vy;
    final tz = _pose.targetZ - rz * dx * upp + fz * vy;
    if (!tx.isFinite || !tz.isFinite) return;
    _set(targetX: tx, targetZ: tz);
  }

  void reset() => _pose = _initial;

  void _set({
    double? azimuth,
    double? pitch,
    double? zoom,
    double? targetX,
    double? targetZ,
  }) {
    _pose = OrbitPose(
      azimuth: _normalizeAngle(azimuth ?? _pose.azimuth),
      pitch: (pitch ?? _pose.pitch).clamp(limits.minPitch, limits.maxPitch),
      zoom: (zoom ?? _pose.zoom).clamp(limits.minZoom, limits.maxZoom),
      targetX: (targetX ?? _pose.targetX).clamp(limits.minX, limits.maxX),
      targetZ: (targetZ ?? _pose.targetZ).clamp(limits.minZ, limits.maxZ),
    );
  }
}
