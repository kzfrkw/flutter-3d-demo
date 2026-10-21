/// 操作案内を閉じたかの記録。プロセス内のメモリだけに持つ。保存・送信はしない。
class GuideMemory {
  GuideMemory({this.dismissed = false});

  bool dismissed;
}
