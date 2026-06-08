part of 'models.dart';

String? _firstClean(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _stringListItemText(_valueForKey(json, key));
    if (value != null) return value;
  }
  return null;
}

List<String> _firstStringList(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final values = _stringList(_valueForKey(json, key));
    if (values.isNotEmpty) return values;
  }
  return const [];
}

List<String> _firstUniqueStringList(
  Map<String, dynamic> json,
  List<String> keys,
) =>
    uniqueCleanPresentationList(_firstStringList(json, keys));

Object? _firstValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _valueForKey(json, key);
    if (value != null) return value;
  }
  return null;
}

Object? _valueForKey(Map<String, dynamic> json, String key) {
  return valueForLooseKey(json, key);
}

List<Object?> _customStyleItems(Map<String, dynamic> json) {
  for (final key in const [
    'customStyles',
    'customStyle',
    'styles',
    'stylePresets',
  ]) {
    final value = _valueForKey(json, key);
    if (value is List) return value;
    if (value is Map) return _customStyleItemsFromMap(value);
  }
  return const [];
}

List<Object?> _customStyleItemsFromMap(Map<dynamic, dynamic> raw) {
  final map = Map<String, dynamic>.from(raw);
  if (_looksLikeCustomStyleMap(map)) return [map];
  return map.entries.where((entry) => entry.value is Map).map((entry) {
    final item = Map<String, dynamic>.from(entry.value as Map);
    if (cleanIdentifierText(item['id']?.toString()) == null) {
      item['id'] = entry.key.toString();
    }
    return item;
  }).toList();
}

bool _looksLikeCustomStyleMap(Map<String, dynamic> map) {
  const keys = [
    ..._chatStyleIdKeys,
    ..._chatStyleNameKeys,
    ..._chatStyleDescriptionKeys,
    ..._chatStyleRuleKeys,
    ..._chatStyleOfficialKeys,
  ];
  return keys.any((key) => _valueForKey(map, key) != null);
}
