part of 'models.dart';

const _personalizationContainerKeys = [
  'personalization',
  'replyPersonalization',
  'replyPersonalizationSettings',
  'replySettings',
  'preferences',
  'settings',
];

const _personalizationColloquialKeys = [
  'isColloquialExpressionEnabled',
  'colloquialExpressionEnabled',
  'colloquialEnabled',
  'colloquial',
  'useColloquialExpression',
  'casualTone',
  'informalTone',
  'useCasualTone',
];

const _personalizationGenderKeys = [
  'userGender',
  'gender',
  'userSex',
  'sex',
];

const _personalizationAgeKeys = [
  'userAgeText',
  'ageText',
  'userAge',
  'age',
  'birthYear',
  'birthday',
  'generation',
  'ageGroup',
];

const _personalizationMemoryEnabledKeys = [
  'isConversationMemoryEnabled',
  'conversationMemoryEnabled',
  'conversationMemory',
  'memoryEnabled',
  'useConversationMemory',
  'rememberConversation',
  'rememberContext',
  'contextMemory',
];

const _personalizationAdaptiveStyleKeys = [
  'isAdaptiveStyleEnabled',
  'adaptiveStyleEnabled',
  'adaptiveStyle',
  'styleAdaptation',
  'useAdaptiveStyle',
  'adaptiveTone',
  'styleLearning',
  'learnStyle',
];

const _personalizationMemoryNotesKeys = [
  'memoryNotes',
  'memoryNote',
  'memory',
  'notes',
  'personalNotes',
  'conversationMemoryNotes',
  'userProfileNotes',
  'profileNotes',
  'personalMemory',
];

ReplyPersonalizationSettings _personalizationSettingsFromJson(
  Map<String, dynamic> json,
) {
  final sources = _personalizationSources(json);
  return ReplyPersonalizationSettings(
    isColloquialExpressionEnabled: _boolValue(_firstValueFromSources(
          sources,
          _personalizationColloquialKeys,
        )) ??
        true,
    userGender: _userGenderValue(_firstValueFromSources(
      sources,
      _personalizationGenderKeys,
    )),
    userAgeText: _firstCleanFromSources(
          sources,
          _personalizationAgeKeys,
        ) ??
        '',
    customStyles: _customStyleItemsFromSources(sources)
        .whereType<Map>()
        .map((e) => ChatStyle.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    isConversationMemoryEnabled: _boolValue(_firstValueFromSources(
          sources,
          _personalizationMemoryEnabledKeys,
        )) ??
        true,
    isAdaptiveStyleEnabled: _boolValue(_firstValueFromSources(
          sources,
          _personalizationAdaptiveStyleKeys,
        )) ??
        true,
    memoryNotes: _firstCleanFromSources(
          sources,
          _personalizationMemoryNotesKeys,
        ) ??
        '',
  ).normalized();
}

List<Map<String, dynamic>> _personalizationSources(Map<String, dynamic> json) =>
    _containerSources(json, _personalizationContainerKeys);

List<Object?> _customStyleItemsFromSources(List<Map<String, dynamic>> sources) {
  for (final source in sources) {
    final items = _customStyleItems(source);
    if (items.isNotEmpty) return items;
  }
  return const [];
}

UserGender _userGenderValue(Object? raw) {
  final text = cleanNonEmptyText(raw?.toString());
  if (text == null) return UserGender.unspecified;
  final normalized = normalizedLooseKey(text);
  for (final gender in UserGender.values) {
    if (normalizedLooseKey(gender.name) == normalized ||
        normalizedLooseKey(gender.title) == normalized ||
        (gender.promptText != null &&
            normalizedLooseKey(gender.promptText!) == normalized)) {
      return gender;
    }
  }
  if (const {'woman', 'girl', '女生', '女性'}.contains(normalized)) {
    return UserGender.female;
  }
  if (const {'man', 'boy', '男生', '男性'}.contains(normalized)) {
    return UserGender.male;
  }
  if (const {'nonbinary', 'nonbinarygender', 'nb', '非二元'}.contains(
    normalized,
  )) {
    return UserGender.nonBinary;
  }
  return UserGender.unspecified;
}
