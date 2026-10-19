import 'dart:async';

import 'package:flutter/material.dart';

enum SceneLoadFailureKind { webgl2Unsupported, loadFailed }

/// 3D を出せなかった理由。
class SceneLoadFailure {
  const SceneLoadFailure(this.kind, {this.detail});

  final SceneLoadFailureKind kind;

  /// 技術的な詳細(補足として小さく出す)。
  final String? detail;

  /// 利用者向けの原因の文言。
  String get cause => switch (kind) {
    SceneLoadFailureKind.webgl2Unsupported =>
      'お使いのブラウザでは 3D 表示に必要な WebGL2 が使えません',
    SceneLoadFailureKind.loadFailed => '3D の読み込みに失敗しました',
  };
}

/// 読み込み中。中央に進捗と「素材を読み込み中」。[slowAfter] を超えたら補足文を出す。
class SceneLoading extends StatefulWidget {
  const SceneLoading({super.key, this.slowAfter = const Duration(seconds: 10)});

  static const String message = '素材を読み込み中';
  static const String slowMessage = '時間がかかっています。回線や端末によっては 30 秒ほどかかることがあります';

  final Duration slowAfter;

  @override
  State<SceneLoading> createState() => _SceneLoadingState();
}

class _SceneLoadingState extends State<SceneLoading> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: scheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Semantics(
            liveRegion: true,
            container: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(SceneLoading.message, style: text.bodyLarge),
                const SizedBox(height: 8),
                // 補足文の場所は最初から確保して、スピナーが跳ねないようにする。
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 360,
                    minHeight: 64,
                  ),
                  child: _slow
                      ? Text(
                          SceneLoading.slowMessage,
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// エラー。中央に原因・案内・[再読み込み]。詳細は [SceneLoadFailure.detail] があるときだけ。
class SceneErrorView extends StatelessWidget {
  const SceneErrorView({
    super.key,
    required this.failure,
    required this.onReload,
  });

  static const String guidance = 'Chrome 最新版でお試しください';
  static const String reloadLabel = '再読み込み';

  final SceneLoadFailure failure;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final detail = failure.detail;
    return ColoredBox(
      color: scheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.error_outline,
                    size: 48,
                    color: scheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    failure.cause,
                    textAlign: TextAlign.center,
                    style: text.titleLarge?.copyWith(color: scheme.onSurface),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  guidance,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  autofocus: true,
                  onPressed: onReload,
                  icon: const Icon(Icons.refresh),
                  label: const Text(reloadLabel),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 16),
                  SelectableText(
                    '詳細: $detail',
                    maxLines: 4,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
