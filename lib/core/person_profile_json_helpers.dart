part of 'models.dart';

const _personProfileCreatedAtKeys = [
  'createdAt',
  'createdTime',
  'createdOn',
  'created',
  'timestamp',
  'time',
];

const _personProfileUpdatedAtKeys = [
  'updatedAt',
  'updatedTime',
  'updatedOn',
  'lastUpdatedAt',
  'modifiedAt',
  'modifiedTime',
  'timestamp',
  'time',
];

PersonProfile _personProfileFromJson(Map<String, dynamic> json) {
  final displayName = _firstClean(json, _personNameKeys);
  if (displayName == null) {
    throw const FormatException('Person profile displayName is required.');
  }
  final createdAt = _dateTimeValue(
    _firstValue(json, _personProfileCreatedAtKeys),
  );
  return PersonProfile(
    id: _firstIdentifier(json, _personProfileIdKeys),
    displayName: displayName,
    aliases: _firstUniqueStringList(json, _personAliasKeys),
    relationship: _firstClean(json, _personRelationshipKeys),
    communicationStyle: _firstClean(json, _personCommunicationStyleKeys) ??
        cleanPresentationText(
            _firstUniqueStringList(json, _personCommunicationAdviceKeys)
                .join('；')),
    personalityTraits: _firstUniqueStringList(json, _personTraitKeys),
    innerNeeds: _firstUniqueStringList(json, _personNeedKeys),
    keyPersonPoints: _firstUniqueStringList(json, _personKeyPointKeys),
    momentsInsights: _firstUniqueStringList(json, _personMomentInsightKeys),
    tonePreferences: _firstUniqueStringList(json, _personTonePreferenceKeys),
    boundaries: _firstUniqueStringList(json, _personBoundaryKeys),
    facts: _firstUniqueStringList(json, _personFactKeys),
    lastSceneSummary: _firstClean(json, _personLastSceneSummaryKeys),
    lastUpdateReason: _firstClean(json, _personLastUpdateReasonKeys),
    confidence: (_doubleValue(_firstValue(json, _personConfidenceKeys)) ?? 0.4)
        .clamp(0, 1)
        .toDouble(),
    createdAt: createdAt,
    updatedAt: _dateTimeValue(
          _firstValue(json, _personProfileUpdatedAtKeys),
        ) ??
        createdAt,
  );
}

Map<String, dynamic> _personProfileToJson(PersonProfile profile) => {
      'id': profile.id,
      'displayName': cleanPresentationText(profile.displayName) ?? '未命名人物',
      'aliases': uniqueCleanPresentationList(profile.aliases),
      'relationship': cleanPresentationText(profile.relationship),
      'communicationStyle': cleanPresentationText(profile.communicationStyle),
      'personalityTraits':
          uniqueCleanPresentationList(profile.personalityTraits),
      'innerNeeds': uniqueCleanPresentationList(profile.innerNeeds),
      'keyPersonPoints': uniqueCleanPresentationList(profile.keyPersonPoints),
      'momentsInsights': uniqueCleanPresentationList(profile.momentsInsights),
      'tonePreferences': uniqueCleanPresentationList(profile.tonePreferences),
      'boundaries': uniqueCleanPresentationList(profile.boundaries),
      'facts': uniqueCleanPresentationList(profile.facts),
      'lastSceneSummary': cleanPresentationText(profile.lastSceneSummary),
      'lastUpdateReason': cleanPresentationText(profile.lastUpdateReason),
      'confidence': profile.confidence.clamp(0, 1).toDouble(),
      'createdAt': profile.createdAt.toIso8601String(),
      'updatedAt': profile.updatedAt.toIso8601String(),
    };
