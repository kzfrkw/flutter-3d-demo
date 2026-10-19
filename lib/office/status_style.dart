import 'package:flutter/material.dart';

import 'status/office_status.dart';

/// 状態ピル・3D パネルの見た目(色・アイコン・文言)。
class StatusPillStyle {
  const StatusPillStyle({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.border,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  /// 枠の色。null なら枠なし。
  final Color? border;
}

/// 会議室の 2 状態の色は固定色。3D のパネルとカードで同じ色にして一致を見せる。
StatusPillStyle roomOccupancyStyle(RoomOccupancy o) => switch (o) {
  RoomOccupancy.free => StatusPillStyle(
    label: o.label,
    icon: Icons.check_circle_outline,
    background: const Color(0xFFE8F5E9),
    foreground: const Color(0xFF1B5E20),
    border: const Color(0xFF1B5E20),
  ),
  RoomOccupancy.occupied => StatusPillStyle(
    label: o.label,
    icon: Icons.block,
    background: const Color(0xFFB71C1C),
    foreground: const Color(0xFFFFFFFF),
    border: const Color(0xFFB71C1C),
  ),
};

/// 名札の固定色。
const Color personTagBackground = Color(0xFF263238);
const Color personTagForeground = Color(0xFFFFFFFF);

/// 対象の種類ごとの状態ピルの見た目。席・人はテーマの色を使う。
StatusPillStyle pillStyleOf(TargetStatus status, ColorScheme scheme) =>
    switch (status) {
      RoomStatus() => roomOccupancyStyle(status.occupancy),
      SeatStatus() => switch (status.presence) {
        SeatPresence.present => StatusPillStyle(
          label: status.presence.label,
          icon: Icons.person,
          background: scheme.primaryContainer,
          foreground: scheme.onPrimaryContainer,
        ),
        SeatPresence.away => StatusPillStyle(
          label: status.presence.label,
          icon: Icons.person_off_outlined,
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurfaceVariant,
        ),
        SeatPresence.unassigned => StatusPillStyle(
          label: status.presence.label,
          icon: Icons.remove_circle_outline,
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurfaceVariant,
        ),
      },
      PersonStatus() => switch (status.activity) {
        PersonActivity.walking => StatusPillStyle(
          label: status.activity.label,
          icon: Icons.directions_walk,
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
        ),
        PersonActivity.stopped => StatusPillStyle(
          label: status.activity.label,
          icon: Icons.pause_circle_outline,
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurfaceVariant,
        ),
      },
    };
