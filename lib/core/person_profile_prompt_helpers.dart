part of 'models.dart';

extension PersonProfilePromptSummary on PersonProfile {
  List<String> get promptSummaryLines => _personProfilePromptLines(this);
}

String _personProfileSummaryForPrompt(PersonProfile profile) =>
    profile.promptSummaryLines.join('\n');

List<String> _personProfilePromptLines(PersonProfile profile) =>
    _personProfilePromptEntries(profile)
        .map((entry) => entry.text)
        .whereType<String>()
        .toList();

List<_PersonProfilePromptEntry> _personProfilePromptEntries(
  PersonProfile profile,
) =>
    [
      _PersonProfilePromptEntry(
        '称呼',
        [cleanPresentationText(profile.displayName) ?? '未命名人物'],
      ),
      _PersonProfilePromptEntry('关系', [profile.relationship]),
      _PersonProfilePromptEntry('沟通风格', [profile.communicationStyle]),
      _PersonProfilePromptEntry('性格倾向', profile.personalityTraits),
      _PersonProfilePromptEntry('内心需求', profile.innerNeeds),
      _PersonProfilePromptEntry('关键人物点', profile.keyPersonPoints),
      _PersonProfilePromptEntry('朋友圈观察', profile.momentsInsights),
      _PersonProfilePromptEntry('偏好', profile.tonePreferences),
      _PersonProfilePromptEntry('避雷', profile.boundaries),
      _PersonProfilePromptEntry('已知信息', profile.facts),
      _PersonProfilePromptEntry('最近画像依据', [profile.lastUpdateReason]),
    ];

class _PersonProfilePromptEntry {
  const _PersonProfilePromptEntry(this.label, this.values);

  final String label;
  final Iterable<String?> values;

  String? get text {
    final cleaned = uniqueCleanPresentationList(values);
    if (cleaned.isEmpty) return null;
    return '$label：${cleaned.join('、')}';
  }
}
