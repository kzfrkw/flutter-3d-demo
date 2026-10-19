import '../data/office_models.dart';

const int minPeople = 5;
const int maxPeople = 10;

/// URL の `people` クエリを整数にする。無い・空・整数でないときは null。
/// 整数なら [minPeople]〜[maxPeople] に丸める(3 → 5、99 → 10)。
int? parsePeopleCount(Uri uri) {
  final raw = uri.queryParameters['people'];
  if (raw == null) return null;
  final n = int.tryParse(raw.trim());
  if (n == null) return null;
  return n.clamp(minPeople, maxPeople);
}

/// 追加の Person(既定ダミー向けの固定リスト)。経路は [base] の Waypoint を使う。
const _extras = <(String, String, String, double, List<String>)>[
  ('person-g', 'メンバーG', 'エンジニア', 1.2, ['wp-07', 'wp-06', 'wp-11', 'wp-06']),
  ('person-h', 'メンバーH', 'デザイナー', 1.0, ['wp-01', 'wp-02', 'wp-09', 'wp-02']),
  ('person-i', 'メンバーI', '企画', 1.4, ['wp-03', 'wp-04', 'wp-05', 'wp-04']),
  ('person-j', 'メンバーJ', 'エンジニア', 1.1, ['wp-12', 'wp-06', 'wp-05', 'wp-06']),
];

/// 人数を [count] にした OfficeData。
/// - count == null、または count == base.people.length: base をそのまま返す(同じ参照)。
/// - count が多い: 追加の Person・Route を足す。席・Waypoint・部屋・予定は base のまま。
///   必要な Waypoint が無い、または足せる人数を超えるときは ArgumentError。
/// - count が少ない: base.people の先頭 count 人だけ残し、外れた人の Route を除き、
///   外れた人が owner の Seat は ownerId を null にした Seat に置き換える。
OfficeData withPeopleCount(OfficeData base, int? count) {
  if (count == null || count == base.people.length) return base;

  var people = base.people;
  var routes = base.routes;
  var seats = base.seats;

  if (count > base.people.length) {
    final need = count - base.people.length;
    if (need > _extras.length) {
      throw ArgumentError.value(count, 'count', '足せるのは最大 ${_extras.length} 人');
    }
    final added = _extras.take(need).toList();
    for (final e in added) {
      for (final id in e.$5) {
        if (base.waypointById(id) == null) {
          throw ArgumentError('追加の人 ${e.$1} に必要な Waypoint $id が無い');
        }
      }
    }
    people = [
      ...base.people,
      for (final e in added)
        Person(
          id: e.$1,
          displayName: e.$2,
          role: e.$3,
          model: 'capsule',
          speed: e.$4,
        ),
    ];
    routes = [
      ...base.routes,
      for (final e in added)
        Route(personId: e.$1, waypointIds: e.$5, loop: true),
    ];
  } else {
    people = base.people.take(count).toList();
    final kept = people.map((p) => p.id).toSet();
    routes = base.routes.where((r) => kept.contains(r.personId)).toList();
    seats = [
      for (final s in base.seats)
        if (s.ownerId == null || kept.contains(s.ownerId))
          s
        else
          Seat(
            id: s.id,
            label: s.label,
            position: s.position,
            facing: s.facing,
          ),
    ];
  }

  return OfficeData(
    floorSize: base.floorSize,
    outerWallThickness: base.outerWallThickness,
    cycleLength: base.cycleLength,
    rooms: base.rooms,
    bookings: base.bookings,
    seats: seats,
    people: people,
    waypoints: base.waypoints,
    routes: routes,
  );
}

/// main.dart から使う入口。
OfficeData officeDataForUri(Uri uri, OfficeData base) =>
    withPeopleCount(base, parsePeopleCount(uri));
