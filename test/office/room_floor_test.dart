import 'package:flutter/material.dart';
import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/scene/entity_pick.dart';
import 'package:flutter_3d_demo/office/scene/office_layout.dart';
import 'package:flutter_3d_demo/office/status/office_status.dart';
import 'package:flutter_3d_demo/office/status_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('会議室の床の箱', () {
    final boxes = buildOfficeLayout(dummyOfficeData);
    const style = LayoutStyle();

    test('各会議室に <roomId>#floor が 1 つずつある', () {
      final floors = boxes.where((b) => b.kind == BoxKind.roomFloor).toList();
      expect(floors, hasLength(dummyOfficeData.rooms.length));
      for (final r in dummyOfficeData.rooms) {
        final f = floors.singleWhere((b) => b.id == '${r.id}#floor');
        expect(f.ref, EntityRef(EntityKind.room, r.id));
        expect(f.center, r.position);
        // 壁の内側に収まる。
        expect(
          f.width,
          closeTo(r.size.width - 2 * style.roomWallThickness, 1e-9),
        );
        expect(
          f.depth,
          closeTo(r.size.depth - 2 * style.roomWallThickness, 1e-9),
        );
        expect(f.bottomY, 0);
        expect(f.height, greaterThan(0));
      }
      expect(boxes.map((b) => b.id).toSet(), hasLength(boxes.length));
    });

    test('順序: roomWall の後・desk の前', () {
      final lastWall = boxes.lastIndexWhere((b) => b.kind == BoxKind.roomWall);
      final firstFloor = boxes.indexWhere((b) => b.kind == BoxKind.roomFloor);
      final firstDesk = boxes.indexWhere((b) => b.kind == BoxKind.desk);
      expect(firstFloor, greaterThan(lastWall));
      expect(firstDesk, greaterThan(firstFloor));
    });

    test('部屋の床をクリックすると会議室の選択になる', () {
      expect(
        entityRefForNodeName('room-a#floor', dummyOfficeData),
        const EntityRef(EntityKind.room, 'room-a'),
      );
      expect(entityRefForNodeName('floor', dummyOfficeData), isNull);
    });
  });

  group('roomFloorColor', () {
    double lum(Color c) => c.computeLuminance();

    test('不透明で、空き/使用中で異なり、輝度差があり、空きが明るい', () {
      final free = roomFloorColor(RoomOccupancy.free);
      final occ = roomFloorColor(RoomOccupancy.occupied);
      expect(free.a, 1.0);
      expect(occ.a, 1.0);
      expect(free, isNot(occ));
      final hi = lum(free);
      final lo = lum(occ);
      expect(hi, greaterThan(lo));
      expect((hi + 0.05) / (lo + 0.05), greaterThanOrEqualTo(3.0));
    });

    test('ピルと同系統(空き=緑系、使用中=赤系)', () {
      final free = HSLColor.fromColor(roomFloorColor(RoomOccupancy.free));
      final occ = HSLColor.fromColor(roomFloorColor(RoomOccupancy.occupied));
      expect(free.hue, inInclusiveRange(90, 160));
      expect(occ.hue < 20 || occ.hue > 340, isTrue);
    });
  });
}
