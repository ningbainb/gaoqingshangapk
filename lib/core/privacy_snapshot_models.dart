part of 'models.dart';

class PrivacySnapshot {
  const PrivacySnapshot({
    required this.hasAPIKey,
    required this.hasCustomConfig,
    required this.historyCount,
    required this.profileCount,
  });

  final bool hasAPIKey;
  final bool hasCustomConfig;
  final int historyCount;
  final int profileCount;

  int get safeHistoryCount => _safeLocalDataCount(historyCount);

  int get safeProfileCount => _safeLocalDataCount(profileCount);

  bool get hasLocalData =>
      hasAPIKey ||
      hasCustomConfig ||
      safeHistoryCount > 0 ||
      safeProfileCount > 0;

  String get historyLine =>
      safeHistoryCount <= 0 ? '暂无历史记录' : '$safeHistoryCount 条生成结果';

  String get historyMetricValue => _localDataMetricValue(safeHistoryCount);

  String get profileLine =>
      safeProfileCount <= 0 ? '暂无人物画像' : '$safeProfileCount 个本地画像';

  String get profileMetricValue => _localDataMetricValue(safeProfileCount);

  String get clearButtonLabel => hasLocalData ? '清空本地数据' : '暂无可清空数据';

  String get apiLine {
    return switch ((hasAPIKey, hasCustomConfig)) {
      (true, true) => '会删除 Key 并恢复默认配置',
      (true, false) => '会删除 Key',
      (false, true) => '会恢复默认配置',
      (false, false) => '暂无 Key 或自定义配置',
    };
  }
}

int _safeLocalDataCount(int count) => max(0, count);

String _localDataMetricValue(int count) {
  final safeCount = _safeLocalDataCount(count);
  return safeCount <= 0 ? '暂无' : '$safeCount';
}
