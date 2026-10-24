import 'dart:math' as math;

import '../data/office_models.dart';
import '../scene/label_placement.dart';
import '../scene/office_layout.dart';
import 'avatar_collision.dart';
import 'people_simulation.dart' show GaitStyle;

/// 操作できる人(自分)の id。データの表(人・席・会議室)には無い id にして、
/// クリックは「背景」扱いにする(entityRefForNodeName が null を返す)。
const String avatarId = 'player';
String avatarBodyNodeName() => '$avatarId#body';
String avatarNoseNodeName() => '$avatarId#nose';
String avatarTagNodeName() => '$avatarId#tag';
String avatarMarkNodeName() => '$avatarId#mark';

/// 起動時の位置。机の島の間の通路。
const FloorPoint defaultAvatarStart = FloorPoint(0, -3.0);

enum AvatarKey { forward, back, left, right }

/// 地面(X–Z 平面)での「画面の上」と「画面の右」。どちらも単位ベクトル。
class ViewAxes {
  const ViewAxes({
    required this.forwardX,
    required this.forwardZ,
    required this.rightX,
    required this.rightZ,
  });

  /// ワールドの +Z を上、+X を右とする。
  static const ViewAxes world = ViewAxes(
    forwardX: 0,
    forwardZ: 1,
    rightX: 1,
    rightZ: 0,
  );

  final double forwardX;
  final double forwardZ;
  final double rightX;
  final double rightZ;
}

/// 十字キーで動かせる人 1 人ぶんの状態。押下状態・位置・向き・歩きの揺れ。
/// 時間を進めるのは描画の毎フレーム([step])。ページは押下状態を書き換えるだけ。
class AvatarController {
  AvatarController(
    List<LayoutBox> boxes, {
    required this.floor,
    FloorPoint start = defaultAvatarStart,
    double startYaw = 0,
    this.speed = 1.5,
    this.turnRate = 12.0,
    this.maxDt = 0.1,
    this.radius = personRadius,
    this.gait = const GaitStyle(),
  }) : _obstacles = boxes.where(isObstacle).toList(growable: false),
       _x = start.x,
       _z = start.z,
       _yaw = _normalize(startYaw) {
    if (circleBlocked(_obstacles, floor, radius, start.x, start.z)) {
      throw ArgumentError('初期位置 (${start.x}, ${start.z}) が障害物に重なる');
    }
  }

  factory AvatarController.forOffice(
    OfficeData data, {
    LayoutStyle style = const LayoutStyle(),
  }) => AvatarController(
    buildOfficeLayout(data, style: style),
    floor: data.floorSize,
  );

  final FloorSize floor;

  /// m/s。
  final double speed;

  /// rad/s。向きを進行方向へ近づける最大角速度。
  final double turnRate;

  /// 1 回の step の dt の上限(PeopleSimulation と同じ規約)。
  /// `speed × maxDt` は円の直径より小さく保つ(薄い壁を飛び越えないため)。
  final double maxDt;
  final double radius;
  final GaitStyle gait;

  final List<LayoutBox> _obstacles;
  final Set<AvatarKey> _pressed = {};
  double _x;
  double _z;
  double _yaw;
  double _bob = 0;
  double _lean = 0;
  double _walked = 0;
  bool _walking = false;

  void setKey(AvatarKey key, bool pressed) {
    if (pressed) {
      _pressed.add(key);
    } else {
      _pressed.remove(key);
    }
  }

  bool isPressed(AvatarKey key) => _pressed.contains(key);

  void releaseAll() => _pressed.clear();

  double get x => _x;
  double get z => _z;
  FloorPoint get position => FloorPoint(_x, _z);

  /// (-π, π]。前方 = (sin yaw, cos yaw)。
  double get yaw => _yaw;

  /// m、0 以上。止まっていれば 0。
  double get bob => _bob;

  /// rad。止まっていれば 0。
  double get lean => _lean;

  /// 直近の step で 1mm より多く進んだか。
  bool get isWalking => _walking;

  void step(double dt, {ViewAxes view = ViewAxes.world}) {
    final d = dt.isNaN ? 0.0 : dt.clamp(0.0, maxDt);
    if (d <= 0) return;
    final ix =
        (isPressed(AvatarKey.right) ? 1 : 0) -
        (isPressed(AvatarKey.left) ? 1 : 0);
    final iy =
        (isPressed(AvatarKey.forward) ? 1 : 0) -
        (isPressed(AvatarKey.back) ? 1 : 0);
    var vx = view.forwardX * iy + view.rightX * ix;
    var vz = view.forwardZ * iy + view.rightZ * ix;
    final len = math.sqrt(vx * vx + vz * vz);
    var moved = 0.0;
    if (len > 1e-9) {
      vx /= len;
      vz /= len;
      final r = moveWithSlide(
        _obstacles,
        floor,
        radius,
        _x,
        _z,
        vx * speed * d,
        vz * speed * d,
      );
      moved = math.sqrt(math.pow(r.x - _x, 2) + math.pow(r.z - _z, 2));
      _x = r.x;
      _z = r.z;
      final diff = _normalize(math.atan2(vx, vz) - _yaw);
      final limit = turnRate * d;
      _yaw = _normalize(_yaw + diff.clamp(-limit, limit));
    }
    _walked += moved;
    _walking = moved > 0.001;
    if (_walking) {
      final phase = _walked / gait.strideLength * 2 * math.pi;
      _bob = gait.bobAmplitude * math.sin(phase).abs();
      _lean = gait.leanAmplitude * math.sin(phase);
    } else {
      _bob = 0;
      _lean = 0;
    }
  }

  static double _normalize(double a) {
    var r = a % (2 * math.pi);
    if (r > math.pi) r -= 2 * math.pi;
    if (r <= -math.pi) r += 2 * math.pi;
    return r;
  }
}
