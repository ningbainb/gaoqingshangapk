part of 'storage.dart';

Future<APIConfig> _loadConfigFor(LocalStore store) async {
  final prefs = await store._ready;
  final decoded = _jsonObjectPreference(prefs, LocalStore._settingsKey);
  if (decoded == null) return APIConfig.defaults;
  try {
    return APIConfig.fromJson(decoded);
  } catch (_) {
    return APIConfig.defaults;
  }
}

Future<void> _saveConfigFor(LocalStore store, APIConfig config) async {
  final prefs = await store._ready;
  await prefs.setString(
    LocalStore._settingsKey,
    jsonEncode(config.toJson()),
  );
}

Future<void> _clearConfigFor(LocalStore store) async {
  final prefs = await store._ready;
  await prefs.remove(LocalStore._settingsKey);
}
