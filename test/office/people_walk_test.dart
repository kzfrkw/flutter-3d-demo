import 'dart:math' as math;

import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/people/people_count.dart';
import 'package:flutter_3d_demo/office/people/people_simulation.dart';
import 'package:flutter_3d_demo/office/scene/office_layout.dart';
import 'package:flutter_test/flutter_test.dart';

const _radius = 0.25;

/// 人の半径ぶん広げた、壁・机・椅子の箱。
List<LayoutBox> _obstacles(OfficeData data) => [
  for (final b in buildOfficeLayout(data))
    if (b.kind != BoxKind.floor && b.kind != BoxKind.roomFloor)
      LayoutBox(
        id: b.id,
        kind: b.kind,
        center: b.center,
        bottomY: b.bottomY,
        width: b.width + 2 * _radius,
        height: b.height,
        depth: b.depth + 2 * _radius,
        yaw: b.yaw,
        color: b.color,
      ),
];

void main() {
  final tenData = withPeopleCount(dummyOfficeData, 10);
  final cases = <String, OfficeData>{
    '既定の 6 人': dummyOfficeData,
    '10 人': tenData,
  };

  group('AC3a グラフの辺は壁・机から人の半径ぶん離れている', () {
    for (final entry in cases.entries) {
      test('${entry.key}: 全 Route の区間と全 neighbors の辺', () {
        final data = entry.value;
        final obstacles = _obstacles(data);
        void checkEdge(String a, String b) {
          final pa = data.waypointById(a)!.position;
          final pb = data.waypointById(b)!.position;
          final len = pa.distanceTo(pb);
          final n = math.max(1, (len / 0.05).ceil());
          for (var i = 0; i <= n; i++) {
            final t = i / n;
            final p = FloorPoint(
              pa.x + (pb.x - pa.x) * t,
              pa.z + (pb.z - pa.z) * t,
            );
            for (final box in obstacles) {
              expect(
                box.containsPoint(p),
                isFalse,
                reason: '$a-$b が ${box.id} に当たる: $p',
              );
            }
          }
        }

        for (final r in data.routes) {
          final ids = r.waypointIds;
          for (var i = 0; i < ids.length; i++) {
            if (!r.loop && i == ids.length - 1) break;
            checkEdge(ids[i], ids[(i + 1) % ids.length]);
          }
        }
        for (final w in data.waypoints) {
          for (final n in w.neighbors) {
            checkEdge(w.id, n);
          }
        }
      });
    }
  });

  for (final entry in cases.entries) {
    group('5 分のシミュレーション(${entry.key})', () {
      final data = entry.value;
      final obstacles = _obstacles(data);
      final sim = PeopleSimulation(data);
      const dt = 1 / 30;
      const steps = 9000;
      final walkers = sim.walkers;
      // 1 秒ごとの歩行距離の累積(窓の検査用)。
      final perSecond = {for (final w in walkers) w.personId: <double>[]};
      final hits = <String>[];
      final lastDist = {for (final w in walkers) w.personId: 0.0};
      var minX = double.infinity;
      var maxX = -double.infinity;

      setUpAll(() {
        for (var i = 1; i <= steps; i++) {
          sim.step(dt);
          for (final w in walkers) {
            final p = w.position;
            minX = math.min(minX, p.x);
            maxX = math.max(maxX, p.x);
            for (final box in obstacles) {
              if (box.containsPoint(p)) {
                hits.add('${w.personId} が ${box.id} の中: $p (step $i)');
              }
            }
          }
          if (i % 30 == 0) {
            for (final w in walkers) {
              perSecond[w.personId]!.add(
                w.walkedDistance - lastDist[w.personId]!,
              );
              lastDist[w.personId] = w.walkedDistance;
            }
          }
        }
      });

      test('AC3b 全時点・全員が壁・机・椅子の中に入らない', () {
        expect(walkers, isNotEmpty);
        expect(hits.take(5).toList(), isEmpty);
      });

      test('AC4 どの 10 秒の窓でも全員が 1m 以上歩く', () {
        for (final w in walkers) {
          final s = perSecond[w.personId]!;
          expect(s, hasLength(300));
          for (var i = 0; i + 10 <= s.length; i++) {
            final sum = s.sublist(i, i + 10).fold(0.0, (a, b) => a + b);
            expect(
              sum,
              greaterThanOrEqualTo(1.0),
              reason: '${w.personId} 窓 $i',
            );
          }
          expect(w.replanCount, 0, reason: w.personId);
        }
      });

      test('5 分のあいだ時間が進み、床の外へ出ない', () {
        expect(sim.elapsed, closeTo(300, 1e-6));
        expect(minX, greaterThan(-data.floorSize.width / 2));
        expect(maxX, lessThan(data.floorSize.width / 2));
      });
    });
  }
}
