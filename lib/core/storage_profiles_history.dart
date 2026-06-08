part of 'storage.dart';

Future<List<GenerationRecord>> _loadHistoryFor(LocalStore store) async {
  final prefs = await store._ready;
  final raw = _jsonPreference(prefs, LocalStore._historyKey);
  if (raw == null) return [];
  final items = _decodeJsonCollectionItems(raw, _historyCollectionKeys);
  final records = <GenerationRecord>[];
  for (final item in items) {
    try {
      records.add(GenerationRecord.fromJson(Map<String, dynamic>.from(item)));
    } catch (_) {}
  }
  return normalizedHistoryRecords(
    records,
    maxCount: LocalStore._maxHistoryCount,
  );
}

Future<void> _saveHistoryFor(
  LocalStore store,
  List<GenerationRecord> records,
) async {
  final normalized = normalizedHistoryRecords(
    records,
    maxCount: LocalStore._maxHistoryCount,
  );
  final prefs = await store._ready;
  await prefs.setString(
    LocalStore._historyKey,
    jsonEncode(normalized.map((e) => e.toJson()).toList()),
  );
}

Future<List<PersonProfile>> _loadProfilesFor(LocalStore store) async {
  final prefs = await store._ready;
  final raw = _jsonPreference(prefs, LocalStore._profilesKey);
  if (raw == null) return [];
  final items = _decodeJsonCollectionItems(raw, _profileCollectionKeys);
  final profiles = <PersonProfile>[];
  for (final item in items) {
    try {
      profiles.add(PersonProfile.fromJson(Map<String, dynamic>.from(item)));
    } catch (_) {}
  }
  return normalizedPersonProfiles(
    profiles,
    maxCount: LocalStore._maxProfileCount,
  );
}

Future<void> _saveProfilesFor(
  LocalStore store,
  List<PersonProfile> profiles,
) async {
  final normalized = normalizedPersonProfiles(
    profiles,
    maxCount: LocalStore._maxProfileCount,
  );
  final prefs = await store._ready;
  await prefs.setString(
    LocalStore._profilesKey,
    jsonEncode(normalized.map((e) => e.toJson()).toList()),
  );
}

const _historyCollectionKeys = [
  'generationHistory',
  'history',
  'histories',
  'generationRecords',
  'records',
  'items',
];

const _profileCollectionKeys = [
  'personProfiles',
  'profiles',
  'people',
  'persons',
  'contacts',
  'records',
  'items',
];

const _collectionWrapperKeys = [
  'data',
  'payload',
  'result',
  'response',
  'content',
  'body',
  'backup',
  'export',
];

List<Map<String, dynamic>> _decodeJsonCollectionItems(
  String raw,
  List<String> collectionKeys,
) {
  try {
    final decoded = jsonDecode(raw);
    return _collectionItemsFromValue(decoded, collectionKeys);
  } catch (_) {}
  return const [];
}

List<Map<String, dynamic>> _collectionItemsFromValue(
  Object? value,
  List<String> collectionKeys, {
  int depth = 0,
}) {
  if (depth >= 4) return const [];
  if (value is List) return _collectionItemsFromList(value);
  if (value is String) {
    try {
      return _collectionItemsFromValue(
        jsonDecode(value),
        collectionKeys,
        depth: depth + 1,
      );
    } catch (_) {
      return const [];
    }
  }
  if (value is! Map) return const [];

  final map = Map<String, dynamic>.from(value);
  for (final key in collectionKeys) {
    final items = _collectionItemsFromValue(
      _collectionValueForKey(map, key),
      collectionKeys,
      depth: depth + 1,
    );
    if (items.isNotEmpty) return items;
  }
  for (final key in _collectionWrapperKeys) {
    final items = _collectionItemsFromValue(
      _collectionValueForKey(map, key),
      collectionKeys,
      depth: depth + 1,
    );
    if (items.isNotEmpty) return items;
  }

  return map.entries.where((entry) => entry.value is Map).map((entry) {
    final item = Map<String, dynamic>.from(entry.value as Map);
    if (cleanIdentifierText(item['id']?.toString()) == null) {
      item['id'] = entry.key.toString();
    }
    return item;
  }).toList();
}

List<Map<String, dynamic>> _collectionItemsFromList(List<Object?> value) {
  return value
      .map(_collectionMapFromValue)
      .whereType<Map<String, dynamic>>()
      .toList();
}

Map<String, dynamic>? _collectionMapFromValue(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return null;
}

Object? _collectionValueForKey(Map<String, dynamic> map, String key) {
  if (map.containsKey(key)) return map[key];
  final normalizedKey = _normalizedCollectionKey(key);
  for (final entry in map.entries) {
    if (_normalizedCollectionKey(entry.key) == normalizedKey) {
      return entry.value;
    }
  }
  return null;
}

String _normalizedCollectionKey(String key) =>
    key.toLowerCase().replaceAll(RegExp(r'[\s_\-\.]'), '');
