String normalizedLooseKey(String key) =>
    key.replaceAll(RegExp(r'[_\-\s]+'), '').toLowerCase();

Object? valueForLooseKey(Map<dynamic, dynamic> data, String key) {
  if (data.containsKey(key)) return data[key];
  final normalizedKey = normalizedLooseKey(key);
  for (final entry in data.entries) {
    final entryKey = entry.key?.toString();
    if (entryKey == null) continue;
    if (normalizedLooseKey(entryKey) == normalizedKey) return entry.value;
  }
  return null;
}
