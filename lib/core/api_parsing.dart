part of 'api_service.dart';

String? _firstCleanText(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _cleanText(_valueForKey(json, key));
    if (value != null) return value;
  }
  return null;
}

Object? _firstValue(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _valueForKey(json, key);
    if (value != null) return value;
  }
  return null;
}

Object? _valueForKey(Map<dynamic, dynamic> json, String key) {
  return valueForLooseKey(json, key);
}

String? _cleanText(Object? value) {
  return cleanPresentationText(value?.toString());
}
