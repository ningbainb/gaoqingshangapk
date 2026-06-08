part of 'models.dart';

const _simulationMetricContainerKeys = [
  'metrics',
  'scorecard',
  'scoreCard',
  'dimensionScores',
  'rubric',
  'evaluation',
  'evaluations',
];

const _simulationOptionContainerKeys = [
  'options',
  'suggestedReplies',
  'recommendedReplies',
  'candidateReplies',
  'alternativeReplies',
  'nextReplies',
  'replyOptions',
  'suggestions',
  'replies',
  'answers',
  'choices',
];

const _simulationScoreMapKeys = [
  'scores',
  'scorecard',
  'scoreCard',
  'relationshipScores',
  'ratings',
  'rating',
];

SimulationTurnResponse _simulationTurnResponseFromJson(
  Map<String, dynamic> json,
) {
  final sources = _simulationResponseSources(json);
  final rawMetrics =
      _firstValueFromSources(sources, _simulationMetricContainerKeys);
  final rawOptions =
      _firstListFromSources(sources, _simulationOptionContainerKeys) ??
          const [];
  final scoreMap = _firstMapFromSources(sources, _simulationScoreMapKeys) ??
      const <String, dynamic>{};
  final metrics = _simulationMetricsFromRaw(rawMetrics);
  final options = cleanUniqueSimulationOptions(
    rawOptions.map(_simulationOptionFromItem).whereType<SimulationOption>(),
    limit: 3,
  );
  final favorability = _firstScoreFromSources(
    sources,
    const ['favorability', 'liking', 'affection'],
    fallback: 55,
    secondary: scoreMap,
  );
  final tension = _firstScoreFromSources(
    sources,
    const ['tension', 'awkwardness', 'risk'],
    fallback: 40,
    secondary: scoreMap,
  );
  final trust = _firstScoreFromSources(
    sources,
    const ['trust', 'confidence'],
    fallback: 55,
    secondary: scoreMap,
  );
  final interest = _firstScoreFromSources(
    sources,
    const ['interest', 'engagement'],
    fallback: 55,
    secondary: scoreMap,
  );
  return SimulationTurnResponse(
    personaMessage: _firstCleanFromSources(
          sources,
          _simulationPersonaMessageKeys,
        ) ??
        '嗯，我听到了。你继续说，我想知道你真正的想法。',
    sceneState: _firstCleanFromSources(sources, _simulationSceneStateKeys) ??
        '对话正在进行中。',
    favorability: favorability,
    tension: tension,
    trust: trust,
    interest: interest,
    metrics: _completeSimulationMetrics(
      metrics,
      favorability: favorability,
      tension: tension,
      trust: trust,
      interest: interest,
    ),
    options: options.isEmpty ? defaultSimulationOptions() : options,
    userScore: _firstOptionalScoreFromSources(
      sources,
      const ['userScore', 'replyScore', 'responseScore', 'score'],
      secondary: scoreMap,
    ),
    feedback: _firstCleanFromSources(sources, _simulationFeedbackKeys),
    betterReply: _firstCleanFromSources(sources, _simulationBetterReplyKeys),
    coachTip: _firstCleanFromSources(sources, _simulationCoachTipKeys) ??
        '下一轮可以更具体地接住对方情绪。',
  );
}

Map<String, dynamic> _simulationTurnResponseToJson(
  SimulationTurnResponse response,
) {
  final favorability = _optionalScore(response.favorability) ?? 55;
  final tension = _optionalScore(response.tension) ?? 40;
  final trust = _optionalScore(response.trust) ?? 55;
  final interest = _optionalScore(response.interest) ?? 55;
  final optionJson = cleanUniqueSimulationOptions(
    response.options,
    limit: 3,
  ).map((option) => option.toJson()).toList();
  final options = optionJson.isEmpty
      ? defaultSimulationOptions().map((option) => option.toJson()).toList()
      : optionJson;

  return {
    'personaMessage': cleanPresentationText(response.personaMessage) ??
        '嗯，我听到了。你继续说，我想知道你真正的想法。',
    'sceneState': cleanPresentationText(response.sceneState) ?? '对话正在进行中。',
    'favorability': favorability,
    'tension': tension,
    'trust': trust,
    'interest': interest,
    'metrics': _completeSimulationMetrics(
      response.metrics,
      favorability: favorability,
      tension: tension,
      trust: trust,
      interest: interest,
    ).map((metric) => metric.toJson()).toList(),
    'options': options,
    'userScore':
        response.userScore == null ? null : _optionalScore(response.userScore),
    'feedback': cleanPresentationText(response.feedback),
    'betterReply': cleanPresentationText(response.betterReply),
    'coachTip': cleanPresentationText(response.coachTip) ?? '下一轮可以更具体地接住对方情绪。',
  };
}

List<Map<String, dynamic>> _simulationResponseSources(
  Map<String, dynamic> json,
) =>
    [
      json,
      ..._responseWrappers(json, _looksLikeSimulationResponseMap),
    ];

bool _looksLikeSimulationResponseMap(Map<String, dynamic> map) {
  const keys = [
    ..._simulationPersonaMessageKeys,
    ..._simulationSceneStateKeys,
    'favorability',
    'liking',
    'affection',
    'tension',
    'awkwardness',
    'trust',
    'interest',
    ..._simulationMetricContainerKeys,
    ..._simulationScoreMapKeys,
    ..._simulationOptionContainerKeys,
    'userScore',
    'replyScore',
    'responseScore',
    ..._simulationFeedbackKeys,
    ..._simulationBetterReplyKeys,
    ..._simulationCoachTipKeys,
  ];
  return keys.any((key) => _valueForKey(map, key) != null);
}
