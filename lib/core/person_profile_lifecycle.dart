part of 'models.dart';

PersonProfile _mergedPersonProfile(
  PersonProfile profile,
  PersonInsight insight,
  String? sceneSummary,
) {
  final incomingName = cleanPresentationText(insight.displayName);
  final incomingAliases = insight.aliases ?? const <String>[];
  final currentDisplayName =
      cleanPresentationText(profile.displayName) ?? '未命名人物';
  final nextDisplayName = incomingName ?? currentDisplayName;
  final nextAliases = incomingName != null && incomingName != currentDisplayName
      ? _merge(profile.aliases, [currentDisplayName, ...incomingAliases])
      : _merge(profile.aliases, incomingAliases);
  return PersonProfile(
    id: cleanIdentifierText(profile.id),
    displayName: nextDisplayName,
    aliases: nextAliases,
    relationship: cleanPresentationText(insight.relationship) ??
        cleanPresentationText(profile.relationship),
    communicationStyle: cleanPresentationText(insight.communicationStyle) ??
        cleanPresentationText(profile.communicationStyle),
    personalityTraits: _merge(
        profile.personalityTraits, insight.personalityTraits ?? const []),
    innerNeeds: _merge(profile.innerNeeds, insight.innerNeeds ?? const []),
    keyPersonPoints:
        _merge(profile.keyPersonPoints, insight.keyPersonPoints ?? const []),
    momentsInsights:
        _merge(profile.momentsInsights, insight.momentsInsights ?? const []),
    tonePreferences:
        _merge(profile.tonePreferences, insight.tonePreferences ?? const []),
    boundaries: _merge(profile.boundaries, insight.boundaries ?? const []),
    facts: _merge(profile.facts, insight.facts ?? const []),
    lastSceneSummary: cleanPresentationText(sceneSummary) ??
        cleanPresentationText(profile.lastSceneSummary),
    lastUpdateReason: cleanPresentationText(insight.updateReason) ??
        cleanPresentationText(profile.lastUpdateReason),
    confidence: [
      profile.confidence,
      (insight.confidence ?? profile.confidence).clamp(0, 1).toDouble()
    ].reduce((a, b) => a > b ? a : b),
    createdAt: profile.createdAt,
    updatedAt: DateTime.now(),
  );
}

PersonProfile _normalizedPersonProfile(
  PersonProfile profile, {
  DateTime? updatedAt,
}) {
  return PersonProfile(
    id: cleanIdentifierText(profile.id),
    displayName: cleanPresentationText(profile.displayName) ?? '未命名人物',
    aliases: uniqueCleanPresentationList(profile.aliases),
    relationship: cleanPresentationText(profile.relationship),
    communicationStyle: cleanPresentationText(profile.communicationStyle),
    personalityTraits: uniqueCleanPresentationList(profile.personalityTraits),
    innerNeeds: uniqueCleanPresentationList(profile.innerNeeds),
    keyPersonPoints: uniqueCleanPresentationList(profile.keyPersonPoints),
    momentsInsights: uniqueCleanPresentationList(profile.momentsInsights),
    tonePreferences: uniqueCleanPresentationList(profile.tonePreferences),
    boundaries: uniqueCleanPresentationList(profile.boundaries),
    facts: uniqueCleanPresentationList(profile.facts),
    lastSceneSummary: cleanPresentationText(profile.lastSceneSummary),
    lastUpdateReason: cleanPresentationText(profile.lastUpdateReason),
    confidence: profile.confidence.clamp(0, 1).toDouble(),
    createdAt: profile.createdAt,
    updatedAt: updatedAt ?? profile.updatedAt,
  );
}
