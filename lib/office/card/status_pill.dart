import 'package:flutter/material.dart';

import '../status_style.dart';

/// 状態ピル(文言+アイコン+枠)。カードと一覧で同じ見た目を使う。
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.style});

  final StatusPillStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: ShapeDecoration(
        color: style.background,
        shape: StadiumBorder(
          side: style.border == null
              ? BorderSide.none
              : BorderSide(color: style.border!, width: 2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(style.icon, size: 18, color: style.foreground),
          ),
          const SizedBox(width: 6),
          Text(
            style.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: style.foreground,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
