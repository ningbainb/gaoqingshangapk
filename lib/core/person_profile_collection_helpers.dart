part of 'models.dart';

enum PersonProfileSortMode { recent, coverage, name }

extension PersonProfileSortModeText on PersonProfileSortMode {
  String get label => switch (this) {
        PersonProfileSortMode.recent => '最近',
        PersonProfileSortMode.coverage => '完整',
        PersonProfileSortMode.name => '名称',
      };
}

extension PersonProfileSearch on PersonProfile {
  List<String> get searchableIdentityValues => uniqueCleanPresentationList([
        displayName,
        ...aliases,
        relationship,
        communicationStyle,
      ]);

  List<String> get searchableInsightValues => uniqueCleanPresentationList([
        ...personalityTraits,
        ...innerNeeds,
        ...keyPersonPoints,
        ...momentsInsights,
        ...tonePreferences,
        ...boundaries,
        ...facts,
        lastSceneSummary,
        lastUpdateReason,
      ]);

  String get searchableText =>
      [...searchableIdentityValues, ...searchableInsightValues].join(' ');
}

extension PersonProfilePreview on PersonProfile {
  List<String> get previewTagValues => uniqueCleanPresentationList([
        ...personalityTraits,
        ...innerNeeds,
        ...keyPersonPoints,
        ...tonePreferences,
      ]);

  List<String> get previewTags => previewTagValues.take(3).toList();

  List<String> get pickerPreviewTagValues => uniqueCleanPresentationList([
        ...keyPersonPoints,
        ...tonePreferences,
        ...boundaries,
      ]);
}

String? normalizedPersonProfileId(String? id) {
  return cleanIdentifierText(id);
}

bool personProfileIdsMatch(String? left, String? right) {
  final normalizedLeft = normalizedPersonProfileId(left);
  final normalizedRight = normalizedPersonProfileId(right);
  return normalizedLeft != null &&
      normalizedRight != null &&
      normalizedLeft == normalizedRight;
}

PersonProfile? personProfileById(List<PersonProfile> profiles, String? id) {
  final normalizedId = normalizedPersonProfileId(id);
  if (normalizedId == null || normalizedId.isEmpty) return null;
  for (final profile in profiles) {
    if (personProfileIdsMatch(profile.id, normalizedId)) return profile;
  }
  return null;
}

bool personProfileMatchesInsight(PersonProfile profile, PersonInsight insight) {
  final knownLabels =
      _normalizedProfileMatchLabels([profile.displayName, ...profile.aliases]);
  final incomingLabels = _normalizedProfileMatchLabels([
    insight.displayName,
    ...?insight.aliases,
  ]);
  return incomingLabels.any(knownLabels.contains);
}

Set<String> _normalizedProfileMatchLabels(Iterable<String?> labels) {
  return uniqueCleanPresentationList(labels).map(normalizedLooseKey).toSet();
}

String? restorablePersonProfileId(
  List<PersonProfile> profiles,
  String? selectedProfileId,
) {
  return personProfileById(profiles, selectedProfileId)?.id;
}

List<(String, bool)> personProfileCoverageSections(PersonProfile profile) =>
    _personProfileCoverageEntries(profile)
        .map((entry) => (entry.label, entry.isFilled))
        .toList();

int personProfileCoveragePercent(PersonProfile profile) {
  final sections = personProfileCoverageSections(profile);
  final filled = sections.where((section) => section.$2).length;
  return ((filled / sections.length) * 100).round();
}

List<_PersonProfileCoverageEntry> _personProfileCoverageEntries(
  PersonProfile profile,
) =>
    [
      _PersonProfileCoverageEntry('性格', profile.personalityTraits),
      _PersonProfileCoverageEntry('需求', profile.innerNeeds),
      _PersonProfileCoverageEntry('关键点', profile.keyPersonPoints),
      _PersonProfileCoverageEntry('动态', profile.momentsInsights),
      _PersonProfileCoverageEntry('回复', profile.tonePreferences),
      _PersonProfileCoverageEntry('避雷', profile.boundaries),
      _PersonProfileCoverageEntry('事实', profile.facts),
    ];

class _PersonProfileCoverageEntry {
  const _PersonProfileCoverageEntry(this.label, this.values);

  final String label;
  final List<String> values;

  bool get isFilled => cleanPresentationList(values).isNotEmpty;
}

List<PersonProfile> filterPersonProfiles(
  List<PersonProfile> profiles, {
  required PersonProfileSortMode sortMode,
  required String query,
}) {
  final filtered = profiles.where((profile) {
    return textMatchesSearchQuery(profile.searchableText, query);
  }).toList();
  filtered.sort((a, b) {
    return switch (sortMode) {
      PersonProfileSortMode.recent => _comparePersonProfileRecent(a, b),
      PersonProfileSortMode.coverage => _comparePersonProfileCoverage(a, b),
      PersonProfileSortMode.name => _comparePersonProfileName(a, b),
    };
  });
  return filtered;
}

int _comparePersonProfileRecent(PersonProfile a, PersonProfile b) {
  final recent = b.updatedAt.compareTo(a.updatedAt);
  return recent != 0 ? recent : _comparePersonProfileName(a, b);
}

int _comparePersonProfileCoverage(PersonProfile a, PersonProfile b) {
  final coverage = personProfileCoveragePercent(b)
      .compareTo(personProfileCoveragePercent(a));
  return coverage != 0 ? coverage : _comparePersonProfileRecent(a, b);
}

int _comparePersonProfileName(PersonProfile a, PersonProfile b) {
  final name = localizedStandardLikeCompare(
    _sortablePersonProfileName(a),
    _sortablePersonProfileName(b),
  );
  if (name != 0) return name;
  final recent = b.updatedAt.compareTo(a.updatedAt);
  if (recent != 0) return recent;
  return localizedStandardLikeCompare(a.id, b.id);
}

String _sortablePersonProfileName(PersonProfile profile) =>
    cleanPresentationText(profile.displayName) ?? '未命名人物';
