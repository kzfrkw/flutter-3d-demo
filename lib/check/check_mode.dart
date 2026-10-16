/// URL のクエリに `check` があるとき true(`/?check`、`/?check#/` など)。
bool isCheckMode(Uri uri) => uri.queryParameters.containsKey('check');
