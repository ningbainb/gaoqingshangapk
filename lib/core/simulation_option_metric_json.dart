part of 'models.dart';

const _simulationOptionIdKeys = [
  'id',
  'optionId',
  'replyId',
  'suggestionId',
  'candidateId',
];

const _simulationOptionTextKeys = [
  'text',
  'reply',
  'replyText',
  'message',
  'suggestion',
  'suggestedReply',
  'recommendedReply',
  'candidateReply',
  'alternativeReply',
  'answer',
  'option',
  'optionText',
  'response',
  'content',
  'nextReply',
  'proposal',
  'draft',
];

const _simulationOptionLabelKeys = [
  'label',
  'styleLabel',
  'styleName',
  'style',
  'tone',
  'toneLabel',
  'category',
  'tag',
];

const _simulationOptionReasonKeys = [
  'reason',
  'explanation',
  'why',
  'rationale',
  'justification',
  'note',
  'notes',
  'comment',
];

const _simulationOptionScoreKeys = [
  'predictedScore',
  'score',
  'qualityScore',
  'expectedScore',
  'confidenceScore',
  'prediction',
  'rating',
];

const _simulationMetricNameKeys = [
  'name',
  'label',
  'metric',
  'title',
  'dimension',
  'criterion',
];

const _simulationMetricScoreKeys = [
  'score',
  'value',
  'rating',
  'points',
];

const _simulationMetricInsightKeys = [
  'insight',
  'comment',
  'reason',
  'explanation',
  'description',
  'feedback',
  'advice',
];

SimulationOption _simulationOptionFromJson(Map<String, dynamic> json) =>
    SimulationOption(
      id: _firstIdentifier(json, _simulationOptionIdKeys),
      text: _firstClean(json, _simulationOptionTextKeys) ?? '我想想怎么说更合适。',
      label: _firstClean(json, _simulationOptionLabelKeys) ?? '建议',
      reason: _firstClean(json, _simulationOptionReasonKeys) ?? '这个回复更稳。',
      predictedScore: _firstScore(
        json,
        _simulationOptionScoreKeys,
        fallback: 60,
      ),
    );

SimulationMetric _simulationMetricFromJson(Map<String, dynamic> json) =>
    SimulationMetric(
      name: _firstClean(json, _simulationMetricNameKeys) ?? '指标',
      score: _firstScore(json, _simulationMetricScoreKeys, fallback: 60),
      insight: _firstClean(json, _simulationMetricInsightKeys) ?? '暂无说明',
    );

Map<String, dynamic> _simulationOptionToJson(SimulationOption option) => {
      'id': cleanIdentifierText(option.id) ?? _uuid.v4(),
      'text': cleanPresentationText(option.text) ?? '',
      'label': cleanPresentationText(option.label) ?? '建议',
      'reason': cleanPresentationText(option.reason) ?? '这个回复更稳。',
      'predictedScore': _optionalScore(option.predictedScore) ?? 60,
    };

Map<String, dynamic> _simulationMetricToJson(SimulationMetric metric) => {
      'name': cleanPresentationText(metric.name) ?? '指标',
      'score': _optionalScore(metric.score) ?? 60,
      'insight': cleanPresentationText(metric.insight) ?? '暂无说明',
    };
