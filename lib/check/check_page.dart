import 'package:flutter/material.dart';

import 'check_result.dart';
import 'env_info.dart';
import 'scene_probe.dart';

/// s0-check: 技術検証の結果を上に、最小の 3D ビューを下に置く開発者用ページ。
class CheckPage extends StatefulWidget {
  const CheckPage({super.key, required this.probe, required this.env});

  final SceneProbe probe;
  final EnvInfo env;

  @override
  State<CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<CheckPage> {
  final Map<CheckItem, CheckResult> _results = {
    for (final item in CheckItem.values) item: const CheckResult.pending(),
  };

  void _report(CheckItem item, CheckResult result) {
    if (!mounted) return;
    setState(() => _results[item] = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('s0-check')),
      body: Column(
        children: [
          for (final item in CheckItem.values)
            _ResultRow(label: item.label, result: _results[item]!),
          ListTile(
            dense: true,
            title: const Text('ブラウザ・版'),
            subtitle: Text(widget.env.summary),
          ),
          const Divider(height: 1),
          Expanded(child: widget.probe.buildView(context, _report)),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.result});

  final String label;
  final CheckResult result;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (result.status) {
      CheckStatus.pending => ('確認中', Colors.grey),
      CheckStatus.ok => ('OK', Colors.green),
      CheckStatus.ng => ('NG', Colors.red),
    };
    return ListTile(
      dense: true,
      title: Text(label),
      subtitle: result.reason == null ? null : Text(result.reason!),
      trailing: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
