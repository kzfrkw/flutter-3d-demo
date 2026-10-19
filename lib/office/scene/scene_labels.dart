import 'package:flutter/material.dart';

import '../status/office_status.dart';
import '../status_style.dart';

/// 3D の面に載せる名札の中身(論理サイズ 180×54 を想定)。
/// 面の上ではテーマに依存しない固定色。flutter_scene は import しない。
class PersonTag extends StatelessWidget {
  const PersonTag({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: personTagBackground,
            border: Border.all(color: personTagForeground, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  maxLines: 1,
                  style: const TextStyle(
                    color: personTagForeground,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 会議室パネルの中身(論理サイズ 144×96 を想定)。状態で色・アイコン・文言が変わる。
class RoomPanel extends StatelessWidget {
  const RoomPanel({super.key, required this.status});

  /// テストで背景の色を読むためのキー。
  static const boxKey = Key('room-panel-box');

  final RoomStatus status;

  @override
  Widget build(BuildContext context) {
    final style = roomOccupancyStyle(status.occupancy);
    return MediaQuery.withNoTextScaling(
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          key: boxKey,
          decoration: BoxDecoration(
            color: style.background,
            border: Border.all(
              color: style.border ?? style.foreground,
              width: 4,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  status.room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: style.foreground,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, size: 28, color: style.foreground),
                      const SizedBox(width: 4),
                      Text(
                        style.label,
                        maxLines: 1,
                        style: TextStyle(
                          color: style.foreground,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
