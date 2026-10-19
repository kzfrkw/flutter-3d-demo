import 'dart:math' as math;

import '../data/office_models.dart';
import 'route_planner.dart';

/// 歩きの見た目のつまみ。
class GaitStyle {
  const GaitStyle({
    this.turnRate = 12.0,
    this.strideLength = 1.4,
    this.bobAmplitude = 0.05,
    this.leanAmplitude = 0.06,
  });

  /// rad/s。向きの補間の最大角速度(180° が約 0.26 秒)。
  final double turnRate;

  /// m。揺れ 1 周期(= 2 歩)ぶんの歩幅。
  final double strideLength;

  /// m。上下の揺れの最大。
  final double bobAmplitude;

  /// rad。左右の傾きの最大。
  final double leanAmplitude;
}

/// 停滞の判定のつまみ。
class StallConfig {
  const StallConfig({this.window = 3.0, this.minDistance = 0.5});

  /// s。この時間ごとに判定する(重ならない窓)。
  final double window;

  /// m。窓の間に歩いた距離がこれ未満なら停滞。
  final double minDistance;
}

/// 1 人ぶんの歩行の状態。[PeopleSimulation] だけが書き換える。
class Walker {
  Walker._(this.personId, this.speed);

  final String personId;

  /// Person.speed(m/s)。
  final double speed;

  double _x = 0;
  double _z = 0;
  double _yaw = 0;
  double _bob = 0;
  double _lean = 0;
  bool _walking = false;
  bool _finished = false;
  double _walked = 0;
  int _replans = 0;

  // 経路: waypoint id の周回リスト、その座標、目標の添字。区間は「現在位置 → ids[target]」。
  List<String> _ids = const [];
  List<FloorPoint> _pts = const [];
  int _target = 0;
  bool _loops = true;
  bool _valid = false;
  String? _standId;

  double _windowTime = 0;
  double _windowDist = 0;

  /// 床面上の位置(毎回新しい FloorPoint)。
  FloorPoint get position => FloorPoint(_x, _z);
  double get x => _x;
  double get z => _z;

  /// 表示する向き。範囲 (-π, π]。前方 = (sin yaw, cos yaw)。
  double get yaw => _yaw;

  /// 上下の揺れ(m, 0 以上)。止まっていれば 0。
  double get bob => _bob;

  /// 前方軸まわりの傾き(rad)。止まっていれば 0。
  double get lean => _lean;

  /// 直近の step で 1 mm でも進んだか(非ループの終点では false)。
  bool get isWalking => _walking;

  /// 生成からの歩いた距離の合計(m)。
  double get walkedDistance => _walked;

  /// 停滞で経路を作り直した回数(通常は 0)。
  int get replanCount => _replans;

  /// 今の周回経路の waypoint id(読み取り専用)。
  List<String> get routeIds => List.unmodifiable(_ids);

  /// 今の経路がループか。
  bool get routeLoops => _loops;

  /// 今向かっている waypoint の id。経路が無効で動けないときは null。
  String? get targetId => _valid ? _ids[_target] : null;
}

class PeopleSimulation {
  PeopleSimulation(
    this.data, {
    int seed = 1,
    this.maxDt = 0.1,
    double minStartSeparation = 0.6,
    this.gait = const GaitStyle(),
    this.stall = const StallConfig(),
  }) : _replanRandom = math.Random(seed ^ 0x5EED) {
    _placeAll(math.Random(seed), minStartSeparation);
  }

  final OfficeData data;

  /// s。1 回の step で進める時間の上限。
  final double maxDt;
  final GaitStyle gait;
  final StallConfig stall;

  final math.Random _replanRandom;
  final List<Walker> _walkers = [];
  late final List<Walker> walkers = List.unmodifiable(_walkers);
  final Map<String, Walker> _byId = {};
  double _elapsed = 0;

  Walker? walkerOf(String personId) => _byId[personId];

  /// step した時間の合計(丸めた後の dt)。
  double get elapsed => _elapsed;

  /// 時間を進める。dt は 0〜maxDt に丸める(負・NaN は 0)。
  void step(double dt) {
    final d = dt.isNaN ? 0.0 : dt.clamp(0.0, maxDt);
    if (d <= 0) return;
    _elapsed += d;
    for (final w in _walkers) {
      _advance(w, d);
    }
  }

  // ---- 移動 ----

  void _advance(Walker w, double d) {
    var moved = 0.0;
    if (w._valid && !w._finished) {
      var remaining = w.speed * d;
      var guard = w._ids.length + 1;
      while (remaining > 0 && guard-- > 0 && !w._finished) {
        final t = w._pts[w._target];
        final dx = t.x - w._x;
        final dz = t.z - w._z;
        final dist = math.sqrt(dx * dx + dz * dz);
        if (remaining >= dist) {
          w._x = t.x;
          w._z = t.z;
          remaining -= dist;
          moved += dist;
          _arrive(w);
        } else {
          w._x += dx / dist * remaining;
          w._z += dz / dist * remaining;
          moved += remaining;
          remaining = 0;
        }
      }
    }
    w._walked += moved;
    w._walking = moved > 0.001;
    _turn(w, d);
    _gait(w);
    _watchStall(w, d, moved);
  }

  void _arrive(Walker w) {
    final next = w._target + 1;
    if (next >= w._ids.length) {
      if (w._loops) {
        w._target = 0;
      } else {
        w._finished = true;
      }
    } else {
      w._target = next;
    }
  }

  // ---- 向き ----

  void _turn(Walker w, double d) {
    if (!w._valid || w._finished) return;
    final t = w._pts[w._target];
    final dx = t.x - w._x;
    final dz = t.z - w._z;
    if (dx == 0 && dz == 0) return;
    final diff = _normalize(math.atan2(dx, dz) - w._yaw);
    final limit = gait.turnRate * d;
    w._yaw = _normalize(w._yaw + diff.clamp(-limit, limit));
  }

  /// 角度を (-π, π] にする。
  static double _normalize(double a) {
    var r = a % (2 * math.pi);
    if (r > math.pi) r -= 2 * math.pi;
    if (r <= -math.pi) r += 2 * math.pi;
    return r;
  }

  // ---- 揺れ ----

  void _gait(Walker w) {
    if (!w._walking) {
      w._bob = 0;
      w._lean = 0;
      return;
    }
    final phase = w._walked / gait.strideLength * 2 * math.pi;
    w._bob = gait.bobAmplitude * math.sin(phase).abs();
    w._lean = gait.leanAmplitude * math.sin(phase);
  }

  // ---- 停滞の検出と再設定 ----

  void _watchStall(Walker w, double d, double moved) {
    if (w._valid && w._finished) return;
    w._windowTime += d;
    w._windowDist += moved;
    if (w._windowTime < stall.window - 1e-9) return;
    final stalled = w._windowDist < stall.minDistance;
    w._windowTime = 0;
    w._windowDist = 0;
    if (stalled) _replan(w);
  }

  void _replan(Walker w) {
    final anchor = w._valid ? w._ids[w._target] : w._standId;
    if (anchor == null) return;
    final candidates = reachableFrom(data, anchor);
    if (candidates.isEmpty) return;
    final dest = candidates[_replanRandom.nextInt(candidates.length)];
    final path = shortestPath(data, anchor, dest);
    if (path == null || path.length < 2) return;
    final ids = roundTripLoop(path);
    final pts = _pointsOf(ids);
    if (pts == null) return;
    w
      .._ids = ids
      .._pts = pts
      .._target = 0
      .._loops = true
      .._valid = true
      .._finished = false
      .._replans += 1;
  }

  // ---- 開始位置 ----

  List<FloorPoint>? _pointsOf(List<String> ids) {
    final pts = <FloorPoint>[];
    for (final id in ids) {
      final wp = data.waypointById(id);
      if (wp == null) return null;
      pts.add(wp.position);
    }
    return pts;
  }

  /// 有効な Route の条件: 2 点以上、全 id が実在、隣り合う点が neighbors でつながる、
  /// 区間の長さの合計が 0 より大きい。
  bool _isValid(List<String> ids, List<FloorPoint>? pts, bool loop) {
    if (pts == null || ids.length < 2) return false;
    final count = loop ? ids.length : ids.length - 1;
    var total = 0.0;
    for (var i = 0; i < count; i++) {
      final a = ids[i];
      final b = ids[(i + 1) % ids.length];
      if (!data.waypointById(a)!.neighbors.contains(b)) return false;
      total += pts[i].distanceTo(pts[(i + 1) % ids.length]);
    }
    return total > 0;
  }

  void _placeAll(math.Random random, double minSep) {
    final placed = <FloorPoint>[];
    for (final person in data.people) {
      final route = data.routeOf(person.id);
      if (route == null) continue;
      final ids = List<String>.of(route.waypointIds);
      final pts = _pointsOf(ids);
      final w = Walker._(person.id, person.speed)
        .._ids = ids
        .._loops = route.loop;
      if (pts != null) w._pts = pts;

      if (_isValid(ids, pts, route.loop)) {
        w._valid = true;
        _placeOnRoute(w, random, minSep, placed);
      } else {
        // 無効な Route: 動けない。最初に実在する waypoint(無ければ先頭)に立つ。
        String? stand;
        for (final id in ids) {
          if (data.waypointById(id) != null) {
            stand = id;
            break;
          }
        }
        stand ??= data.waypoints.isEmpty ? null : data.waypoints.first.id;
        if (stand == null) continue;
        final p = data.waypointById(stand)!.position;
        w
          .._standId = stand
          .._x = p.x
          .._z = p.z;
      }
      _walkers.add(w);
      _byId[w.personId] = w;
    }
  }

  void _placeOnRoute(
    Walker w,
    math.Random random,
    double minSep,
    List<FloorPoint> placed,
  ) {
    final n = w._ids.length;
    final count = w._loops ? n : n - 1;
    final lens = [
      for (var i = 0; i < count; i++) w._pts[i].distanceTo(w._pts[(i + 1) % n]),
    ];
    final total = lens.fold(0.0, (a, b) => a + b);

    (FloorPoint, int) at(double s) {
      var acc = 0.0;
      for (var i = 0; i < count; i++) {
        if (s <= acc + lens[i] || i == count - 1) {
          final len = lens[i];
          final t = len == 0 ? 0.0 : ((s - acc) / len).clamp(0.0, 1.0);
          final a = w._pts[i];
          final b = w._pts[(i + 1) % n];
          return (
            FloorPoint(a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t),
            (i + 1) % n,
          );
        }
        acc += lens[i];
      }
      throw StateError('unreachable');
    }

    double nearest(FloorPoint p) => placed.isEmpty
        ? double.infinity
        : placed.map((o) => o.distanceTo(p)).reduce(math.min);

    (FloorPoint, int)? best;
    var bestScore = -1.0;
    for (var attempt = 0; attempt < 50; attempt++) {
      final cand = at(random.nextDouble() * total);
      final score = nearest(cand.$1);
      if (score > bestScore) {
        best = cand;
        bestScore = score;
      }
      if (score >= minSep) break;
    }
    final (p, target) = best!;
    w
      .._x = p.x
      .._z = p.z
      .._target = target;
    placed.add(p);
    final t = w._pts[target];
    w._yaw = math.atan2(t.x - p.x, t.z - p.z);
    if (t.x == p.x && t.z == p.z) w._yaw = 0;
  }
}
