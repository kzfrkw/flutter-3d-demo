import 'package:flutter_3d_demo/office/data/dummy_office_data.dart';
import 'package:flutter_3d_demo/office/status/office_status.dart';
import 'package:flutter_3d_demo/office/status/virtual_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cycle = Duration(minutes: 5);

  group('VirtualClock', () {
    test('advance で進み、通知される', () {
      final c = VirtualClock(cycleLength: cycle);
      var n = 0;
      c.addListener(() => n++);
      c.advance(const Duration(seconds: 3));
      expect(c.value, const Duration(seconds: 3));
      expect(n, 1);
    });

    test('resolution 未満は通知されず、積算で追いつく', () {
      final c = VirtualClock(cycleLength: cycle);
      var n = 0;
      c.addListener(() => n++);
      c.advance(const Duration(milliseconds: 100));
      expect(n, 0);
      expect(c.value, Duration.zero);
      c.advance(const Duration(milliseconds: 160));
      expect(n, 1);
      expect(c.value, const Duration(milliseconds: 250));
    });

    test('cycleLength ちょうどで 0 に戻る', () {
      final c = VirtualClock(cycleLength: cycle);
      c.advance(cycle);
      expect(c.value, Duration.zero);
      c.advance(const Duration(seconds: 301));
      expect(c.value, const Duration(seconds: 1));
    });

    test('巨大な dt でも範囲内', () {
      final c = VirtualClock(cycleLength: cycle);
      c.advance(const Duration(days: 100000));
      expect(c.value, greaterThanOrEqualTo(Duration.zero));
      expect(c.value, lessThan(cycle));
    });

    test('負の dt と不正な cycleLength は無視', () {
      final c = VirtualClock(cycleLength: cycle);
      c.advance(const Duration(seconds: -5));
      expect(c.value, Duration.zero);
      final z = VirtualClock(cycleLength: Duration.zero);
      z.advance(const Duration(seconds: 5));
      expect(z.value, Duration.zero);
    });

    test('start は cycle で剰余', () {
      final c = VirtualClock(
        cycleLength: cycle,
        start: const Duration(seconds: 310),
      );
      expect(c.value, const Duration(seconds: 10));
    });

    test('既定データで会議室の状態が切り替わる', () {
      final c = VirtualClock(cycleLength: dummyOfficeData.cycleLength);
      RoomOccupancy occ(String id) => roomStatusAt(
        dummyOfficeData,
        dummyOfficeData.roomById(id)!,
        c.value,
      ).occupancy;
      final a0 = occ('room-a');
      final b0 = occ('room-b');
      expect(b0, RoomOccupancy.occupied);
      expect(a0, RoomOccupancy.free);
      c.advance(const Duration(seconds: 30));
      expect(occ('room-a'), RoomOccupancy.occupied);
    });
  });

  group('parseVirtualTimeStart', () {
    test('秒を解釈、剰余', () {
      expect(
        parseVirtualTimeStart(Uri.parse('http://x/?time=20'), cycle),
        const Duration(seconds: 20),
      );
      expect(
        parseVirtualTimeStart(Uri.parse('http://x/?time=320.5'), cycle),
        const Duration(seconds: 20, milliseconds: 500),
      );
    });
    test('無い・数でない・負・非有限は null', () {
      for (final q in [
        '',
        '?time=abc',
        '?time=-3',
        '?time=NaN',
        '?time=Infinity',
      ]) {
        expect(parseVirtualTimeStart(Uri.parse('http://x/$q'), cycle), isNull);
      }
    });
  });
}
