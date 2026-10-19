import '../data/office_models.dart';

/// neighbors の辺だけをたどる最短経路(辺の数が最小)。from と to を含む。
/// from == to なら [from]。どちらかが実在しない、または到達できなければ null。
/// neighbors の並び順で探索するので、同じ入力なら結果は常に同じ。
List<String>? shortestPath(OfficeData data, String fromId, String toId) {
  if (data.waypointById(fromId) == null || data.waypointById(toId) == null) {
    return null;
  }
  if (fromId == toId) return [fromId];
  final parent = <String, String>{fromId: fromId};
  final queue = <String>[fromId];
  for (var head = 0; head < queue.length; head++) {
    final id = queue[head];
    for (final n in data.waypointById(id)!.neighbors) {
      if (parent.containsKey(n) || data.waypointById(n) == null) continue;
      parent[n] = id;
      if (n == toId) {
        final path = <String>[toId];
        var cur = toId;
        while (cur != fromId) {
          cur = parent[cur]!;
          path.add(cur);
        }
        return path.reversed.toList();
      }
      queue.add(n);
    }
  }
  return null;
}

/// [fromId] から辿り着ける waypoint の id(fromId を除く)。幅優先の順。
List<String> reachableFrom(OfficeData data, String fromId) {
  if (data.waypointById(fromId) == null) return const [];
  final seen = <String>{fromId};
  final queue = <String>[fromId];
  for (var head = 0; head < queue.length; head++) {
    for (final n in data.waypointById(queue[head])!.neighbors) {
      if (data.waypointById(n) == null || !seen.add(n)) continue;
      queue.add(n);
    }
  }
  return queue.sublist(1);
}

/// 片道の経路 [a, b, c] から、往復の周回 [a, b, c, b] を作る(wrap の c→a ではなく b→a が
/// neighbors になる)。2 点 [a, b] は [a, b] のまま。1 点以下は渡さない(ArgumentError)。
List<String> roundTripLoop(List<String> path) {
  if (path.length < 2) {
    throw ArgumentError.value(path, 'path', '2 点以上が要る');
  }
  if (path.length == 2) return List.of(path);
  return [...path, ...path.sublist(1, path.length - 1).reversed];
}
