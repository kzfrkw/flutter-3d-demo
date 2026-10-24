import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/data/office_models.dart';
import 'package:flutter_3d_demo/office/people/avatar_controller.dart';
import 'package:flutter_3d_demo/office/people/people_count.dart';
import 'package:flutter_3d_demo/office/scene/entity_pick.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  EntityRef? pick(String name) => entityRefForNodeName(name, dummyOfficeData);

  test('席・会議室・人のノード名から EntityRef', () {
    expect(pick('seat-1#desk'), const EntityRef(EntityKind.seat, 'seat-1'));
    expect(pick('seat-1#chair'), const EntityRef(EntityKind.seat, 'seat-1'));
    expect(
      pick('room-a#wall-south-1'),
      const EntityRef(EntityKind.room, 'room-a'),
    );
    for (final part in ['body', 'nose', 'tag']) {
      expect(
        pick('person-a#$part'),
        const EntityRef(EntityKind.person, 'person-a'),
      );
    }
    expect(pick('room-a#panel'), const EntityRef(EntityKind.room, 'room-a'));
  });

  test('エンティティの無いもの・データに無い id は null', () {
    expect(pick('floor'), isNull);
    expect(pick('outer-wall#north'), isNull);
    expect(pick('person-zzz#body'), isNull);
    expect(pick('room-z#panel'), isNull);
    expect(pick(''), isNull);
    expect(pick('#body'), isNull);
  });

  test('ノード名の組み立て', () {
    expect(tagNodeName('person-a'), 'person-a#tag');
    expect(panelNodeName('room-a'), 'room-a#panel');
    expect(pick(tagNodeName('person-b')), isNotNull);
    expect(pick(panelNodeName('room-c')), isNotNull);
  });

  test('自分(player)のノードは背景(null)。データの id と衝突しない(#12 AC18)', () {
    for (final name in [
      avatarBodyNodeName(),
      avatarNoseNodeName(),
      avatarTagNodeName(),
      avatarMarkNodeName(),
    ]) {
      expect(pick(name), isNull, reason: name);
    }
    expect(avatarBodyNodeName(), 'player#body');
    for (final n in [null, 5, 6, 7, 8, 9, 10]) {
      final data = withPeopleCount(dummyOfficeData, n);
      expect(data.people.any((p) => p.id == avatarId), isFalse);
      expect(data.seats.any((s) => s.id == avatarId), isFalse);
      expect(data.rooms.any((r) => r.id == avatarId), isFalse);
    }
  });
}
