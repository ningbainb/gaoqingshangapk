part of 'models.dart';

List<SimulationMetric> _simulationMetricsFromRaw(Object? raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((e) => SimulationMetric.fromJson(Map<String, dynamic>.from(e)))
        .take(8)
        .toList();
  }
  if (raw is Map) {
    return raw.entries
        .map((entry) {
          final name = entry.key.toString();
          final value = entry.value;
          if (value is Map) {
            return SimulationMetric.fromJson({
              'name': name,
              ...Map<String, dynamic>.from(value),
            });
          }
          return SimulationMetric.fromJson({'name': name, 'score': value});
        })
        .map(_normalizedSimulationMetric)
        .whereType<SimulationMetric>()
        .take(8)
        .toList();
  }
  return const [];
}

List<SimulationMetric> defaultSimulationMetrics({
  int favorability = 55,
  int tension = 40,
  int trust = 55,
  int interest = 55,
}) =>
    [
      SimulationMetric(
          name: '好感度', score: favorability, insight: '关系还有继续推进空间。'),
      SimulationMetric(
          name: '自然度',
          score: ((favorability + interest) / 2).round(),
          insight: '保持日常口吻，不要太用力。'),
      SimulationMetric(name: '边界感', score: trust, insight: '尊重对方节奏，也保留自己的空间。'),
      SimulationMetric(
          name: '推进度', score: interest, insight: '先接住对方，再轻轻推进下一步。'),
      SimulationMetric(name: '情绪接住', score: trust, insight: '优先回应对方情绪里的关键词。'),
      SimulationMetric(
          name: '风险控制', score: 100 - tension, insight: '紧张度越高，越要减少解释和施压。'),
    ];

List<SimulationMetric> _completeSimulationMetrics(
  List<SimulationMetric> metrics, {
  required int favorability,
  required int tension,
  required int trust,
  required int interest,
}) {
  final fallbackMetrics = defaultSimulationMetrics(
    favorability: favorability,
    tension: tension,
    trust: trust,
    interest: interest,
  );
  final requiredNames = fallbackMetrics.map((metric) => metric.name).toSet();
  final result = <SimulationMetric>[];
  final existing = <String>{};

  for (final metric in metrics) {
    final normalized = _normalizedSimulationMetric(metric);
    if (normalized == null) continue;
    final name = normalized.name;
    if (!requiredNames.contains(name)) continue;
    if (existing.add(name)) {
      result.add(normalized);
    }
  }
  for (final fallback in fallbackMetrics) {
    if (existing.add(fallback.name)) {
      result.add(fallback);
    }
  }
  for (final metric in metrics) {
    if (result.length >= 8) break;
    final normalized = _normalizedSimulationMetric(metric);
    if (normalized == null) continue;
    final name = normalized.name;
    if (requiredNames.contains(name)) continue;
    if (existing.add(name)) {
      result.add(normalized);
    }
  }
  return result;
}

SimulationMetric? _normalizedSimulationMetric(SimulationMetric metric) {
  final name = cleanPresentationText(metric.name);
  if (name == null) return null;
  return SimulationMetric(
    name: name,
    score: metric.score,
    insight: cleanPresentationText(metric.insight) ?? '暂无说明',
  );
}
