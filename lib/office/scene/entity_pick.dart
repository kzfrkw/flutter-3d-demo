import '../data/office_models.dart';

/// 人の名札のノード名。
String tagNodeName(String personId) => '$personId#tag';

/// 会議室パネルのノード名。
String panelNodeName(String roomId) => '$roomId#panel';

/// ノード名の最初の '#' より前を id として、person → seat → room の順にデータから引く。
/// '#' が無い('floor')・外壁・データに無い id は null(= 背景)。部位名は解釈しない。
EntityRef? entityRefForNodeName(String nodeName, OfficeData data) {
  final i = nodeName.indexOf('#');
  if (i <= 0) return null;
  final id = nodeName.substring(0, i);
  if (data.personById(id) != null) return EntityRef(EntityKind.person, id);
  if (data.seatById(id) != null) return EntityRef(EntityKind.seat, id);
  if (data.roomById(id) != null) return EntityRef(EntityKind.room, id);
  return null;
}
