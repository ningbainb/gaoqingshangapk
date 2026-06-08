part of 'models.dart';

enum SimulationScenario {
  dailyChat('日常闲聊', '练习自然接话，避免尬聊，让对方愿意继续聊。'),
  comfort('安慰情绪', '练习接住对方情绪，稳定陪伴，不过度说教。'),
  invitation('邀约推进', '练习低压力推进邀约，表达清楚但不逼迫。'),
  conflict('化解误会', '练习化解误会，减少防御感，给关系留余地。'),
  boundary('表达边界', '练习温和但清楚地表达边界，不攻击对方。');

  const SimulationScenario(this.title, this.promptGoal);
  final String title;
  final String promptGoal;
}

enum SimulationSpeaker { user, persona }

class SimulationMessage {
  SimulationMessage({String? id, required this.speaker, required this.text})
      : id = cleanIdentifierText(id) ?? _uuid.v4();
  final String id;
  final SimulationSpeaker speaker;
  final String text;

  SimulationMessage normalized() => SimulationMessage(
        id: cleanIdentifierText(id),
        speaker: speaker,
        text: cleanPresentationText(text) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'speaker': speaker.name,
        'text': cleanPresentationText(text) ?? '',
      };
}

class SimulationOption {
  SimulationOption({
    String? id,
    required this.text,
    this.label = '建议',
    required this.reason,
    this.predictedScore = 60,
  }) : id = cleanIdentifierText(id) ?? _uuid.v4();
  final String id;
  final String text;
  final String label;
  final String reason;
  final int predictedScore;

  factory SimulationOption.fromJson(Map<String, dynamic> json) =>
      _simulationOptionFromJson(json);

  SimulationOption normalized() => SimulationOption(
        id: cleanIdentifierText(id),
        text: cleanPresentationText(text) ?? '',
        label: cleanPresentationText(label) ?? '建议',
        reason: cleanPresentationText(reason) ?? '这个回复更稳。',
        predictedScore: _optionalScore(predictedScore) ?? 60,
      );

  Map<String, dynamic> toJson() => _simulationOptionToJson(this);
}

class SimulationMetric {
  const SimulationMetric({
    required this.name,
    required this.score,
    required this.insight,
  });

  final String name;
  final int score;
  final String insight;

  factory SimulationMetric.fromJson(Map<String, dynamic> json) =>
      _simulationMetricFromJson(json);

  Map<String, dynamic> toJson() => _simulationMetricToJson(this);
}

List<SimulationOption> defaultSimulationOptions() => [
      SimulationOption(
          text: '我明白，你刚刚那句话其实挺重要的。',
          label: '稳妥',
          reason: '先回应对方表达的重点。',
          predictedScore: 70),
      SimulationOption(
          text: '你愿意多说一点吗？我想听真实想法。',
          label: '追问',
          reason: '给对方继续表达的空间。',
          predictedScore: 74),
      SimulationOption(
          text: '我可能理解得不完全对，你是更在意这件事本身，还是我的态度？',
          label: '澄清',
          reason: '适合信息不够时降低误会。',
          predictedScore: 76),
    ];

SimulationOption? _simulationOptionFromItem(Object? item) {
  if (item is Map) {
    final json = Map<String, dynamic>.from(item);
    if (_firstClean(json, _simulationOptionTextKeys) == null) return null;
    return SimulationOption.fromJson(json);
  }
  final text = cleanPresentationText(item?.toString());
  if (text == null) return null;
  return SimulationOption(
    text: text,
    label: '建议',
    reason: '模型提供的候选回复。',
  );
}

List<SimulationOption> cleanUniqueSimulationOptions(
  Iterable<SimulationOption> options, {
  int? limit,
}) =>
    uniqueByCleanPresentationText(
      options,
      normalize: (option) => option.normalized(),
      text: (option) => option.text,
      limit: limit,
    );

String? cleanSimulationReplyInput(String? reply) =>
    cleanPresentationText(reply);

bool canSubmitSimulationReplyInput(String? reply, {required bool isBusy}) =>
    !isBusy && cleanSimulationReplyInput(reply) != null;

List<SimulationMessage> cleanSimulationMessages(
  Iterable<SimulationMessage> messages,
) =>
    messages
        .map((message) => message.normalized())
        .where((message) => message.text.isNotEmpty)
        .toList();
