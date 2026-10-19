import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/people/people_simulation.dart';
import 'package:flutter_3d_demo/office/people/route_planner.dart';
import 'package:flutter_test/flutter_test.dart';

import 'people_test_data.dart';

double _angleDiff(double a, double b) {
  var d = (a - b) % (2 * math.pi);
  if (d > math.pi) d -= 2 * math.pi;
  if (d < -math.pi) d += 2 * math.pi;
  return d.abs();
}

/// 点 (x,z) と線分 a-b の距離。
double _distToSegment(double x, double z, FloorPoint a, FloorPoint b) {
  final dx = b.x - a.x;
  final dz = b.z - a.z;
  final len2 = dx * dx + dz * dz;
  var t = len2 == 0 ? 0.0 : ((x - a.x) * dx + (z - a.z) * dz) / len2;
  t = t.clamp(0.0, 1.0);
  return math.sqrt(
    math.pow(x - (a.x + t * dx), 2) + math.pow(z - (a.z + t * dz), 2),
  );
}

void main() {
  // 3 点ループ: 直角三角形 (0,0) → (3,0) → (3,4) → (0,0)
  final triPoints = {
    'a': const FloorPoint(0, 0),
    'b': const FloorPoint(3, 0),
    'c': const FloorPoint(3, 4),
  };
  final triEdges = [('a', 'b'), ('b', 'c'), ('c', 'a')];

  OfficeData triData({double speed = 1.5}) => smallData(
    points: triPoints,
    edges: triEdges,
    routes: {
      'p': ['a', 'b', 'c'],
    },
    speeds: {'p': speed},
  );

  group('AC1 Route の waypoint を順にたどる', () {
    test('位置が常に区間の線分上にあり、進んだ距離が speed×時間に一致する', () {
      final data = triData();
      final sim = PeopleSimulation(data);
      final w = sim.walkers.single;
      final segs = [
        (triPoints['a']!, triPoints['b']!),
        (triPoints['b']!, triPoints['c']!),
        (triPoints['c']!, triPoints['a']!),
      ];
      var px = w.x;
      var pz = w.z;
      var travelled = 0.0;
      for (var i = 0; i < 900; i++) {
        sim.step(1 / 30);
        travelled += math.sqrt(math.pow(w.x - px, 2) + math.pow(w.z - pz, 2));
        px = w.x;
        pz = w.z;
        final onEdge = segs.any(
          (s) => _distToSegment(w.x, w.z, s.$1, s.$2) < 1e-9,
        );
        expect(onEdge, isTrue, reason: 'step $i: (${w.x}, ${w.z})');
      }
      // 直線の区間内の移動は距離が一致する(角では弦になるため上限は speed×時間)。
      expect(w.walkedDistance, closeTo(1.5 * 30, 1e-6));
      expect(travelled, lessThanOrEqualTo(w.walkedDistance + 1e-9));
    });

    test('waypoint を順に通過し、末尾の次は先頭に向かう', () {
      final data = triData(speed: 1.0);
      final sim = PeopleSimulation(data, seed: 3);
      final w = sim.walkers.single;
      // 向かう waypoint(targetId)の切り替え = その waypoint を通過した、とみなす。
      final visited = <String>[];
      var prev = w.targetId;
      for (var i = 0; i < 30 * 30; i++) {
        sim.step(1 / 30);
        if (w.targetId != prev) {
          visited.add(prev!);
          prev = w.targetId;
        }
      }
      // 周長 12m、速度 1m/s で 30 秒 → 2 周半(頂点の通過は 7〜8 回)。
      expect(visited.length, greaterThanOrEqualTo(7));
      const order = ['a', 'b', 'c'];
      for (var i = 1; i < visited.length; i++) {
        final prevIdx = order.indexOf(visited[i - 1]);
        expect(visited[i], order[(prevIdx + 1) % 3]);
      }
    });
  });

  group('AC2 大きな dt', () {
    test('maxDt を超える dt は maxDt に丸められる', () {
      final sim = PeopleSimulation(triData());
      sim.step(100);
      expect(sim.elapsed, closeTo(0.1, 1e-12));
      expect(sim.walkers.single.walkedDistance, closeTo(0.15, 1e-9));
    });

    test('負・NaN の dt は 0 として扱う', () {
      final sim = PeopleSimulation(triData());
      sim.step(-1);
      sim.step(double.nan);
      expect(sim.elapsed, 0);
      expect(sim.walkers.single.walkedDistance, 0);
    });

    test('1 回の step が複数の短い区間をまたいでも、waypoint を飛ばさず辺の上にある', () {
      final points = {
        'a': const FloorPoint(0, 0),
        'b': const FloorPoint(0.05, 0),
        'c': const FloorPoint(0.05, 0.05),
      };
      final data = smallData(
        points: points,
        edges: [('a', 'b'), ('b', 'c'), ('c', 'a')],
        routes: {
          'p': ['a', 'b', 'c'],
        },
        speeds: {'p': 1.0},
      );
      final sim = PeopleSimulation(data, maxDt: 1.0);
      final w = sim.walkers.single;
      final segs = [
        (points['a']!, points['b']!),
        (points['b']!, points['c']!),
        (points['c']!, points['a']!),
      ];
      for (var i = 0; i < 200; i++) {
        sim.step(0.1); // 0.1m: 区間(0.05m)を複数またぐ
        final onEdge = segs.any(
          (s) => _distToSegment(w.x, w.z, s.$1, s.$2) < 1e-9,
        );
        expect(onEdge, isTrue);
      }
      expect(w.walkedDistance, closeTo(20.0, 1e-6));
    });

    test('dt が区間の残りより長いとき、waypoint にぴったり着いて次の区間へ持ち越す', () {
      final data = smallData(
        points: {'a': const FloorPoint(0, 0), 'b': const FloorPoint(1, 0)},
        edges: [('a', 'b')],
        routes: {
          'p': ['a', 'b'],
        },
        speeds: {'p': 1.0},
      );
      final sim = PeopleSimulation(data, maxDt: 5.0);
      final w = sim.walkers.single;
      sim.step(2.5); // 1m の往復 2 回 + 0.5m
      expect(w.walkedDistance, closeTo(2.5, 1e-9));
      expect(w.z, closeTo(0, 1e-9));
      expect(w.x, inInclusiveRange(0.0, 1.0));
    });
  });

  group('AC5 向きが進行方向に合う', () {
    final dirs = <String, FloorPoint>{
      '+X': const FloorPoint(5, 0),
      '-X': const FloorPoint(-5, 0),
      '+Z': const FloorPoint(0, 5),
      '-Z': const FloorPoint(0, -5),
    };
    for (final e in dirs.entries) {
      test('${e.key} 方向の区間で、0.3 秒後に yaw が進行方向と 5 度以内で一致する', () {
        final data = smallData(
          points: {'o': const FloorPoint(0, 0), 'd': e.value},
          edges: [('o', 'd')],
          routes: {
            'p': ['o', 'd'],
          },
        );
        final sim = PeopleSimulation(data);
        final w = sim.walkers.single;
        // 折り返し(区間の切り替え)を何度か通して確かめる。
        var checked = 0;
        var sinceSwitch = 0.0;
        var prevTarget = w.targetId;
        for (var i = 0; i < 30 * 40; i++) {
          sim.step(1 / 30);
          if (w.targetId != prevTarget) {
            sinceSwitch = 0;
            prevTarget = w.targetId;
          } else {
            sinceSwitch += 1 / 30;
          }
          if (sinceSwitch >= 0.3) {
            final out = w.targetId == 'd';
            final expected = out
                ? math.atan2(e.value.x, e.value.z)
                : math.atan2(-e.value.x, -e.value.z);
            expect(
              _angleDiff(w.yaw, expected) * 180 / math.pi,
              lessThanOrEqualTo(5),
              reason: 'step $i',
            );
            checked++;
          }
        }
        expect(checked, greaterThan(100));
      });
    }

    test('初期の yaw は最初の区間の向きで、開始直後に回転しない', () {
      final data = smallData(
        points: {'o': const FloorPoint(0, 0), 'd': const FloorPoint(-5, 0)},
        edges: [('o', 'd')],
        routes: {
          'p': ['o', 'd'],
        },
      );
      final w = PeopleSimulation(data).walkers.single;
      // 目標の waypoint に向かう向きで始まる(-X へ向かうなら -π/2、+X なら +π/2)。
      final expected = w.targetId == 'd' ? -math.pi / 2 : math.pi / 2;
      expect(_angleDiff(w.yaw, expected), lessThan(1e-9));
    });
  });

  group('AC6 停滞すると経路を作り直す', () {
    final points = {
      'wp-01': const FloorPoint(0, 0),
      'wp-02': const FloorPoint(4, 0),
      'wp-03': const FloorPoint(4, 4),
      'wp-04': const FloorPoint(8, 4),
    };
    final edges = [('wp-01', 'wp-02'), ('wp-02', 'wp-03'), ('wp-03', 'wp-04')];

    void expectReplanned(OfficeData data, String reason) {
      final sim = PeopleSimulation(data, maxDt: 0.1);
      final w = sim.walkers.single;
      final startX = w.x;
      final startZ = w.z;
      // window(3 秒)の手前まで: 動かず、再設定もしない。
      for (var i = 0; i < 29; i++) {
        sim.step(0.1);
      }
      expect(w.replanCount, 0, reason: reason);
      expect(w.x, startX, reason: reason);
      expect(w.z, startZ, reason: reason);
      // window に達する step で再設定される。
      sim.step(0.1);
      expect(w.replanCount, 1, reason: reason);
      final ids = w.routeIds;
      expect(ids.length, greaterThanOrEqualTo(2), reason: reason);
      for (var i = 0; i < ids.length; i++) {
        final a = data.waypointById(ids[i])!;
        final b = ids[(i + 1) % ids.length];
        expect(a.neighbors, contains(b), reason: reason);
      }
      // その後に動き出す。
      for (var i = 0; i < 20; i++) {
        sim.step(0.1);
      }
      expect(w.walkedDistance, greaterThan(1.0), reason: reason);
      expect(w.replanCount, 1, reason: reason);
    }

    test('存在しない waypoint だけの Route', () {
      expectReplanned(
        smallData(
          points: points,
          edges: edges,
          routes: {
            'p': ['xx-1', 'xx-2'],
          },
        ),
        '存在しない id',
      );
    });

    test('長さ 0 の区間だけの Route', () {
      expectReplanned(
        smallData(
          points: points,
          edges: edges,
          routes: {
            'p': ['wp-01', 'wp-01'],
          },
        ),
        '長さ 0',
      );
    });

    test('neighbors でつながらない並びの Route', () {
      expectReplanned(
        smallData(
          points: points,
          edges: edges,
          routes: {
            'p': ['wp-01', 'wp-04'],
          },
        ),
        '辺が無い',
      );
    });

    test('到達できる行き先が無いデータでは例外なく動かないまま', () {
      final data = smallData(
        points: {'only': const FloorPoint(1, 1)},
        edges: const [],
        routes: {
          'p': ['only', 'only'],
        },
      );
      final sim = PeopleSimulation(data);
      for (var i = 0; i < 100; i++) {
        sim.step(0.1);
      }
      final w = sim.walkers.single;
      expect(w.replanCount, 0);
      expect(w.walkedDistance, 0);
    });

    test('通常の Route では再設定されない', () {
      final sim = PeopleSimulation(triData());
      for (var i = 0; i < 30 * 60; i++) {
        sim.step(1 / 30);
      }
      expect(sim.walkers.single.replanCount, 0);
    });
  });

  group('route_planner', () {
    final data = smallData(
      points: {
        'a': const FloorPoint(0, 0),
        'b': const FloorPoint(1, 0),
        'c': const FloorPoint(2, 0),
        'd': const FloorPoint(1, 1),
        'x': const FloorPoint(9, 9),
      },
      edges: [('a', 'b'), ('b', 'c'), ('a', 'd'), ('d', 'c')],
      routes: const {},
    );

    test('shortestPath は辺の数が最小の経路を返す', () {
      expect(shortestPath(data, 'a', 'c'), hasLength(3));
      expect(shortestPath(data, 'a', 'b'), ['a', 'b']);
    });

    test('from == to は [from]', () {
      expect(shortestPath(data, 'a', 'a'), ['a']);
    });

    test('到達できない・実在しない id は null', () {
      expect(shortestPath(data, 'a', 'x'), isNull);
      expect(shortestPath(data, 'a', 'nope'), isNull);
      expect(shortestPath(data, 'nope', 'a'), isNull);
    });

    test('roundTripLoop は往復の周回にする', () {
      expect(roundTripLoop(['a', 'b', 'c']), ['a', 'b', 'c', 'b']);
      expect(roundTripLoop(['a', 'b']), ['a', 'b']);
      expect(() => roundTripLoop(['a']), throwsArgumentError);
    });
  });

  group('AC7 起動直後に人が重ならない', () {
    double minPair(PeopleSimulation sim) {
      var m = double.infinity;
      final ws = sim.walkers;
      for (var i = 0; i < ws.length; i++) {
        for (var j = i + 1; j < ws.length; j++) {
          m = math.min(m, ws[i].position.distanceTo(ws[j].position));
        }
      }
      return m;
    }

    test('既定データの開始時点で全員が 0.5m 以上離れている', () {
      expect(
        minPair(PeopleSimulation(dummyOfficeData)),
        greaterThanOrEqualTo(0.5),
      );
    });

    test('同じ seed なら同じ開始位置になる', () {
      final a = PeopleSimulation(dummyOfficeData, seed: 7);
      final b = PeopleSimulation(dummyOfficeData, seed: 7);
      for (var i = 0; i < a.walkers.length; i++) {
        expect(a.walkers[i].position, b.walkers[i].position);
      }
    });

    test('Route を持つ人の数だけ Walker があり、順序は data.people の順', () {
      final sim = PeopleSimulation(dummyOfficeData);
      expect(
        sim.walkers.map((w) => w.personId),
        dummyOfficeData.people.map((p) => p.id),
      );
      expect(sim.walkerOf('person-a'), isNotNull);
      expect(sim.walkerOf('nobody'), isNull);
    });
  });

  group('揺れ', () {
    test('歩いている間は bob が 0 以上 bobAmplitude 以下で、止まっていれば 0', () {
      final sim = PeopleSimulation(triData());
      final w = sim.walkers.single;
      expect(w.bob, 0);
      var maxBob = 0.0;
      for (var i = 0; i < 300; i++) {
        sim.step(1 / 30);
        expect(w.bob, inInclusiveRange(0.0, 0.05 + 1e-12));
        expect(w.lean.abs(), lessThanOrEqualTo(0.06 + 1e-12));
        maxBob = math.max(maxBob, w.bob);
      }
      expect(maxBob, greaterThan(0.03));
    });
  });

  group('AC9 people/ は純 Dart', () {
    test('lib/office/people は flutter 系を import しない', () {
      final files = Directory('lib/office/people')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(files, isNotEmpty);
      for (final f in files) {
        final src = f.readAsStringSync();
        for (final bad in [
          'package:flutter/',
          'package:flutter_scene',
          'dart:ui',
          'vector_math',
          'DateTime',
        ]) {
          expect(src, isNot(contains(bad)), reason: '${f.path}: $bad');
        }
      }
    });

    test(
      'lib/office で flutter_scene を import するのは office_scene_builder.dart だけ',
      () {
        final files = Directory('lib/office')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
        final users = files
            .where(
              (f) => f.readAsStringSync().contains('package:flutter_scene'),
            )
            .map((f) => f.path.split('/').last)
            .toList();
        expect(users, ['office_scene_builder.dart']);
      },
    );
  });
}
