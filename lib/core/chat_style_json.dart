part of 'models.dart';

const _chatStyleIdKeys = [
  'id',
  'styleId',
  'styleUuid',
  'customStyleId',
];

const _chatStyleNameKeys = [
  'name',
  'title',
  'styleName',
  'styleLabel',
  'label',
  'displayName',
];

const _chatStyleDescriptionKeys = [
  'description',
  'desc',
  'summary',
  'subtitle',
  'intro',
];

const _chatStyleRuleKeys = [
  'rules',
  'styleRules',
  'instructions',
  'guidelines',
  'constraints',
  'promptRules',
];

const _chatStyleOfficialKeys = [
  'isOfficial',
  'official',
  'isBuiltin',
  'builtin',
  'builtIn',
  'isPreset',
  'preset',
];

ChatStyle _chatStyleFromJson(Map<String, dynamic> json) => ChatStyle(
      id: _firstIdentifier(json, _chatStyleIdKeys),
      name: _firstClean(json, _chatStyleNameKeys) ?? '',
      description: _firstClean(json, _chatStyleDescriptionKeys) ?? '',
      rules: _firstStringList(json, _chatStyleRuleKeys),
      isOfficial: _firstBool(json, _chatStyleOfficialKeys) ?? true,
    );

bool? _firstBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _boolValue(_valueForKey(json, key));
    if (value != null) return value;
  }
  return null;
}
