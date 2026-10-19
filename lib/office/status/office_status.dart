import '../data/office_models.dart';
import '../people/people_simulation.dart';

/// 状態の文言はここの `label` だけに持つ。パネル・カード・テストはここを参照する。
enum RoomOccupancy {
  free('空き'),
  occupied('使用中');

  const RoomOccupancy(this.label);
  final String label;
}

enum SeatPresence {
  present('在席'),
  away('離席'),
  unassigned('使用者なし');

  const SeatPresence(this.label);
  final String label;
}

enum PersonActivity {
  walking('歩行中'),
  stopped('停止中');

  const PersonActivity(this.label);
  final String label;
}

const String unassignedOwnerLabel = '未割り当て';

/// 椅子の中心からこの距離(m)以内に使用者がいれば在席(境界ちょうどは在席)。
/// 椅子の半径 0.25 + 人の半径 0.25 + 余裕。
const double seatPresenceRadius = 0.8;

typedef PersonSnapshot = ({FloorPoint position, bool isWalking});

/// 人の今の様子の問い合わせ口。PeopleSimulation を知らずにテストできる。
typedef PersonLookup = PersonSnapshot? Function(String personId);

PersonLookup personLookupOf(PeopleSimulation? sim) {
  if (sim == null) return (_) => null;
  return (id) {
    final w = sim.walkerOf(id);
    if (w == null) return null;
    return (position: w.position, isWalking: w.isWalking);
  };
}

sealed class TargetStatus {
  const TargetStatus();
  EntityRef get ref;
  String get title;
}

class RoomStatus extends TargetStatus {
  const RoomStatus({
    required this.room,
    required this.occupancy,
    this.current,
    this.next,
    this.nextIsNextCycle = false,
  });

  final Room room;
  final RoomOccupancy occupancy;

  /// 使用中のときの予定。
  final Booking? current;

  /// 次の予定。予定が 1 件も無ければ null。
  final Booking? next;

  /// next が一巡の終わりを越えた次周の先頭か。
  final bool nextIsNextCycle;

  @override
  EntityRef get ref => EntityRef(EntityKind.room, room.id);
  @override
  String get title => room.name;
}

class SeatStatus extends TargetStatus {
  const SeatStatus({required this.seat, this.owner, required this.presence});

  final Seat seat;
  final Person? owner;
  final SeatPresence presence;

  @override
  EntityRef get ref => EntityRef(EntityKind.seat, seat.id);
  @override
  String get title => seat.label;
}

class PersonStatus extends TargetStatus {
  const PersonStatus({required this.person, required this.activity});

  final Person person;
  final PersonActivity activity;

  @override
  EntityRef get ref => EntityRef(EntityKind.person, person.id);
  @override
  String get title => person.displayName;
}

RoomStatus roomStatusAt(OfficeData data, Room room, Duration time) {
  final cycle = data.cycleLength;
  final t = cycle > Duration.zero
      ? Duration(microseconds: time.inMicroseconds % cycle.inMicroseconds)
      : Duration.zero;
  final bookings = data.bookingsOf(room.id);
  Booking? current;
  Booking? next;
  for (final b in bookings) {
    if (current == null && b.start <= t && t < b.end) current = b;
    if (next == null && b.start > t) next = b;
  }
  var nextIsNextCycle = false;
  if (next == null && bookings.isNotEmpty) {
    next = bookings.first;
    nextIsNextCycle = true;
  }
  return RoomStatus(
    room: room,
    occupancy: current != null ? RoomOccupancy.occupied : RoomOccupancy.free,
    current: current,
    next: next,
    nextIsNextCycle: nextIsNextCycle,
  );
}

SeatStatus seatStatusAt(OfficeData data, Seat seat, PersonLookup lookup) {
  final ownerId = seat.ownerId;
  final owner = ownerId == null ? null : data.personById(ownerId);
  if (owner == null) {
    return SeatStatus(seat: seat, presence: SeatPresence.unassigned);
  }
  final snap = lookup(owner.id);
  final present =
      snap != null &&
      snap.position.distanceTo(seat.position) <= seatPresenceRadius;
  return SeatStatus(
    seat: seat,
    owner: owner,
    presence: present ? SeatPresence.present : SeatPresence.away,
  );
}

PersonStatus personStatusAt(Person person, PersonLookup lookup) => PersonStatus(
  person: person,
  activity: lookup(person.id)?.isWalking == true
      ? PersonActivity.walking
      : PersonActivity.stopped,
);

/// ref が指すものがデータに無ければ null(カードを閉じる根拠)。
TargetStatus? statusOf(
  EntityRef ref,
  OfficeData data, {
  required Duration time,
  required PersonLookup lookup,
}) {
  switch (ref.kind) {
    case EntityKind.room:
      final r = data.roomById(ref.id);
      return r == null ? null : roomStatusAt(data, r, time);
    case EntityKind.seat:
      final s = data.seatById(ref.id);
      return s == null ? null : seatStatusAt(data, s, lookup);
    case EntityKind.person:
      final p = data.personById(ref.id);
      return p == null ? null : personStatusAt(p, lookup);
  }
}
