part of 'storage.dart';

Future<AppearanceSettings> _loadAppearanceFor(LocalStore store) async {
  final prefs = await store._ready;
  final decoded = _jsonObjectPreference(prefs, LocalStore._appearanceKey);
  if (decoded == null) {
    return _loadLegacyAppearance(prefs) ?? AppearanceSettings.defaults;
  }
  try {
    return AppearanceSettings.fromJson(decoded);
  } catch (_) {
    return _loadLegacyAppearance(prefs) ?? AppearanceSettings.defaults;
  }
}

Future<void> _saveAppearanceFor(
  LocalStore store,
  AppearanceSettings settings,
) async {
  final prefs = await store._ready;
  await prefs.setString(
      LocalStore._appearanceKey, jsonEncode(settings.toJson()));
  await _removeLegacyAppearancePreferences(prefs);
}

Future<void> _clearAppearanceFor(LocalStore store) async {
  final prefs = await store._ready;
  await prefs.remove(LocalStore._appearanceKey);
  await _removeLegacyAppearancePreferences(prefs);
}
