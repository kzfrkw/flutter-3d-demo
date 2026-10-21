import 'package:flutter/material.dart';

import '../data/office_models.dart';
import '../status/office_status.dart';
import '../status_style.dart';
import 'status_pill.dart';

/// s2-card。席・会議室・人の情報カード。状態を受け取って表示するだけ。
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.status, required this.onClose});

  final TargetStatus status;
  final VoidCallback onClose;

  static String _kindLabel(TargetStatus s) => switch (s) {
    RoomStatus() => '会議室',
    SeatStatus() => '席',
    PersonStatus() => '人',
  };

  static IconData _kindIcon(TargetStatus s) => switch (s) {
    RoomStatus() => Icons.meeting_room_outlined,
    SeatStatus() => Icons.event_seat_outlined,
    PersonStatus() => Icons.person_outline,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final kind = _kindLabel(status);
    final pill = StatusPill(style: pillStyleOf(status, scheme));
    final rows = switch (status) {
      final RoomStatus s => [
        _InfoRow(label: '状態', child: pill),
        _InfoRow(label: '定員', child: Text('${s.room.capacity}名')),
        _InfoRow(
          label: '現在の予定',
          child: s.current == null
              ? const Text('なし')
              : _BookingText(booking: s.current!),
        ),
        _InfoRow(
          label: '次の予定',
          child: s.next == null
              ? const Text('予定なし')
              : _BookingText(booking: s.next!, nextCycle: s.nextIsNextCycle),
        ),
      ],
      final SeatStatus s => [
        _InfoRow(
          label: '使用者',
          child: Text(s.owner?.displayName ?? unassignedOwnerLabel),
        ),
        _InfoRow(label: '状態', child: pill),
      ],
      final PersonStatus s => [
        _InfoRow(label: '役割', child: Text(s.person.role)),
        _InfoRow(label: '現在の行動', child: pill),
      ],
    };

    return Material(
      color: Colors.transparent,
      child: Semantics(
        container: true,
        label: '$kind ${status.title} の詳細',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      _kindIcon(status),
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kind,
                          style: text.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            status.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '閉じる',
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
              Divider(color: scheme.outlineVariant, height: 24),
              for (final row in rows) ...[row, const SizedBox(height: 12)],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: DefaultTextStyle.merge(
              style: text.bodyLarge,
              child: Align(alignment: Alignment.centerLeft, child: child),
            ),
          ),
        ],
      ),
    );
  }
}

String _mmss(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class _BookingText extends StatelessWidget {
  const _BookingText({required this.booking, this.nextCycle = false});

  final Booking booking;
  final bool nextCycle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final range = '${_mmss(booking.start)}〜${_mmss(booking.end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(booking.title),
        Text(
          nextCycle ? '次周 ・ $range' : range,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
