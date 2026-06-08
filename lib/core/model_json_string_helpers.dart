part of 'models.dart';

List<String> _stringList(Object? raw) {
  if (raw is List) {
    return raw.map(_stringListItemText).whereType<String>().toList();
  }
  if (raw is String) {
    return raw
        .split(RegExp(r'[\n,，、;；]+'))
        .map(cleanPresentationText)
        .whereType<String>()
        .toList();
  }
  final single = _stringListItemText(raw);
  if (single != null) return [single];
  return const [];
}

String? _stringListItemText(Object? raw) {
  if (raw is Map) {
    final json = raw.map((key, value) => MapEntry(key.toString(), value));
    final value = _firstValue(json, const [
      'text',
      'value',
      'name',
      'label',
      'title',
      'type',
      'modality',
      'mode',
      'inputType',
      'content',
      'description',
      'summary',
      'trait',
      'need',
      'point',
      'insight',
      'observation',
      'advice',
      'fact',
      'rule',
      'note',
      'topic',
      'item',
    ]);
    if (value is List) {
      return cleanPresentationText(_stringList(value).join('；'));
    }
    if (value is Map) return _stringListItemText(value);
    return cleanPresentationText(value?.toString());
  }
  if (raw is List) return cleanPresentationText(_stringList(raw).join('；'));
  return cleanPresentationText(raw?.toString());
}

String? _cleanIdentifier(Object? value) {
  return cleanIdentifierText(value?.toString());
}

String? _firstIdentifier(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _cleanIdentifier(_valueForKey(json, key));
    if (value != null) return value;
  }
  return null;
}

List<String> _merge(List<String> current, List<String> incoming) {
  return uniqueCleanPresentationList([...current, ...incoming], limit: 12);
}
