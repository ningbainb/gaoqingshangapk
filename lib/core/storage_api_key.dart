part of 'storage.dart';

Future<String> _loadAPIKeyFor(LocalStore store) async {
  final prefs = await store._ready;
  final fallback =
      _storedStringPreference(prefs, LocalStore._apiKeyFallbackKey) ?? '';
  try {
    final value = await store._secure.read(key: LocalStore._apiKey);
    return cleanAPIKeyInput(value) ?? fallback;
  } catch (_) {
    return fallback;
  }
}

Future<void> _saveAPIKeyFor(LocalStore store, String key) async {
  final cleanedKey = cleanAPIKeyInput(key);
  final prefs = await store._ready;
  if (cleanedKey == null) {
    try {
      await store._secure.delete(key: LocalStore._apiKey);
    } catch (_) {}
    await prefs.remove(LocalStore._apiKeyFallbackKey);
  } else {
    try {
      await store._secure.write(key: LocalStore._apiKey, value: cleanedKey);
      await prefs.remove(LocalStore._apiKeyFallbackKey);
    } catch (_) {
      await prefs.setString(LocalStore._apiKeyFallbackKey, cleanedKey);
    }
  }
}
