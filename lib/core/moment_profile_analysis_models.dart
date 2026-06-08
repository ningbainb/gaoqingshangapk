part of 'models.dart';

class MomentProfileAnalysis {
  const MomentProfileAnalysis({
    required this.sceneSummary,
    this.sourcePlatform,
    this.visibleName,
    this.relationshipGuess,
    this.personalityTraits = const [],
    this.innerNeeds = const [],
    this.keyPersonPoints = const [],
    this.momentsInsights = const [],
    this.communicationAdvice = const [],
    this.boundaries = const [],
    this.stableFacts = const [],
    this.confidence = 0.4,
    this.updateReason,
  });

  final String sceneSummary;
  final String? sourcePlatform;
  final String? visibleName;
  final String? relationshipGuess;
  final List<String> personalityTraits;
  final List<String> innerNeeds;
  final List<String> keyPersonPoints;
  final List<String> momentsInsights;
  final List<String> communicationAdvice;
  final List<String> boundaries;
  final List<String> stableFacts;
  final double confidence;
  final String? updateReason;

  int get writableInsightCount =>
      uniqueCleanPresentationList(personalityTraits).length +
      uniqueCleanPresentationList(innerNeeds).length +
      uniqueCleanPresentationList(keyPersonPoints).length +
      uniqueCleanPresentationList(momentsInsights).length +
      uniqueCleanPresentationList(communicationAdvice).length +
      uniqueCleanPresentationList(boundaries).length +
      uniqueCleanPresentationList(stableFacts).length;

  PersonInsight get personInsight {
    final name = cleanPresentationText(visibleName);
    final traits = uniqueCleanPresentationList(personalityTraits);
    final communicationStyle = cleanPresentationText(traits.take(3).join('，'));
    return PersonInsight(
      displayName: name,
      aliases: name == null ? null : [name],
      relationship: cleanPresentationText(relationshipGuess),
      communicationStyle: communicationStyle,
      personalityTraits: traits,
      innerNeeds: uniqueCleanPresentationList(innerNeeds),
      keyPersonPoints: uniqueCleanPresentationList(keyPersonPoints),
      momentsInsights: uniqueCleanPresentationList(momentsInsights),
      tonePreferences: uniqueCleanPresentationList(communicationAdvice),
      boundaries: uniqueCleanPresentationList(boundaries),
      facts: uniqueCleanPresentationList(stableFacts),
      confidence: confidence.clamp(0, 1).toDouble(),
      updateReason: cleanPresentationText(updateReason),
    );
  }

  factory MomentProfileAnalysis.fromJson(Map<String, dynamic> json) {
    final sources = _momentProfileSources(json);
    return MomentProfileAnalysis(
      sceneSummary:
          _firstCleanFromSources(sources, _sceneSummaryKeys) ?? '已从截图提取人物画像。',
      sourcePlatform: _firstCleanFromSources(sources, _platformKeys),
      visibleName: _firstCleanFromSources(sources, _personNameKeys),
      relationshipGuess: _firstCleanFromSources(
        sources,
        _personRelationshipKeys,
      ),
      personalityTraits:
          _firstUniqueStringListFromSources(sources, _personTraitKeys)
              .take(8)
              .toList(),
      innerNeeds: _firstUniqueStringListFromSources(sources, _personNeedKeys)
          .take(8)
          .toList(),
      keyPersonPoints:
          _firstUniqueStringListFromSources(sources, _personKeyPointKeys)
              .take(8)
              .toList(),
      momentsInsights:
          _firstUniqueStringListFromSources(sources, _personMomentInsightKeys)
              .take(8)
              .toList(),
      communicationAdvice: _firstUniqueStringListFromSources(
        sources,
        const [
          ..._personCommunicationAdviceKeys,
          'advice',
        ],
      ).take(8).toList(),
      boundaries:
          _firstUniqueStringListFromSources(sources, _personBoundaryKeys)
              .take(8)
              .toList(),
      stableFacts: _firstUniqueStringListFromSources(sources, _personFactKeys)
          .take(10)
          .toList(),
      confidence: _doubleInRange(
        _firstValueFromSources(sources, _personConfidenceKeys),
        fallback: 0.4,
      ),
      updateReason: _firstCleanFromSources(
        sources,
        _personLastUpdateReasonKeys,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'sceneSummary': cleanPresentationText(sceneSummary) ?? '已从截图提取人物画像。',
        'sourcePlatform': cleanPresentationText(sourcePlatform),
        'visibleName': cleanPresentationText(visibleName),
        'relationshipGuess': cleanPresentationText(relationshipGuess),
        'personalityTraits':
            uniqueCleanPresentationList(personalityTraits).take(8).toList(),
        'innerNeeds': uniqueCleanPresentationList(innerNeeds).take(8).toList(),
        'keyPersonPoints':
            uniqueCleanPresentationList(keyPersonPoints).take(8).toList(),
        'momentsInsights':
            uniqueCleanPresentationList(momentsInsights).take(8).toList(),
        'communicationAdvice':
            uniqueCleanPresentationList(communicationAdvice).take(8).toList(),
        'boundaries': uniqueCleanPresentationList(boundaries).take(8).toList(),
        'stableFacts':
            uniqueCleanPresentationList(stableFacts).take(10).toList(),
        'confidence': confidence.clamp(0, 1).toDouble(),
        'updateReason': cleanPresentationText(updateReason),
      };
}
