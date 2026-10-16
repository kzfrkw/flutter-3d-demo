/// s0-check で確かめる 3 項目。
enum CheckItem {
  gltf('glTF 表示'),
  widgetEmbed('3D 面にウィジェット埋め込み'),
  animation('アニメ再生');

  const CheckItem(this.label);

  final String label;
}

enum CheckStatus { pending, ok, ng }

/// 1 項目の判定結果。NG のときは [reason] に理由を入れる。
class CheckResult {
  const CheckResult.pending() : status = CheckStatus.pending, reason = null;
  const CheckResult.ok() : status = CheckStatus.ok, reason = null;
  const CheckResult.ng(String this.reason) : status = CheckStatus.ng;

  final CheckStatus status;
  final String? reason;
}
