part of 'models.dart';

const _responseWrapperKeys = [
  'data',
  'result',
  'response',
  'output',
  'payload',
  'content',
  'message',
  'body',
];

Map<String, dynamic>? _firstMap(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _valueForKey(json, key);
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final decoded = decodeJsonObject(value);
      if (decoded != null) return decoded;
    }
  }
  return null;
}

List<Map<String, dynamic>> _responseWrappers(
  Map<String, dynamic> json,
  bool Function(Map<String, dynamic>) looksLikeResponse,
) =>
    _responseWrappersAtDepth(json, looksLikeResponse, 0);

List<Map<String, dynamic>> _responseWrappersAtDepth(
  Map<String, dynamic> json,
  bool Function(Map<String, dynamic>) looksLikeResponse,
  int depth,
) {
  final wrappers = <Map<String, dynamic>>[];
  if (depth >= 4) return wrappers;
  for (final key in _responseWrapperKeys) {
    final map = _mapValue(_valueForKey(json, key));
    if (map == null) continue;
    if (looksLikeResponse(map)) {
      wrappers.add(map);
    }
    wrappers.addAll(
      _responseWrappersAtDepth(map, looksLikeResponse, depth + 1),
    );
  }
  return wrappers;
}

Map<String, dynamic>? _mapValue(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) return decodeJsonObject(value);
  return null;
}

List<Map<String, dynamic>> _containerSources(
  Map<String, dynamic> json,
  List<String> keys,
) =>
    [
      json,
      ..._containerSourcesAtDepth(json, keys, 0),
    ];

List<Map<String, dynamic>> _containerSourcesAtDepth(
  Map<String, dynamic> json,
  List<String> keys,
  int depth,
) {
  if (depth >= 3) return const [];
  final sources = <Map<String, dynamic>>[];
  for (final key in keys) {
    final nested = _mapValue(_valueForKey(json, key));
    if (nested == null) continue;
    sources.add(nested);
    sources.addAll(_containerSourcesAtDepth(nested, keys, depth + 1));
  }
  return sources;
}

String? _firstCleanFromSources(
  List<Map<String, dynamic>> sources,
  List<String> keys,
) {
  for (final source in sources) {
    final value = _firstClean(source, keys);
    if (value != null) return value;
  }
  return null;
}

List<String> _firstStringListFromSources(
  List<Map<String, dynamic>> sources,
  List<String> keys,
) {
  for (final source in sources) {
    final values = _firstStringList(source, keys);
    if (values.isNotEmpty) return values;
  }
  return const [];
}

List<String> _firstUniqueStringListFromSources(
  List<Map<String, dynamic>> sources,
  List<String> keys,
) =>
    uniqueCleanPresentationList(_firstStringListFromSources(sources, keys));

Object? _firstValueFromSources(
  List<Map<String, dynamic>> sources,
  List<String> keys,
) {
  for (final source in sources) {
    final value = _firstValue(source, keys);
    if (value != null) return value;
  }
  return null;
}

List<Object?>? _firstListFromSources(
  List<Map<String, dynamic>> sources,
  List<String> keys,
) {
  for (final source in sources) {
    for (final key in keys) {
      final value = _valueForKey(source, key);
      if (value is List) return value;
    }
  }
  return null;
}

Map<String, dynamic>? _firstMapFromSources(
  List<Map<String, dynamic>> sources,
  List<String> keys,
) {
  for (final source in sources) {
    final map = _firstMap(source, keys);
    if (map != null) return map;
  }
  return null;
}

int _firstScoreFromSources(
  List<Map<String, dynamic>> sources,
  List<String> keys, {
  required int fallback,
  Map<String, dynamic>? secondary,
}) =>
    _firstOptionalScoreFromSources(sources, keys, secondary: secondary) ??
    fallback;

int? _firstOptionalScoreFromSources(
  List<Map<String, dynamic>> sources,
  List<String> keys, {
  Map<String, dynamic>? secondary,
}) {
  for (final source in sources) {
    final score = _firstOptionalScore(source, keys);
    if (score != null) return score;
  }
  if (secondary == null) return null;
  return _firstOptionalScore(secondary, keys);
}
