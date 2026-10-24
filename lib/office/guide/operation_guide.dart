import 'package:flutter/material.dart';

const String guideTitle = '操作案内';
const String guideLearnHeading = 'このデモでわかること';
const String guideLearn1 = '3D のオフィスを人が歩く';
const String guideLearn2 = '3D の上に Flutter ウィジェットを載せる';
const String guideOperationHeading = '操作';
const String guideTouch = 'タッチ操作:1本指ドラッグで回転、ピンチでズーム、タップで詳細';
const String guideArrowsLabel = '十字キー';
const String guideArrows = '自分を動かす(↑↓←→ で画面の上下左右へ)';
const String guideArrowsNote = '十字キーは PC のキーボード用です。効かないときは 3D を一度クリックしてください。';
const String guideDeveloperHeading = 'Flutter 開発者の方へ';
const String guideHotReload =
    '色や配置はコードを変えるとホットリロードですぐ反映できます。'
    '色は lib/office/status_style.dart、'
    '配置は lib/office/scene/office_layout.dart を編集してください。';
const String guideNote =
    '3D が操作しにくいときは「一覧」から選べます。'
    'この案内は「ヘルプ」(スマホでは ≡ メニュー内)でいつでも開けます。';
const String guideStartLabel = 'はじめる';

/// s3-guide。最前面に重ねる案内。閉じる操作はすべて [onClose] を呼ぶ(Esc は OfficePage が受ける)。
class OperationGuideOverlay extends StatelessWidget {
  const OperationGuideOverlay({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    Widget op(Key key, String label, String body) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(body, style: text.bodyMedium)),
        ],
      ),
    );

    Widget learn(IconData icon, String body) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(body, style: text.bodyMedium)),
        ],
      ),
    );

    return FocusScope(
      autofocus: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: ModalBarrier(
              key: const Key('guide-barrier'),
              color: Colors.black54,
              dismissible: true,
              onDismiss: onClose,
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
                child: Semantics(
                  container: true,
                  label: guideTitle,
                  child: Material(
                    color: scheme.surfaceContainerHigh,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(guideTitle, style: text.titleLarge),
                              ),
                              IconButton(
                                key: const Key('guide-close-button'),
                                tooltip: '閉じる',
                                icon: const Icon(Icons.close),
                                onPressed: onClose,
                              ),
                            ],
                          ),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    guideLearnHeading,
                                    style: text.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  learn(Icons.directions_walk, guideLearn1),
                                  learn(Icons.widgets_outlined, guideLearn2),
                                  const SizedBox(height: 16),
                                  Text(
                                    guideOperationHeading,
                                    style: text.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  op(
                                    const Key('guide-op-drag'),
                                    'ドラッグ',
                                    '3D を回転',
                                  ),
                                  op(
                                    const Key('guide-op-wheel'),
                                    'ホイール',
                                    'ズーム',
                                  ),
                                  op(
                                    const Key('guide-op-right-drag'),
                                    '右ドラッグ',
                                    '移動(パン)',
                                  ),
                                  op(
                                    const Key('guide-op-click'),
                                    'クリック',
                                    '会議室・席・人の詳細を見る',
                                  ),
                                  op(
                                    const Key('guide-op-arrows'),
                                    guideArrowsLabel,
                                    guideArrows,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    guideArrowsNote,
                                    key: const Key('guide-arrows-note'),
                                    style: text.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    guideTouch,
                                    style: text.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    guideDeveloperHeading,
                                    style: text.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(guideHotReload, style: text.bodyMedium),
                                  const SizedBox(height: 16),
                                  Text(
                                    guideNote,
                                    style: text.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              key: const Key('guide-start-button'),
                              autofocus: true,
                              onPressed: onClose,
                              child: const Text(guideStartLabel),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
